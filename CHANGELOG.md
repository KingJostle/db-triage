# Changelog

## [Unreleased]

### Added
- **The derived-check engine.** Nineteen registry rows carry `source=derived` and the CLI
  evaluated none of them: they were rows in a catalog that nothing ever produced.
  `derive_findings()` now emits **16** of the 19 from the preflight, the run bookkeeping and
  `reference/versions.yml`:
  - `PG-SEC-012` — the authentication posture was not verified. Previously a Neon or RDS run
    printed four bare `permission denied for function pg_hba_file_rules` errors with check_id
    `?` and left the reader to work out that `PG-SEC-001/002/003/006/007` had therefore not
    evaluated. It now says so in the P0 band, names every check it blinded, and states that
    their absence is a gap rather than a clean bill of health.
  - `PG-REL-001`/`002`/`003`/`004` — major version past EOL, EOL *and* network-exposed,
    within 180 days of EOL, and minor releases behind, read from `reference/versions.yml`.
    They drop to `confidence: low` when that file is stale, as designed.
  - `XX-META-001` through `XX-META-007` — checks skipped, privilege ceiling, statistics reset
    within 24 h, stale version data, standby target, managed platform, and partial database
    coverage. Plus `XX-META-009`/`010` (run metadata, credits) and `PG-BAK-010`.
  - `PG-CFG-005` — drift from `baseline.settings`, derived from `PG-CFG-001`'s evidence. It
    reports settings the baseline names that sit at the server default as differing but
    unconfirmable, at `confidence: medium`, rather than pretending it can see them.
  The three remaining rows are named in `XX-META-001` with the reason each is blocked
  (`PG-CAP-003`/`PG-CAP-006` need `--save`/`--compare`, which do not exist; `PG-CORR-008` is
  retired by design). A test fails if a future derived row is neither emitted nor documented
  as blocked — the whole point being that a check which did not run must never read as one
  that came back clean.
- Markdown rendering for the P254 and P255 bands, which previously had no section at all, so
  a finding in either was counted but invisible.

### Fixed
- **`as_datetime()` could not parse the timestamp PostgreSQL actually emits.**
  `2026-04-28 02:58:23.655268+00` failed on both the fractional seconds and the two-digit
  UTC offset, which `%z` does not accept, so `XX-META-003` would have stayed silent forever.
  Caught by writing the test before trusting the parser.
- **`platform_skip` was never read.** The column had been in `checks/registry.csv` since
  0.1.0 and no code parsed it, so every managed-platform suppression in the catalog was
  inert. `bin/db-triage` now applies it: the check is dropped, listed in Appendix A with
  reason `platform`, and named in `XX-META-006` so a skipped check is never mistaken for a
  clean one. `platform_priority` is now honoured too (format `rds=100;neon=150`), though no
  row uses it yet.
- **The per-database pass never changed database.** `run_psql` ignored its `dbname`
  argument whenever `--dsn` was given, because the DSN carries its own database. Scanning an
  estate therefore re-ran the per-database pass against the DSN's database once per
  database: its findings were duplicated N times, **and every other database was silently
  never examined** while the report listed it as scanned. New `dsn_with_database()` rewrites
  the database in both URI and keyword DSN forms. Findings are additionally de-duplicated on
  `(check_id, object, details)`, and skip records on `(check_id, reason)`.
- **`PG-IDX-008` was titled "Unindexed foreign key on a large table"** while its condition
  fires on `child ≥ 100 MB` **OR** `parent writes ≥ 1000`. On a real database where no child
  table reached 8 MB, all 129 findings fired on the write-activity arm and the report called
  8 kB tables large. Retitled to "Unindexed foreign key on a large or write-active table".
  The `details` string already named both thresholds and is unchanged.
- Paste mode now reads the platform from preflight output when the paste contains it, and
  says in its caveats when it does not. The rung-4 command in `SKILL.md` is two lines now:
  preflight, then the fast pass.

### Changed
- `PG-DUR-001` (fsync), `PG-DUR-002` (full_page_writes), `PG-CORR-003`
  (ignore_checksum_failure) and `PG-REPL-001` (no synchronous standby) now carry
  `platform_skip=neon`. Neon replaces the storage layer: the compute node is stateless,
  durability is a safekeeper quorum, and `neondb_owner` is not a superuser and cannot change
  any of them. `PG-REPL-001` is the sharpest case — Neon sets
  `synchronous_standby_names = 'walproposer'`, and the walproposer never appears in
  `pg_stat_replication`, so the check reported "every commit is hanging" against a cluster
  serving traffic normally. Skipped on `neon` **only**: on RDS `fsync = off` is reachable
  through a parameter group and remains a P1. Verified against Neon PostgreSQL 17.10 on
  2026-09-02, where this took the P1 band from five false positives to empty.

### Added
- `tests/test_runner.py` — 33 pure-function regression tests for `bin/db-triage`, covering
  all three defects above. No database, no network, standard library only.
- `.claude-plugin/marketplace.json` and `.claude-plugin/plugin.json`, so the repository is
  installable with `/plugin marketplace add <owner>/db-triage` and `/plugin install
  db-triage@db-triage` — the route that also works from the Claude desktop plugin browser.
  Validated with `claude plugin validate` (CLI 2.1.257).
- `skills/db-triage/SKILL.md`, a generated copy of the root `SKILL.md` for the plugin
  layout. `bin/build.py` writes it; `bin/build.py --check` fails if it has drifted, so the
  two install routes cannot ship different skills under one name.
- `bin/build.py` now validates `SKILL.md` frontmatter: the opening `---` must be line 1, a
  `description` must be present and within the 1536-character budget, and no key may fall
  outside the set claude.ai accepts on upload.

### Changed
- `SKILL.md` frontmatter: `version: 0.1.0` moved under `metadata:`. Claude Code ignores
  unknown top-level keys, but the claude.ai packaging step rejects any key outside
  `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools` — so the
  old frontmatter would have failed an upload. `VERSION` remains the source of truth.
- `SKILL.md` §9 now locates `checks/registry.csv` in both layouts — beside `SKILL.md` in a
  clone, or two levels up in the plugin layout — instead of assuming the clone layout.

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
