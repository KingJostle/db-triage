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
import importlib.util
import os
import sys
import unittest
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

class TestRegistryTitles(unittest.TestCase):
    """A title must not claim something the check's condition does not require."""

    @classmethod
    def setUpClass(cls):
        with open(os.path.join(ROOT, "checks", "registry.csv"),
                  newline="", encoding="utf-8") as fh:
            cls.rows = {r["check_id"]: r for r in csv.DictReader(fh)}

    def test_idx_008_title_does_not_promise_a_large_table(self):
        row = self.rows["PG-IDX-008"]
        self.assertIn("OR", row["condition"].upper(),
                      "precondition for this test: the check has a two-armed condition")
        self.assertNotIn("large table", row["title"].lower(),
                         "the condition also fires on parent write activity, so a finding "
                         "can name an 8 kB table; the title must not call it large")

    def test_idx_008_title_covers_the_write_active_arm(self):
        title = self.rows["PG-IDX-008"]["title"].lower()
        self.assertTrue("write-active" in title or "write active" in title,
                        "title should name the arm that actually fires most often: %r" % title)


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
        durability is a safekeeper quorum, so these four are provider-set and
        unchangeable by the tenant (neondb_owner is not a superuser). They are
        skipped on neon ONLY — on RDS, fsync=off is settable through a parameter
        group and would be a real alarm.
        """
        for cid in ("PG-DUR-001", "PG-DUR-002", "PG-CORR-003", "PG-REPL-001"):
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
