#!/usr/bin/env python3
"""Regression tests for bin/db-triage.

These cover the three defects found when db-triage was run against a Neon
PostgreSQL 17 cluster in September 2026, all of which distorted the report:

  1. `platform_skip` was declared in checks/registry.csv but never read, so every
     managed-platform suppression in the catalog was inert. On Neon that produced
     five P1 findings against a healthy database.
  2. The per-database pass ran once per scanned database but `run_psql` ignored
     `dbname` whenever a `--dsn` was given, so it re-scanned the DSN's database N
     times: findings were duplicated N times and the other databases were never
     looked at.
  3. PG-IDX-008's title claimed "large table" while its condition also fires on
     parent write activity, so 8 kB tables were reported as large.

Pure-function tests only: no database, no network, standard library only.

    python3 tests/test_runner.py          # or: python3 -m unittest discover tests
"""

import csv
import json
import importlib.util
import os
import sys
import unittest
from datetime import date, datetime, timedelta, timezone
from importlib.machinery import SourceFileLoader

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_runner():
    """bin/db-triage has no .py extension, so import it by path."""
    path = os.path.join(ROOT, "bin", "db-triage")
    loader = SourceFileLoader("db_triage", path)
    spec = importlib.util.spec_from_loader("db_triage", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


dt = load_runner()


def registry_row(check_id, **over):
    """A registry row with every column bin/db-triage reads, overridable."""
    row = {
        "check_id": check_id, "engine": "postgresql", "category": "BAK",
        "priority": "1", "title": "test check", "scope": "cluster", "cost": "0",
        "pass": "fast", "source": "sql", "min_version": "", "max_version": "",
        "run_on": "any", "requires": "", "platform_skip": "", "platform_priority": "",
        "fix_effort": "S", "fix_risk": "low", "condition": "", "thresholds": "",
        "reads": "pg_settings", "ref": "reference/x.md", "docs_url": "https://example.invalid",
        "status": "active", "since": "0.1.0", "superseded_by": "", "threshold_changed": "",
    }
    row.update(over)
    return row


def finding(check_id, object_=None, details="d", evidence_json=None):
    return {"check_id": check_id, "scope": "cluster", "object": object_,
            "details": details, "evidence_json": evidence_json, "confidence": "high"}


# --------------------------------------------------------------- defect 1

class TestPlatformSkip(unittest.TestCase):
    """A check whose platform_skip names the detected platform must not appear."""

    def setUp(self):
        self.registry = {
            "PG-BAK-001": registry_row("PG-BAK-001", platform_skip="rds;neon;supabase"),
            "PG-WRAP-001": registry_row("PG-WRAP-001", category="WRAP"),
        }

    def test_finding_is_dropped_on_matching_platform(self):
        out, _ = dt.enrich([finding("PG-BAK-001")], self.registry, {}, platform="neon")
        self.assertEqual([f["check_id"] for f in out], [])

    def test_finding_survives_on_a_platform_not_listed(self):
        out, _ = dt.enrich([finding("PG-BAK-001")], self.registry, {}, platform="self-managed")
        self.assertEqual([f["check_id"] for f in out], ["PG-BAK-001"])

    def test_finding_survives_when_platform_is_unknown(self):
        out, _ = dt.enrich([finding("PG-BAK-001")], self.registry, {}, platform=None)
        self.assertEqual([f["check_id"] for f in out], ["PG-BAK-001"])

    def test_unlisted_checks_still_run_on_a_managed_platform(self):
        out, _ = dt.enrich([finding("PG-WRAP-001")], self.registry, {}, platform="neon")
        self.assertEqual([f["check_id"] for f in out], ["PG-WRAP-001"])

    def test_skip_is_recorded_with_a_reason(self):
        skipped = []
        dt.enrich([finding("PG-BAK-001")], self.registry, {}, platform="neon", skipped=skipped)
        self.assertEqual(len(skipped), 1, "the drop must be reported, never silent")
        self.assertEqual(skipped[0]["check_id"], "PG-BAK-001")
        self.assertIn("neon", skipped[0]["reason"])

    def test_skip_is_recorded_once_per_check_not_once_per_finding(self):
        skipped = []
        findings = [finding("PG-BAK-001", "a"), finding("PG-BAK-001", "b"),
                    finding("PG-BAK-001", "c")]
        dt.enrich(findings, self.registry, {}, platform="neon", skipped=skipped)
        self.assertEqual(len(skipped), 1)

    def test_platform_match_is_case_insensitive_and_space_tolerant(self):
        reg = {"PG-BAK-001": registry_row("PG-BAK-001", platform_skip="rds; NEON ;supabase")}
        out, _ = dt.enrich([finding("PG-BAK-001")], reg, {}, platform="neon")
        self.assertEqual(out, [])

    def test_substring_platform_names_do_not_match(self):
        """'neon' must not be matched by a platform called 'neonate'."""
        reg = {"PG-BAK-001": registry_row("PG-BAK-001", platform_skip="neonate")}
        out, _ = dt.enrich([finding("PG-BAK-001")], reg, {}, platform="neon")
        self.assertEqual([f["check_id"] for f in out], ["PG-BAK-001"])


class TestPlatformPriority(unittest.TestCase):
    """platform_priority re-prioritises rather than drops."""

    def test_priority_is_overridden_for_the_detected_platform(self):
        reg = {"PG-MEM-001": registry_row("PG-MEM-001", priority="20",
                                          platform_priority="rds=100;neon=150")}
        out, _ = dt.enrich([finding("PG-MEM-001")], reg, {}, platform="neon")
        self.assertEqual(out[0]["priority"], 150)

    def test_priority_is_untouched_on_other_platforms(self):
        reg = {"PG-MEM-001": registry_row("PG-MEM-001", priority="20",
                                          platform_priority="rds=100")}
        out, _ = dt.enrich([finding("PG-MEM-001")], reg, {}, platform="neon")
        self.assertEqual(out[0]["priority"], 20)

    def test_malformed_entries_are_ignored_rather_than_crashing(self):
        reg = {"PG-MEM-001": registry_row("PG-MEM-001", priority="20",
                                          platform_priority="neon=not-a-number;;garbage")}
        out, _ = dt.enrich([finding("PG-MEM-001")], reg, {}, platform="neon")
        self.assertEqual(out[0]["priority"], 20)


# --------------------------------------------------------------- defect 2

class TestDeduplication(unittest.TestCase):
    """No (check_id, object, details) triple may be emitted more than once."""

    def setUp(self):
        self.registry = {"PG-IDX-008": registry_row("PG-IDX-008", category="IDX",
                                                    priority="50", scope="relation")}

    def test_identical_findings_collapse_to_one(self):
        f = finding("PG-IDX-008", "neondb.public.audit_log", "child 1496 kB")
        out, _ = dt.enrich([f, dict(f)], self.registry, {})
        self.assertEqual(len(out), 1)

    def test_no_duplicate_triples_survive(self):
        f = finding("PG-IDX-008", "neondb.public.audit_log", "child 1496 kB")
        out, _ = dt.enrich([dict(f) for _ in range(5)], self.registry, {})
        triples = [(x["check_id"], x.get("object"), x.get("details")) for x in out]
        self.assertEqual(len(triples), len(set(triples)))

    def test_distinct_objects_are_preserved(self):
        out, _ = dt.enrich([finding("PG-IDX-008", "neondb.public.audit_log", "x"),
                            finding("PG-IDX-008", "neondb.public.calibration_events", "y")],
                           self.registry, {})
        self.assertEqual(len(out), 2)

    def test_same_object_different_details_are_preserved(self):
        """Two constraints on one table are two findings, not one."""
        out, _ = dt.enrich([finding("PG-IDX-008", "neondb.public.services", "fk live_current"),
                            finding("PG-IDX-008", "neondb.public.services", "fk eta_calibration")],
                           self.registry, {})
        self.assertEqual(len(out), 2)

    def test_cluster_scope_findings_with_no_object_dedupe(self):
        out, _ = dt.enrich([finding("PG-IDX-008", None, "same"),
                            finding("PG-IDX-008", None, "same")], self.registry, {})
        self.assertEqual(len(out), 1)


class TestSkipDeduplication(unittest.TestCase):
    """Version and privilege gates report once per database; collapse them."""

    def test_identical_skips_collapse(self):
        reason = "only applies to PostgreSQL 12 and older"
        out = dt.dedupe_skips([{"check_id": "PG-VAC-013", "reason": reason},
                               {"check_id": "PG-VAC-013", "reason": reason}])
        self.assertEqual(len(out), 1)

    def test_same_check_different_reasons_are_kept(self):
        out = dt.dedupe_skips([{"check_id": "PG-REPL-008", "reason": "standby only"},
                               {"check_id": "PG-REPL-008", "reason": "needs 9.6 or newer"}])
        self.assertEqual(len(out), 2)

    def test_order_is_preserved(self):
        out = dt.dedupe_skips([{"check_id": "B", "reason": "r"},
                               {"check_id": "A", "reason": "r"},
                               {"check_id": "B", "reason": "r"}])
        self.assertEqual([s["check_id"] for s in out], ["B", "A"])


class TestDsnDatabaseOverride(unittest.TestCase):
    """The root cause of the duplicates: dbname was ignored whenever a dsn was given."""

    def test_uri_path_is_replaced(self):
        got = dt.dsn_with_database("postgresql://u@host.example/neondb", "postgres")
        self.assertTrue(got.endswith("/postgres"), got)
        self.assertIn("host.example", got)

    def test_uri_query_string_is_preserved(self):
        got = dt.dsn_with_database(
            "postgresql://u@host.example/neondb?sslmode=require", "postgres")
        self.assertIn("sslmode=require", got)
        self.assertIn("/postgres?", got)

    def test_uri_with_no_database_component_gains_one(self):
        got = dt.dsn_with_database("postgresql://u@host.example", "postgres")
        self.assertTrue(got.endswith("/postgres"), got)

    def test_postgres_scheme_alias_is_accepted(self):
        got = dt.dsn_with_database("postgres://u@host.example/neondb", "other")
        self.assertTrue(got.endswith("/other"), got)

    def test_keyword_string_dbname_is_replaced_not_appended(self):
        got = dt.dsn_with_database("host=h port=5432 dbname=neondb", "postgres")
        self.assertIn("dbname=postgres", got)
        self.assertNotIn("dbname=neondb", got)

    def test_keyword_string_without_dbname_gains_one(self):
        got = dt.dsn_with_database("host=h port=5432", "postgres")
        self.assertIn("dbname=postgres", got)
        self.assertIn("host=h", got)

    def test_none_dsn_stays_none(self):
        self.assertIsNone(dt.dsn_with_database(None, "postgres"))

    def test_no_dbname_returns_dsn_unchanged(self):
        self.assertEqual(dt.dsn_with_database("postgresql://u@h/db", None),
                         "postgresql://u@h/db")

    def test_password_in_uri_is_preserved(self):
        got = dt.dsn_with_database("postgresql://u:p%40ss@h/neondb", "postgres")
        self.assertIn("u:p%40ss@h", got)


# --------------------------------------------------------------- defect 3

# --------------------------------------------------------------- derived checks

REAL_REGISTRY = None


def real_registry():
    global REAL_REGISTRY
    if REAL_REGISTRY is None:
        with open(os.path.join(ROOT, "checks", "registry.csv"),
                  newline="", encoding="utf-8") as fh:
            REAL_REGISTRY = {r["check_id"]: r for r in csv.DictReader(fh)}
    return REAL_REGISTRY


def derive(core=None, run=None, findings=None, skipped=None, errors=None, config=None):
    """Call derive_findings with a realistic preflight, returning {check_id: finding}."""
    base_core = {"connected_role": "app", "is_superuser": "f", "has_pg_monitor": "t",
                 "has_read_all_stats": "t", "in_recovery": "f", "version_num": "170010",
                 "version_short": "17.10", "hba_rule_count": "12",
                 "earliest_stats_reset": ""}
    base_core.update(core or {})
    base_run = {"target": "t", "engine": "postgresql", "platform": "self-managed",
                "access": "rung 1", "stats_window": "since x", "server_version": "17.10"}
    base_run.update(run or {})
    out = dt.derive_findings(base_run, {"core": [base_core]}, real_registry(),
                             config or {}, findings or [], skipped or [], errors or [])
    return {f["check_id"]: f for f in out}


class TestTimestampParsing(unittest.TestCase):
    """The format PostgreSQL actually emits must parse, or XX-META-003 never fires."""

    def test_postgres_native_format_with_two_digit_offset(self):
        got = dt.as_datetime("2026-04-28 02:58:23.655268+00")
        self.assertIsNotNone(got, "this is the literal shape psql --csv returns")
        self.assertEqual(got.year, 2026)
        self.assertEqual(got.utcoffset().total_seconds(), 0)

    def test_offset_without_fractional_seconds(self):
        self.assertIsNotNone(dt.as_datetime("2026-09-02 14:00:00+00"))

    def test_colon_separated_offset(self):
        self.assertIsNotNone(dt.as_datetime("2026-09-02 14:00:00+00:00"))

    def test_four_digit_negative_offset(self):
        got = dt.as_datetime("2026-09-02 14:00:00-0400")
        self.assertEqual(got.utcoffset().total_seconds(), -4 * 3600)

    def test_naive_timestamp_is_treated_as_utc(self):
        self.assertEqual(dt.as_datetime("2026-09-02 14:00:00").utcoffset().total_seconds(), 0)

    def test_date_only(self):
        self.assertIsNotNone(dt.as_datetime("2026-09-02"))

    def test_garbage_returns_none_rather_than_raising(self):
        for bad in ("", None, "not a date", "2026-13-45 99:99:99"):
            self.assertIsNone(dt.as_datetime(bad))


class TestVersionTuple(unittest.TestCase):

    def test_numeric_comparison_not_string(self):
        self.assertGreater(dt.version_tuple("17.10"), dt.version_tuple("17.6"))

    def test_major_minor_from_version_num(self):
        self.assertEqual(dt.major_minor("170010"), ("17", 10))
        self.assertEqual(dt.major_minor("160004"), ("16", 4))

    def test_pre_10_returns_nothing(self):
        self.assertEqual(dt.major_minor("90624"), (None, None))

    def test_garbage_returns_nothing(self):
        self.assertEqual(dt.major_minor("abc"), (None, None))
        self.assertEqual(dt.major_minor(None), (None, None))


class TestDerivedAlwaysOn(unittest.TestCase):

    def test_run_metadata_and_credits_always_emit(self):
        got = derive()
        self.assertIn("XX-META-009", got)
        self.assertIn("XX-META-010", got)

    def test_credits_state_the_read_only_promise(self):
        self.assertIn("Read-only", derive()["XX-META-010"]["details"])

    def test_metadata_never_contains_a_password(self):
        got = derive(run={"access": "rung 1: /usr/bin/psql"})
        self.assertNotIn("password", json.dumps(got["XX-META-009"]).lower().replace(
            "no password appears in this report", ""))


class TestPgSec012(unittest.TestCase):
    """The check the whole exercise was named for."""

    def test_fires_on_a_permission_error(self):
        got = derive(errors=[{"check_id": None,
                              "message": "ERROR:  permission denied for function pg_hba_file_rules"}])
        self.assertIn("PG-SEC-012", got)

    def test_names_every_check_it_blinded(self):
        got = derive(errors=[{"message": "permission denied for function pg_hba_file_rules"}])
        d = got["PG-SEC-012"]["details"]
        for cid in ("PG-SEC-001", "PG-SEC-002", "PG-SEC-003", "PG-SEC-006", "PG-SEC-007"):
            self.assertIn(cid, d)

    def test_says_it_is_a_gap_not_a_clean_bill(self):
        got = derive(errors=[{"message": "permission denied for function pg_hba_file_rules"}])
        self.assertIn("not a clean bill of health", got["PG-SEC-012"]["details"])

    def test_fires_when_the_view_returned_nothing_to_a_non_superuser(self):
        got = derive(core={"hba_rule_count": "", "is_superuser": "f"})
        self.assertIn("PG-SEC-012", got)

    def test_silent_when_hba_was_readable(self):
        self.assertNotIn("PG-SEC-012", derive(core={"hba_rule_count": "12"}))

    def test_silent_for_a_superuser_with_no_rules_reported(self):
        got = derive(core={"hba_rule_count": "0", "is_superuser": "t"})
        self.assertNotIn("PG-SEC-012", got)

    def test_is_priority_zero_so_it_is_read_first(self):
        got = derive(errors=[{"message": "permission denied for function pg_hba_file_rules"}])
        self.assertEqual(got["PG-SEC-012"]["priority"], 0)


class TestDerivedMetaChecks(unittest.TestCase):

    def test_standby_fires_in_recovery(self):
        self.assertIn("XX-META-005", derive(core={"in_recovery": "t"}))

    def test_standby_silent_on_a_primary(self):
        self.assertNotIn("XX-META-005", derive(core={"in_recovery": "f"}))

    def test_privilege_ceiling_fires_without_pg_monitor(self):
        got = derive(core={"has_pg_monitor": "f", "has_read_all_stats": "f",
                           "is_superuser": "f"})
        self.assertIn("XX-META-002", got)

    def test_privilege_ceiling_silent_with_pg_monitor(self):
        self.assertNotIn("XX-META-002", derive(core={"has_pg_monitor": "t"}))

    def test_privilege_ceiling_silent_for_superuser(self):
        got = derive(core={"has_pg_monitor": "f", "has_read_all_stats": "f",
                           "is_superuser": "t"})
        self.assertNotIn("XX-META-002", got)

    def test_recent_stats_reset_fires(self):
        recent = (datetime.now(timezone.utc) - timedelta(hours=3))
        got = derive(core={"earliest_stats_reset": recent.strftime("%Y-%m-%d %H:%M:%S+00")})
        self.assertIn("XX-META-003", got)

    def test_old_stats_reset_is_silent(self):
        old = (datetime.now(timezone.utc) - timedelta(days=40))
        got = derive(core={"earliest_stats_reset": old.strftime("%Y-%m-%d %H:%M:%S+00")})
        self.assertNotIn("XX-META-003", got)

    def test_database_cap_fires_and_says_the_rest_are_unknown(self):
        got = derive(run={"databases_capped": "scanned 5 of 20"})
        self.assertIn("XX-META-007", got)
        self.assertIn("not known to be clean", got["XX-META-007"]["details"])

    def test_meta_001_names_the_unimplemented_rows(self):
        got = derive(skipped=[{"check_id": "PG-X", "reason": "standby only"}])
        d = got["XX-META-001"]["details"]
        self.assertIn("PG-CAP-003", d)
        self.assertIn("came back not asked", d)

    def test_platform_meta_006_and_bak_010_fire_together(self):
        got = derive(run={"platform": "neon"},
                     skipped=[{"check_id": "PG-BAK-001", "reason": "platform: neon owns it"}])
        self.assertIn("XX-META-006", got)
        self.assertIn("PG-BAK-010", got)

    def test_no_platform_findings_on_self_managed(self):
        got = derive(run={"platform": "self-managed"})
        self.assertNotIn("XX-META-006", got)
        self.assertNotIn("PG-BAK-010", got)


class TestDerivedVersionChecks(unittest.TestCase):
    """PG-REL-001..004 against a synthetic versions.yml view."""

    def setUp(self):
        self._orig = dt.load_versions
        self.data = {"as_of": date.today().isoformat(),
                     "postgresql": {"majors": {
                         "14": {"eol": "2020-01-01", "latest_minor": "14.19"},
                         "16": {"eol": (date.today() + timedelta(days=90)).isoformat(),
                                "latest_minor": "16.10"},
                         "17": {"eol": "2029-11-08", "latest_minor": "17.6"}}}}
        dt.load_versions = lambda: self.data

    def tearDown(self):
        dt.load_versions = self._orig

    def test_past_eol_fires_rel_001(self):
        got = derive(core={"version_num": "140012", "version_short": "14.12"})
        self.assertIn("PG-REL-001", got)
        self.assertEqual(got["PG-REL-001"]["priority"], 20)

    def test_past_eol_escalates_to_rel_002_when_network_exposed(self):
        got = derive(core={"version_num": "140012"},
                     findings=[{"check_id": "PG-SEC-003"}])
        self.assertIn("PG-REL-002", got)
        self.assertEqual(got["PG-REL-002"]["priority"], 1)

    def test_rel_002_needs_sec_003_to_have_fired(self):
        self.assertNotIn("PG-REL-002", derive(core={"version_num": "140012"}))

    def test_approaching_eol_fires_rel_003(self):
        got = derive(core={"version_num": "160004", "version_short": "16.4"})
        self.assertIn("PG-REL-003", got)
        self.assertNotIn("PG-REL-001", got)

    def test_supported_version_is_silent(self):
        got = derive(core={"version_num": "170006", "version_short": "17.6"})
        for cid in ("PG-REL-001", "PG-REL-002", "PG-REL-003", "PG-REL-004"):
            self.assertNotIn(cid, got)

    def test_two_minors_behind_fires_rel_004(self):
        got = derive(core={"version_num": "160004", "version_short": "16.4"})
        self.assertIn("PG-REL-004", got)

    def test_one_minor_behind_does_not_fire(self):
        got = derive(core={"version_num": "170005", "version_short": "17.5"})
        self.assertNotIn("PG-REL-004", got)

    def test_server_newer_than_registry_does_not_fire_rel_004(self):
        """17.10 > 17.6 numerically; as strings '17.10' < '17.6' and this would misfire."""
        got = derive(core={"version_num": "170010", "version_short": "17.10"})
        self.assertNotIn("PG-REL-004", got)

    def test_server_newer_than_registry_flags_the_registry_as_stale(self):
        got = derive(core={"version_num": "170010", "version_short": "17.10"})
        self.assertIn("XX-META-004", got)
        self.assertIn("has not been refreshed", got["XX-META-004"]["details"])

    def test_stale_versions_file_lowers_rel_confidence(self):
        self.data["as_of"] = (date.today() - timedelta(days=400)).isoformat()
        got = derive(core={"version_num": "140012"})
        self.assertEqual(got["PG-REL-001"]["confidence"], "low")
        self.assertIn("XX-META-004", got)

    def test_fresh_versions_file_keeps_rel_confidence_high(self):
        got = derive(core={"version_num": "140012"})
        self.assertEqual(got["PG-REL-001"]["confidence"], "high")

    def test_pg_9_is_skipped_rather_than_misread(self):
        got = derive(core={"version_num": "90624", "version_short": "9.6.24"})
        for cid in ("PG-REL-001", "PG-REL-003", "PG-REL-004"):
            self.assertNotIn(cid, got)


class TestDerivedBaselineDrift(unittest.TestCase):
    """PG-CFG-005 compares baseline.settings against PG-CFG-001's evidence."""

    def cfg001(self, name, value):
        return {"check_id": "PG-CFG-001", "evidence": {"setting": name, "value": value}}

    def test_differing_value_is_reported(self):
        got = derive(config={"baseline": {"settings": {"work_mem": "64MB"}}},
                     findings=[self.cfg001("work_mem", "4MB")])
        self.assertIn("PG-CFG-005", got)
        self.assertIn("work_mem", got["PG-CFG-005"]["details"])

    def test_matching_value_is_silent(self):
        got = derive(config={"baseline": {"settings": {"work_mem": "64MB"}}},
                     findings=[self.cfg001("work_mem", "64MB")])
        self.assertNotIn("PG-CFG-005", got)

    def test_setting_absent_from_cfg001_is_reported_as_at_default(self):
        got = derive(config={"baseline": {"settings": {"work_mem": "64MB"}}}, findings=[])
        self.assertIn("PG-CFG-005", got)
        self.assertIn("shipped default", got["PG-CFG-005"]["details"])
        self.assertEqual(got["PG-CFG-005"]["confidence"], "medium",
                         "a default-valued setting cannot be confirmed, so not 'high'")

    def test_no_baseline_means_no_finding(self):
        self.assertNotIn("PG-CFG-005", derive(config={}))


class TestDerivedCoverage(unittest.TestCase):
    """Every derived row is either emitted or documented as blocked."""

    def test_no_derived_row_is_silently_unhandled(self):
        derived = {cid for cid, r in real_registry().items()
                   if r["source"] == "derived" and r["status"] == "active"}
        handled = set(dt.UNIMPLEMENTED_DERIVED)
        source = open(os.path.join(ROOT, "bin", "db-triage"), encoding="utf-8").read()
        body = source[source.index("def derive_findings"):source.index("def enrich(")]
        for cid in sorted(derived):
            with self.subTest(check=cid):
                self.assertTrue(cid in handled or ('"%s"' % cid) in body,
                                "%s is source=derived and active, but derive_findings "
                                "neither emits it nor lists it in UNIMPLEMENTED_DERIVED"
                                % cid)

    def test_blocked_rows_each_carry_a_reason(self):
        for cid, reason in dt.UNIMPLEMENTED_DERIVED.items():
            with self.subTest(check=cid):
                self.assertTrue(len(reason) > 20, "%s needs a real reason" % cid)


class TestRegistryTitles(unittest.TestCase):
    """A title must not claim something the check's condition does not require."""

    @classmethod
    def setUpClass(cls):
        with open(os.path.join(ROOT, "checks", "registry.csv"),
                  newline="", encoding="utf-8") as fh:
            cls.rows = {r["check_id"]: r for r in csv.DictReader(fh)}

    def test_idx_008_is_size_only_so_its_title_is_true(self):
        """The original defect: one check with a size OR write-rate condition, titled
        'on a large table'. It is now split, so IDX-008 carries only the size arm and
        the title is accurate again."""
        row = self.rows["PG-IDX-008"]
        self.assertIn("large table", row["title"].lower())
        self.assertIn("min_bytes", row["thresholds"])
        self.assertNotIn("parent_writes", row["thresholds"],
                         "the write arm belongs to PG-IDX-018 now; IDX-008 must not "
                         "keep a threshold that lets an 8 kB table be called large")

    def test_idx_018_carries_the_write_active_arm(self):
        row = self.rows["PG-IDX-018"]
        self.assertIn("write-active", row["title"].lower())
        self.assertIn("parent_writes_per_day", row["thresholds"],
                      "the arm must be a rate, not a lifetime counter")
        self.assertIn("min_child_rows", row["thresholds"])

    def test_the_write_arm_is_a_rate_not_a_lifetime_counter(self):
        """1,290 writes over four months is ~10/day and fired 129 findings. A per-day
        rate with a child-row floor is what stops that."""
        th = dict(p.split("=", 1) for p in self.rows["PG-IDX-018"]["thresholds"].split(";") if p)
        self.assertGreaterEqual(int(th["parent_writes_per_day"]), 1000)
        self.assertGreaterEqual(int(th["min_child_rows"]), 10000)

    def test_the_three_idx_tiers_do_not_overlap(self):
        p = {c: int(self.rows[c]["priority"]) for c in
             ("PG-IDX-008", "PG-IDX-018", "PG-IDX-009")}
        self.assertLess(p["PG-IDX-008"], p["PG-IDX-018"],
                        "a 100 MB child outranks a write-active small one")
        self.assertLess(p["PG-IDX-018"], p["PG-IDX-009"],
                        "a write-active parent outranks the residual tier")

    def test_repl_001_is_not_skipped_wholesale_on_neon(self):
        """Its SQL recognises Neon's walproposer directly, guarded by the
        neon_superuser fingerprint, so a genuinely broken synchronous standby on Neon
        still fires. A blanket platform_skip would have hidden that."""
        self.assertNotIn("neon", dt.split_platforms(self.rows["PG-REPL-001"]["platform_skip"]))
        sql = open(os.path.join(ROOT, "checks", "postgres", "checks",
                                "PG-REPL-001.sql"), encoding="utf-8").read()
        self.assertIn("walproposer", sql)
        self.assertIn("neon_superuser", sql,
                      "the walproposer exemption must be fingerprint-guarded, or the "
                      "same name on a stock cluster would be silently excused")


class TestRegistryIntegrity(unittest.TestCase):
    """Guards against the class of bug where a registry column is silently unused."""

    @classmethod
    def setUpClass(cls):
        with open(os.path.join(ROOT, "checks", "registry.csv"),
                  newline="", encoding="utf-8") as fh:
            cls.rows = list(csv.DictReader(fh))

    def test_every_platform_skip_value_is_a_known_platform(self):
        known = {"rds", "aurora", "cloudsql", "azure", "supabase", "neon", "crunchy",
                 "timescale", "alloydb", "heroku", "planetscale", "self-managed"}
        for r in self.rows:
            for p in dt.split_platforms(r.get("platform_skip")):
                self.assertIn(p, known,
                              "%s lists unknown platform %r in platform_skip"
                              % (r["check_id"], p))

    def test_neon_storage_artifacts_are_skipped_on_neon(self):
        """Verified against a real Neon PostgreSQL 17.10 compute, 2026-09-02.

        Neon replaces the storage layer: the compute node is stateless and
        durability is a safekeeper quorum, so these three are provider-set and
        unchangeable by the tenant (neondb_owner is not a superuser). They are
        skipped on neon ONLY — on RDS, fsync=off is settable through a parameter
        group and would be a real alarm.

        PG-REPL-001 is deliberately NOT in this list: its SQL recognises the
        walproposer directly, which keeps the check alive on Neon for a genuinely
        broken standby. See test_repl_001_is_not_skipped_wholesale_on_neon.
        """
        for cid in ("PG-DUR-001", "PG-DUR-002", "PG-CORR-003"):
            with self.subTest(check=cid):
                row = next(r for r in self.rows if r["check_id"] == cid)
                platforms = dt.split_platforms(row["platform_skip"])
                self.assertIn("neon", platforms)
                self.assertNotIn("rds", platforms,
                                 "%s must not be blanket-skipped on RDS" % cid)

    def test_platform_skip_is_actually_honoured_by_the_runner(self):
        """The defect this suite exists for: the column was parsed by nobody."""
        listed = [r for r in self.rows if r.get("platform_skip", "").strip()]
        self.assertTrue(listed, "precondition: some check declares platform_skip")
        row = listed[0]
        platform = dt.split_platforms(row["platform_skip"])[0]
        reg = {row["check_id"]: row}
        out, _ = dt.enrich([finding(row["check_id"])], reg, {}, platform=platform)
        self.assertEqual(out, [],
                         "%s declares platform_skip=%s but still fired on %s"
                         % (row["check_id"], row["platform_skip"], platform))


if __name__ == "__main__":
    unittest.main(verbosity=2)
