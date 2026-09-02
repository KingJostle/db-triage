# Priority model

One integer sort key, 0–255, lower is worse, shared by every category. That is the whole
point: a security finding, a vacuum finding and a backup finding have to interleave
correctly in a single ranked list, and they can only do that if they are measured on the
same scale.

The integers actually used are sparse — **0, 1, 5, 10, 20, 50, 100, 150, 200, 230, 240,
250, 254, 255** — so a future check can be slotted between two existing ones without
renumbering anything.

## The bands

| P | Band | One-line meaning | PostgreSQL examples |
|---|---|---|---|
| **0** | Meta | The run itself is incomplete, or its inputs are unreliable. Read these before believing anything else. | Checks skipped for privilege; statistics reset 3 h ago; the target is a standby; `pg_hba.conf` unreadable. |
| **1** | You get fired | Data loss or a hard outage is happening, or is hours to days away. Drop everything. | XID age ≥ 1.5 B; `fsync=off`; `full_page_writes=off`; `archive_command` failing; synchronous replication configured with no sync standby (commits hang); checksum failures reported; `zero_damaged_pages=on`; inactive slot retaining > 10 GB; `trust` reachable over the network. |
| **5** | One step from fired | Posture that becomes a P1 within days without action. | `autovacuum=off`; `track_counts=off`; replica lag > 5 min or > 1 GB; orphaned prepared transactions; sequence ≥ 90 % exhausted; connections ≥ 90 % of the ceiling; inactive slot retaining > 1 GB. |
| **10** | Active harm | Hurting users now, or a setting that turns a routine event into an outage. | XID age ≥ 1.0 B; a blocking chain older than 5 min; idle-in-transaction > 1 h; `synchronous_commit=off` cluster-wide; a slot invalidated or lost; a logical subscription erroring; a published table with no replica identity; the server restarted in the last 24 h. |
| **20** | Known-dangerous, not yet hurting | Needs a plan this month; usually a restart, an upgrade or a schema change. | Major version past EOL; `shared_buffers` at 128 MB; `wal_level=minimal`; collation version mismatch; a client transaction open > 1 h; `autovacuum_freeze_max_age` ≥ 1 B; disk ≥ 80 %. |
| **50** | Daily-briefing ceiling | Real problems worth fixing this week. `--max-priority 50` is the documented cut-off for an unattended scheduled run. | Checkpoints mostly requested; estimated table bloat > 50 % and > 1 GB wasted; an invalid index; an unused index ≥ 1 GB; duplicate indexes; an unindexed foreign key on a large table; tables overdue for vacuum; data checksums off; `PUBLIC` holding write grants; restore never tested. |
| **100** | Tuning and configuration detail | Fix when convenient; measurable but not urgent. | `work_mem` default with heavy temp-file spill; `effective_cache_size` default; slow-query logging off; settings pending a restart; `pg_stat_statements` missing; one statement over 25 % of total time; high rollback ratio; no monitoring evidence. |
| **150** | Hygiene and low-confidence heuristics | Worth a look; may well be intentional. | Overlapping indexes; small unused indexes; wide indexes; low-cardinality single-column indexes; plan-hostile query patterns found by regex; `random_page_cost=4`; cache hit ratio < 90 %; daily deadlocks; tables without a primary key; more than 1,000 partitions. |
| **200** | Non-default configuration | Inventory of every setting that differs from the shipped default, at server, database/role and relation level. Not problems: the thing you read *after* the problems, to understand why the server behaves as it does. | |
| **230** | Security review | Lists a security reviewer signs off on. | Superusers; CREATEROLE / CREATEDB / REPLICATION / BYPASSRLS holders; members of the file-access roles; login roles with no password. |
| **240** | Workload profile | Top statements by time, mean, I/O, calls and WAL; a wait-event snapshot. Not problems, but the raw material for the next step. | |
| **250** | Environment inventory | What this thing is: version, platform, role, sizes, extensions, topology, object counts, autovacuum configuration. | |
| **254** | Run metadata | Timestamp, target, mode, duration, versions, checks run/skipped/suppressed. | |
| **255** | Credits | One row. Suppressible. | |

## Documented ceilings

| Filter | Band | Use |
|---|---|---|
| `--max-priority 10` | pager | Wake someone up. |
| `--max-priority 50` | daily job | The default for a scheduled unattended run; everything above is noise for a lights-out job. |
| `--max-priority 150` | weekly review | What a DBA reads on Monday. |
| no filter | full report | The consulting deliverable. |

## Why 1 / 5 / 10 / 20 and not just "critical"

P1 is reserved for "the reasons you get fired", and the tool's credibility depends on never
crying wolf there. A replica six minutes behind is bad; it is not *the database refuses
writes tomorrow*. Keeping P5, P10 and P20 distinct is what lets a scheduled job page on
`≤10` while the weekly review still sees everything down to `≤50`.

## One check ID, one priority

A magnitude tier of the same condition gets its **own** check ID rather than a variable
priority: `PG-WRAP-001` is P1 at 1,500,000,000 and `PG-WRAP-002` is P10 at 1,000,000,000.
This matters for suppression. If one ID could emit at several priorities, a rule written to
silence the mild tier would silence the severe one too, silently, forever.

## Platform re-prioritisation

The registry's `platform_priority` column can lower a check on a platform where the
condition is expected — for example a managed platform that archives WAL outside
PostgreSQL. Re-prioritisation is data, not code, it is always visible in the report through
`XX-META-006`, and it never removes a finding: it moves it.
