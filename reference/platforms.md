# Managed platforms

db-triage fingerprints the platform during preflight and adapts, because a managed platform
changes what is *knowable*, not only what is *true*. The adaptations are data — the
registry's `platform_skip` and `platform_priority` columns — not code, and every one of them
is reported through `XX-META-006` so the reader knows what changed.

## Fingerprints

First match wins.

| Platform | PostgreSQL signal | MySQL signal |
|---|---|---|
| Aurora (PostgreSQL) | function `aurora_version()` exists | `@@aurora_version` exists |
| RDS | role `rdsadmin` exists; settings named `rds.*`; extension `rds_tools` available | user `rdsadmin@localhost`; `mysql.rds_*` procedures |
| AlloyDB | settings named `alloydb.*` | — |
| Cloud SQL | roles `cloudsqladmin`, `cloudsqlsuperuser` | user `cloudsqladmin`; `@@version_comment` contains "Google" |
| Azure Database Flexible Server | role `azure_pg_admin`; settings named `azure.*` | user `azure_superuser`; `@@version_comment` contains "Azure" |
| Supabase | role `supabase_admin` | — |
| Neon | role `neon_superuser` | — |
| Timescale Cloud | role `tsdbadmin` | — |
| Crunchy Bridge | role `crunchy_superuser` | — |
| Heroku | schema `heroku_ext` | — |
| PlanetScale / Vitess | — | `@@version_comment` contains "Vitess" |
| Self-managed | none of the above | none of the above |

Verify these against the current offering before trusting them: providers rename roles.
`reference/versions.yml` carries the `as_of` date that governs how much to trust this table,
and `XX-META-004` fires when it is stale.

## What changes, and why

**(a) The platform owns backups.** WAL archiving happens outside PostgreSQL, so
`archive_mode` tells you nothing. `PG-BAK-001` is skipped and `PG-BAK-010` fires instead,
saying what to confirm in the console. This matters more than it sounds: on RDS a backup
retention period of **0 disables automated backups entirely**, and nothing inside the
database can see that.

**(b) Superuser is withheld.** `pg_hba_file_rules` raises a permission error, the server log
is not readable through `pg_read_file()`, and `pg_ls_waldir()` may be denied. Those checks
are skipped with reason `platform`, and `PG-SEC-012` fires so the report states plainly that
the authentication posture was **not verified** rather than implying it is fine.

**(c) The platform sets the obvious knobs.** `shared_buffers`, `data_checksums` and
`wal_level` are sized by the provider, so `PG-MEM-001` and `PG-CORR-004` are normally silent
— and when they *do* fire on a managed instance, that is a real signal.

**(d) Everything else runs unchanged.** Wraparound, bloat, replication slots, locks,
indexes, sequences, roles and workload are all visible to an ordinary `pg_monitor` role, and
they are the majority of the catalog. A managed instance is not a black box; it is a box
with four specific holes in it.

## Checks skipped by platform

Derived from the registry's `platform_skip` column. `bin/build.py` regenerates this list.

| Platform | Checks skipped |
|---|---|
| rds, aurora, cloudsql, azure, supabase, neon | `PG-CORR-004` (data checksums disabled) |
| rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku | `PG-BAK-001` (no wal archiving: point-in-time recovery impossible); `PG-MEM-001` (shared_buffers at the shipped default); `PG-REL-013` (logging collector off with a stderr-only destination); `PG-SEC-001` (trust authentication reachable over the network); `PG-SEC-002` (cleartext password authentication over the network); `PG-SEC-003` (listening on all interfaces with world-open hba rules); `PG-SEC-004` (ssl disabled while accepting non-local connections); `PG-SEC-007` (trust authentication on the local socket) |

## Privilege ladder

Ask for the least that does the job:

| Grant | What it unlocks |
|---|---|
| plain `LOGIN` | Settings, catalog, sizes, indexes, constraints, sequences, roles. Most of `CFG`, `SCHEMA`, `IDX`, `SEC` review rows. |
| `pg_monitor` | `pg_stat_activity.query` for other users, `pg_stat_replication`, `pg_stat_statements` rows for other users, `pg_ls_waldir()`, `pg_ls_logdir()`. This is the right level for db-triage and the one to ask for. |
| superuser | `pg_hba_file_rules`, `pg_read_file()` on the server log, `pg_authid.rolpassword`. Needed only for the HBA checks, the log-scanning deep checks and `PG-SEC-018`. |

`XX-META-009` records which role was used, and `XX-META-002` fires when the role is below
`pg_monitor` and says what the missing grant would unlock. Running as superuser gives the
most complete run and carries the most risk; prefer `pg_monitor` and accept the two or three
skipped checks.
