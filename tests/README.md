# Tests

## What is here

| File | Purpose |
|---|---|
| `fixtures/postgres-provoke.sql` | **The only file in this repository that writes.** It deliberately creates the conditions db-triage detects, so the checks can be exercised against a real server instead of against a mock. |
| `test_runner.py` | Pure-function regression tests for `bin/db-triage`: no database, no network, standard library only. Run with `python3 tests/test_runner.py`. |

```bash
python3 tests/test_runner.py        # 30 tests, ~0.01s
```

`test_runner.py` covers the three defects found when db-triage was first run against a
managed platform (Neon, 2026-09-02), each of which distorted the report:

1. **`platform_skip` was declared but never read.** Every managed-platform suppression in
   the catalog was inert. On Neon that produced five P1 findings against a healthy database.
2. **The per-database pass never changed database.** `run_psql` ignored its `dbname`
   argument whenever a `--dsn` was given, so it re-scanned the DSN's own database once per
   database in the estate: findings were duplicated N times *and every other database was
   silently never looked at* while the report claimed it had been. This is the worse half of
   the bug — the duplicates were merely the visible symptom.
3. **`PG-IDX-008`'s title contradicted its condition**, calling an 8 kB table "large".

There is no compose matrix and no expected-output fixture set in this release. What exists
instead is documented below: the exact verification that was performed, and — just as
importantly — what was not.

## Running the pass against a container

```bash
# 1. Start a throwaway server. Any supported major will do; 16 is what this was verified on.
docker run -d --name pg-triage \
  -e POSTGRES_PASSWORD=triage -e POSTGRES_HOST_AUTH_METHOD=trust \
  -p 5439:5432 postgres:16 \
  -c shared_preload_libraries=pg_stat_statements \
  -c track_io_timing=on \
  -c logging_collector=on

export PGHOST=localhost PGPORT=5439 PGUSER=postgres

# 2. A pristine run. This is the baseline assertion: a default install should produce
#    only the documented findings and nothing unexpected at P<=20.
psql -X -q -c "CREATE EXTENSION pg_stat_statements;"     # a write: yours to run, not db-triage's
../bin/db-triage --format summary

# 3. Apply the fixtures to a throwaway database and run again.
createdb triage_test
psql -d triage_test -q -f fixtures/postgres-provoke.sql
../bin/db-triage --format summary

# 4. Run the generated passes directly, which is what paste mode does.
psql -X -q -f ../checks/postgres/fast-cluster.sql  --csv > /tmp/fc.csv 2>&1
psql -d triage_test -X -q -f ../checks/postgres/fast-database.sql --csv > /tmp/fd.csv 2>&1
psql -d triage_test -X -q -f ../checks/postgres/inventory.sql --csv > /tmp/inv.csv 2>&1
grep -E 'ERROR|FATAL' /tmp/fc.csv /tmp/fd.csv /tmp/inv.csv     # must be empty

# 5. Round-trip the paste-mode path.
../bin/db-triage --offline /tmp/fc.csv --format summary
```

Several fixture findings sit below the production thresholds on purpose — a 92 MB bloated
table is not a 1 GB one. Lower them at the command line to see those checks fire:

```bash
../bin/db-triage --format summary \
  --config /dev/null 2>/dev/null      # or use a config with a `thresholds:` block
psql -d triage_test -X -q \
  -v pg_vac_006_min_bytes=1048576 -v pg_vac_006_wasted_bytes=1048576 \
  -v pg_idx_002_min_bytes=1 -v pg_idx_002_stats_age_days=0 \
  -f ../checks/postgres/lib/thresholds.sql \
  -f ../checks/postgres/01_session.sql \
  -f ../checks/postgres/checks/PG-VAC-006.sql \
  -f ../checks/postgres/checks/PG-IDX-002.sql --csv
```

Two findings need a second session and cannot be provoked by a script alone:

```bash
# PG-LOCK-003 (idle in transaction) — leave this sitting in another terminal:
psql -c "BEGIN; SELECT 1;" -c "SELECT pg_sleep(3600);"

# PG-LOCK-001 (blocking chain) — one session locks, another waits:
psql -d triage_test -c "BEGIN; LOCK TABLE triage_fixture.orders IN ACCESS EXCLUSIVE MODE; SELECT pg_sleep(600);" &
psql -d triage_test -c "SELECT count(*) FROM triage_fixture.orders;" &
```

Clean up: `dropdb triage_test`, `psql -c "SELECT pg_drop_replication_slot('triage_fixture_dead_slot');"`,
`docker rm -f pg-triage`.

---

## What was actually verified for release 0.1.0

**Server: PostgreSQL 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1), x86-64, self-managed**, with
`pg_stat_statements` 1.10 installed and preloaded, `track_io_timing = on`,
`logging_collector = on`, connected as a superuser.

| What | Result |
|---|---|
| All 186 PostgreSQL check files, run individually against a near-default database | 186 pass, 0 errors |
| All 186 run individually against the fixture database | 186 pass, 0 errors |
| `fast-cluster.sql` (108 checks) end to end | exit 0, no `ERROR`/`FATAL`, 105 `@@CHECK` markers, 3 `@@SKIP` (standby-only checks correctly gated) |
| `fast-database.sql` (46 checks) against the fixture database | exit 0, no errors, 12 checks fired |
| `inventory.sql` (32 checks) against the fixture database | exit 0, no errors, 36 rows |
| `embedded-fast.sql` (the SKILL.md block) | exit 0, no errors, fires correctly |
| `bin/db-triage` in `markdown`, `jsonl`, `csv` and `summary` | all render; `--offline` round-trip reproduces the same findings |
| `--fail-priority` exit codes | 1 when a finding is at or below the threshold, 0 otherwise |
| `bin/build.py --check` | exits 0 clean; verified to exit 1 on an injected `UPDATE` and an injected `pg_terminate_backend()` |
| Read-only lint | 350 `.sql` files scanned across both engines, no mutating statement outside `tests/fixtures/` |
| Threshold override path | `psql -v` overrides confirmed to win over the generated defaults |
| Suppression path | a `skip:` rule with a `reason` and an `until` correctly marks findings suppressed and lists them in Appendix B |

**Findings confirmed to fire correctly against the fixture**, with the object each named:

`PG-IDX-001` (invalid index `dupes_k_uniq`, left by a failed `CREATE UNIQUE INDEX
CONCURRENTLY`) · `PG-IDX-002`/`003` (unused index) · `PG-IDX-004` (duplicate index pair) ·
`PG-IDX-005` (two prefix-overlapping indexes) · `PG-IDX-008`/`009` (unindexed foreign key
`order_lines.order_id`) · `PG-IDX-010` (heavy sequential scans) · `PG-IDX-012` (write-heavy
table with many indexes) · `PG-IDX-015` (low-cardinality index) · `PG-VAC-003` (dead tuples)
· `PG-VAC-006`/`007` (estimated bloat — **90.0 % on a table where exactly 90 % of rows were
deleted, which is the estimator's accuracy check**) · `PG-VAC-009` (autovacuum disabled by
storage parameter) · `PG-SCHEMA-001` (sequence at 97.8 % of its int4 range) · `PG-SCHEMA-003`
(no primary key) · `PG-SCHEMA-008` (`NOT VALID` constraint) · `PG-SCHEMA-009` (trigger on a
hot table) · `PG-SCHEMA-010` (relation count) · `PG-SCHEMA-011` (unpopulated materialized
view) · `PG-SEC-013` (PUBLIC CREATE on `public`) · `PG-SEC-014` (SECURITY DEFINER without
`search_path`) · `PG-SEC-015`/`016` (PUBLIC grants) · `PG-DUR-005` (unlogged table) ·
`PG-REPL-004`/`009` (inactive slot, unbounded retention) · `PG-LOCK-001` (a real blocking
chain, root blocker identified) · `PG-LOCK-005` (long open transaction) · `PG-CONN-008`
(sessions waiting on locks) · `PG-VAC-005` (xmin horizon, holder named) · `PG-CORR-004`,
`PG-CORR-007`, `PG-BAK-001`, `PG-MEM-001`, `PG-MEM-003`, `PG-MEM-006`, `PG-MEM-007`,
`PG-MEM-009`, `PG-REL-005`, `PG-REL-006`, `PG-REL-007`, `PG-REL-009`, `PG-QRY-003`,
`PG-QRY-010` (regex patterns, provoked with real statements), `PG-INFO-*`.

**Baseline on a near-default cluster** (the "no false alarms" assertion): the only findings
at P≤20 were `PG-BAK-001` (P1, no archiving — correct for a default install),
`PG-MEM-001` (P20, `shared_buffers` at 128 MB — correct), and `PG-REL-005` (P10, restarted
within 24 hours — correct, the cluster had just been started). No unexpected finding at or
below P20.

---

## What was NOT verified, and why

Read this before trusting the version gating.

| Not verified | Why | Risk |
|---|---|---|
| **PostgreSQL 11, 12, 13, 14, 15, 17, 18** | Only a 16.13 server was available in the build environment. | The version branches are written from the documented catalog changes and are **untested**. The specific risks: the `pg_stat_checkpointer` branch (PostgreSQL 17) in `PG-WAL-001`, `PG-WAL-009` and `PG-INFO-008`; the `pg_stat_bgwriter` branch below 16 in `PG-WAL-004`; the `pg_stat_statements` pre-1.8 branch (PostgreSQL 12 and older) in every `QRY` check; `PG-VAC-013`'s `max_version` gate. Each is a `\if` on a `\gset` probe, so a wrong branch produces a psql error next to its `@@CHECK` marker rather than a wrong answer — but it has not been seen. |
| **A standby** | No replica was built. | `PG-REPL-008`, `PG-REPL-011`, `PG-REPL-016` and the standby-side behaviour of every `run_on` gate were exercised only through their gating (they correctly printed `@@SKIP` on a primary), not through their SQL. |
| **A managed platform other than Neon** | None reachable. | The fingerprints in `00_preflight.sql` and `reference/platforms.md` are written from published role and setting names and are **not** confirmed against a current RDS, Aurora, Cloud SQL, Azure, Supabase, Timescale or Heroku instance. **Neon is now the exception**: verified 2026-09-02 against PostgreSQL 17.10, where the `neon_superuser` fingerprint matched, `platform_skip` correctly suppressed 8 checks, and the P1 band went from 5 false positives to empty. |
| **`PG-IDX-016`** (GIN pending list) | Needs `pgstatginindex()` from `pgstattuple`, and reads index pages. | Marked `status=planned` in the registry. No SQL file exists; `bin/build.py` reports it rather than failing. |
| **The deep pass** | Every cost-2 PostgreSQL check reads the server log or the host. | `deep-cluster.sql` and `deep-database.sql` are generated with **zero checks**. `PG-VAC-011`, `PG-CORR-005`, `PG-REL-011` and `PG-REL-014` are declared in the registry with `source=log` and are not implemented. |
| **Host and interview checks** | Need a shell on the database host, a saved snapshot, or a recorded answer. | `PG-CAP-001`, `PG-CAP-002`, `PG-CAP-003`, `PG-CAP-006`, `PG-INFO-002`, `PG-BAK-008`, `PG-BAK-009`, `PG-CFG-005` and `PG-REL-001` through `PG-REL-004` are registry rows the CLI does not yet evaluate. They are reported as skipped rather than as clear. |
| **Non-ASCII identifiers** | Not in the fixture. | Object names are emitted through `format('%I.%I.%I', ...)`, which was spot-checked against a table named `"Weird.Name tbl"` and quoted it correctly. Non-ASCII names, and identifiers longer than 63 bytes, were not tested. |
| **`versions.yml` dates** | Transcribed from the published support policies rather than fetched. | `XX-META-004` exists precisely to nag about this, and the `REL` findings drop to `confidence: low` when the file is stale. |
| **Very large estates** | The fixture database is 168 MB. | The `> 50,000 relations` sampling path (`XX-META-007`) and the cost-1 checks' behaviour at that scale are untested. |

## Adding a test

`test_runner.py` asserts against the runner's pure functions and against `registry.csv`
itself; there is still no assertion framework for the **SQL checks**, which need a live
server. For runner or registry behaviour, add a case to `test_runner.py`. For a new check,
the honest minimum is:

1. Add a fixture statement that makes it fire, and list it in the fixture's summary block.
2. Run the check file directly and confirm the `details` string contains the measured values
   and not a boilerplate sentence.
3. Run it against a database where it should *not* fire and confirm zero rows.
4. Run it on the oldest and newest supported majors.
5. Record what you verified, and what you could not, in the table above.

Step 5 is the one that matters. A test suite that quietly does not cover something is the
same failure mode as a health check that quietly skips something.
