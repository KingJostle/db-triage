# db-triage

**sp_Blitz for PostgreSQL and MySQL.** Point it at a database you have never seen before and
get back a ranked punch list: what will get you fired, what to fix this week, what to plan,
and what is merely worth knowing. It is a first responder — it establishes the patient's
condition and orders the problems. It never treats.

Every finding carries the mechanism, the numbers actually measured, the threshold that was
crossed, an imperative next action, an effort and risk estimate, and a confidence level.
Everything runs read-only, bounded, and identifiable as `db-triage` in `pg_stat_activity`.

```
# db-triage — prod-pg-1 — 2026-09-02 14:31 UTC

**Verdict:** 2 findings need action today; backups unverified. PRIMARY · PostgreSQL 15.6 ·
self-managed · fast mode · 118 checks run, 6 skipped, 1 suppressed · counters cover 41 days.

## 1. Fix first

### 1. [P1] PG-BAK-002 — archive_command is failing — cluster
**What:** pg_stat_archiver reports 4,812 failures; the last failure was at 2026-08-29
03:14 UTC (4 days 11:17:00 ago) on WAL file 0000000100004C3A00000021, and the last
success was 2026-08-29 03:14 UTC. Failing archiving means WAL segments cannot be recycled:
pg_wal grows until the volume fills and the server PANICs.
**Do:** Read the actual error: grep -m5 'archive command failed' <logfile> — it is almost
always credentials, a full destination, or a changed bucket policy. Do not set
archive_command to `true` to clear the backlog: that is PG-BAK-004 and it destroys the
archive silently.
**Validate:** SELECT now()-last_archived_time, failed_count FROM pg_stat_archiver;
**If it goes wrong:** at the current WAL rate the volume fills in ~9 days, after which the
primary PANICs. Without archives, PITR already ends at 2026-08-29 03:14.
**Effort / risk:** S / low · Ref: reference/checks-postgres.md#pg-bak-002
```

## The safety contract

This is the part to read before pointing it at production.

| Promise | How it is enforced |
|---|---|
| **Read-only, always.** | The session opens with `SET default_transaction_read_only = on`, so a mistake fails rather than writes. |
| **Bounded.** | `statement_timeout` 10 s (fast) / 60 s (deep), `lock_timeout` 2 s, so no catalog read queues behind DDL and nothing runs away. |
| **Identifiable.** | `application_name = 'db-triage/<version>'`. Your DBA can see the run and cancel it. |
| **Never mutates anything, including statistics.** | No `VACUUM`, `ANALYZE`, `REINDEX`, `CHECKPOINT`, `pg_stat_reset*`, `pg_terminate_backend`, `ALTER SYSTEM`, `CREATE EXTENSION`, or temp tables — the whole repository is lint-checked for this by `bin/build.py --check`. |
| **No heavy scans.** | No check reads user table *data*. `count(*)` on user tables is forbidden. Bloat is estimated from the catalog; measuring it is a deep-pass, opt-in, per-relation choice. |
| **Never acts on your behalf.** | Every "next action" is text. If db-triage suggests `VACUUM FREEZE`, you run it. |
| **Never reads secrets.** | Password hashes are tested for null only, never echoed. `primary_conninfo` is redacted. Connection strings never reach a report. |

The one file that writes is `tests/fixtures/postgres-provoke.sql`, which exists to create
findings on purpose. It carries a loud header and refuses to run against a database whose
name does not look like a throwaway.

## Priority bands

One integer, lower is worse, shared across every category — so a security finding, a vacuum
finding and a backup finding interleave correctly in one list.

| P | Band | Meaning |
|---|---|---|
| 0 | Meta | The run itself is incomplete or its inputs are unreliable. Read first. |
| 1 | You get fired | Data loss or a hard outage is happening or is hours away. |
| 5 | One step from fired | Becomes a P1 within days without action. |
| 10 | Active harm | Hurting users now, or a setting that turns a routine event into an outage. |
| 20 | Known-dangerous | Needs a plan this month. |
| 50 | Daily-briefing ceiling | Worth fixing this week. The documented cut-off for an unattended job. |
| 100 | Tuning detail | Fix when convenient. |
| 150 | Hygiene | Worth a look; may be intentional. |
| 200–255 | Inventory | Non-default config, security review, workload profile, environment, metadata. Not problems. |

Ceilings: `--max-priority 10` pages someone; `--max-priority 50` is the daily job;
`--max-priority 150` is the weekly review; no filter is the consulting deliverable.
Full table: [`reference/priorities.md`](reference/priorities.md). Full catalog:
[`docs/Checks_by_Priority.md`](docs/Checks_by_Priority.md).

## 60-second quick start

### As a Claude skill

One command, then ask for a database health check:

```
git clone https://github.com/<owner>/db-triage.git ~/.claude/skills/db-triage
```

Claude Code reads personal skills from `~/.claude/skills/<name>/SKILL.md`, and `SKILL.md`
sits at this repository's root — so the clone lands it in the right place with `checks/`
and `reference/` beside it. Restart Claude Code (or `/reload-plugins`), then `/db-triage`.
For a team repository, clone into that repository's `.claude/skills/db-triage` and commit
it, so everyone working there gets it.

Or install it as a plugin, which also works from the plugin browser in the Claude desktop
app:

```
/plugin marketplace add <owner>/db-triage
/plugin install db-triage@db-triage
```

The non-interactive equivalent: `claude plugin install db-triage@<owner>/db-triage
--scope user`.

Either route gives the same skill. `SKILL.md` is self-sufficient — with only that file and
a DSN, Claude runs a correct fast pass and produces a correctly formatted report — but with
the repository present it runs the full 376-check catalog and cites the per-check
reference. The skill looks for `checks/registry.csv` beside `SKILL.md` (clone layout) and
two levels up (plugin layout, where the file is `skills/db-triage/SKILL.md`), and says in
the report's META row which of the two passes it actually ran.

`skills/db-triage/SKILL.md` is a generated copy of the root `SKILL.md`, written by
`bin/build.py`. Edit the root file; `bin/build.py --check` fails if the copy has drifted.

### As a CLI

Needs Python 3.9+ and the `psql` you already have. No database driver, no install.

```
git clone https://github.com/<owner>/db-triage.git && cd db-triage
export PGHOST=... PGUSER=readonly PGDATABASE=appdb      # or use --dsn
./bin/db-triage --format markdown --out report.md
```

Useful variants:

```
./bin/db-triage --format summary                        # the 10-minute deliverable
./bin/db-triage --mode inventory                        # "describe this estate"
./bin/db-triage --max-priority 50 --fail-priority 10 \
                --format jsonl --out daily.jsonl        # scheduled job; exit 1 pages someone
./bin/db-triage --all-databases --format markdown       # every database, not the largest five
```

Ask for `pg_monitor`, not superuser:

```sql
CREATE ROLE db_triage LOGIN PASSWORD '...';   -- run this yourself; db-triage never does
GRANT pg_monitor TO db_triage;
```

### Paste mode, when you have no access at all

Hand the DBA one command and read what comes back:

```
psql "$DSN" -X -q -f checks/postgres/fast-cluster.sql --csv > triage.csv 2>&1
./bin/db-triage --offline triage.csv --format markdown
```

The pasted output and the live run go through the same evaluation path, so the report is
the same report.

## What it is not

Not a tuning tool, not a monitoring system, not a corruption checker, not a query tuner. It
reports signals and points at the tool that goes deeper: `EXPLAIN (ANALYZE, BUFFERS)` for a
statement it names, `pgstattuple_approx` before you act on an estimated-bloat finding,
`pg_amcheck` when it reports a collation mismatch, and a real restore test for anything in
the backup category.

It also will not guess passwords, estimate restore time from nothing, analyse deadlock
graphs, or invent an index definition. It points at the table and the statements and stops.

## Repository layout

```
SKILL.md                          Claude entry point; self-sufficient for a fast pass
skills/db-triage/SKILL.md         GENERATED copy of the above, for the plugin layout
.claude-plugin/                   plugin.json + marketplace.json, for /plugin install
checks/registry.csv               THE catalog: one row per check, all metadata
checks/postgres/
  01_session.sql                  the read-only contract, sourced before every batch
  00_preflight.sql                version, role, privileges, platform, database list
  checks/PG-*.sql                 one file per check, the canonical query
  fast-cluster.sql  fast-database.sql  inventory.sql   GENERATED runnable passes
  embedded-fast.sql               GENERATED into SKILL.md
  lib/                            bloat estimators, unit handling, threshold defaults
reference/
  checks-postgres.md              one anchored section per check: why, confirm, fix, caveats
  priorities.md  categories.md  methodology.md  platforms.md
  versions.yml  report-template.md  config-example.yml  extending.md
bin/db-triage                     the CLI
bin/build.py                      validates and regenerates everything derived
docs/Checks_by_Priority.md        GENERATED human catalog
examples/                         a real report, real JSONL, a paste-mode transcript
tests/fixtures/                   SQL that provokes findings (the only file that writes)
```

## Credits

db-triage is **modelled on the methodology of Brent Ozar's SQL Server First Responder Kit**,
in particular `sp_Blitz`: a single integer priority shared across categories, a reserved P1
band, a documented ceiling for unattended jobs, stable check IDs that are never reused,
details built from the values actually found, a reserved high band for descriptive rows,
suppression that lives outside the tool, and "first responder, not surgeon".

**No code was copied.** The First Responder Kit is T-SQL against SQL Server DMVs, none of
which is portable; every check here was derived from how PostgreSQL and MySQL actually fail
and written against their own catalogs. **db-triage is not affiliated with, endorsed by, or
supported by Brent Ozar Unlimited.** If you run SQL Server, use the First Responder Kit
itself: <https://www.brentozar.com/first-aid/>.

The bloat estimators in `checks/postgres/lib/` were re-derived from PostgreSQL's documented
page layout rather than adapted from an existing implementation, and each carries its own
error bars.

MIT licensed. See [`CONTRIBUTING.md`](CONTRIBUTING.md) before proposing a check — the
false-positive story has to be agreed before the SQL is written.
