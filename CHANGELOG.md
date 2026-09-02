# Changelog

All notable changes to db-triage are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and db-triage uses
[semantic versioning](https://semver.org/) with two project-specific rules:

- **A threshold change is a minor version bump** and gets an entry here naming the check,
  the old value, the new value and the evidence for the change. The check row's
  `threshold_changed` column is set to the same version.
- **Changing a check's *meaning* is not a threshold change.** It retires the check ID and
  issues a new one, because suppression lists and trend tracking in the wild key on IDs.

## [Unreleased]

## [0.1.0] — 2026-09-02

First release. PostgreSQL is complete; MySQL and MariaDB ship alongside it.

### Added

- **The check registry** (`checks/registry.csv`): 216 PostgreSQL and engine-agnostic rows
  across 19 categories, each with its priority, scope, cost, pass, source, version and
  role gating, platform adaptations, thresholds, condition text, reference anchor and
  official documentation link. This is the catalog of record; everything else is generated
  from it or validated against it.
- **186 PostgreSQL check queries** (`checks/postgres/checks/`), each returning the fixed
  column set `check_id, scope, object, details, evidence_json, confidence`, with `details`
  built from the values actually measured.
- **The read-only session contract** (`checks/postgres/01_session.sql`):
  `default_transaction_read_only`, statement and lock timeouts, an identifiable
  `application_name`, enforced before every batch and lint-checked across the repository by
  `bin/build.py --check`.
- **Generated pass files**: `fast-cluster.sql` (108 checks), `fast-database.sql` (46),
  `inventory.sql` (32), and the deep-pass shells. Each check is bracketed by `@@CHECK` and
  `@@END` markers and gated on server version and node role, so a check that does not apply
  prints `@@SKIP` rather than erroring.
- **Catalog-only bloat estimators** (`checks/postgres/lib/bloat_table.sql`,
  `bloat_btree.sql`), re-derived from PostgreSQL's documented page layout with their error
  bars written into the file. No third-party estimator source was copied.
- **`SKILL.md`**, self-sufficient: the safety contract, the access ladder including paste
  mode, preflight, the session block, the priority bands, the finding model, the report
  template and a compact embedded fast pass covering every check at priority 10 or below.
- **`bin/build.py`**: validates registry against check files, reference anchors, threshold
  declarations, read-only compliance and the embedded pass; regenerates the pass files,
  `docs/Checks_by_Priority.md`, the merged registry and the SKILL.md block.
- **`bin/db-triage`**: stdlib-only CLI driving `psql`, with `markdown`, `jsonl`, `csv` and
  `summary` output, `--offline` for paste mode, `.db-triage.yml` thresholds and
  suppression, and `--fail-priority` for scheduled runs.
- **`reference/checks-postgres.md`**: one anchored section per check — what fires it, why
  it matters, how to confirm it independently, how to fix it safest-first, and what would
  make the finding wrong.
- **`tests/fixtures/postgres-provoke.sql`**: deliberately creates an invalid index, a
  duplicate index, an unused index, a table with no primary key, a near-exhausted sequence,
  a bloated unvacuumed table, an unindexed foreign key, an inactive replication slot and
  several security findings. The only file in the repository that writes.

### Verified

Every PostgreSQL check file, the three generated pass files and the embedded fast pass were
executed against a live PostgreSQL 16.13 cluster with `pg_stat_statements` installed, on
both a near-default database and the fixture database. See `tests/README.md` for what was
and was not exercised.

### Known gaps

- `PG-IDX-016` (GIN pending list) is `status=planned`: it needs `pgstatginindex()` from the
  `pgstattuple` extension and reads index pages, so it is a deep-pass check that could not
  be verified here.
- The deep pass contains no SQL checks: every cost-2 PostgreSQL check in this release reads
  the server log or the host, so `deep-cluster.sql` and `deep-database.sql` are empty
  shells and the log-reading checks are declared but not implemented.
- `PG-CAP-001`, `PG-CAP-002`, `PG-CAP-003`, `PG-CAP-006`, `PG-INFO-002`, `PG-CFG-005`,
  `PG-REL-001` through `PG-REL-004` and `PG-BAK-008` are `source` other than `sql`: they
  need a host helper, a saved snapshot, `versions.yml` or an interview answer, and the CLI
  does not yet evaluate them.
- Only PostgreSQL 16 was available for verification. The version gating for 11–15 and 17 is
  written from the documented catalog changes and is **not** tested.
