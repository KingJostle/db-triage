# db-triage — PostgreSQL check reference

One section per check, anchored by its lowercase check ID so that a finding's `ref` field
is a working link. `bin/build.py --check` fails if any registry row has no anchor here.

Each section follows the same six parts:

- **What fires it** — the exact condition, with the threshold that was crossed.
- **Thresholds** — the overridable numbers and their defaults. Change them per target in
  `.db-triage.yml` under `thresholds:`; see `reference/config-example.yml`.
- **Why it matters** — the mechanism, first. Not the metric.
- **How to confirm** — a query you can run yourself, sometimes heavier than db-triage is
  allowed to be.
- **How to fix** — ordered, safest option first. **Every one of these is a write, and
  db-triage never runs any of them.**
- **False positives and caveats** — what would make this finding wrong.

Read `reference/priorities.md` for what the priority numbers mean and
`reference/categories.md` for the category codes.

---

## Contents

**Run and tool integrity (`META`)** — [XX-META-001](#xx-meta-001) · [XX-META-002](#xx-meta-002) · [XX-META-003](#xx-meta-003) · [XX-META-004](#xx-meta-004) · [XX-META-005](#xx-meta-005) · [XX-META-006](#xx-meta-006) · [XX-META-007](#xx-meta-007) · [XX-META-008](#xx-meta-008) · [XX-META-009](#xx-meta-009) · [XX-META-010](#xx-meta-010)

**Wraparound and freeze (`WRAP`)** — [PG-WRAP-001](#pg-wrap-001) · [PG-WRAP-002](#pg-wrap-002) · [PG-WRAP-003](#pg-wrap-003) · [PG-WRAP-004](#pg-wrap-004) · [PG-WRAP-005](#pg-wrap-005) · [PG-WRAP-006](#pg-wrap-006) · [PG-WRAP-007](#pg-wrap-007) · [PG-WRAP-008](#pg-wrap-008)

**Autovacuum and bloat (`VAC`)** — [PG-VAC-001](#pg-vac-001) · [PG-VAC-002](#pg-vac-002) · [PG-VAC-003](#pg-vac-003) · [PG-VAC-004](#pg-vac-004) · [PG-VAC-005](#pg-vac-005) · [PG-VAC-006](#pg-vac-006) · [PG-VAC-007](#pg-vac-007) · [PG-VAC-008](#pg-vac-008) · [PG-VAC-009](#pg-vac-009) · [PG-VAC-010](#pg-vac-010) · [PG-VAC-011](#pg-vac-011) · [PG-VAC-012](#pg-vac-012) · [PG-VAC-013](#pg-vac-013)

**Backup and recovery (`BAK`)** — [PG-BAK-001](#pg-bak-001) · [PG-BAK-002](#pg-bak-002) · [PG-BAK-003](#pg-bak-003) · [PG-BAK-004](#pg-bak-004) · [PG-BAK-005](#pg-bak-005) · [PG-BAK-006](#pg-bak-006) · [PG-BAK-007](#pg-bak-007) · [PG-BAK-008](#pg-bak-008) · [PG-BAK-009](#pg-bak-009) · [PG-BAK-010](#pg-bak-010) · [PG-BAK-011](#pg-bak-011)

**Corruption signals (`CORR`)** — [PG-CORR-001](#pg-corr-001) · [PG-CORR-002](#pg-corr-002) · [PG-CORR-003](#pg-corr-003) · [PG-CORR-004](#pg-corr-004) · [PG-CORR-005](#pg-corr-005) · [PG-CORR-006](#pg-corr-006) · [PG-CORR-007](#pg-corr-007) · [PG-CORR-008](#pg-corr-008)

**Durability (`DUR`)** — [PG-DUR-001](#pg-dur-001) · [PG-DUR-002](#pg-dur-002) · [PG-DUR-003](#pg-dur-003) · [PG-DUR-004](#pg-dur-004) · [PG-DUR-005](#pg-dur-005) · [PG-DUR-006](#pg-dur-006)

**Replication and HA (`REPL`)** — [PG-REPL-001](#pg-repl-001) · [PG-REPL-002](#pg-repl-002) · [PG-REPL-003](#pg-repl-003) · [PG-REPL-004](#pg-repl-004) · [PG-REPL-005](#pg-repl-005) · [PG-REPL-006](#pg-repl-006) · [PG-REPL-007](#pg-repl-007) · [PG-REPL-008](#pg-repl-008) · [PG-REPL-009](#pg-repl-009) · [PG-REPL-010](#pg-repl-010) · [PG-REPL-011](#pg-repl-011) · [PG-REPL-012](#pg-repl-012) · [PG-REPL-013](#pg-repl-013) · [PG-REPL-014](#pg-repl-014) · [PG-REPL-015](#pg-repl-015) · [PG-REPL-016](#pg-repl-016)

**Checkpoints and write-ahead log (`WAL`)** — [PG-WAL-001](#pg-wal-001) · [PG-WAL-002](#pg-wal-002) · [PG-WAL-003](#pg-wal-003) · [PG-WAL-004](#pg-wal-004) · [PG-WAL-005](#pg-wal-005) · [PG-WAL-006](#pg-wal-006) · [PG-WAL-007](#pg-wal-007) · [PG-WAL-008](#pg-wal-008) · [PG-WAL-009](#pg-wal-009)

**Memory and caching (`MEM`)** — [PG-MEM-001](#pg-mem-001) · [PG-MEM-002](#pg-mem-002) · [PG-MEM-003](#pg-mem-003) · [PG-MEM-004](#pg-mem-004) · [PG-MEM-005](#pg-mem-005) · [PG-MEM-006](#pg-mem-006) · [PG-MEM-007](#pg-mem-007) · [PG-MEM-008](#pg-mem-008) · [PG-MEM-009](#pg-mem-009) · [PG-MEM-010](#pg-mem-010)

**Connections and pooling (`CONN`)** — [PG-CONN-001](#pg-conn-001) · [PG-CONN-002](#pg-conn-002) · [PG-CONN-003](#pg-conn-003) · [PG-CONN-004](#pg-conn-004) · [PG-CONN-005](#pg-conn-005) · [PG-CONN-006](#pg-conn-006) · [PG-CONN-007](#pg-conn-007) · [PG-CONN-008](#pg-conn-008)

**Locking and long transactions (`LOCK`)** — [PG-LOCK-001](#pg-lock-001) · [PG-LOCK-002](#pg-lock-002) · [PG-LOCK-003](#pg-lock-003) · [PG-LOCK-004](#pg-lock-004) · [PG-LOCK-005](#pg-lock-005) · [PG-LOCK-006](#pg-lock-006) · [PG-LOCK-007](#pg-lock-007) · [PG-LOCK-008](#pg-lock-008) · [PG-LOCK-009](#pg-lock-009) · [PG-LOCK-010](#pg-lock-010)

**Security (`SEC`)** — [PG-SEC-001](#pg-sec-001) · [PG-SEC-002](#pg-sec-002) · [PG-SEC-003](#pg-sec-003) · [PG-SEC-004](#pg-sec-004) · [PG-SEC-005](#pg-sec-005) · [PG-SEC-006](#pg-sec-006) · [PG-SEC-007](#pg-sec-007) · [PG-SEC-008](#pg-sec-008) · [PG-SEC-009](#pg-sec-009) · [PG-SEC-010](#pg-sec-010) · [PG-SEC-011](#pg-sec-011) · [PG-SEC-012](#pg-sec-012) · [PG-SEC-013](#pg-sec-013) · [PG-SEC-014](#pg-sec-014) · [PG-SEC-015](#pg-sec-015) · [PG-SEC-016](#pg-sec-016) · [PG-SEC-017](#pg-sec-017) · [PG-SEC-018](#pg-sec-018) · [PG-SEC-019](#pg-sec-019) · [PG-SEC-020](#pg-sec-020) · [PG-SEC-021](#pg-sec-021)

**Indexes (`IDX`)** — [PG-IDX-001](#pg-idx-001) · [PG-IDX-002](#pg-idx-002) · [PG-IDX-003](#pg-idx-003) · [PG-IDX-004](#pg-idx-004) · [PG-IDX-005](#pg-idx-005) · [PG-IDX-006](#pg-idx-006) · [PG-IDX-007](#pg-idx-007) · [PG-IDX-008](#pg-idx-008) · [PG-IDX-009](#pg-idx-009) · [PG-IDX-010](#pg-idx-010) · [PG-IDX-011](#pg-idx-011) · [PG-IDX-012](#pg-idx-012) · [PG-IDX-013](#pg-idx-013) · [PG-IDX-014](#pg-idx-014) · [PG-IDX-015](#pg-idx-015) · [PG-IDX-016](#pg-idx-016) · [PG-IDX-017](#pg-idx-017)

**Schema design (`SCHEMA`)** — [PG-SCHEMA-001](#pg-schema-001) · [PG-SCHEMA-002](#pg-schema-002) · [PG-SCHEMA-003](#pg-schema-003) · [PG-SCHEMA-004](#pg-schema-004) · [PG-SCHEMA-005](#pg-schema-005) · [PG-SCHEMA-006](#pg-schema-006) · [PG-SCHEMA-007](#pg-schema-007) · [PG-SCHEMA-008](#pg-schema-008) · [PG-SCHEMA-009](#pg-schema-009) · [PG-SCHEMA-010](#pg-schema-010) · [PG-SCHEMA-011](#pg-schema-011) · [PG-SCHEMA-012](#pg-schema-012) · [PG-SCHEMA-013](#pg-schema-013)

**Queries and workload visibility (`QRY`)** — [PG-QRY-001](#pg-qry-001) · [PG-QRY-002](#pg-qry-002) · [PG-QRY-003](#pg-qry-003) · [PG-QRY-004](#pg-qry-004) · [PG-QRY-005](#pg-qry-005) · [PG-QRY-006](#pg-qry-006) · [PG-QRY-007](#pg-qry-007) · [PG-QRY-008](#pg-qry-008) · [PG-QRY-009](#pg-qry-009) · [PG-QRY-010](#pg-qry-010) · [PG-QRY-011](#pg-qry-011) · [PG-QRY-012](#pg-qry-012) · [PG-QRY-013](#pg-qry-013) · [PG-QRY-014](#pg-qry-014) · [PG-QRY-015](#pg-qry-015) · [PG-QRY-016](#pg-qry-016) · [PG-QRY-017](#pg-qry-017)

**Capacity and growth (`CAP`)** — [PG-CAP-001](#pg-cap-001) · [PG-CAP-002](#pg-cap-002) · [PG-CAP-003](#pg-cap-003) · [PG-CAP-004](#pg-cap-004) · [PG-CAP-005](#pg-cap-005) · [PG-CAP-006](#pg-cap-006) · [PG-CAP-007](#pg-cap-007) · [PG-CAP-008](#pg-cap-008)

**Reliability and operations (`REL`)** — [PG-REL-001](#pg-rel-001) · [PG-REL-002](#pg-rel-002) · [PG-REL-003](#pg-rel-003) · [PG-REL-004](#pg-rel-004) · [PG-REL-005](#pg-rel-005) · [PG-REL-006](#pg-rel-006) · [PG-REL-007](#pg-rel-007) · [PG-REL-008](#pg-rel-008) · [PG-REL-009](#pg-rel-009) · [PG-REL-010](#pg-rel-010) · [PG-REL-011](#pg-rel-011) · [PG-REL-012](#pg-rel-012) · [PG-REL-013](#pg-rel-013) · [PG-REL-014](#pg-rel-014)

**Non-default configuration (`CFG`)** — [PG-CFG-001](#pg-cfg-001) · [PG-CFG-002](#pg-cfg-002) · [PG-CFG-003](#pg-cfg-003) · [PG-CFG-004](#pg-cfg-004) · [PG-CFG-005](#pg-cfg-005)

**Environment inventory (`INFO`)** — [PG-INFO-001](#pg-info-001) · [PG-INFO-002](#pg-info-002) · [PG-INFO-003](#pg-info-003) · [PG-INFO-004](#pg-info-004) · [PG-INFO-005](#pg-info-005) · [PG-INFO-006](#pg-info-006) · [PG-INFO-007](#pg-info-007) · [PG-INFO-008](#pg-info-008) · [PG-INFO-009](#pg-info-009) · [PG-INFO-010](#pg-info-010) · [PG-INFO-011](#pg-info-011) · [PG-INFO-012](#pg-info-012)


---


## Run and tool integrity (`META`)

<a id="xx-meta-001"></a>
### XX-META-001 — Checks skipped
**Priority 0** · Run and tool integrity · scope: cluster · cost 0 · source: derived · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** Any registry check eligible for this engine/version/role did not run; details list each with reason in {privilege, version, platform, standby, cost, user-skip, timeout, error, no-input, embedded-subset, planned}.

**Reads.** `run bookkeeping`

**Why it matters.** A health check that silently omits what it could not evaluate is worse than no health check, because the reader will read silence as absence. This row lists every eligible check that did not run and why, so "backups look fine" can never mean "the backup checks were skipped for privilege".

**How to fix.** Grant what the reasons ask for and re-run: `pg_monitor` unlocks most of it, superuser unlocks the pg_hba and log checks, and the interview answers in `.db-triage.yml` unlock the backup-posture checks.

**False positives and caveats.** A skip with reason `cost` is not a defect: cost-2 checks are opt-in by design.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html)

---

<a id="xx-meta-002"></a>
### XX-META-002 — Insufficient privileges for core visibility
**Priority 0** · Run and tool integrity · scope: role · cost 0 · source: derived · pass: fast · effort S / risk low · since 0.1.0 · PostgreSQL 10+

**What fires it.** Connected role is not a member of pg_monitor and lacks pg_read_all_stats, so pg_stat_activity.query and pg_stat_statements rows for other users are masked.

**Reads.** `pg_has_role(), pg_roles`

**Why it matters.** Without `pg_monitor` (or `pg_read_all_stats`), `pg_stat_activity.query` is masked to `<insufficient privilege>` for every session other than your own, and `pg_stat_statements` shows only your own statements. The lock, long-transaction, connection and workload checks then measure a fraction of the server and report it as the whole.

**How to confirm.** `SELECT pg_has_role(current_user,'pg_monitor','USAGE');`

**How to fix.** `GRANT pg_monitor TO <the db-triage role>;`. It is a read-only predefined role: it grants no ability to change anything, which is why it is the right level to ask for rather than superuser.

**False positives and caveats.** On managed platforms the provider's admin role may already include it under another name; check `\du` before asking for a change.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/predefined-roles.html)

---

<a id="xx-meta-003"></a>
### XX-META-003 — Statistics reset within 24 hours
**Priority 0** · Run and tool integrity · scope: cluster · cost 0 · source: derived · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** Any of pg_stat_database.stats_reset, pg_stat_bgwriter/pg_stat_checkpointer.stats_reset or pg_stat_statements_info.stats_reset is within 24 h; every counter-based finding becomes confidence=low.

**Thresholds.** `stats_age_seconds` = 86,400

**Reads.** `pg_stat_database, pg_stat_bgwriter, pg_stat_statements_info`

**Why it matters.** Every rate in this report is a counter divided by the time since that counter was last reset. A reset three hours ago makes "0 index scans" mean "0 index scans in three hours", which is not evidence of anything. A restart resets some counters and not others, so the windows can differ between views in the same report.

**How to fix.** Nothing to fix. Wait until the counters cover a representative period — a week is the usual minimum for index-usage decisions — and re-run before acting on any counter-based finding.

**False positives and caveats.** `pg_stat_statements` is reset independently of `pg_stat_database`; both windows are reported separately in PG-INFO-012 and PG-INFO-008.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html)

---

<a id="xx-meta-004"></a>
### XX-META-004 — db-triage registry is stale
**Priority 0** · Run and tool integrity · scope: cluster · cost 0 · source: derived · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** registry.csv generated_at older than 365 days, or reference/versions.yml as_of older than 180 days; EOL and latest-minor checks become confidence=low.

**Thresholds.** `registry_age_days` = 365, `versions_age_days` = 180

**Reads.** `registry.csv, reference/versions.yml`

**Why it matters.** The end-of-life dates, latest minor releases and platform fingerprints in `reference/versions.yml` are transcribed data with a date on it. Once it is stale, PG-REL-001 through PG-REL-004 are answering last year's question, and a fingerprint that a provider has since renamed silently reclassifies a managed instance as self-managed.

**How to fix.** Refresh `reference/versions.yml` from the official support pages and set `as_of` to today. The procedure and the source URLs are in the file's own header.

**False positives and caveats.** Staleness does not make the REL findings wrong, only unverified: they drop to `confidence: low` rather than being suppressed.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/support/versioning/)

---

<a id="xx-meta-005"></a>
### XX-META-005 — Target is a standby/replica
**Priority 0** · Run and tool integrity · scope: cluster · cost 0 · source: derived · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** pg_is_in_recovery() is true; primary-only checks are skipped and usage counters are this instance's only.

**Reads.** `pg_is_in_recovery()`

**Why it matters.** A standby is not a smaller primary. Its usage counters (`idx_scan`, `seq_scan`) describe only the queries run against it; its `pg_stat_replication` is empty; vacuum and checkpoints happen on the primary. Half the catalog means something different here, and reading a standby report as if it were the primary is how an index that serves the reporting replica gets dropped.

**How to fix.** Nothing to fix — running against a standby is encouraged, because it costs the primary nothing. Run the primary-only checks against the primary as a second pass and compare the two reports.

**False positives and caveats.** Index-usage findings from a standby run should be labelled "standby usage" and never merged with primary counters.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/warm-standby.html)

---

<a id="xx-meta-006"></a>
### XX-META-006 — Managed platform detected; checks adapted
**Priority 0** · Run and tool integrity · scope: cluster · cost 0 · source: derived · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** A platform fingerprint from reference/platforms.md matched; details list checks skipped or re-prioritised.

**Reads.** `pg_roles, pg_settings, pg_available_extensions`

**Why it matters.** A managed platform changes what is knowable, not only what is true. The provider owns backups, withholds superuser, and sets the obvious knobs itself, so several checks would either be blind or would fire on something the provider has already handled.

**How to fix.** Nothing to fix. Read `reference/platforms.md` for what changed, and confirm in the provider console the things SQL cannot see: backup retention greater than zero, PITR enabled, and the network rules in front of the instance.

**False positives and caveats.** A fingerprint is a heuristic. Set `baseline.managed` in `.db-triage.yml` if it guessed wrong.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/support/versioning/)

---

<a id="xx-meta-007"></a>
### XX-META-007 — Run limited to N of M databases / relation sampling in effect
**Priority 0** · Run and tool integrity · scope: cluster · cost 0 · source: derived · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** More databases exist than were scanned (fast-pass cap 5), or a scanned database has more than 50,000 relations so per-relation checks used top-N sampling.

**Thresholds.** `max_databases` = 5, `max_relations` = 50,000

**Reads.** `pg_database, pg_class`

**Why it matters.** PostgreSQL statistics are per-database: `pg_stat_user_tables`, `pg_stat_statements` and the index counters describe only the database you are connected to. A cluster with twelve databases scanned in five of them has an eight-sevenths blind spot, and a database with 200,000 relations makes the per-relation checks expensive enough that they must sample.

**How to fix.** Re-run with `--all-databases` when you need the whole estate, and `--databases a,b,c` when you know which ones matter. Above 50 databases the run also needs `--bring-the-pain`, which exists to make the cost a conscious decision.

**False positives and caveats.** Sampling means a per-relation finding is the worst of the sample, not the worst in the database.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html)

---

<a id="xx-meta-008"></a>
### XX-META-008 — Interview questions unanswered
**Priority 0** · Run and tool integrity · scope: interview · cost 0 · source: interview · pass: fast · effort S / risk low · since 0.1.0 · needs interview

**What fires it.** Any source=interview check has no recorded answer in .db-triage.yml interview:, or the answer is older than 180 days.

**Thresholds.** `answer_age_days` = 180

**Reads.** `.db-triage.yml`

**Why it matters.** Three facts decide whether a database can survive a disaster, and none of them is visible from SQL: what takes backups, when one last succeeded, and when a restore was last tested. Reporting "no backup findings" without those answers would be the single most dangerous thing this tool could do.

**How to fix.** Answer the questions once and record them under `interview:` in `.db-triage.yml`. They carry a date and age out after 180 days, which is roughly how long an untested restore procedure stays trustworthy.

**False positives and caveats.** An answer is not a verification. "pgBackRest runs nightly" and "a restore completed last month" are different claims, and only the second one is evidence.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/backup.html)

---

<a id="xx-meta-009"></a>
### XX-META-009 — Run metadata
**Priority 254** · Run and tool integrity · scope: cluster · cost 0 · source: derived · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Always. Target label, engine, version, role, platform, mode, DSN host (never the password), start/end, duration, checks run/skipped/suppressed, db-triage and registry versions.

**Reads.** `run bookkeeping`

**Why it matters.** A report without its own provenance cannot be compared to another one. This row records the target, the engine and version, the role used, the platform, the mode, the access rung, the time window, and which db-triage and registry versions produced it.

**How to fix.** Nothing to fix. Keep it with the report; `--compare` uses it to decide whether two runs are comparable.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html)

---

<a id="xx-meta-010"></a>
### XX-META-010 — db-triage credits
**Priority 255** · Run and tool integrity · scope: cluster · cost 0 · source: derived · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Always, unless suppressed. db-triage version and repository URL.

**Reads.** `VERSION`

**Why it matters.** Version and repository URL, so that whoever reads this report a year from now can find the tool that produced it and see what its checks meant at the time.

**How to fix.** Nothing to fix. Suppress it with a `skip` entry if it is noise in your pipeline.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html)

---


## Wraparound and freeze (`WRAP`)

<a id="pg-wrap-001"></a>
### PG-WRAP-001 — Transaction ID or MultiXact wraparound imminent
**Priority 1** · Wraparound and freeze · scope: database · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** greatest(age(datfrozenxid), mxid_age(datminmxid)) >= 1,500,000,000 for any database, including templates. At 2^31 the cluster refuses new XIDs and stops accepting writes.

**Thresholds.** `xid_age` = 1,500,000,000

**Reads.** `pg_database`

**Why it matters.** Every row version records the transaction that created it, in a 32-bit counter that wraps. PostgreSQL keeps old rows visible by freezing them before the counter can lap them; if freezing falls far enough behind, the server refuses new write transactions rather than risk showing rows from the future as if they were from the past. That refusal is not graceful degradation: it is a hard stop that ends only when a single-user-mode VACUUM completes, and on a multi-hundred-gigabyte table that can take days. At 1.5 billion of the 2.147 billion limit there is under 30 % of headroom left.

**How to confirm.** `SELECT datname, age(datfrozenxid), mxid_age(datminmxid) FROM pg_database ORDER BY 2 DESC;` and, per relation, `SELECT n.nspname, c.relname, age(c.relfrozenxid), pg_size_pretty(pg_total_relation_size(c.oid)) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind IN ('r','m','t') ORDER BY 3 DESC LIMIT 20;`

**How to fix.** 1. First find out what is *blocking* freezing, because vacuuming harder will not help until it is gone: check PG-VAC-005 (oldest xmin horizon), PG-LOCK-005 and PG-LOCK-006 (long and prepared transactions), and PG-REPL-002/003/004 (replication slots holding an xmin). 2. Then vacuum the relations PG-WRAP-004 names, oldest first, with the cost delay removed for the session: `SET vacuum_cost_delay = 0; VACUUM (FREEZE, VERBOSE) <schema>.<table>;`. 3. Do not wait for autovacuum to get there on its own — it is already trying and losing. 4. Once the age is falling, fix the cause so it does not recur.

**False positives and caveats.** `template0` normally has a high age and does not accept connections; it is still frozen by the anti-wraparound path and is not usually the problem. A high MultiXact age with a low XID age points at heavy row-level locking (`SELECT ... FOR SHARE`, foreign-key checks) rather than at ordinary write volume.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/routine-vacuuming.html#VACUUM-FOR-WRAPAROUND)

---

<a id="pg-wrap-002"></a>
### PG-WRAP-002 — Transaction ID or MultiXact age high
**Priority 10** · Wraparound and freeze · scope: database · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** greatest(age(datfrozenxid), mxid_age(datminmxid)) >= 1,000,000,000 and < 1,500,000,000 in any database. Five times the default freeze age: autovacuum has been trying and failing for a long time.

**Thresholds.** `xid_age` = 1,000,000,000, `xid_age_critical` = 1,500,000,000

**Reads.** `pg_database`

**Why it matters.** The same mechanism as PG-WRAP-001, five times past the point where the forced anti-wraparound vacuum should have started. Autovacuum has been trying and failing for a long time. There is still weeks of room at a typical rate, which is why this is P10 and not P1 — but the *reason* it got here has not gone away on its own, and it will not.

**How to fix.** Treat it exactly like PG-WRAP-001, with time to plan: find what is holding the xmin horizon, clear it, then vacuum the oldest relations in a maintenance window rather than an incident.

**False positives and caveats.** If the age is falling between runs, the fix is already working and this row is history rather than news. `--compare` shows that directly.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/routine-vacuuming.html#VACUUM-FOR-WRAPAROUND)

---

<a id="pg-wrap-003"></a>
### PG-WRAP-003 — Anti-wraparound vacuum overdue
**Priority 50** · Wraparound and freeze · scope: database · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** age(datfrozenxid) > 1.5 x autovacuum_freeze_max_age (or mxid_age > 1.5 x autovacuum_multixact_freeze_max_age) and < 1,000,000,000. The forced vacuum should have run at 1.0x, so something is blocking freezing.

**Thresholds.** `freeze_multiple` = 1.5, `xid_age_ceiling` = 1,000,000,000

**Reads.** `pg_database, pg_settings`

**Why it matters.** `autovacuum_freeze_max_age` is the point at which PostgreSQL forces an anti-wraparound vacuum whether autovacuum is otherwise interested or not. Being 50 % past it means that forced vacuum has been triggered and has not finished — it is being cancelled, starved, or blocked. The count is not yet dangerous; the fact that the safety mechanism is not working is.

**How to confirm.** `SELECT * FROM pg_stat_progress_vacuum;` while it runs, and `SELECT relname, last_autovacuum FROM pg_stat_user_tables ORDER BY last_autovacuum NULLS FIRST LIMIT 20;`

**How to fix.** Find out why the forced vacuum is not completing. The usual causes, in order of frequency: an old xmin horizon (PG-VAC-005) making the vacuum unable to remove anything; a lock conflict repeatedly cancelling it (PG-VAC-011 reads the log for this); cost limits making it too slow to keep up (PG-VAC-008); or `autovacuum_enabled=false` on the relation itself (PG-VAC-009).

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/routine-vacuuming.html#VACUUM-FOR-WRAPAROUND)

---

<a id="pg-wrap-004"></a>
### PG-WRAP-004 — Tables driving transaction ID age
**Priority 50** · Wraparound and freeze · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 9.6+

**What fires it.** Emitted for the current database when WRAP-001/002/003 fired: the top 10 relations by greatest(age(relfrozenxid), mxid_age(relminmxid)), with size and whether a vacuum is currently processing them.

**Thresholds.** `top_n` = 10, `min_age` = 200,000,000

**Reads.** `pg_class, pg_namespace, pg_stat_progress_vacuum`

**Why it matters.** Database-level age is the maximum over its relations, so knowing which relations carry it turns "the database is at 1.2 billion" into a list of things to vacuum, in order, with their sizes — which is what decides how long the maintenance window has to be.

**How to fix.** Vacuum the listed relations oldest-first with `VACUUM (FREEZE)`. Size tells you the cost; the `pg_stat_progress_vacuum` column tells you whether autovacuum is already on it, in which case leave it alone and watch.

**False positives and caveats.** TOAST tables appear separately from their parent and are frozen separately. A toast table with a high age and a small parent is normal for a table with many large values.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/routine-vacuuming.html#VACUUM-FOR-WRAPAROUND)

---

<a id="pg-wrap-005"></a>
### PG-WRAP-005 — Autovacuum disabled
**Priority 5** · Wraparound and freeze · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** pg_settings.autovacuum = off. The emergency anti-wraparound vacuum still runs, which is why this is P5 and not P1, but nothing else does: bloat and stale statistics grow without bound.

**Reads.** `pg_settings`

**Why it matters.** With autovacuum off, nothing reclaims dead tuples, nothing refreshes planner statistics, and nothing sets the visibility map. Bloat grows without bound, plans degrade as statistics go stale, and the only vacuuming that ever happens is the emergency anti-wraparound pass — which is why this is P5 rather than P1: the cluster will not stop accepting writes, it will just get steadily worse until it does.

**How to fix.** Turn it back on: `ALTER SYSTEM SET autovacuum = on; SELECT pg_reload_conf();` (both are writes — run them yourself). If it was turned off to stop autovacuum interfering with a bulk load, the right tool is per-table `autovacuum_enabled=false` on the specific relation, removed when the load finishes.

**False positives and caveats.** Some vendors ship images with autovacuum off for benchmarks. That is a benchmark configuration, not a production one.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-autovacuum.html)

---

<a id="pg-wrap-006"></a>
### PG-WRAP-006 — Statistics tracking disabled (autovacuum blind)
**Priority 5** · Wraparound and freeze · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** pg_settings.track_counts = off. Autovacuum cannot see dead tuples, so only anti-wraparound vacuums will ever run.

**Reads.** `pg_settings`

**Why it matters.** `track_counts` is what feeds `n_dead_tup` and `n_mod_since_analyze`. With it off, autovacuum's launcher has no signal at all: it cannot see that a table has dead rows, so it never schedules a vacuum, and it cannot see modifications, so it never schedules an ANALYZE. Autovacuum appears to be on and does essentially nothing.

**How to fix.** `ALTER SYSTEM SET track_counts = on; SELECT pg_reload_conf();`. The overhead is a per-backend counter increment; it is not a tuning knob worth turning off.

**False positives and caveats.** This is occasionally turned off in the mistaken belief that it costs measurable performance. It does not, and turning it off disables autovacuum in everything but name.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-autovacuum.html)

---

<a id="pg-wrap-007"></a>
### PG-WRAP-007 — autovacuum_freeze_max_age raised to 1 billion or more
**Priority 20** · Wraparound and freeze · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** autovacuum_freeze_max_age >= 1,000,000,000 or autovacuum_multixact_freeze_max_age >= 1,000,000,000. Halves the safety margin and lengthens the emergency freeze window.

**Thresholds.** `freeze_max_age` = 1,000,000,000

**Reads.** `pg_settings`

**Why it matters.** Raising `autovacuum_freeze_max_age` delays the forced anti-wraparound vacuum. That reduces how often the expensive freeze runs, at the cost of leaving less room between where freezing starts and where the server stops accepting writes. At 1 billion, the emergency window is roughly half what the default gives — and the emergency vacuum has to scan the whole relation, so the window has to be big enough for the largest table, not the average one.

**How to fix.** Lower it towards the 200,000,000 default, or accept it and make sure the freeze actually completes: per-table `autovacuum_freeze_max_age`, `autovacuum_vacuum_cost_delay = 0` for the relevant tables, and monitoring on `age(datfrozenxid)`.

**False positives and caveats.** A raised value is sometimes a deliberate trade on a very-high-write, small-table workload. It is a trade, not a mistake — but it needs the monitoring that goes with it.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-autovacuum.html)

---

<a id="pg-wrap-008"></a>
### PG-WRAP-008 — vacuum_failsafe_age raised above the default
**Priority 100** · Wraparound and freeze · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · PostgreSQL 14+

**What fires it.** vacuum_failsafe_age or vacuum_multixact_failsafe_age > 1,600,000,000. The failsafe (which drops cost delays and index cleanup) is the last automatic defence against wraparound.

**Thresholds.** `failsafe_age` = 1,600,000,000

**Reads.** `pg_settings`

**Why it matters.** The vacuum failsafe is the last automatic defence: past `vacuum_failsafe_age` a vacuum abandons its cost delays and skips index cleanup so that it can finish before wraparound stops the server. Raising the threshold delays that behaviour, which is exactly the behaviour you want to happen early rather than late.

**How to fix.** Return it to the 1,600,000,000 default unless you have a specific, documented reason. If the failsafe is firing often, the problem is the vacuum throughput (PG-VAC-008) rather than the failsafe.

**False positives and caveats.** PostgreSQL 14 and newer only; older versions have no failsafe at all, which is one reason the anti-wraparound checks matter more on them.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-autovacuum.html)

---


## Autovacuum and bloat (`VAC`)

<a id="pg-vac-001"></a>
### PG-VAC-001 — Autovacuum running more than 6 hours on one relation
**Priority 50** · Autovacuum and bloat · scope: relation · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 9.6+ · needs pg_monitor

**What fires it.** A pg_stat_progress_vacuum row whose backend xact_start is more than 6 hours old. With default cost settings autovacuum moves roughly 8 MB/s of dirty pages; a run this long means the table needs per-table cost settings or partitioning.

**Thresholds.** `duration_seconds` = 21,600

**Reads.** `pg_stat_progress_vacuum, pg_stat_activity`

**Why it matters.** Autovacuum is deliberately slow: it accumulates a cost as it reads and dirties pages and sleeps whenever it exceeds the limit. A run lasting six hours on one relation means the table is large enough, or the throttle tight enough, that the vacuum cannot finish between the events that make it necessary. While it runs it holds a SHARE UPDATE EXCLUSIVE lock, which blocks DDL and other vacuums on that relation.

**How to confirm.** `SELECT p.*, a.xact_start, now()-a.xact_start AS running FROM pg_stat_progress_vacuum p JOIN pg_stat_activity a USING (pid);`

**How to fix.** Give that relation its own settings rather than loosening the whole cluster: `ALTER TABLE t SET (autovacuum_vacuum_cost_delay = 0);` for a table that must be vacuumed quickly, plus a lower `autovacuum_vacuum_scale_factor` so the runs start earlier and each one has less to do. If the relation is very large, partitioning is the structural answer: vacuum then works on one partition at a time.

**False positives and caveats.** A long run is expected the first time a very large table is frozen. Compare against the previous run rather than treating one long vacuum as a defect.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/progress-reporting.html)

---

<a id="pg-vac-002"></a>
### PG-VAC-002 — Autovacuum workers saturated
**Priority 50** · Autovacuum and bloat · scope: cluster · cost 1 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** Running autovacuum workers equals autovacuum_max_workers AND at least 20 tables in this database currently exceed their vacuum threshold. Both conditions are required so an idle cluster that happens to have 3 workers busy does not fire.

**Thresholds.** `overdue_tables` = 20

**Reads.** `pg_stat_activity, pg_settings, pg_stat_user_tables`

**Why it matters.** `autovacuum_max_workers` bounds how many relations can be vacuumed at once, cluster-wide. When every worker is busy and a queue of tables already exceeds its threshold, the queue grows: each table accumulates more dead tuples before its turn, so each run takes longer, so the queue grows faster. Both halves of the condition are required, because three busy workers on an idle cluster is normal.

**How to fix.** Raising `autovacuum_max_workers` alone usually makes it worse: the per-worker cost limit is shared, so more workers each go slower. Raise the cost limit at the same time (or lower `autovacuum_vacuum_cost_delay`), and give the biggest offenders per-table settings so they stop monopolising a worker.

**False positives and caveats.** `autovacuum_max_workers` needs a restart. `autovacuum_vacuum_cost_limit` does not.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-autovacuum.html)

---

<a id="pg-vac-003"></a>
### PG-VAC-003 — Tables overdue for vacuum
**Priority 50** · Autovacuum and bloat · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** n_dead_tup > 2 x the table's effective vacuum threshold (autovacuum_vacuum_threshold + autovacuum_vacuum_scale_factor x n_live_tup, honouring reloptions) AND n_dead_tup >= 100,000 AND pg_relation_size >= 100 MB. Top 10 by n_dead_tup.

**Thresholds.** `dead_multiple` = 2, `min_dead_tuples` = 100,000, `min_bytes` = 104,857,600, `top_n` = 10

**Reads.** `pg_stat_user_tables, pg_class, pg_settings`

**Why it matters.** Dead tuples are row versions no transaction can still see. They occupy pages, so every sequential scan reads them, every index still points at them until the vacuum removes the entries, and the table grows on disk. Autovacuum triggers at `threshold + scale_factor x live_rows`; being twice past that means the trigger fired and the vacuum has not caught up, or never started.

**How to confirm.** `SELECT relname, n_dead_tup, n_live_tup, last_autovacuum FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 20;`

**How to fix.** Find out why the vacuum is not keeping up rather than vacuuming by hand and moving on: PG-VAC-005 (an xmin horizon making the vacuum unable to remove anything), PG-VAC-008 (throttled), PG-VAC-009 (disabled on the relation), PG-VAC-002 (workers saturated). For a large, hot table, a per-table `autovacuum_vacuum_scale_factor` of 0.01 or a fixed `autovacuum_vacuum_threshold` makes vacuums start earlier and finish faster.

**False positives and caveats.** `n_dead_tup` is an estimate maintained by the statistics collector; it can be stale, and it resets when statistics are reset. A table that was just vacuumed can still show a high count until the next statistics update.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ALL-TABLES-VIEW)

---

<a id="pg-vac-004"></a>
### PG-VAC-004 — Large tables never analyzed or with stale statistics
**Priority 50** · Autovacuum and bloat · scope: relation · cost 1 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** (last_analyze and last_autoanalyze both null and n_live_tup >= 100,000) OR (n_mod_since_analyze > 0.2 x n_live_tup and n_live_tup >= 1,000,000). The planner is flying blind on exactly the tables where it matters.

**Thresholds.** `never_analyzed_rows` = 100,000, `stale_fraction` = 0.2, `stale_min_rows` = 1,000,000, `top_n` = 10

**Reads.** `pg_stat_user_tables`

**Why it matters.** The planner chooses between a sequential scan, an index scan and a nested loop using row-count estimates from `pg_statistic`. On a table that has never been analyzed, those estimates are defaults — the planner effectively guesses. The failure mode is not a slightly worse plan; it is a nested loop over what it believes is 200 rows and is actually 20 million.

**How to confirm.** `SELECT relname, n_live_tup, n_mod_since_analyze, last_analyze, last_autoanalyze FROM pg_stat_user_tables ORDER BY n_mod_since_analyze DESC LIMIT 20;`

**How to fix.** `ANALYZE <schema>.<table>;` — a write from db-triage's point of view, so run it yourself. Then find out why autoanalyze is not doing it: `track_counts` off (PG-WRAP-006), autovacuum off (PG-WRAP-005), or `autovacuum_analyze_scale_factor` too coarse for a table this size.

**False positives and caveats.** A table loaded once and never modified legitimately shows `n_mod_since_analyze = 0` and an old `last_analyze`; it is only a problem when the data changed after the analyze.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ALL-TABLES-VIEW)

---

<a id="pg-vac-005"></a>
### PG-VAC-005 — Old transaction horizon holding back vacuum
**Priority 50** · Autovacuum and bloat · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 9.6+ · needs pg_monitor

**What fires it.** age() of the oldest xmin across pg_stat_activity.backend_xmin, pg_replication_slots.xmin/catalog_xmin, pg_prepared_xacts and pg_stat_replication.backend_xmin is >= 50,000,000 (25% of the default freeze age). Vacuum cannot remove anything newer than that xmin anywhere in the cluster.

**Thresholds.** `xmin_age` = 50,000,000

**Reads.** `pg_stat_activity, pg_replication_slots, pg_prepared_xacts, pg_stat_replication`

**Why it matters.** Vacuum can only remove a row version that is invisible to every possible observer. The oldest `xmin` in the cluster is that bound, and it is cluster-wide: one forgotten transaction in one database stops vacuum from cleaning anything newer in *every* database. This is the single most common reason that a cluster with healthy-looking autovacuum settings still bloats and still drifts towards wraparound.

**How to confirm.** `SELECT pid, backend_xmin, age(backend_xmin), state, xact_start, query FROM pg_stat_activity WHERE backend_xmin IS NOT NULL ORDER BY age(backend_xmin) DESC;` plus the same over `pg_replication_slots` and `pg_prepared_xacts`.

**How to fix.** Identify the holder from the details, then deal with it at source. A backend: find out what it is doing and whether it should be. A replication slot: PG-REPL-002/003/004 — restart the consumer or drop the slot. A prepared transaction: PG-LOCK-006 — resolve it. A standby with `hot_standby_feedback=on`: PG-REPL-016 on that standby. Then set `idle_in_transaction_session_timeout` so it cannot recur silently (PG-LOCK-007).

**False positives and caveats.** On a quiet cluster 50 million XIDs can represent months, so the age alone does not tell you the transaction is recent. The check therefore reports the transaction's start time where one exists.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/routine-vacuuming.html)

---

<a id="pg-vac-006"></a>
### PG-VAC-006 — Estimated table bloat over 50 percent (1 GB or more wasted)
**Priority 50** · Autovacuum and bloat · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** Catalog-only estimator: estimated bloat >= 50% AND estimated wasted bytes >= 1 GB on relations >= 1 GB. Estimated, not measured; confirm with pgstattuple_approx before any rewrite.

**Thresholds.** `bloat_pct` = 50, `wasted_bytes` = 1,073,741,824, `min_bytes` = 1,073,741,824, `top_n` = 10

**Reads.** `pg_class, pg_attribute, pg_stats, pg_namespace`

**Why it matters.** Bloat is the space in a relation not occupied by live rows: dead tuples not yet reclaimed, plus free space inside pages. It is not wasted disk alone — every sequential scan reads it, every index-only scan is less likely to hit an all-visible page, and the buffer cache holds it instead of holding data. At 50 % and a gigabyte, a scan does twice the I/O it needs to and the fix is worth a maintenance window.

**How to confirm.** `pgstattuple_approx()` for the measured figure; `pg_stat_user_tables.n_dead_tup` for whether it is still growing.

**How to fix.** Confirm the estimate first with `SELECT * FROM pgstattuple_approx('<schema>.<table>');` (needs the `pgstattuple` extension and reads the relation, so run it off-peak). If it is real: `VACUUM (FULL)` rewrites the table but takes an ACCESS EXCLUSIVE lock for the duration and needs as much free disk as the table; `pg_repack` does the same online at the cost of more disk and more WAL. On a partitioned table, rewriting one partition at a time is usually the practical route.

**False positives and caveats.** **This is an estimate from `pg_stats`, not a measurement.** It is wrong on TOAST-heavy tables (out-of-line values are not counted), on tables with wide variable-length columns, and on anything whose statistics are stale. A freshly vacuumed table legitimately keeps free space for reuse: 30 % on a busy table is normal, not damage. Never schedule a rewrite on this number alone.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/routine-vacuuming.html)

---

<a id="pg-vac-007"></a>
### PG-VAC-007 — Estimated table bloat over 30 percent (200 MB or more wasted)
**Priority 100** · Autovacuum and bloat · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** Estimated bloat >= 30% AND estimated wasted bytes >= 200 MB, excluding relations already reported by VAC-006.

**Thresholds.** `bloat_pct` = 30, `wasted_bytes` = 209,715,200, `bloat_pct_high` = 50, `wasted_bytes_high` = 1,073,741,824, `top_n` = 10

**Reads.** `pg_class, pg_attribute, pg_stats, pg_namespace`

**Why it matters.** The same estimator as PG-VAC-006 at a lower threshold. At 30 % and 200 MB it is worth knowing about and rarely worth a maintenance window on its own — it is the row you read next to PG-VAC-003 to decide whether vacuum is keeping up.

**How to fix.** Usually nothing. If the same relations appear here run after run and the percentage is rising, the vacuum is losing: treat it as PG-VAC-003.

**False positives and caveats.** Same estimator caveats as PG-VAC-006. At this threshold the false-positive rate is meaningfully higher.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/routine-vacuuming.html)

---

<a id="pg-vac-008"></a>
### PG-VAC-008 — Autovacuum throttled at defaults on a large database
**Priority 100** · Autovacuum and bloat · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** Total size of the scanned databases >= 500 GB while autovacuum_vacuum_cost_limit is -1 (inheriting vacuum_cost_limit 200) and autovacuum_vacuum_cost_delay >= 2 ms. The resulting dirty-page throughput per worker is computed from vacuum_cost_page_dirty and reported in the finding.

**Thresholds.** `total_bytes` = 536,870,912,000, `cost_delay_ms` = 2

**Reads.** `pg_settings, pg_database_size()`

**Why it matters.** Autovacuum is throttled by a cost accounting: it accumulates cost as it hits, misses and dirties pages, and sleeps for `autovacuum_vacuum_cost_delay` whenever the running total passes the limit. The shipped defaults were chosen for a server much smaller than a half-terabyte database. The finding computes the resulting dirty-page throughput per worker from the live settings, so you can compare it against how fast the data actually churns.

**How to fix.** Raise `autovacuum_vacuum_cost_limit` (no restart needed) rather than lowering the delay to zero globally — the delay is what keeps vacuum from saturating the storage. A common shape on a large, fast-storage server is `autovacuum_vacuum_cost_limit = 2000` with the default 2 ms delay, plus `autovacuum_vacuum_cost_delay = 0` on individual tables that must be vacuumed quickly.

**False positives and caveats.** On slow or shared storage, raising the limit can turn a vacuum problem into a latency problem. Change it in steps and watch commit latency.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-autovacuum.html)

---

<a id="pg-vac-009"></a>
### PG-VAC-009 — Tables with autovacuum disabled via a storage parameter
**Priority 100** · Autovacuum and bloat · scope: relation · cost 1 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** pg_class.reloptions contains autovacuum_enabled=false. Details include n_dead_tup and last_vacuum so you can see whether anything is vacuuming them at all.

**Reads.** `pg_class, pg_stat_user_tables`

**Why it matters.** `autovacuum_enabled=false` stops autovacuum considering the relation for ordinary vacuuming and analyzing. The anti-wraparound path still runs, so the cluster will not stop accepting writes — but dead tuples accumulate without limit and the planner statistics go stale, and nothing will ever tell you.

**How to fix.** If it was set for a bulk load that has finished, remove it: `ALTER TABLE t RESET (autovacuum_enabled);`. If it is deliberate, make the manual vacuum that replaces it visible — a cron job nobody monitors is not a substitute.

**False positives and caveats.** This is a legitimate setting for a table written in bulk and then read-only, or for one where vacuum timing must be controlled by hand. The finding reports the dead-tuple count so you can see whether the arrangement is working.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-createtable.html#SQL-CREATETABLE-STORAGE-PARAMETERS)

---

<a id="pg-vac-010"></a>
### PG-VAC-010 — Very large tables using the default vacuum scale factor
**Priority 100** · Autovacuum and bloat · scope: relation · cost 1 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** reltuples >= 100,000,000 and no per-table autovacuum_vacuum_scale_factor or autovacuum_vacuum_threshold override. 20% of 100 M rows is 20 M dead tuples before the first vacuum.

**Thresholds.** `min_tuples` = 100,000,000

**Reads.** `pg_class`

**Why it matters.** `autovacuum_vacuum_scale_factor` is a fraction of the table, so the trigger point scales with the table. At the default 0.2, a table of 100 million rows accumulates 20 million dead tuples before the first vacuum — and then that vacuum has 20 million tuples to remove and a very large table to scan, so it is slow, and while it is slow more dead tuples accumulate.

**How to fix.** Give large tables their own settings: `ALTER TABLE t SET (autovacuum_vacuum_scale_factor = 0.01, autovacuum_vacuum_threshold = 10000);` or, for the largest, `scale_factor = 0.0` with a fixed threshold so the trigger stops scaling entirely.

**False positives and caveats.** `reltuples` is an estimate updated by vacuum and analyze; on a table that has never been analyzed it can be badly wrong or -1.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-createtable.html#SQL-CREATETABLE-STORAGE-PARAMETERS)

---

<a id="pg-vac-011"></a>
### PG-VAC-011 — Autovacuum cancelled by lock conflicts (server log)
**Priority 100** · Autovacuum and bloat · scope: cluster · cost 2 · source: log · pass: deep · effort M / risk low · since 0.1.0 · PostgreSQL 10+ · needs superuser, os

**What fires it.** At least 10 'canceling autovacuum task' messages in the last 24 hours of server log. Deep pass only; requires log access.

**Thresholds.** `cancel_count` = 10, `window_hours` = 24

**Reads.** `server log via pg_current_logfile()/pg_read_file`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** Autovacuum yields when it conflicts with a lock request, and logs "canceling autovacuum task". A handful of these is normal. Ten or more in a day on the same relation means something — usually a migration loop, a frequent `ALTER TABLE`, or an ORM taking stronger locks than it needs — is repeatedly preventing that table from ever being vacuumed.

**How to fix.** Find what takes the conflicting lock and make it stop, or run it less often. The anti-wraparound vacuum does *not* yield, which is why a table in this state often sits fine for months and then triggers PG-WRAP-003.

**False positives and caveats.** Deep pass only: it reads the server log, which needs superuser or shell access. Absent that access it is skipped, not passed.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-autovacuum.html)

---

<a id="pg-vac-012"></a>
### PG-VAC-012 — Low HOT-update ratio on update-heavy tables
**Priority 150** · Autovacuum and bloat · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** n_tup_upd >= 1,000,000 and n_tup_hot_upd / n_tup_upd < 0.10 and fillfactor is unset. A lower fillfactor helps only when the updated columns are not indexed, which cannot be verified from the catalog, so confidence is low.

**Thresholds.** `min_updates` = 1,000,000, `hot_ratio` = 0.10

**Reads.** `pg_stat_user_tables, pg_class`

**Why it matters.** A heap-only tuple update writes the new row version on the same page as the old one and skips updating every index. When it cannot — because the page is full — the update writes to a new page and adds an entry to every index on the table, which is both slower and a source of index bloat. A ratio under 10 % on a million updates means almost every update is paying the full cost.

**How to fix.** Lower the fillfactor so pages keep room for updates: `ALTER TABLE t SET (fillfactor = 90);` — this affects only pages written after the change, so it takes effect gradually or after a rewrite.

**False positives and caveats.** **Confidence is low by construction.** A HOT update is only possible when *no indexed column* changed, and the catalog cannot tell which columns the application updates. If the workload updates an indexed column every time, a lower fillfactor costs space and buys nothing.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/storage-hot.html)

---

<a id="pg-vac-013"></a>
### PG-VAC-013 — Insert-only tables never vacuumed (PostgreSQL 12 and older)
**Priority 100** · Autovacuum and bloat · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 12 and older

**What fires it.** PostgreSQL 12 and older only: n_tup_ins >= 10,000,000, n_tup_upd + n_tup_del = 0, and the table has never been vacuumed. Before 13 autovacuum ignores insert-only tables, so they are frozen only by the anti-wraparound path and never get a visibility map.

**Thresholds.** `min_inserts` = 10,000,000

**Reads.** `pg_stat_user_tables`

**Why it matters.** Before PostgreSQL 13 autovacuum had no insert-driven trigger at all: a table that is only ever inserted into accumulates no dead tuples, so it never crosses the vacuum threshold and is never vacuumed. Two consequences follow. Its visibility map is never set, so index-only scans always have to visit the heap; and its pages are only ever frozen by the emergency anti-wraparound vacuum, which then has the whole table to do at once.

**How to fix.** Vacuum it on a schedule until the server is upgraded: `VACUUM (FREEZE, ANALYZE) <table>;` during a quiet period. On PostgreSQL 13 and newer, `autovacuum_vacuum_insert_threshold` handles this automatically and the check does not apply.

**False positives and caveats.** Only fires on PostgreSQL 12 and older.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-autovacuum.html)

---


## Backup and recovery (`BAK`)

<a id="pg-bak-001"></a>
### PG-BAK-001 — No WAL archiving: point-in-time recovery impossible
**Priority 1** · Backup and recovery · scope: setting · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · primary only

**What fires it.** archive_mode = off on a self-managed primary. Skipped on managed platforms, where BAK-010 fires instead. Confidence medium: snapshot-based strategies exist, but pg_dump alone is not PITR.

**Reads.** `pg_settings`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.


**Why it matters.** Point-in-time recovery needs two things: a base backup, and the stream of WAL written since. With `archive_mode = off` on a self-managed primary the second one does not exist, so the only recoverable states are the moments the base backups were taken. Everything after the newest one is gone. A `pg_dump` is a logical export taken at one instant — useful, but it is not PITR and it does not shrink the recovery point objective.

**How to confirm.** `SELECT * FROM pg_stat_archiver;` and, from the backup tool, `pgbackrest info` / `barman list-backups` / `wal-g backup-list`.

**How to fix.** Decide the strategy before touching the setting. The usual answer is a backup tool that manages both halves — pgBackRest, Barman or WAL-G — rather than a hand-written `archive_command`, because they also handle retention, verification and parallel restore. Then: set `archive_mode = on` (needs a restart), set `archive_command` or `archive_library`, and confirm `pg_stat_archiver.last_archived_time` advances.

**False positives and caveats.** Skipped on managed platforms, where the provider archives outside PostgreSQL — PG-BAK-010 fires there instead. Confidence is medium because a snapshot-based strategy on a filesystem that supports consistent snapshots is a legitimate alternative; the finding asks you to name what you rely on.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/continuous-archiving.html)

---

<a id="pg-bak-002"></a>
### PG-BAK-002 — archive_command is failing
**Priority 1** · Backup and recovery · scope: cluster · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · PostgreSQL 9.4+ · primary only

**What fires it.** pg_stat_archiver.failed_count > 0 AND last_failed_time > coalesce(last_archived_time, -infinity). WAL cannot be recycled, pg_wal grows, and the server eventually PANICs when the volume fills.

**Reads.** `pg_stat_archiver`

**Platform.** This check is reported at **P5** on rds, cloudsql, azure, supabase, crunchy, timescale, heroku; reported at **P200** on aurora, neon, alloydb. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** A failing `archive_command` is an outage on a timer. WAL segments cannot be recycled until they are archived, so `pg_wal` grows at the rate WAL is generated. When the volume fills, the server PANICs and shuts down. Meanwhile PITR has already stopped: the recoverable window ended at the last successful archive, however long ago that was.

**How to confirm.** `SELECT now()-last_archived_time AS since_success, failed_count, last_failed_wal FROM pg_stat_archiver;` — the interval should fall below a minute and `failed_count` should stop rising.

**How to fix.** 1. Read the actual error: `grep -m5 'archive command failed' <logfile>` — it is almost always credentials, a full destination, or a changed bucket policy. 2. Fix the cause. 3. **Do not** set `archive_command` to `true` to clear the backlog: that is PG-BAK-004 and it destroys the archive silently. 4. Watch `pg_stat_archiver.last_archived_time` advance; the backlog drains at archive speed. 5. If the disk will fill before the backlog drains, add disk *and* confirm the last base backup is restorable, because PITR already ends at the last success.

**False positives and caveats.** `failed_count` is cumulative since the statistics reset; an old failure that has since been fixed shows a non-zero count with `last_archived_time` newer than `last_failed_time`, which is why the check compares the two timestamps rather than testing the count alone.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-wal.html#RUNTIME-CONFIG-WAL-ARCHIVING)

---

<a id="pg-bak-003"></a>
### PG-BAK-003 — WAL archiving stalled
**Priority 1** · Backup and recovery · scope: cluster · cost 1 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · PostgreSQL 12+ · primary only · needs pg_monitor

**What fires it.** archive_mode is on and either at least 10 .ready files are queued in pg_wal/archive_status, or archive_mode is on with a non-zero archive_timeout and last_archived_time is older than max(1 h, 3 x archive_timeout).

**Thresholds.** `ready_files` = 10, `stall_seconds` = 3,600

**Reads.** `pg_stat_archiver, pg_ls_archive_statusdir(), pg_current_wal_lsn()`

**Platform.** This check is reported at **P5** on rds, cloudsql, azure, supabase, crunchy, timescale, heroku; reported at **P200** on aurora, neon, alloydb. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** Every completed WAL segment gets a `.ready` file in `pg_wal/archive_status`, removed when the archiver succeeds. A queue of them means the archiver is running slower than WAL is being produced, or has stopped succeeding. This is the same eventual outcome as PG-BAK-002 — `pg_wal` fills, the server PANICs — reached without a single error in the log, because a slow archiver is not a failing one.

**How to confirm.** `SELECT count(*) FROM pg_ls_archive_statusdir() WHERE name LIKE '%.ready';` re-run a minute apart: the number should not be rising.

**How to fix.** Measure the archive rate against the WAL rate (PG-INFO-008 reports both). If the archiver is simply too slow, parallelise it — every serious backup tool supports it — rather than making it asynchronous by hand. If it has stopped, treat it as PG-BAK-002.

**False positives and caveats.** PostgreSQL 12 and newer only; `pg_ls_archive_statusdir()` does not exist before that. Needs `pg_monitor`.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-wal.html#RUNTIME-CONFIG-WAL-ARCHIVING)

---

<a id="pg-bak-004"></a>
### PG-BAK-004 — archive_command is a no-op (WAL archived to nowhere)
**Priority 1** · Backup and recovery · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · primary only

**What fires it.** archive_mode is on and archive_command matches an effective no-op: 'true', '/bin/true', ':', 'exit 0', 'cd .', or a comment. Archiving reports success and keeps nothing.

**Reads.** `pg_settings`

**Platform.** This check is reported at **P100** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** An `archive_command` of `true`, `/bin/true`, `:`, `exit 0` or a redirect to `/dev/null` exits successfully without storing anything. Everything downstream believes archiving works: `pg_stat_archiver.archived_count` rises, `failed_count` stays at zero, WAL is recycled on schedule, and monitoring based on those counters is green. There is no archive and no point-in-time recovery, and nothing in the server will ever say so.

**How to confirm.** Look in the archive destination for the segments `pg_stat_archiver.last_archived_wal` claims were stored.

**How to fix.** Set a real `archive_command`, or `archive_mode = off` if archiving is genuinely not wanted — an honest "no PITR" is better than a fake one. This setting is usually left behind after someone used it to drain a backlog during an incident (see PG-BAK-002, step 3).

**False positives and caveats.** A command that pipes to a script is not detected here: the script may itself be a no-op. This check catches the obvious case, not every case.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-wal.html#RUNTIME-CONFIG-WAL-ARCHIVING)

---

<a id="pg-bak-005"></a>
### PG-BAK-005 — Archiving enabled but no archive_command or archive_library set
**Priority 5** · Backup and recovery · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · primary only

**What fires it.** archive_mode <> off and both archive_command and archive_library (15+) are empty. WAL is retained forever and the log fills with warnings.

**Reads.** `pg_settings`

**Platform.** This check is reported at **P100** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** With `archive_mode` on and no command or library to run, every completed segment is kept in `pg_wal` waiting for an archiver that cannot succeed. `pg_wal` grows without limit, the log fills with warnings, and the outcome is the same as PG-BAK-002 — usually faster, because nothing is draining at all.

**How to fix.** Either set `archive_command`/`archive_library`, or set `archive_mode = off` and accept that there is no PITR. Both are deliberate positions; this state is neither.

**False positives and caveats.** `archive_library` exists from PostgreSQL 15; on older versions only `archive_command` applies.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-wal.html#RUNTIME-CONFIG-WAL-ARCHIVING)

---

<a id="pg-bak-006"></a>
### PG-BAK-006 — wal_level = minimal
**Priority 20** · Backup and recovery · scope: setting · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** wal_level = minimal. No archiving, no streaming replication and no online base backup are possible without a restart.

**Reads.** `pg_settings`

**Why it matters.** `wal_level = minimal` omits the information needed to replay WAL anywhere other than this server's own crash recovery. It rules out streaming replication, archive-based recovery and online base backups simultaneously — so there is no standby, no PITR, and `pg_basebackup` will refuse. It also means raising the level later requires a restart, so this is not something that can be fixed in the middle of an incident.

**How to fix.** `ALTER SYSTEM SET wal_level = 'replica';` and restart. `replica` is the default and is right for almost everything; `logical` only if logical replication or CDC is needed, at the cost of somewhat more WAL.

**False positives and caveats.** `minimal` is a legitimate choice for a bulk-load-only staging server that is rebuilt rather than recovered — but then say so, because everything else about the server looks like it should be recoverable.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-wal.html)

---

<a id="pg-bak-007"></a>
### PG-BAK-007 — archive_timeout unset on a low-write primary
**Priority 50** · Backup and recovery · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · primary only

**What fires it.** archive_mode is on, archive_timeout = 0, and no pg_receivewal is connected. The current segment may not ship for hours, so the recovery point objective is undefined. 60-300 s is a typical setting.

**Reads.** `pg_settings, pg_stat_replication`

**Platform.** This check is reported at **P150** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** A WAL segment is archived when it fills. On a server that writes slowly, the current 16 MB segment can sit unarchived for hours, and everything in it is outside the recovery window for that whole time. `archive_timeout` forces a segment switch after a fixed interval, which bounds the exposure at the cost of one partly-filled segment per interval.

**How to fix.** Set `archive_timeout` to the recovery point objective you actually promise — 60 to 300 seconds is typical. The cost is a 16 MB segment per interval regardless of how little is in it, so on a very quiet server this is a real storage trade rather than a free one.

**False positives and caveats.** Not needed when `pg_receivewal` is streaming WAL continuously, which is why the check looks for it before firing.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-wal.html#RUNTIME-CONFIG-WAL-ARCHIVING)

---

<a id="pg-bak-008"></a>
### PG-BAK-008 — Last successful base backup unknown or older than 7 days
**Priority 1** · Backup and recovery · scope: cluster · cost 0 · source: external · pass: fast · effort M / risk low · since 0.1.0 · needs os, interview

**What fires it.** No backup tool output could be read (pgbackrest info, barman list-backups, wal-g backup-list) and the interview question is unanswered, so this fires with confidence low and details 'unverified'; or a tool reported the newest full/incremental as completed 7 or more days ago, or not OK.

**Thresholds.** `backup_age_days` = 7

**Reads.** `external backup tool output, .db-triage.yml interview`

**Platform.** This check is reported at **P100** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** The single most important fact about a database is whether it can be restored, and PostgreSQL has no backup history table to answer it. This check reads the backup tool's own output where one is reachable, and otherwise reports the honest answer: unverified. It fires at P1 with `confidence: low` rather than staying silent, because a report that omits backups reads as a report that found backups fine.

**How to fix.** Answer it: run `pgbackrest info`, `barman list-backups` or `wal-g backup-list`, and record the result under `interview:` in `.db-triage.yml`. Then note that a backup that has never been restored is a hypothesis — see PG-BAK-009.

**False positives and caveats.** "No backup tool on this host" is not "no backups": backups are frequently taken from a replica or by an external agent. This is why the finding is phrased as unverified rather than absent.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/backup.html)

---

<a id="pg-bak-009"></a>
### PG-BAK-009 — Restore never tested, or RPO/RTO undocumented
**Priority 50** · Backup and recovery · scope: interview · cost 0 · source: interview · pass: fast · effort L / risk low · since 0.1.0 · needs interview

**What fires it.** The answer to 'when was the last successful restore test?' is more than 90 days ago, never, or unknown; or RPO/RTO are not stated.

**Thresholds.** `restore_test_days` = 90

**Reads.** `.db-triage.yml interview`

**Why it matters.** A backup that has never been restored is a file with hopeful properties. Restore tests find the things backup tests do not: missing roles and tablespaces, an unarchived WAL gap, a recovery target that cannot be reached, an encryption key nobody has, and — most often — a restore time nobody had measured against the recovery time objective they promised.

**How to fix.** Restore the newest backup to a scratch host, to a specific point in time, and time it. Record the date and the measured duration under `interview:`. Repeat quarterly; 90 days is the threshold here because that is roughly how long a restore procedure stays accurate as the estate changes around it.

**False positives and caveats.** Interview-based: it fires until answered, and the answer ages out after 180 days.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/backup.html)

---

<a id="pg-bak-010"></a>
### PG-BAK-010 — Managed-platform backups not verifiable from SQL
**Priority 100** · Backup and recovery · scope: cluster · cost 0 · source: derived · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** A managed platform was fingerprinted. Confirm in the provider console that automated backup retention is greater than 0 and PITR is enabled: on RDS a retention period of 0 disables backups entirely.

**Reads.** `platform fingerprint`

**Why it matters.** On a managed platform, backups happen outside PostgreSQL, so `archive_mode`, `pg_stat_archiver` and the WAL directory tell you nothing about whether the instance is recoverable. The facts that matter are in the provider console.

**How to fix.** Confirm three things in the console: the automated backup retention period is greater than zero (on RDS, a retention of 0 disables backups entirely), point-in-time recovery is enabled, and the backup window does not collide with your heaviest batch job. Record the answers under `interview:`.

**False positives and caveats.** Provider snapshots are usually storage-level and restore as a new instance, which has a different recovery time profile from a PITR into an existing one. Measure it once.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/backup.html)

---

<a id="pg-bak-011"></a>
### PG-BAK-011 — Base backup running for more than 2 hours
**Priority 100** · Backup and recovery · scope: cluster · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · PostgreSQL 13+ · primary only · needs pg_monitor

**What fires it.** A pg_stat_progress_basebackup row whose elapsed time exceeds 2 hours, or whose phase has not advanced. Informational context for the operator: it explains load and WAL retention.

**Thresholds.** `duration_seconds` = 7,200

**Reads.** `pg_stat_progress_basebackup`

**Why it matters.** A base backup holds a WAL retention obligation for its whole duration and adds sustained read load. A run of more than two hours is worth knowing about while triaging anything else, because it explains I/O, it explains why `pg_wal` is not shrinking, and — if it is stuck rather than slow — it will keep doing both indefinitely.

**How to fix.** Nothing, if it is progressing: the check reports the streamed and total bytes so you can see. If the phase has not advanced, find the backup client and deal with it there.

**False positives and caveats.** PostgreSQL 13 and newer only.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/progress-reporting.html)

---


## Corruption signals (`CORR`)

<a id="pg-corr-001"></a>
### PG-CORR-001 — Data checksum failures reported
**Priority 1** · Corruption signals · scope: database · cost 0 · source: sql · pass: fast · effort L / risk high · since 0.1.0 · PostgreSQL 12+

**What fires it.** pg_stat_database.checksum_failures > 0 in any database, including the shared-objects row. Reported by the server, not inferred.

**Reads.** `pg_stat_database`

**Why it matters.** A checksum failure is the storage layer telling you it returned a page whose contents do not match what was written. This is a report, not an inference: PostgreSQL computed the checksum on read and it did not match. The cause is below the database — a failing device, a controller with a broken cache, memory without ECC, or a filesystem that lost a write — and it will not fix itself.

**How to confirm.** `SELECT datname, checksum_failures, checksum_last_failure FROM pg_stat_database WHERE checksum_failures > 0;` and the server log around `checksum_last_failure`.

**How to fix.** 1. Stop and take a backup *now*, before doing anything else, because every subsequent action risks propagating or destroying evidence. 2. Find which relation the failure is in from the server log (the checksum error names the file and block). 3. Verify the extent with `pg_amcheck` for indexes and a careful `SELECT` for the heap. 4. Rebuild what is damaged from a known-good backup or a replica; an index can be reindexed, a heap page cannot. 5. Replace or re-verify the hardware, because a single failure is rarely a single failure.

**False positives and caveats.** PostgreSQL 12 and newer, and only when checksums were enabled at cluster creation. Zero failures with checksums off means nothing at all (PG-CORR-004). Do **not** reach for `zero_damaged_pages` or `ignore_checksum_failure` — those hide the problem rather than solving it.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/checksums.html)

---

<a id="pg-corr-002"></a>
### PG-CORR-002 — zero_damaged_pages enabled
**Priority 1** · Corruption signals · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** zero_damaged_pages = on. Damaged pages are silently replaced with zeros on read, which is silent data loss.

**Reads.** `pg_settings`

**Why it matters.** With `zero_damaged_pages = on`, a page whose header fails validation is replaced in memory with zeros and the query continues with a WARNING. Every row on that page disappears from every query result, silently, and if the zeroed page is then written back the loss becomes permanent. This is a tool for a supervised salvage operation where the alternative is losing the whole relation.

**How to fix.** `ALTER SYSTEM RESET zero_damaged_pages; SELECT pg_reload_conf();`. If it was set during a recovery, take the backup and verify the relations that were read while it was on — you do not know which rows went missing.

**False positives and caveats.** Sometimes set in a container image or a recovery runbook and never removed. Always check whether it is still needed rather than assuming it is deliberate.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/checksums.html)

---

<a id="pg-corr-003"></a>
### PG-CORR-003 — ignore_checksum_failure enabled
**Priority 1** · Corruption signals · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** ignore_checksum_failure = on. Checksum mismatches are logged and the page is used anyway.

**Reads.** `pg_settings`

**Platform.** This check is reported at **P100** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** `ignore_checksum_failure = on` turns the strongest corruption signal the database has into a WARNING it then ignores. The bad page is used: its rows flow into query results, into indexes built from them, into the WAL stream that reaches every replica, and into every backup taken afterwards. It converts a detectable failure into an undetectable one that spreads.

**How to fix.** `ALTER SYSTEM RESET ignore_checksum_failure; SELECT pg_reload_conf();` and then treat any past failures as PG-CORR-001.

**False positives and caveats.** Has no effect when checksums are disabled — but its presence in the configuration is still worth removing so it does not surprise someone after checksums are enabled.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/checksums.html)

---

<a id="pg-corr-004"></a>
### PG-CORR-004 — Data checksums disabled
**Priority 50** · Corruption signals · scope: cluster · cost 0 · source: sql · pass: fast · effort L / risk med · since 0.1.0

**What fires it.** current_setting('data_checksums') = off. Silent storage corruption cannot be detected. Enabling requires pg_checksums with the cluster shut down (12+) or a logical rebuild.

**Reads.** `pg_settings`

**Platform.** This check is reported at **P150** on rds, cloudsql, azure, supabase, crunchy, timescale, heroku; reported at **P200** on aurora, neon, alloydb. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.


**Why it matters.** Without checksums, PostgreSQL has no way to notice that a page came back different from how it was written. Corruption is detected only when it happens to break something the server validates structurally; a flipped bit inside a value simply returns a wrong answer, and keeps returning it, into reports and into backups. Checksums do not prevent corruption; they are what makes it detectable while it is still one page.

**How to confirm.** `SHOW data_checksums;`

**How to fix.** Enabling requires the cluster to be shut down: `pg_checksums --enable -D <datadir>` (PostgreSQL 12 and newer), which rewrites every page and takes as long as reading the whole cluster. The alternative is a logical dump and reload into a new cluster created with `initdb --data-checksums`. Either way it is a planned outage, which is why this is P50 rather than P1.

**False positives and caveats.** Skipped on the managed platforms that decide this at instance creation. PostgreSQL 18 enables checksums by default for new clusters. The overhead is a few percent of CPU on write-heavy workloads — real, and much smaller than the cost of undetected corruption.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/checksums.html)

---

<a id="pg-corr-005"></a>
### PG-CORR-005 — Corruption messages in the recent server log
**Priority 1** · Corruption signals · scope: cluster · cost 2 · source: log · pass: deep · effort L / risk high · since 0.1.0 · PostgreSQL 10+ · needs superuser, os

**What fires it.** Any of: 'invalid page in block', 'could not read block', 'unexpected chunk number', 'missing chunk number', 'unexpected zero page', 'page verification failed', 'WAL contains references to invalid pages', 'PANIC' in the last 50 MB of server log. Crash-only patterns route to REL-011 instead.

**Thresholds.** `scan_bytes` = 52,428,800

**Reads.** `server log via pg_current_logfile()/pg_read_file`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** Some corruption never reaches a checksum: a truncated relation file, a torn multi-page structure, a TOAST chunk that does not match its length. Those surface as specific error messages in the server log — "invalid page in block", "unexpected chunk number", "missing chunk number", "could not read block" — and they are frequently seen by one unlucky query, logged, and never noticed.

**How to fix.** Treat any hit as PG-CORR-001: back up first, identify the relation, verify with `pg_amcheck`, rebuild from a known-good source, then investigate the storage.

**False positives and caveats.** Deep pass only: it reads the server log, which needs superuser or shell access. A pattern match in a log line is evidence to follow up, not a diagnosis.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/checksums.html)

---

<a id="pg-corr-006"></a>
### PG-CORR-006 — Collation version mismatch (index corruption risk)
**Priority 20** · Corruption signals · scope: database · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 13+

**What fires it.** pg_database.datcollversion differs from pg_database_collation_actual_version() (15+), or pg_collation.collversion differs from pg_collation_actual_version() (13+). A glibc or ICU upgrade changed sort order under existing text indexes, so index lookups can miss rows.

**Reads.** `pg_database, pg_collation`

**Why it matters.** A text index is stored in the sort order of its collation. When the operating system's locale data changes — a glibc upgrade is the usual cause, and moving between distributions is the other — the sort order can change under indexes that were built with the old one. The index is then internally consistent and wrong: equality and range lookups can miss rows that are present. Nothing errors; queries just quietly return fewer rows.

**How to confirm.** `SELECT datname, datcollversion, pg_database_collation_actual_version(oid) FROM pg_database;` and the equivalent over `pg_collation`.

**How to fix.** 1. `REINDEX` every index on a text, varchar or char column in the affected database, ideally `REINDEX INDEX CONCURRENTLY` so it does not block. 2. Only then `ALTER DATABASE <db> REFRESH COLLATION VERSION;` (or `ALTER COLLATION ... REFRESH VERSION`) — refreshing first records agreement you have not yet established. 3. Until the reindex is done, treat unique constraints on text columns as unverified.

**False positives and caveats.** PostgreSQL 13 and newer for collations, 15 and newer for the database-level version. PostgreSQL cannot tell you whether the *specific* sort orders you depend on actually changed, only that the provider's version string did — so this can be a false alarm, and it is not safe to assume it is.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/collation.html)

---

<a id="pg-corr-007"></a>
### PG-CORR-007 — No integrity-verification tooling installed (amcheck)
**Priority 100** · Corruption signals · scope: database · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · PostgreSQL 10+

**What fires it.** amcheck is listed in pg_available_extensions but not installed in this database. This is the PostgreSQL analogue of never running a consistency check.

**Reads.** `pg_available_extensions, pg_extension`

**Why it matters.** `amcheck` is how PostgreSQL verifies that a B-tree index still agrees with its heap and with its own invariants. Without it, a collation change (PG-CORR-006), a storage fault, or a bad restore is discovered by a user getting a wrong answer. It is the closest analogue to a scheduled consistency check, and it is not installed by default.

**How to fix.** `CREATE EXTENSION amcheck;` in each database, then schedule `pg_amcheck --heapallindexed` (PostgreSQL 14 and newer) against a replica or a restored copy rather than the primary — it reads everything and that is the point.

**False positives and caveats.** `amcheck` verifies structure and index-heap agreement; it does not detect a page whose *values* are wrong but structurally valid. That is what checksums are for.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/amcheck.html)

---

<a id="pg-corr-008"></a>
### PG-CORR-008 — Reserved: invalid indexes are reported by PG-IDX-001
**Priority 150** · Corruption signals · scope: relation · cost 0 · source: derived · pass: fast · effort S / risk low · since 0.1.0 · **status: retired** · superseded by PG-IDX-001

**What fires it.** Never emits. The row exists so the identifier is never reused.

**Why it matters.** Retired. Invalid indexes are reported by PG-IDX-001; this identifier is kept so it can never be reused.

**How to fix.** Nothing. See PG-IDX-001.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-createindex.html)

---


## Durability (`DUR`)

<a id="pg-dur-001"></a>
### PG-DUR-001 — fsync disabled
**Priority 1** · Durability · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** fsync = off. Any operating-system crash or power loss can leave the cluster unrecoverable, not merely missing recent transactions.

**Reads.** `pg_settings`

**Platform.** This check is reported at **P200** on aurora, neon, alloydb. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** `fsync = off` tells PostgreSQL never to ask the operating system to make anything durable. Write-ahead logging still happens, but the WAL is not flushed before the commit returns and data pages are not flushed at checkpoint, so after an operating-system crash or power loss the on-disk state can be arbitrarily inconsistent — not merely missing the last few seconds, but unrecoverable. The documentation's own word for the result is that the database may be unrecoverable.

**How to confirm.** `SHOW fsync;`

**How to fix.** `ALTER SYSTEM RESET fsync; SELECT pg_reload_conf();`. If this cluster genuinely does not need durability — a CI database rebuilt on every run, a throwaway import staging area — record `environment: dev` in `.db-triage.yml` so the finding is re-prioritised visibly rather than suppressed.

**False positives and caveats.** This is a legitimate setting for a database whose entire contents can be regenerated. It is never a legitimate setting for one that cannot.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/wal-reliability.html)

---

<a id="pg-dur-002"></a>
### PG-DUR-002 — full_page_writes disabled
**Priority 1** · Durability · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** full_page_writes = off. Torn pages after a crash are unrecoverable unless the filesystem guarantees atomic 8 kB writes (ZFS does; ext4 and xfs do not).

**Reads.** `pg_settings`

**Platform.** This check is reported at **P200** on aurora, neon, alloydb. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** A PostgreSQL page is 8 kB; most storage guarantees atomicity only at 512 bytes or 4 kB. A crash during a page write can therefore leave the page half-old and half-new — torn — and WAL replay cannot repair it, because WAL records describe changes relative to a page that is now neither version. `full_page_writes` fixes this by logging the entire page the first time it is touched after each checkpoint. Turning it off removes the repair mechanism.

**How to fix.** `ALTER SYSTEM RESET full_page_writes; SELECT pg_reload_conf();` unless the filesystem genuinely guarantees atomic 8 kB writes. ZFS does. ext4 and xfs do not, and neither do most cloud block devices regardless of what their documentation implies about durability. Confirm the filesystem before treating this as intentional.

**False positives and caveats.** It is also disabled implicitly when `wal_log_hints` is off and checksums are off on some replica setups; the finding reports both so the combination is visible. Turning it off does measurably reduce WAL volume, which is why it is tempting.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/wal-reliability.html)

---

<a id="pg-dur-003"></a>
### PG-DUR-003 — synchronous_commit off cluster-wide
**Priority 10** · Durability · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** synchronous_commit = off at server level. Bounded loss of up to about 3 x wal_writer_delay (600 ms by default) on a crash. Often deliberate; always worth knowing about.

**Reads.** `pg_settings`

**Why it matters.** `synchronous_commit = off` lets COMMIT return before its WAL record is flushed. The loss on a crash is bounded — roughly three times `wal_writer_delay`, so about 600 ms by default — and the cluster stays internally consistent: no torn transactions, no corruption, just some committed transactions that are not there any more. That is a real and sometimes correct trade. What makes it worth a P10 row is that it is invisible: the application was told the transaction was durable.

**How to confirm.** `SHOW synchronous_commit;` and `SELECT * FROM pg_db_role_setting;` for overrides.

**How to fix.** If it is deliberate, keep it and make sure the people who own the data know. If it is not, `ALTER SYSTEM RESET synchronous_commit; SELECT pg_reload_conf();`. The better shape is usually per-role or per-transaction — `ALTER ROLE bulk_loader SET synchronous_commit = off` — so the trade applies to the work that can tolerate it and not to everything.

**False positives and caveats.** Frequently a deliberate choice on queue tables, event ingestion and cache databases. The check reports it, at P10, rather than judging it.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-wal.html)

---

<a id="pg-dur-004"></a>
### PG-DUR-004 — synchronous_commit weaker than the synchronous-standby expectation
**Priority 100** · Durability · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 9.6+ · primary only · needs pg_monitor

**What fires it.** A standby has sync_state = 'sync' while synchronous_commit is 'local' or 'remote_write'. The standby may lose the last transactions on a crash even though the topology says it will not.

**Reads.** `pg_settings, pg_stat_replication`

**Platform.** This check is reported at **P200** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** `sync_state = 'sync'` promises that a commit is safe on the standby before it returns. At `synchronous_commit = remote_write` the primary waits only for the standby's operating system to accept the WAL, not for it to reach durable storage; at `local` it waits for nothing on the standby at all. The topology says synchronous replication; the setting says otherwise, and a crash of the standby host is where the difference shows up.

**How to fix.** Set `synchronous_commit = on` (or `remote_apply` if reads on the standby must see committed data) so the guarantee matches the topology. If the latency cost of `on` is the reason for the current setting, then the honest position is that this is asynchronous replication with a synchronous-looking configuration, and it should be documented as such.

**False positives and caveats.** `remote_write` is a defensible middle ground when the standby is on independent power and you accept losing transactions only if both hosts fail. It is a considered trade; this row exists to make sure it was considered.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/warm-standby.html#SYNCHRONOUS-REPLICATION)

---

<a id="pg-dur-005"></a>
### PG-DUR-005 — Unlogged tables present
**Priority 100** · Durability · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** Any relation with relpersistence = 'u'. Contents are truncated on crash recovery and are never replicated to a standby.

**Reads.** `pg_class`

**Platform.** This check is reported at **P50** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** An unlogged relation is not written to WAL. Three consequences follow, and only the first is widely known: it is truncated to empty on crash recovery; it does not exist on any standby; and it is not in any base backup or PITR restore. The write performance is genuinely better, which is why it is used — and a table that was created unlogged for a good reason two years ago is now frequently holding something someone expects to survive.

**How to fix.** Confirm the contents are genuinely regenerable. If they are not: `ALTER TABLE t SET LOGGED;`, which rewrites the table and writes all of it to WAL, so it needs a window on anything large.

**False positives and caveats.** Correct and useful for staging tables, materialised caches and session stores. The finding lists the size so a 40 GB "cache" that nobody remembers creating is visible.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-createtable.html)

---

<a id="pg-dur-006"></a>
### PG-DUR-006 — wal_sync_method changed from the platform default
**Priority 150** · Durability · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** pg_settings.source for wal_sync_method is not 'default'. Almost never the right thing to change; listed for review.

**Reads.** `pg_settings`

**Platform.** This check is reported at **P200** on aurora, neon, alloydb. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** PostgreSQL picks the fastest flush method its build detected as safe on this platform. Overriding it is occasionally right for a specific storage stack and is more often a setting copied from a blog post whose original justification is long gone — and an unsafe method here silently weakens every durability guarantee above it.

**How to fix.** Compare against the platform default reported in the finding. `pg_test_fsync` measures the alternatives on this host; unless it shows a real difference *and* the method is safe on this filesystem, reset it.

**False positives and caveats.** Review row. A non-default value is not automatically wrong; it is automatically worth being able to explain.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-wal.html)

---


## Replication and HA (`REPL`)

<a id="pg-repl-001"></a>
### PG-REPL-001 — Synchronous replication configured but no synchronous standby connected
**Priority 1** · Replication and HA · scope: cluster · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 9.6+ · primary only · needs pg_monitor

**What fires it.** synchronous_standby_names is non-empty, no pg_stat_replication row has sync_state = 'sync' or 'quorum', and synchronous_commit is not 'off' or 'local'. Commits are hanging right now. **Except on Neon**, where the named synchronous standby is `walproposer` — see *False positives* below.

**Reads.** `pg_settings, pg_stat_replication`

**Why it matters.** With `synchronous_standby_names` set and no standby matching it, every commit that requires synchronous confirmation waits — indefinitely. Sessions block in `SyncRep` wait, connections accumulate, and the application sees an unavailable database while the server itself looks healthy: it is not out of CPU, out of memory or out of connections yet, it is simply waiting for a standby that is not there.

**How to confirm.** `SELECT application_name, sync_state, state FROM pg_stat_replication;` and `SHOW synchronous_standby_names;`

**How to fix.** 1. If the standby is coming back, that is the fix: reconnect it. 2. If it is gone, `ALTER SYSTEM SET synchronous_standby_names = ''; SELECT pg_reload_conf();` unblocks commits immediately — and it also drops the durability guarantee those commits were promised, so it is a deliberate trade made under pressure, not a cleanup. 3. Afterwards, use a quorum specification (`ANY 1 (a, b)`) so the loss of one standby cannot do this again.

**False positives and caveats.** `synchronous_commit = off` or `local` at the server level defeats synchronous replication regardless of the names, so the check requires neither to be set before firing.

The one known false positive, and the reason the SQL changed in 0.2.0: **Neon**. Neon sets `synchronous_standby_names = 'walproposer'`, and walproposer is not a standby — it is a background worker inside the compute that ships WAL to a Paxos quorum of safekeepers and releases the commit when the quorum has it. That acknowledgement never appears as `sync_state = 'sync'` or `'quorum'` in `pg_stat_replication`, so the P1 conclusion "commits are hanging right now" was simply false: on Neon the commits were fine, and durability was the safekeepers'. The check now suppresses itself when the `neon_superuser` role is present **and** either `synchronous_standby_names` names `walproposer` or a `pg_stat_replication` row is called `walproposer`. Both halves matter: on a stock cluster that happens to have `synchronous_standby_names = 'walproposer'` and no such standby, commits really do hang and the check still fires at P1. This was fixed in the check rather than gated in the registry because the fault was in the check's model of the world, not in its priority — see [reference/platforms.md](platforms.md#pg-repl-001-on-neon-the-check-was-wrong-not-the-priority).

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/warm-standby.html#SYNCHRONOUS-REPLICATION)

---

<a id="pg-repl-002"></a>
### PG-REPL-002 — Inactive replication slot retaining more than 10 GB of WAL
**Priority 1** · Replication and HA · scope: slot · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 9.4+

**What fires it.** A slot with active = false whose restart_lsn is 10 GB or more behind the current WAL position, or whose wal_status is 'unreserved' (13+). pg_wal grows until the volume fills and the primary PANICs.

**Thresholds.** `retained_bytes` = 10,737,418,240

**Reads.** `pg_replication_slots, pg_current_wal_lsn()`

**Why it matters.** A replication slot guarantees that the primary keeps every WAL segment its consumer has not yet confirmed — forever, and by design, because that is the entire purpose of a slot. When the consumer stops and the slot is left behind, `pg_wal` grows at the full WAL rate until the volume fills and the primary PANICs. Ten gigabytes retained by something that is not connected is an outage on a schedule you can calculate from the WAL rate.

**How to confirm.** `SELECT slot_name, active, wal_status, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) FROM pg_replication_slots;`

**How to fix.** 1. Identify the consumer from the slot name and type. 2. If it is coming back, restart it and confirm `active` becomes true. 3. If it is gone for good: `SELECT pg_drop_replication_slot('<name>');` — irreversible, and the consumer will have to re-snapshot from scratch, so confirm nobody intends to resume it. 4. Then set `max_slot_wal_keep_size` (PG-REPL-009) so the next dead consumer breaks its own slot instead of the primary.

**False positives and caveats.** A logical slot also holds `catalog_xmin`, so it blocks vacuum as well as WAL recycling (PG-VAC-005). Dropping a logical slot used by a CDC pipeline forces a full re-snapshot downstream, which can be a much larger event than the disk pressure it relieves.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/warm-standby.html#STREAMING-REPLICATION-SLOTS)

---

<a id="pg-repl-003"></a>
### PG-REPL-003 — Inactive replication slot retaining more than 1 GB of WAL
**Priority 5** · Replication and HA · scope: slot · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 9.4+

**What fires it.** A slot with active = false retaining between 1 GB and 10 GB of WAL.

**Thresholds.** `retained_bytes` = 1,073,741,824, `retained_bytes_high` = 10,737,418,240

**Reads.** `pg_replication_slots, pg_current_wal_lsn()`

**Why it matters.** The same mechanism as PG-REPL-002, one order of magnitude earlier. A gigabyte of retained WAL behind an inactive slot is not itself a problem; the rate of change is. The finding reports the retained size so a second run tells you how fast it is growing and therefore how long there is.

**How to fix.** As PG-REPL-002, with time to find the consumer's owner rather than guessing.

**False positives and caveats.** A slot that is briefly inactive during a consumer restart is normal. Two consecutive runs showing growth is the signal.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/warm-standby.html#STREAMING-REPLICATION-SLOTS)

---

<a id="pg-repl-004"></a>
### PG-REPL-004 — Inactive replication slot
**Priority 50** · Replication and HA · scope: slot · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 9.4+

**What fires it.** A slot with active = false retaining less than 1 GB. The consumer may be gone for good; details include inactive_since (17+), slot type and output plugin.

**Thresholds.** `retained_bytes_low` = 1,073,741,824

**Reads.** `pg_replication_slots`

**Why it matters.** A slot with a consumer that never returns is a slow-motion version of PG-REPL-002: it holds WAL and, if logical, an xmin horizon, and nothing will ever clean it up. Slots outlive the thing that created them — a decommissioned standby, a CDC connector removed from the pipeline, a `pg_basebackup` that was interrupted — and they are invisible in every topology diagram.

**How to fix.** Identify the consumer, then either restart it or drop the slot. `inactive_since` (PostgreSQL 17 and newer) tells you how long it has been gone, which is usually the deciding fact.

**False positives and caveats.** Physical slots for standbys that are legitimately offline for maintenance look identical to abandoned ones. Ask before dropping.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/warm-standby.html#STREAMING-REPLICATION-SLOTS)

---

<a id="pg-repl-005"></a>
### PG-REPL-005 — Replication slot invalidated or lost
**Priority 10** · Replication and HA · scope: slot · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 13+

**What fires it.** pg_replication_slots.wal_status = 'lost' (13+), or conflicting = true (16+), or invalidation_reason is set (17+). The consumer must be re-initialised; the slot still exists and misleads anyone reading the topology.

**Reads.** `pg_replication_slots`

**Why it matters.** `wal_status = 'lost'` means the WAL this slot needed has already been removed — usually because `max_slot_wal_keep_size` did its job and broke the slot rather than letting it fill the disk. That is the intended outcome, and it still needs handling: the consumer cannot resume from where it stopped, so it must be re-initialised from a fresh base backup or snapshot. The slot object survives, so anything that monitors "does the slot exist" reports it as healthy.

**How to confirm.** `SELECT slot_name, wal_status, conflicting, invalidation_reason FROM pg_replication_slots;` (the last two columns are PostgreSQL 16 and 17 respectively).

**How to fix.** Drop the slot and rebuild the consumer: `pg_basebackup` for a physical standby, a fresh initial snapshot for a logical subscriber. There is no way to resume a lost slot.

**False positives and caveats.** PostgreSQL 13 and newer. On a standby, a slot can also be invalidated by a recovery conflict, which is what the `conflicting` column reports.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/warm-standby.html#STREAMING-REPLICATION-SLOTS)

---

<a id="pg-repl-006"></a>
### PG-REPL-006 — Streaming replica lagging badly
**Priority 5** · Replication and HA · scope: replica · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 10+ · primary only · needs pg_monitor

**What fires it.** pg_wal_lsn_diff(sent_lsn, replay_lsn) >= 1 GB or replay_lag >= 5 minutes for a connected standby. A failover now would lose minutes of data or take minutes to complete.

**Thresholds.** `lag_bytes` = 1,073,741,824, `lag_seconds` = 300

**Reads.** `pg_stat_replication`

**Platform.** This check is reported at **P200** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** A standby a gigabyte or five minutes behind is not a failover target: promoting it either loses everything after its replay position or spends minutes applying the backlog first, during which it is not serving. It is also not a read replica in any useful sense, because the reads are answering with stale data by exactly that margin.

**How to confirm.** `SELECT application_name, state, sync_state, write_lag, flush_lag, replay_lag, pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) FROM pg_stat_replication;`

**How to fix.** Find which half is behind. If `sent_lsn` is close to the primary's position but `replay_lsn` trails, the standby cannot apply fast enough — usually single-threaded replay against a write-heavy primary, or recovery conflicts (PG-REPL-011). If `sent_lsn` itself trails, it is the network or the WAL sender. `pg_stat_replication`'s `write_lag`, `flush_lag` and `replay_lag` separate the three stages.

**False positives and caveats.** The lag columns are null until the standby reports back, so a freshly connected standby shows nulls rather than zeros. On an idle primary, `replay_lag` can be stale simply because nothing has been sent.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/warm-standby.html)

---

<a id="pg-repl-007"></a>
### PG-REPL-007 — Streaming replica lag moderate
**Priority 50** · Replication and HA · scope: replica · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 10+ · primary only · needs pg_monitor

**What fires it.** pg_wal_lsn_diff(sent_lsn, replay_lsn) >= 100 MB or replay_lag >= 30 s, below the REPL-006 thresholds.

**Thresholds.** `lag_bytes` = 104,857,600, `lag_seconds` = 30, `lag_bytes_high` = 1,073,741,824, `lag_seconds_high` = 300

**Reads.** `pg_stat_replication`

**Platform.** This check is reported at **P200** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** The same measurement as PG-REPL-006 at a threshold that is worth watching rather than acting on. A hundred megabytes or thirty seconds is normal on a busy primary during a batch job and abnormal at 3am.

**How to fix.** Nothing on its own. Compare against a previous run: steady lag at this level is a capacity statement about the standby, and growing lag is PG-REPL-006 arriving.

**False positives and caveats.** A single sample. Lag is bursty by nature.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/warm-standby.html)

---

<a id="pg-repl-008"></a>
### PG-REPL-008 — Standby not streaming
**Priority 5** · Replication and HA · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 9.6+ · standby only

**What fires it.** In recovery and either pg_stat_wal_receiver is empty or its status is not 'streaming' while restore_command is empty; or the receive-to-replay gap is 1 GB or more (replay stalled).

**Thresholds.** `replay_gap_bytes` = 1,073,741,824

**Reads.** `pg_stat_wal_receiver, pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn()`

**Why it matters.** A standby that is not streaming is falling further behind every second, and unlike lag there is no bound on it. Three shapes produce this: the WAL receiver is not running at all, it is running but not in `streaming` state (usually authentication or a network problem), or it is receiving fine and replay has stalled — which is the dangerous one, because `pg_last_wal_receive_lsn()` keeps advancing and any monitoring that watches only the receiver looks healthy.

**How to confirm.** `SELECT * FROM pg_stat_wal_receiver;` and `SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn(), pg_last_xact_replay_timestamp();`

**How to fix.** Read the standby's log: the WAL receiver reports its own failures there in detail. For a stalled replay, look for a recovery conflict or a very long read query holding the relation the replay needs.

**False positives and caveats.** A standby recovering from an archive rather than streaming legitimately has no WAL receiver, which is why the check requires `restore_command` to be empty before firing on that condition.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/warm-standby.html)

---

<a id="pg-repl-009"></a>
### PG-REPL-009 — Slot WAL retention unbounded
**Priority 50** · Replication and HA · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · PostgreSQL 13+ · primary only

**What fires it.** PostgreSQL 13 or newer, at least one replication slot exists, and max_slot_wal_keep_size = -1. A dead consumer can then fill the WAL volume and take down the primary. Size a cap to the volume, for example 20-50 GB.

**Reads.** `pg_settings, pg_replication_slots`

**Platform.** This check is reported at **P150** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** `max_slot_wal_keep_size = -1` means a slot can retain WAL without limit. That is what makes PG-REPL-002 an outage rather than an inconvenience: a single stopped consumer can fill the WAL volume and PANIC the primary. Setting a cap converts that failure mode into a broken slot (PG-REPL-005), which costs one consumer a re-snapshot instead of costing everyone the database.

**How to fix.** Size the cap to the WAL volume and to how long you want a consumer to be able to be away: `ALTER SYSTEM SET max_slot_wal_keep_size = '50GB'; SELECT pg_reload_conf();`. Then monitor `wal_status` so a slot that gets invalidated is noticed rather than discovered later.

**False positives and caveats.** PostgreSQL 13 and newer. Setting it too low invalidates slots during ordinary consumer restarts, so size it against the longest outage you want to survive, not the shortest.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-replication.html)

---

<a id="pg-repl-010"></a>
### PG-REPL-010 — Standby streaming without a slot while wal_keep_size is 0
**Priority 50** · Replication and HA · scope: replica · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · PostgreSQL 9.4+ · primary only · needs pg_monitor

**What fires it.** A pg_stat_replication row whose pid is not any slot's active_pid, while wal_keep_size (or wal_keep_segments before 13) is 0. Any network interruption that outlasts checkpoint recycling forces a rebuild of that standby.

**Reads.** `pg_stat_replication, pg_replication_slots, pg_settings`

**Platform.** This check is reported at **P200** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** Without a slot, the primary keeps only the WAL its own checkpoints have not yet recycled. A standby that disconnects for longer than that — a network partition, a reboot, a long GC pause — comes back asking for a segment that no longer exists and cannot resume. The recovery from that is a full base backup, which on a large database is measured in hours.

**How to fix.** Give every standby a physical replication slot (`primary_slot_name` on the standby), and pair it with `max_slot_wal_keep_size` (PG-REPL-009) so the slot cannot become the new problem. `wal_keep_size` is the older, cruder alternative: it keeps a fixed amount for everyone, which is both more disk and less protection.

**False positives and caveats.** Some deployments deliberately avoid slots and rely on WAL archiving plus `restore_command` for catch-up, which is a legitimate design. The check cannot see the standby's `restore_command`, so confirm before acting.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-replication.html)

---

<a id="pg-repl-011"></a>
### PG-REPL-011 — Standby query conflicts high
**Priority 50** · Replication and HA · scope: database · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · standby only

**What fires it.** On a standby, total pg_stat_database_conflicts divided by days since stats reset is 100 per day or more. Queries are being cancelled; consider hot_standby_feedback (and its primary-side bloat cost) or a larger max_standby_streaming_delay.

**Thresholds.** `conflicts_per_day` = 100

**Reads.** `pg_stat_database_conflicts, pg_stat_database`

**Why it matters.** Replay on a standby must sometimes remove or lock something a running query is reading. When it cannot wait any longer (`max_standby_streaming_delay`), it cancels the query. A hundred cancellations a day means the standby is not usable for the queries being run against it, and the users are seeing "canceling statement due to conflict with recovery".

**How to confirm.** `SELECT * FROM pg_stat_database_conflicts;`

**How to fix.** Two directions, and they trade against each other. Raise `max_standby_streaming_delay` to let queries finish, at the cost of replay lag (PG-REPL-006). Or set `hot_standby_feedback = on` so the primary holds back vacuum for this standby's queries, at the cost of bloat on the primary (PG-VAC-005 there, and PG-REPL-016 here). There is no setting that gives both; pick which cost you prefer.

**False positives and caveats.** Conflict counters are cumulative since the statistics reset. The check divides by the window, which is why it needs a window long enough to be meaningful.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/hot-standby.html#HOT-STANDBY-CONFLICT)

---

<a id="pg-repl-012"></a>
### PG-REPL-012 — Logical subscription disabled or erroring
**Priority 10** · Replication and HA · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** pg_subscription.subenabled = false; or enabled with no worker pid in pg_stat_subscription; or pg_stat_subscription_stats.apply_error_count/sync_error_count > 0 (15+). Data diverges while the publisher's slot keeps retaining WAL.

**Reads.** `pg_subscription, pg_stat_subscription, pg_stat_subscription_stats`

**Why it matters.** A stopped or erroring logical subscription is a silent data divergence. The subscriber keeps serving reads with data that is progressively more out of date, and the publisher's replication slot keeps retaining WAL for a consumer that is not consuming (PG-REPL-002). Apply errors are usually a constraint violation on the subscriber or a schema change applied on only one side.

**How to fix.** Read the error: `SELECT * FROM pg_stat_subscription_stats;` (PostgreSQL 15 and newer) and the subscriber's log. Fix the schema or the conflicting row, then re-enable. On PostgreSQL 15 and newer, `ALTER SUBSCRIPTION ... SKIP (lsn = ...)` skips a single poisoned transaction — which is a decision to lose data, so make it deliberately.

**False positives and caveats.** `pg_stat_subscription_stats` does not exist before PostgreSQL 15; the check falls back to reporting the enabled state and worker count, and the errors have to come from the log.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/logical-replication-subscription.html)

---

<a id="pg-repl-013"></a>
### PG-REPL-013 — Published table without a usable replica identity
**Priority 10** · Replication and HA · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 10+ · primary only

**What fires it.** A table published for UPDATE or DELETE with relreplident = 'n'; or 'd' with no primary key; or 'i' with no valid replica-identity index. UPDATE and DELETE on the publisher error out.

**Reads.** `pg_publication_tables, pg_publication, pg_class, pg_index`

**Why it matters.** Logical replication identifies rows on the subscriber by their replica identity. A table published for UPDATE or DELETE with `REPLICA IDENTITY NOTHING`, or with `DEFAULT` and no primary key, has no way to identify a row — so PostgreSQL refuses the statement outright on the *publisher*. This is not a replication warning; it is application statements failing.

**How to confirm.** `SELECT relname, relreplident FROM pg_class WHERE oid = 'schema.table'::regclass;`

**How to fix.** Give the table a primary key, which is the right answer for other reasons too (PG-SCHEMA-003). Failing that, `ALTER TABLE t REPLICA IDENTITY USING INDEX <a unique, non-partial, NOT NULL index>`. `REPLICA IDENTITY FULL` works but ships the whole old row and makes the subscriber do a full scan per change (PG-SCHEMA-004).

**False positives and caveats.** Only applies to publications that include UPDATE or DELETE; an insert-only publication is unaffected.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/logical-replication-publication.html)

---

<a id="pg-repl-014"></a>
### PG-REPL-014 — Synchronous standby with high flush lag
**Priority 50** · Replication and HA · scope: replica · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 10+ · primary only · needs pg_monitor

**What fires it.** A standby with sync_state = 'sync' whose flush_lag is 1 second or more. Every commit on the primary waits that long.

**Thresholds.** `flush_lag_seconds` = 1

**Reads.** `pg_stat_replication`

**Platform.** This check is reported at **P200** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** With a synchronous standby, `flush_lag` is added directly to every commit on the primary. A second of flush lag means every write transaction takes a second longer than the primary's own work required — and the cause is on the other host, so nothing you measure on the primary explains it.

**How to fix.** Look at the standby's storage: `flush_lag` is the time to get WAL onto its durable storage. Slow disks, a saturated network, or a standby doing heavy read work are the usual causes. If the latency is inherent, the honest options are to move the standby closer, or to accept asynchronous replication and say so.

**False positives and caveats.** PostgreSQL 10 and newer for the lag columns. On a lightly loaded primary these can be stale.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/warm-standby.html#SYNCHRONOUS-REPLICATION)

---

<a id="pg-repl-015"></a>
### PG-REPL-015 — WAL senders or replication slots at capacity
**Priority 50** · Replication and HA · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 9.4+ · primary only · needs pg_monitor

**What fires it.** Connected WAL senders >= max_wal_senders, or existing slots >= max_replication_slots. A new standby or a base backup cannot connect.

**Reads.** `pg_stat_replication, pg_replication_slots, pg_settings`

**Why it matters.** `max_wal_senders` and `max_replication_slots` are hard limits, and both need a restart to raise. Hitting either means the next standby, `pg_basebackup`, `pg_receivewal` or logical subscriber is refused — which is usually discovered at the worst moment, when someone is trying to build a replacement standby during an incident.

**How to fix.** Raise the limit and restart during a planned window, before you need the headroom. Leave room for at least one base backup on top of the standbys you run: `pg_basebackup` consumes a WAL sender for its duration.

**False positives and caveats.** Both settings need a restart, so this is a plan-ahead finding rather than a fix-now one.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-replication.html)

---

<a id="pg-repl-016"></a>
### PG-REPL-016 — hot_standby_feedback on with long-running standby queries
**Priority 150** · Replication and HA · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · standby only · needs pg_monitor

**What fires it.** On a standby with hot_standby_feedback = on, the longest active query is 30 minutes or older. That query is pinning the primary's xmin horizon (see PG-VAC-005 on the primary).

**Thresholds.** `query_seconds` = 1,800

**Reads.** `pg_settings, pg_stat_activity`

**Why it matters.** `hot_standby_feedback = on` makes this standby report its oldest transaction back to the primary so the primary will not vacuum away rows the standby's queries still need. That is how you stop recovery conflicts (PG-REPL-011) — and it means a long-running query here directly holds the primary's xmin horizon, so the primary bloats and drifts toward wraparound because of a report running on a replica.

**How to confirm.** On the primary: `SELECT backend_xmin, age(backend_xmin), application_name FROM pg_stat_replication;`

**How to fix.** Cap query duration on the standby (`ALTER ROLE reporting SET statement_timeout = '30min'`), or turn feedback off and raise `max_standby_streaming_delay` instead so the cost lands here rather than on the primary.

**False positives and caveats.** The consequence is invisible from the standby: PG-VAC-005 fires on the *primary*, which is a different report.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/hot-standby.html#HOT-STANDBY-CONFLICT)

---


## Checkpoints and write-ahead log (`WAL`)

<a id="pg-wal-001"></a>
### PG-WAL-001 — Checkpoints mostly requested (max_wal_size too small)
**Priority 50** · Checkpoints and write-ahead log · scope: cluster · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · primary only

**What fires it.** At least 20 checkpoints since the statistics reset and requested / (requested + timed) >= 0.5. Every requested checkpoint restarts full-page writes; the default max_wal_size of 1 GB is small for any real write load.

**Thresholds.** `min_checkpoints` = 20, `requested_ratio` = 0.5

**Reads.** `pg_stat_bgwriter (<=16) / pg_stat_checkpointer (17+)`

**Platform.** This check is reported at **P200** on aurora, neon, alloydb. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** A checkpoint happens either because `checkpoint_timeout` elapsed (timed) or because WAL volume reached `max_wal_size` (requested). Requested checkpoints are the bad kind: they are unpredictable, they bunch under load, and each one restarts full-page-image logging, so the WAL immediately after a checkpoint is several times larger than the changes it records. A server checkpointing on volume is generating more WAL, which triggers more checkpoints.

**How to confirm.** `SELECT * FROM pg_stat_bgwriter;` (or `pg_stat_checkpointer` on PostgreSQL 17 and newer) — the ratio of requested to timed should fall.

**How to fix.** Raise `max_wal_size` until checkpoints are mostly timed — it costs disk in `pg_wal` and nothing else, and 8-16 GB is unremarkable on a busy server. Then, if checkpoints are still bunching, raise `checkpoint_timeout` towards 15-30 minutes so each one has longer to spread its writes.

**False positives and caveats.** Both counters are cumulative since the statistics reset, so a burst of requested checkpoints during last month's data load still shows here. Check the reset timestamp before acting.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/wal-configuration.html)

---

<a id="pg-wal-002"></a>
### PG-WAL-002 — max_wal_size at the default on a write-active primary
**Priority 100** · Checkpoints and write-ahead log · scope: cluster · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · primary only

**What fires it.** max_wal_size is 1 GB and WAL generation is 1 GB/hour or more (from pg_stat_wal since reset on 14+, otherwise from the checkpoint rate). Complements WAL-001.

**Thresholds.** `wal_bytes_per_hour` = 1,073,741,824

**Reads.** `pg_settings, pg_stat_wal`

**Platform.** This check is reported at **P200** on aurora, neon, alloydb. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** The shipped `max_wal_size` of 1 GB was chosen so PostgreSQL starts on a small machine. On a server generating a gigabyte of WAL an hour, it is consumed every hour, so checkpoints are driven by volume rather than by the clock — which is PG-WAL-001 with the cause named.

**How to fix.** Raise it. The rule of thumb is enough WAL for at least one `checkpoint_timeout` of writing, so that timed checkpoints win: at 1 GB/hour and a 15-minute timeout, 2 GB is the floor and more is better. The cost is `pg_wal` disk.

**False positives and caveats.** Below PostgreSQL 14 there is no `pg_stat_wal`, so the rate is estimated from the WAL position against uptime, which is a lower bound.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/wal-configuration.html)

---

<a id="pg-wal-003"></a>
### PG-WAL-003 — checkpoint_completion_target below 0.9
**Priority 150** · Checkpoints and write-ahead log · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** checkpoint_completion_target < 0.9. The pre-14 default of 0.5 concentrates checkpoint writes into the first half of the interval.

**Thresholds.** `target` = 0.9

**Reads.** `pg_settings`

**Platform.** This check is reported at **P200** on aurora, neon, alloydb. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** `checkpoint_completion_target` is the fraction of the checkpoint interval over which the checkpointer spreads its writes. At 0.5 — the default before PostgreSQL 14 — the same dirty pages are written in half the time, which shows up as a periodic I/O spike and a matching latency spike every checkpoint.

**How to fix.** `ALTER SYSTEM SET checkpoint_completion_target = 0.9; SELECT pg_reload_conf();`. This is the PostgreSQL 14 default and there is very little reason to run lower.

**False positives and caveats.** Cosmetic on a server whose storage is nowhere near saturated. It costs nothing to set correctly.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/wal-configuration.html)

---

<a id="pg-wal-004"></a>
### PG-WAL-004 — Backends forced to write or fsync their own buffers
**Priority 100** · Checkpoints and write-ahead log · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · primary only

**What fires it.** pg_stat_bgwriter.buffers_backend_fsync > 0 or backend writes exceed checkpointer plus background-writer writes (<=16); from 16 the same signal is read from pg_stat_io for backend_type 'client backend'. The checkpointer and background writer cannot keep up.

**Reads.** `pg_stat_bgwriter (<=16), pg_stat_io (16+)`

**Platform.** This check is reported at **P200** on aurora, neon, alloydb. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** Dirty buffers are supposed to be written by the checkpointer and the background writer, off the critical path. When a backend cannot find a clean buffer to evict, it writes one itself — inside the query, while the user waits. A backend *fsync* is worse: it means the fsync request queue to the checkpointer was full, which only happens when the checkpointer is already behind.

**How to confirm.** PostgreSQL 16 and newer: `SELECT backend_type, writes, fsyncs FROM pg_stat_io WHERE context='normal' AND object='relation';` Older: `SELECT buffers_backend, buffers_backend_fsync, buffers_checkpoint, buffers_clean FROM pg_stat_bgwriter;`

**How to fix.** In order of usual effect: raise `max_wal_size` so checkpoints are less frequent and less bunched (PG-WAL-001); raise `bgwriter_lru_maxpages` and lower `bgwriter_delay` so the background writer cleans more per round (PG-WAL-005); and check whether the storage is simply saturated, which no setting will fix.

**False positives and caveats.** PostgreSQL 17 removed `buffers_backend` and `buffers_backend_fsync`; the check reads `pg_stat_io` from 16 onward and `pg_stat_bgwriter` below that.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/wal-configuration.html)

---

<a id="pg-wal-005"></a>
### PG-WAL-005 — Background writer hitting its per-round limit
**Priority 150** · Checkpoints and write-ahead log · scope: cluster · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · primary only

**What fires it.** pg_stat_bgwriter.maxwritten_clean >= 1,000 per day since the statistics reset. bgwriter_lru_maxpages is stopping the cleaning scan early.

**Thresholds.** `maxwritten_per_day` = 1,000

**Reads.** `pg_stat_bgwriter`

**Platform.** This check is reported at **P200** on aurora, neon, alloydb. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** The background writer stops each cleaning round when it has written `bgwriter_lru_maxpages` buffers. Hitting that limit repeatedly means it is not cleaning as fast as buffers are being dirtied, so the shortfall is paid by backends writing their own (PG-WAL-004).

**How to fix.** Raise `bgwriter_lru_maxpages` (default 100) and consider lowering `bgwriter_delay` (default 200 ms) so rounds happen more often. Both take effect on reload.

**False positives and caveats.** Only meaningful next to PG-WAL-004: a background writer that hits its limit while no backend is writing its own buffers is keeping up well enough.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-resource.html)

---

<a id="pg-wal-006"></a>
### PG-WAL-006 — pg_wal directory unusually large
**Priority 50** · Checkpoints and write-ahead log · scope: cluster · cost 1 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** Sum of pg_ls_waldir() sizes >= max(3 x max_wal_size, 50 GB). This is the symptom; the cause is BAK-002/003, REPL-002/003, or a large wal_keep_size.

**Thresholds.** `waldir_multiple` = 3, `waldir_floor_bytes` = 53,687,091,200

**Reads.** `pg_ls_waldir(), pg_settings`

**Platform.** This check is reported at **P200** on aurora, neon, alloydb. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** `pg_wal` should hover around `max_wal_size` plus whatever `wal_keep_size` and the slots require. Several times that means something is preventing recycling, and `pg_wal` filling its volume is a PANIC rather than a degradation. This check is the symptom; the cause is one of: archiving failing or stalled (PG-BAK-002, PG-BAK-003), a slot retaining WAL (PG-REPL-002/003/004), or a large `wal_keep_size`.

**How to confirm.** `SELECT pg_size_pretty(sum(size)) FROM pg_ls_waldir();` re-run to see whether it is still growing.

**How to fix.** Identify which of those it is — the finding reports the slot count, the archiver failure count and `wal_keep_size` so you can tell at a glance — and fix that. Do not delete WAL segments by hand: `pg_wal` is not a directory to tidy, and removing a segment the server still needs makes the cluster unrecoverable.

**False positives and caveats.** Needs `pg_monitor` and is unavailable on most managed platforms. A large `pg_wal` immediately after a bulk load is normal and shrinks over the following checkpoints.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/wal-configuration.html)

---

<a id="pg-wal-007"></a>
### PG-WAL-007 — WAL buffers overflowing
**Priority 100** · Checkpoints and write-ahead log · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 14+ · primary only

**What fires it.** pg_stat_wal.wal_buffers_full >= 10% of wal_write and >= 100,000 since reset. Raising wal_buffers requires a restart.

**Thresholds.** `full_ratio` = 0.10, `min_full` = 100,000

**Reads.** `pg_stat_wal`

**Why it matters.** `wal_buffers` is the shared staging area for WAL before it is written. When it fills, the backend that wanted to insert a record has to flush WAL itself first — serialising writers behind an I/O that was supposed to be someone else's job. On a write-heavy server with the default sizing this can be a meaningful fraction of commit latency.

**How to fix.** Raise `wal_buffers` (it needs a restart). 64 MB is a common value on a busy server; the default is 1/32nd of `shared_buffers` capped at 16 MB, which is small for modern write rates.

**False positives and caveats.** PostgreSQL 14 and newer for `pg_stat_wal`. The ratio against `wal_write` is a heuristic: on a server that writes rarely but in bursts, a high ratio over few events is not the same problem as a high ratio over millions.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-wal.html)

---

<a id="pg-wal-008"></a>
### PG-WAL-008 — WAL compression off with a high full-page-image ratio
**Priority 150** · Checkpoints and write-ahead log · scope: cluster · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · PostgreSQL 14+ · primary only

**What fires it.** pg_stat_wal.wal_fpi / wal_records >= 0.3 while wal_compression is off. From 15 lz4 and zstd are available and cheap.

**Thresholds.** `fpi_ratio` = 0.3

**Reads.** `pg_stat_wal, pg_settings`

**Why it matters.** A full-page image is written the first time a page changes after each checkpoint, so it is 8 kB of WAL for what might be a 20-byte change. A high ratio means either frequent checkpoints (PG-WAL-001) or a workload that touches many pages sparsely. WAL compression trades CPU for a substantial reduction in exactly this traffic, which matters most where WAL is also being shipped over a network.

**How to fix.** `ALTER SYSTEM SET wal_compression = 'lz4'; SELECT pg_reload_conf();` on PostgreSQL 15 and newer (`zstd` where CPU is cheaper than bandwidth); on 14, only `pglz` is available and the trade is less favourable. Fixing PG-WAL-001 first often reduces the ratio on its own.

**False positives and caveats.** PostgreSQL 14 and newer.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-wal.html)

---

<a id="pg-wal-009"></a>
### PG-WAL-009 — Slow checkpoint sync phase
**Priority 100** · Checkpoints and write-ahead log · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · primary only

**What fires it.** Average checkpoint sync_time is 5 seconds or more per checkpoint. Storage fsync latency is high, which shows up as commit latency spikes.

**Thresholds.** `sync_ms` = 5,000, `min_checkpoints` = 20

**Reads.** `pg_stat_bgwriter (<=16) / pg_stat_checkpointer (17+)`

**Platform.** This check is reported at **P200** on aurora, neon, alloydb. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** A checkpoint's sync phase is the fsync of every file it dirtied. A long sync phase is storage latency, not PostgreSQL: the checkpoint cannot complete, WAL accumulates while it waits, and the resulting latency shows up in commits that have nothing to do with the checkpoint.

**How to fix.** This is a storage finding. Measure with `pg_test_fsync`; look for a saturated device, a network-attached volume with a shallow queue, or a write cache that has been disabled after a battery failure. `checkpoint_completion_target` and `max_wal_size` reduce how often you pay it, but not how long it takes.

**False positives and caveats.** Averaged over every checkpoint since the statistics reset, so one very slow checkpoint during a storage incident skews it for a long time.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/wal-configuration.html)

---


## Memory and caching (`MEM`)

<a id="pg-mem-001"></a>
### PG-MEM-001 — shared_buffers at the shipped default
**Priority 20** · Memory and caching · scope: setting · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** shared_buffers <= 128 MB. The shipped default is sized to start anywhere, not to run anything. Managed platforms size it themselves, so this almost always means an untuned self-managed server.

**Thresholds.** `shared_buffers_bytes` = 134,217,728

**Reads.** `pg_settings`

**Platform.** This check is reported at **P100** on rds, cloudsql, azure, supabase, crunchy, timescale, heroku; reported at **P200** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.


**Why it matters.** 128 MB is the value that lets PostgreSQL start on any machine, not the value that makes it work on this one. With a buffer cache that small, almost every read goes to the operating-system cache or the disk, the cache hit ratio the server reports is meaningless, and checkpoints write a small working set over and over.

**How to confirm.** `SHOW shared_buffers;`

**How to fix.** 25 % of RAM is the conventional starting point, and it is a starting point rather than an answer: past roughly 40 % the buffer cache mostly duplicates what the OS page cache already holds (PG-MEM-002). Changing it requires a restart, so pair it with `effective_cache_size` (PG-MEM-006) in the same window.

**False positives and caveats.** Skipped on managed platforms, which size this themselves. On a container with a small memory limit, 128 MB may be correct — the finding reports the cluster size so you can judge.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-resource.html)

---

<a id="pg-mem-002"></a>
### PG-MEM-002 — shared_buffers above 40 percent of RAM
**Priority 100** · Memory and caching · scope: setting · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · needs os

**What fires it.** shared_buffers > 40% of RAM. Double-buffering with the operating-system cache, and heavier checkpoints. Skipped when RAM is unknown.

**Thresholds.** `ram_fraction` = 0.40, `ram_bytes` = 0

**Reads.** `pg_settings, baseline.ram_gb`

**Why it matters.** Past roughly 40 % of RAM the buffer cache starts working against itself: the same pages are held in both `shared_buffers` and the operating-system page cache, so effective cache size does not grow; there is less memory left for `work_mem` allocations and for the page cache that backs sequential reads; and every checkpoint has more dirty pages to write at once.

**How to fix.** Bring it back towards 25-40 % of RAM, and raise `effective_cache_size` to reflect the total (shared buffers plus OS cache) so the planner's picture is right.

**False positives and caveats.** Needs RAM, which SQL cannot see: supply `baseline.ram_gb` in `.db-triage.yml` or the check does not run at all. The 40 % figure is a convention, not a threshold in the code — workloads with a working set that fits entirely in a large `shared_buffers` legitimately go higher.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-resource.html)

---

<a id="pg-mem-003"></a>
### PG-MEM-003 — Worst-case memory commitment exceeds RAM (OOM risk)
**Priority 50** · Memory and caching · scope: setting · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · needs os

**What fires it.** shared_buffers + max_connections x work_mem x max(2, hash_mem_multiplier) + autovacuum_max_workers x coalesce(autovacuum_work_mem, maintenance_work_mem) >= RAM. The OOM killer takes out the postmaster, not the offending backend. Fires at P100 with the computed figure when RAM is unknown.

**Thresholds.** `ram_bytes` = 0, `ram_fraction` = 1.0

**Reads.** `pg_settings, baseline.ram_gb`

**Why it matters.** `work_mem` is a per-operation limit, not a per-connection one: a single query with three sorts and a hash join can allocate it four times over, and `hash_mem_multiplier` raises the ceiling for hash nodes specifically. Multiplied by `max_connections` and added to `shared_buffers` and the autovacuum workers, the worst case frequently exceeds RAM by a wide margin. The failure mode is not swapping: on Linux the OOM killer usually takes the postmaster, which restarts the entire cluster and drops every session.

**How to confirm.** The finding shows the arithmetic; re-run it after the change.

**How to fix.** Lower `max_connections` and put a pooler in front (PG-CONN-003), which is the change that actually fixes it. Lower the global `work_mem` and raise it per role for the roles that need it: `ALTER ROLE reporting SET work_mem = '256MB'`. Set `vm.overcommit_memory = 2` on Linux so allocation fails in one backend rather than the kernel choosing a victim.

**False positives and caveats.** Needs RAM: without `baseline.ram_gb` the check does not run, and the computed worst case is reported in PG-INFO-001 instead. The worst case is a ceiling, not a prediction — most workloads never approach it, which is exactly why it is not noticed until they do.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-resource.html)

---

<a id="pg-mem-004"></a>
### PG-MEM-004 — work_mem at the default with heavy temp-file spill
**Priority 100** · Memory and caching · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0

**What fires it.** work_mem <= 4 MB and either temp_bytes >= 10 GB/day or temp_files >= 1,000/day across the scanned databases. Raise it per role rather than globally, because of MEM-003.

**Thresholds.** `work_mem_bytes` = 4,194,304, `temp_bytes_per_day` = 10,737,418,240, `temp_files_per_day` = 1,000

**Reads.** `pg_settings, pg_stat_database`

**Why it matters.** When a sort, hash or materialise step exceeds `work_mem`, it spills to disk: the data is written out and read back, turning a memory operation into two I/O operations. At the 4 MB default, that happens on quite ordinary queries. Ten gigabytes of temp files a day is the workload telling you which operations are running on disk.

**How to confirm.** `SELECT datname, temp_files, pg_size_pretty(temp_bytes) FROM pg_stat_database ORDER BY temp_bytes DESC;`

**How to fix.** Raise `work_mem` for the roles that run the heavy queries, not globally — the global value multiplies by `max_connections` in PG-MEM-003. `ALTER ROLE reporting SET work_mem = '256MB';`. PG-QRY-009 names the specific statements, which is a better place to start than the setting.

**False positives and caveats.** Counters are cumulative since the statistics reset; the check divides by that window. A nightly analytics job legitimately produces large temp volume.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-resource.html)

---

<a id="pg-mem-005"></a>
### PG-MEM-005 — maintenance_work_mem at the default on a large database
**Priority 100** · Memory and caching · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** maintenance_work_mem <= 64 MB while the scanned databases total 100 GB or more. Index builds and, before 17, vacuum dead-tuple storage are throttled by it.

**Thresholds.** `maintenance_work_mem_bytes` = 67,108,864, `total_bytes` = 107,374,182,400

**Reads.** `pg_settings, pg_database_size()`

**Platform.** This check is reported at **P200** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** `maintenance_work_mem` bounds `CREATE INDEX`, `REINDEX`, `ALTER TABLE` rewrites and — before PostgreSQL 17 — the dead-tuple array that vacuum uses. A vacuum that fills that array has to stop, pass over every index, and start again: on a large table with several indexes, that is the difference between one index pass and five.

**How to fix.** 1-2 GB is normal on a server with real memory. It is allocated per operation, not per connection, and only by maintenance operations — but note that autovacuum workers use `autovacuum_work_mem` if set, and inherit this value if not, so the true ceiling is this times `autovacuum_max_workers`.

**False positives and caveats.** PostgreSQL 17 replaced vacuum's dead-tuple array with a structure that uses memory much more efficiently, so the vacuum half of this matters less there. The index-build half is unchanged.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-resource.html)

---

<a id="pg-mem-006"></a>
### PG-MEM-006 — effective_cache_size at the default
**Priority 100** · Memory and caching · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** effective_cache_size is 4 GB with source = 'default'. The planner under-values index scans, because it believes only 4 GB is cached anywhere.

**Reads.** `pg_settings`

**Platform.** This check is reported at **P200** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** `effective_cache_size` allocates nothing. It tells the planner how much data it can expect to find cached, in `shared_buffers` plus the operating-system page cache, and that estimate is what makes repeated index lookups look cheap. Left at 4 GB on a host with more memory, the planner systematically over-estimates the cost of index scans and drifts towards sequential scans and hash joins on exactly the queries an index would win.

**How to fix.** Set it to 50-75 % of RAM. It takes effect on reload, costs nothing, and is one of the few settings where the conventional value is close to universally right.

**False positives and caveats.** Only fires when the source is `default`, so a deliberately chosen 4 GB on a 8 GB host does not.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-query.html)

---

<a id="pg-mem-007"></a>
### PG-MEM-007 — random_page_cost at the spinning-disk default
**Priority 150** · Memory and caching · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · needs interview

**What fires it.** random_page_cost = 4 while baseline.storage is ssd, nvme, cloud or unknown. On SSD and cloud storage 1.1-1.5 is typical. Confidence low when storage is unknown.

**Thresholds.** `storage_class` = unknown

**Reads.** `pg_settings, baseline.storage`

**Why it matters.** `random_page_cost = 4` against `seq_page_cost = 1` models a spinning disk, where a random seek genuinely costs about four sequential reads. On SSD, NVMe and cloud block storage the real ratio is close to 1, and leaving the default makes the planner prefer sequential scans on exactly the queries where an index would win.

**How to fix.** 1.1 for local NVMe, 1.1-2.0 for cloud volumes. Change it globally and measure: this setting moves plans, so it is one to make during a period you are watching rather than on a Friday.

**False positives and caveats.** **Confidence depends on an input db-triage cannot see.** Set `baseline.storage` in `.db-triage.yml`; without it this is a guess based on the setting alone. On genuinely spinning disks, 4 is correct.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-query.html)

---

<a id="pg-mem-008"></a>
### PG-MEM-008 — Huge pages not in effect with a large buffer cache
**Priority 100** · Memory and caching · scope: setting · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** shared_buffers >= 8 GB and either huge_pages_status = 'off' (17+) or huge_pages = off. Page-table overhead and TLB misses scale with the buffer cache.

**Thresholds.** `shared_buffers_bytes` = 8,589,934,592

**Reads.** `pg_settings`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** Mapping a large `shared_buffers` with 4 kB pages costs page-table entries per backend and constant TLB pressure — with hundreds of connections, the page tables themselves become gigabytes. 2 MB huge pages reduce that by a factor of 512 and remove the TLB misses.

**How to fix.** Set `vm.nr_hugepages` on the host to cover `shared_buffers` plus overhead, then `huge_pages = on` and restart. Use `on` rather than `try`: with `on` the server refuses to start if huge pages are unavailable, which is a clear failure rather than a silent loss of the benefit.

**False positives and caveats.** `huge_pages_status` only exists from PostgreSQL 17; below that the check reads the requested setting, which does not prove they were actually obtained. Transparent huge pages are a different thing and are generally recommended *off* for databases.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/kernel-resources.html#LINUX-HUGE-PAGES)

---

<a id="pg-mem-009"></a>
### PG-MEM-009 — temp_file_limit unlimited
**Priority 100** · Memory and caching · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** temp_file_limit = -1. One runaway sort or hash join can fill the data volume.

**Reads.** `pg_settings`

**Why it matters.** `temp_file_limit = -1` means one query can write temporary files until the volume is full. When it fills, every write in the cluster fails, and if `pg_wal` shares the volume the server PANICs. One bad estimate in one ad-hoc query is enough.

**How to fix.** Set it to a size that no single legitimate query needs — a few gigabytes is usually generous — so a runaway query fails with "temporary file size exceeds temp_file_limit" instead of taking the server down. It is per-session, so it can be raised for the roles that genuinely need more.

**False positives and caveats.** Set too low it breaks legitimate analytics. PG-CAP-008 and PG-QRY-009 show what the workload actually writes, which is the number to size against.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-resource.html)

---

<a id="pg-mem-010"></a>
### PG-MEM-010 — Buffer cache hit ratio below 90 percent
**Priority 150** · Memory and caching · scope: database · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** blks_hit / (blks_hit + blks_read) < 0.90 for databases with at least 1,000,000 block reads. Confidence low: the operating-system cache masks this and analytic workloads legitimately read from disk. Reported for correlation with MEM-001/002, not as a target.

**Thresholds.** `hit_ratio` = 0.90, `min_reads` = 1,000,000

**Reads.** `pg_stat_database`

**Platform.** This check is reported at **P200** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** The ratio of `blks_hit` to `blks_hit + blks_read` is widely quoted as a health metric and is a poor one. "Read" here means "not found in `shared_buffers`", which includes every block served instantly from the operating-system page cache — so a server with plenty of free memory and a 70 % ratio may be doing no physical I/O at all.

**How to fix.** Read it next to PG-MEM-001 and PG-MEM-002 rather than tuning towards it. If it is low *and* `shared_buffers` is tiny, that is a finding. If it is low on a server with a large buffer cache and a working set much larger than RAM, that is a description of the workload.

**False positives and caveats.** **Confidence is low by design.** This number cannot distinguish a page-cache hit from a disk read. `track_io_timing` (PG-QRY-012) plus `pg_stat_statements` I/O times is the measurement that can.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-DATABASE-VIEW)

---


## Connections and pooling (`CONN`)

<a id="pg-conn-001"></a>
### PG-CONN-001 — Connections at 90 percent or more of max_connections
**Priority 5** · Connections and pooling · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** Client backends >= 0.90 x (max_connections - superuser_reserved_connections - reserved_connections). The next spike returns 'FATAL: sorry, too many clients already'.

**Thresholds.** `conn_fraction` = 0.90

**Reads.** `pg_stat_activity, pg_settings`

**Why it matters.** `max_connections` is a hard ceiling, and crossing it is not degradation: the next connection is refused with `FATAL: sorry, too many clients already`. The application sees an unavailable database. Superuser-reserved connections mean the real ceiling is lower than the setting, which is why the check computes the usable number rather than comparing against `max_connections` directly.

**How to confirm.** `SELECT count(*), state FROM pg_stat_activity WHERE backend_type='client backend' GROUP BY state;`

**How to fix.** In the moment: find and end whatever is holding connections — PG-CONN-004 (idle), PG-LOCK-003 (idle in transaction), PG-LOCK-001 (blocked). Permanently: put a transaction-mode pooler in front (PgBouncer, pgcat, RDS Proxy) so the application's pool size stops being the database's connection count. Raising `max_connections` needs a restart and makes PG-MEM-003 worse.

**False positives and caveats.** A single sample. Behind a pooler, a high count is by design and the threshold should be raised per target.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-connection.html)

---

<a id="pg-conn-002"></a>
### PG-CONN-002 — Connections at 70 percent or more of max_connections
**Priority 50** · Connections and pooling · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** Client backends >= 0.70 x usable max_connections, below the CONN-001 threshold.

**Thresholds.** `conn_fraction` = 0.70, `conn_fraction_high` = 0.90

**Reads.** `pg_stat_activity, pg_settings`

**Why it matters.** The same measurement one step earlier, at the point where there is still time to act deliberately rather than during an incident.

**How to fix.** As PG-CONN-001, with time to do it properly.

**False positives and caveats.** On a server sized for a pooler this is the normal steady state; override the threshold per target rather than living with the noise.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-connection.html)

---

<a id="pg-conn-003"></a>
### PG-CONN-003 — max_connections very high with no evidence of a pooler
**Priority 50** · Connections and pooling · scope: setting · cost 0 · source: sql · pass: fast · effort L / risk med · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** max_connections >= 500 and neither a known pooler application_name (pgbouncer, pgpool, pgcat, odyssey, supavisor, rds_proxy) nor 80% of connections arriving from 3 or fewer addresses. Each backend is an operating-system process.

**Thresholds.** `max_conn` = 500, `pooler_address_fraction` = 0.8, `pooler_address_count` = 3

**Reads.** `pg_settings, pg_stat_activity`

**Platform.** This check is reported at **P150** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** Each PostgreSQL connection is an operating-system process with its own memory, its own catalog caches, and its own entry in the shared proc array that every snapshot has to walk. Past a few hundred, the cost is not the idle connections themselves but the contention they add to everything else — and `max_connections` multiplies directly into the worst-case memory figure in PG-MEM-003.

**How to fix.** Put a transaction-mode pooler in front and bring `max_connections` down to what the pooler actually opens, typically a small multiple of the core count. This is the single highest-leverage change on most over-connected servers, and it is an architecture change rather than a setting.

**False positives and caveats.** **Confidence is medium**: the heuristic looks for known pooler application names and for connections concentrated on a few addresses. A pooler that does not set `application_name` and runs on many hosts looks exactly like no pooler.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-connection.html)

---

<a id="pg-conn-004"></a>
### PG-CONN-004 — Most connections idle
**Priority 100** · Connections and pooling · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** At least 100 client connections and 80% or more in state = 'idle'. Application-side pools sized for peak; a transaction-mode pooler reclaims the memory.

**Thresholds.** `min_connections` = 100, `idle_fraction` = 0.80

**Reads.** `pg_stat_activity`

**Why it matters.** An idle backend still holds a process, its catalog caches, and its slot in the proc array that every transaction snapshot examines. Eighty per cent idle usually means an application-side pool sized for peak that never shrinks — the connections were opened once and will be held until the process restarts.

**How to fix.** A transaction-mode pooler returns the connection between transactions, which is what actually reclaims the memory. Failing that, lower the application pool's maximum and set an idle timeout in the driver.

**False positives and caveats.** Idle is not idle-in-transaction: an idle connection holds no locks and no snapshot, so this is a capacity finding rather than a correctness one. That is why it is P100.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW)

---

<a id="pg-conn-005"></a>
### PG-CONN-005 — High connection churn
**Priority 100** · Connections and pooling · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 14+

**What fires it.** pg_stat_database.sessions divided by the statistics window is 10 sessions/second or more cluster-wide. PostgreSQL forks a process per connection, so churn burns CPU and adds latency.

**Thresholds.** `sessions_per_second` = 10

**Reads.** `pg_stat_database`

**Why it matters.** PostgreSQL forks a process and builds fresh catalog caches for every connection. At ten new sessions a second, a measurable share of the server's CPU goes to connection setup rather than to queries — and each connection pays part of that cost in its own latency, so it shows up as slowness in the application rather than as load on the server.

**How to fix.** This is what connection pooling is for. Either pool in the application (a long-lived pool rather than connect-per-request) or in front of the database.

**False positives and caveats.** PostgreSQL 14 and newer for `pg_stat_database.sessions`. Serverless and short-lived-worker architectures produce this shape by design, which is why they need a pooler more than anything else does.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-DATABASE-VIEW)

---

<a id="pg-conn-006"></a>
### PG-CONN-006 — Sessions ending abnormally
**Priority 100** · Connections and pooling · scope: database · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 14+

**What fires it.** (sessions_fatal + sessions_killed + sessions_abandoned) / sessions >= 1% with at least 10,000 sessions. Clients are being rejected or are dropping connections.

**Thresholds.** `abnormal_fraction` = 0.01, `min_sessions` = 10,000

**Reads.** `pg_stat_database`

**Platform.** This check is reported at **P150** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** Sessions ending abnormally are errors somebody is already seeing. `sessions_fatal` means the server refused or terminated them; `sessions_abandoned` means the client vanished without a clean disconnect, which is usually a network device or a container runtime cutting idle connections; `sessions_killed` means an administrator or a timeout ended them.

**How to fix.** Split them by kind first — they have entirely different causes. Abandoned sessions point at TCP keepalives and idle timeouts in the path; fatal ones point at authentication, `max_connections`, or a resource limit, and the server log says which.

**False positives and caveats.** PostgreSQL 14 and newer.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-DATABASE-VIEW)

---

<a id="pg-conn-007"></a>
### PG-CONN-007 — statement_timeout unset globally
**Priority 150** · Connections and pooling · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0

**What fires it.** statement_timeout = 0 at server level with no per-role or per-database override in pg_db_role_setting. Set it per application role rather than globally.

**Reads.** `pg_settings, pg_db_role_setting`

**Why it matters.** With no `statement_timeout`, a statement runs until it finishes or the client disappears, holding its snapshot and its locks for the whole time. That is the mechanism behind PG-LOCK-001 (everything queued behind it) and PG-VAC-005 (vacuum unable to clean past its xmin). One badly-planned query becomes a cluster-wide problem.

**How to fix.** Set it per role rather than globally, so migrations, backups and maintenance sessions are not cut off: `ALTER ROLE app SET statement_timeout = '30s';`. Applications can raise it per transaction where they genuinely need to.

**False positives and caveats.** A global `statement_timeout` will eventually kill something important at the worst moment. Per-role is the shape that works.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-client.html)

---

<a id="pg-conn-008"></a>
### PG-CONN-008 — Sessions currently waiting on locks
**Priority 50** · Connections and pooling · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** At least 10 sessions with wait_event_type = 'Lock' at snapshot time. See LOCK-001/002 for the chain.

**Thresholds.** `waiting_sessions` = 10

**Reads.** `pg_stat_activity`

**Why it matters.** Ten sessions waiting on locks at one instant is either a pile-up in progress or a coincidence, and a single sample cannot tell you which. It is reported because when it is a pile-up, the next thing to look at is the chain, and PG-LOCK-001 and PG-LOCK-002 have already found it.

**How to fix.** Read PG-LOCK-001 and PG-LOCK-002 in this report: they name the session at the root. If neither fired, the waits are short and this is normal contention.

**False positives and caveats.** Snapshot only, at the moment the check ran.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/explicit-locking.html)

---


## Locking and long transactions (`LOCK`)

<a id="pg-lock-001"></a>
### PG-LOCK-001 — Blocking chain: session blocked more than 5 minutes
**Priority 10** · Locking and long transactions · scope: session · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 9.6+ · needs pg_monitor

**What fires it.** A backend with a non-empty pg_blocking_pids() that has been waiting since state_change for 5 minutes or more. Details name the root blocker, its state, transaction start and query fingerprint.

**Thresholds.** `blocked_seconds` = 300

**Reads.** `pg_stat_activity, pg_blocking_pids()`

**Why it matters.** PostgreSQL lock waits are transitive: one session holding a lock blocks a second, and everything that wants what the second one holds queues behind both. Five minutes is long enough that the blocker is not doing ordinary work — it is idle in a transaction, waiting on something external, or running a statement nobody expected to take this long. Meanwhile the queue grows, and if the root blocker holds a lock on a hot table, the queue is the whole application.

**How to confirm.** `SELECT pid, pg_blocking_pids(pid), state, now()-state_change AS waiting, left(query,80) FROM pg_stat_activity WHERE cardinality(pg_blocking_pids(pid)) > 0;`

**How to fix.** 1. Read the root blocker's state and query from the finding. 2. If it is `idle in transaction`, the fix is at the client: the application opened a transaction and stopped. 3. Ending it is `SELECT pg_cancel_backend(<pid>)` first (cancels the statement) and `pg_terminate_backend(<pid>)` only if that fails (drops the connection and rolls back) — both are writes, so they are yours to run, and both roll back the blocker's work. 4. Then prevent it: `statement_timeout` and `idle_in_transaction_session_timeout` per role.

**False positives and caveats.** `pg_blocking_pids()` is a point-in-time snapshot and is relatively expensive on a server with thousands of sessions. The first blocker listed is not always the ultimate root of a deep chain.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/explicit-locking.html)

---

<a id="pg-lock-002"></a>
### PG-LOCK-002 — Blocking chain: session blocked more than 30 seconds
**Priority 50** · Locking and long transactions · scope: session · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 9.6+ · needs pg_monitor

**What fires it.** As LOCK-001 but with a wait of 30 seconds or more and less than 5 minutes.

**Thresholds.** `blocked_seconds` = 30, `blocked_seconds_high` = 300

**Reads.** `pg_stat_activity, pg_blocking_pids()`

**Why it matters.** The same chain, thirty seconds in. At this length it is frequently normal contention on a hot row; the reason to report it is that it is the shape PG-LOCK-001 grows out of, and seeing it repeatedly across runs identifies the contended object.

**How to fix.** Nothing on a single occurrence. Repeatedly on the same object is an application lock-ordering or transaction-scoping problem.

**False positives and caveats.** Snapshot only.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/explicit-locking.html)

---

<a id="pg-lock-003"></a>
### PG-LOCK-003 — Idle in transaction for more than 1 hour
**Priority 10** · Locking and long transactions · scope: session · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** A backend in state 'idle in transaction' (or 'idle in transaction (aborted)') since state_change 1 hour or more ago. It holds locks and the xmin horizon, and blocks DDL and vacuum.

**Thresholds.** `idle_seconds` = 3,600

**Reads.** `pg_stat_activity`

**Why it matters.** `idle in transaction` is the most expensive state a connection can be in. The transaction holds every lock it has taken, it pins the cluster-wide xmin horizon so vacuum cannot clean past it anywhere (PG-VAC-005), and it blocks any DDL that needs a conflicting lock — while doing nothing at all. An hour of this is not a slow query; it is an application that opened a transaction and went away.

**How to confirm.** `SELECT pid, state, now()-state_change AS idle_for, backend_xmin, age(backend_xmin), left(query,80) FROM pg_stat_activity WHERE state LIKE 'idle in transaction%' ORDER BY state_change;`

**How to fix.** Fix it at the client: a transaction should be opened as late as possible and committed or rolled back immediately, and an ORM that opens one at request start and holds it across an external HTTP call is the classic source. Then set `idle_in_transaction_session_timeout` (PG-LOCK-007) so the next one ends itself.

**False positives and caveats.** `idle in transaction (aborted)` holds locks too, and is even less likely to be doing anything useful.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW)

---

<a id="pg-lock-004"></a>
### PG-LOCK-004 — Idle in transaction for more than 5 minutes
**Priority 50** · Locking and long transactions · scope: session · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** As LOCK-003 but 5 minutes or more and less than 1 hour.

**Thresholds.** `idle_seconds` = 300, `idle_seconds_high` = 3,600

**Reads.** `pg_stat_activity`

**Why it matters.** The same state, five minutes in — long enough to be a bug rather than a slow round trip, short enough that the damage is still small.

**How to fix.** As PG-LOCK-003. Five minutes repeatedly is the early warning for the one-hour version.

**False positives and caveats.** Snapshot only.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW)

---

<a id="pg-lock-005"></a>
### PG-LOCK-005 — Client transaction open for more than 1 hour
**Priority 20** · Locking and long transactions · scope: session · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** A client backend whose xact_start is 1 hour or older, excluding maintenance statements (VACUUM, CREATE INDEX, REINDEX, CLUSTER, COPY) and base-backup application names. It holds the xmin horizon, which is what VAC-005 measures.

**Thresholds.** `xact_seconds` = 3,600

**Reads.** `pg_stat_activity`

**Why it matters.** A long-running transaction pins the xmin horizon for as long as it is open, whether it is doing work or not. That is what stops vacuum from cleaning dead tuples anywhere in the cluster (PG-VAC-005) and what makes freezing stall (PG-WRAP-003). Maintenance statements and base backups legitimately run for hours and are excluded; what is left is application work.

**How to fix.** Break long transactions into shorter ones. Where a long read genuinely needs a consistent snapshot — an export, a reconciliation — run it on a replica instead, and accept the standby-side cost (PG-REPL-011, PG-REPL-016) rather than the primary-side one.

**False positives and caveats.** A single `REPEATABLE READ` transaction doing a large export is legitimate and will fire this. The finding reports the query so the difference is visible.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW)

---

<a id="pg-lock-006"></a>
### PG-LOCK-006 — Orphaned prepared transactions
**Priority 5** · Locking and long transactions · scope: cluster · cost 0 · source: sql · pass: fast · effort S / risk high · since 0.1.0

**What fires it.** A row in pg_prepared_xacts prepared 1 hour or more ago. Prepared transactions hold locks and the xmin horizon indefinitely, survive restarts, and are invisible in pg_stat_activity.

**Thresholds.** `prepared_seconds` = 3,600

**Reads.** `pg_prepared_xacts`

**Why it matters.** A prepared transaction is the first phase of a two-phase commit: it has done its work, taken its locks, and is waiting for a coordinator to tell it to commit or roll back. It holds those locks and its xmin **forever**. It survives server restarts. It does not appear in `pg_stat_activity`. Nothing will ever time it out. An orphaned one is a permanent, invisible block on vacuum for the entire cluster.

**How to confirm.** `SELECT gid, prepared, owner, database, age(transaction) FROM pg_prepared_xacts ORDER BY prepared;`

**How to fix.** Find out whether a transaction manager owns it. If not: `ROLLBACK PREPARED '<gid>';` (or `COMMIT PREPARED`, if that is genuinely the intent) — a write, so it is yours to run, and it is irreversible in either direction. Then check `max_prepared_transactions`: if nothing uses two-phase commit, setting it to 0 makes this impossible.

**False positives and caveats.** Do not roll back a prepared transaction that a live XA coordinator still owns: you will break its recovery. Confirm before acting.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-prepare-transaction.html)

---

<a id="pg-lock-007"></a>
### PG-LOCK-007 — idle_in_transaction_session_timeout disabled
**Priority 100** · Locking and long transactions · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 9.6+

**What fires it.** idle_in_transaction_session_timeout = 0 at server level with no role override. 5-15 minutes is a reasonable value for application roles.

**Reads.** `pg_settings, pg_db_role_setting`

**Why it matters.** Nothing stops a client that opened a transaction and disappeared — a paused debugger, a crashed worker, a connection a firewall silently dropped — from holding its locks and the cluster's xmin horizon indefinitely. `idle_in_transaction_session_timeout` is the server-side backstop for a client-side failure.

**How to fix.** `ALTER ROLE app SET idle_in_transaction_session_timeout = '5min';` per application role. Leave interactive and migration roles alone: a DBA in a `psql` session mid-migration should not be disconnected.

**False positives and caveats.** Terminating an idle-in-transaction session rolls back its work, which is correct here but will surface as an error in the application. Introduce it with a generous value first.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-client.html)

---

<a id="pg-lock-008"></a>
### PG-LOCK-008 — Deadlocks occurring regularly
**Priority 150** · Locking and long transactions · scope: database · cost 0 · source: sql · pass: fast · effort L / risk low · since 0.1.0

**What fires it.** pg_stat_database.deadlocks divided by days since stats reset is 1 per day or more, with at least 7 deadlocks total. Usually an application lock-ordering bug; log_lock_waits and deadlock_timeout help diagnose it.

**Thresholds.** `deadlocks_per_day` = 1, `min_deadlocks` = 7

**Reads.** `pg_stat_database`

**Why it matters.** A deadlock is always an application bug: two transactions took the same locks in different orders, and PostgreSQL broke the tie by killing one. The server is fine; a user got an error. One a day means it is systematic rather than a coincidence, and the same pair of statements is almost certainly responsible every time.

**How to confirm.** `SELECT datname, deadlocks FROM pg_stat_database ORDER BY deadlocks DESC;` and the deadlock graphs in the server log.

**How to fix.** Set `log_lock_waits = on` and `deadlock_timeout` to a value you can live with, so the server logs the full deadlock graph — that graph names both statements, which is what makes the fix obvious. The fix is to take locks in a consistent order, usually by sorting the keys before updating them.

**False positives and caveats.** Cumulative since the statistics reset. Retry-on-deadlock in the application hides the user impact without fixing the cause.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/explicit-locking.html)

---

<a id="pg-lock-009"></a>
### PG-LOCK-009 — lock_timeout unset
**Priority 150** · Locking and long transactions · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** lock_timeout = 0 at server level. A migration's ALTER TABLE queued behind a long transaction blocks every statement that arrives behind it.

**Reads.** `pg_settings`

**Why it matters.** This is the setting that decides whether a routine migration can take down the application. An `ALTER TABLE` needs an ACCESS EXCLUSIVE lock; while it waits for one, **every subsequent statement on that table queues behind it**, including plain `SELECT`s. With no `lock_timeout`, an `ALTER TABLE` stuck behind one long transaction (PG-LOCK-005) blocks the entire table indefinitely.

**How to fix.** Set `lock_timeout` in migration sessions — `SET lock_timeout = '3s';` at the top of the migration — so the migration fails and retries instead of the application failing. Many migration frameworks do this; check that yours does.

**False positives and caveats.** A global `lock_timeout` interferes with legitimate long-lock operations. Session-level in migrations is the shape that works.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-client.html)

---

<a id="pg-lock-010"></a>
### PG-LOCK-010 — Active query running more than 10 minutes
**Priority 100** · Locking and long transactions · scope: session · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** A client backend in state 'active' whose query_start is 10 minutes or older, with the same maintenance exclusions as LOCK-005. It may be legitimate analytics; it is listed so the reader can decide.

**Thresholds.** `query_seconds` = 600

**Reads.** `pg_stat_activity`

**Why it matters.** A statement running for ten minutes is either analytics that legitimately takes this long, or a query whose plan went wrong. The catalog cannot tell them apart, so the finding reports the statement, its wait state and its transaction age and leaves the judgement to you.

**How to fix.** If it is unexpected: `EXPLAIN` it with realistic parameters and compare against `pg_stat_statements` (PG-QRY-013 flags statements whose runtime varies wildly, which is the signature of a plan that is sometimes wrong). If it is expected: consider running it on a replica so it stops holding the primary's xmin.

**False positives and caveats.** Maintenance statements and backup application names are excluded. A parallel query appears once per leader, not once per worker.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW)

---


## Security (`SEC`)

<a id="pg-sec-001"></a>
### PG-SEC-001 — trust authentication reachable over the network
**Priority 1** · Security · scope: cluster · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 10+ · needs superuser

**What fires it.** A host, hostssl or hostnossl pg_hba rule with auth_method = 'trust' whose address is not 127.0.0.1/32 or ::1/128 and whose error column is null. Anyone who can reach the port is any role they name.

**Reads.** `pg_hba_file_rules`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.


**Why it matters.** `trust` means no authentication at all: the client says which role it wants and gets it. On a `host` rule with a non-local address, anyone who can reach the port is any role in the cluster, including superusers. There is no password to steal and no log entry that distinguishes an attacker from an application.

**How to confirm.** `SELECT line_number, type, database, user_name, address, auth_method FROM pg_hba_file_rules WHERE auth_method='trust';`

**How to fix.** Change the method to `scram-sha-256` and give the roles passwords, then reload with `SELECT pg_reload_conf();`. Do it in the right order — set passwords first, then change the rule — or you lock everything out. If the rule exists to let a specific automated client in, `cert` authentication or a `.pgpass` file with a real password is the replacement.

**False positives and caveats.** Needs superuser to read `pg_hba_file_rules`; on managed platforms it is skipped and PG-SEC-012 says so. A `trust` rule limited to a private subnet is less bad than one open to the world and is still a role-boundary failure inside that subnet.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/auth-methods.html)

---

<a id="pg-sec-002"></a>
### PG-SEC-002 — Cleartext password authentication over the network
**Priority 5** · Security · scope: cluster · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 10+ · needs superuser

**What fires it.** A host or hostnossl pg_hba rule with auth_method = 'password'. The password crosses the network in the clear.

**Reads.** `pg_hba_file_rules`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.


**Why it matters.** The `password` method sends the password across the connection in clear text. On a `hostnossl` rule, or on a `host` rule where the client does not negotiate TLS, anyone on the network path reads it — and it is the same password that works from anywhere else the role is allowed.

**How to fix.** `scram-sha-256` never sends the password itself, over TLS or otherwise. Set `password_encryption = 'scram-sha-256'`, have each role set its password again (changing the setting does not re-hash existing ones), then change the rules and reload.

**False positives and caveats.** `md5` is better than `password` and still deprecated: see PG-SEC-006.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/auth-password.html)

---

<a id="pg-sec-003"></a>
### PG-SEC-003 — Listening on all interfaces with world-open HBA rules
**Priority 50** · Security · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 10+ · needs superuser

**What fires it.** listen_addresses is '*', '0.0.0.0' or '::' AND a host rule matches 0.0.0.0/0, ::/0, 'all' or 'samenet' for database 'all'. Confidence low: a firewall or security group may be in front; the report asks.

**Reads.** `pg_settings, pg_hba_file_rules`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.


**Why it matters.** `listen_addresses = '*'` plus an HBA rule matching `0.0.0.0/0` means PostgreSQL's own access control places no network restriction at all. Whatever limits reachability — a security group, a firewall, a private subnet — is outside the database, and db-triage cannot see it.

**How to fix.** Confirm what is actually in front of the port, and record it. If the answer is "nothing", narrow the HBA rule to the networks that need it; `listen_addresses` is the coarser lever and narrowing the rule is usually the more precise fix.

**False positives and caveats.** **Confidence is low by design.** This is extremely common and usually fine because of a firewall the tool cannot see. It is reported so that the assumption gets checked rather than inherited.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html)

---

<a id="pg-sec-004"></a>
### PG-SEC-004 — SSL disabled while accepting non-local connections
**Priority 50** · Security · scope: setting · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** ssl = off and listen_addresses is not localhost-only. Credentials and data travel in clear text.

**Reads.** `pg_settings`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.


**Why it matters.** With `ssl = off` and non-local `listen_addresses`, the server cannot offer TLS on any connection. Every password exchange, every query and every result crosses the network in clear text — including the ones that carry the data you are protecting with everything else.

**How to fix.** Provide a certificate and key readable by the server account, `ALTER SYSTEM SET ssl = on`, and reload. Then require it for the connections that matter by changing their HBA rules to `hostssl` — enabling TLS alone does not force clients to use it (PG-SEC-005).

**False positives and caveats.** A server reachable only over a private network or a service mesh that terminates TLS elsewhere is a legitimate exception. Record it rather than rediscovering the question.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/ssl-tcp.html)

---

<a id="pg-sec-005"></a>
### PG-SEC-005 — Most client connections not using SSL
**Priority 100** · Security · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 9.5+ · needs pg_monitor

**What fires it.** ssl = on and fewer than 50% of non-local client backends have pg_stat_ssl.ssl = true.

**Thresholds.** `ssl_fraction` = 0.50

**Reads.** `pg_stat_ssl, pg_stat_activity`

**Why it matters.** The server offers TLS and most clients are not using it. `sslmode` defaults to `prefer` in libpq, which silently falls back to an unencrypted connection whenever the server allows one — so a plain `host` rule in `pg_hba.conf` is enough to make encryption optional in practice.

**How to fix.** Change the relevant `host` lines to `hostssl` so the server refuses unencrypted connections. Do it after confirming each client is configured for TLS, because this breaks anything that is not.

**False positives and caveats.** Local socket connections legitimately have no TLS and are excluded. This is a snapshot: a client that connects hourly may not be represented.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/ssl-tcp.html)

---

<a id="pg-sec-006"></a>
### PG-SEC-006 — Non-SCRAM password authentication in use
**Priority 100** · Security · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 10+

**What fires it.** password_encryption = 'md5', or roles whose stored password is md5-format, or pg_hba rules using md5/password/ident. SCRAM-SHA-256 has been available since 10 and md5 is deprecated.

**Reads.** `pg_settings, pg_authid, pg_hba_file_rules`

**Why it matters.** MD5 password verification sends a value derived only from the stored hash, so anyone who can read `pg_authid` can authenticate as that role without knowing the password. The hash is also a plain MD5 of the password and the role name, which is offline-crackable at very high rates. SCRAM-SHA-256 has been available since PostgreSQL 10, is the default from 14, and PostgreSQL 18 warns on md5.

**How to confirm.** `SELECT rolname FROM pg_authid WHERE rolpassword LIKE 'md5%';` (needs superuser).

**How to fix.** `ALTER SYSTEM SET password_encryption = 'scram-sha-256';` then have every role set its password again — changing the setting does not re-hash existing passwords, and a role whose stored hash is still md5 will keep authenticating with md5. Then remove the `md5` HBA rules.

**False positives and caveats.** Very old client libraries may not support SCRAM. Check driver versions before switching the HBA rules.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/auth-password.html)

---

<a id="pg-sec-007"></a>
### PG-SEC-007 — trust authentication on the local socket
**Priority 100** · Security · scope: cluster · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · PostgreSQL 10+ · needs superuser

**What fires it.** A pg_hba rule with type = 'local' and auth_method = 'trust'. Anyone with a shell on the host is superuser. P100 rather than P1 because it requires host access, which is itself usually controlled.

**Reads.** `pg_hba_file_rules`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.


**Why it matters.** A `local` `trust` rule means any operating-system account that can reach the Unix socket can connect as any role, including superusers, with no credential. That includes every process in the same container and anything that obtains a shell on the host. It is P100 rather than P1 because it requires host access first — but host access is exactly what an attacker gets from an unrelated vulnerability, and this turns it into full database compromise.

**How to fix.** `peer` gives the same convenience for the `postgres` operating-system account without giving it to everything else on the host. Change the rule and reload.

**False positives and caveats.** Extremely common on development machines and in container images. On a laptop it is fine; on a shared host it is not.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/auth-methods.html)

---

<a id="pg-sec-008"></a>
### PG-SEC-008 — Application connections running as superuser
**Priority 50** · Security · scope: role · cost 0 · source: sql · pass: fast · effort L / risk med · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** At least 5 concurrent client connections, or any connection from a non-local client_addr, under a superuser role whose application_name is not an interactive client (psql, pgAdmin, DBeaver, DataGrip, db-triage).

**Thresholds.** `min_connections` = 5

**Reads.** `pg_stat_activity, pg_roles`

**Why it matters.** A superuser bypasses every permission check, every row-level security policy and every event trigger, and can read and write files on the host as the server account. An application connecting as one turns any SQL-injection bug into host compromise, and removes every layer of defence you built inside the database.

**How to fix.** Create a role with exactly the privileges the application needs and switch the connection string. This is usually a day of work and it is the single highest-value security change available on most databases.

**False positives and caveats.** **Confidence is medium**: the check excludes known interactive client names, but an application whose `application_name` is unset looks identical to a DBA session. Set `application_name` in your connection strings — it makes every diagnostic in this report better.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/role-attributes.html)

---

<a id="pg-sec-009"></a>
### PG-SEC-009 — Superuser roles
**Priority 230** · Security · scope: role · cost 0 · source: sql · pass: inventory · effort M / risk med · since 0.1.0

**What fires it.** Inventory of roles with rolsuper and rolcanlogin, excluding platform-owned roles and baseline.expected_superusers.

**Reads.** `pg_roles`

**Why it matters.** Superuser is not a permission level; it is the absence of permission checks. This row exists so that the list is *reviewed* rather than discovered: every entry should be a person or a service whose need for it someone can state.

**How to fix.** Remove what is not needed. From PostgreSQL 11 the predefined roles (`pg_read_all_data`, `pg_monitor`, `pg_signal_backend`) cover most of the reasons people historically granted superuser.

**False positives and caveats.** Platform-owned roles are excluded. Add your own known-good roles to `baseline.expected_superusers` so the list shows only the surprises.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/role-attributes.html)

---

<a id="pg-sec-010"></a>
### PG-SEC-010 — Roles with elevated attributes
**Priority 230** · Security · scope: role · cost 0 · source: sql · pass: inventory · effort M / risk med · since 0.1.0

**What fires it.** Login roles with rolcreaterole, rolcreatedb, rolreplication or rolbypassrls, excluding superusers already listed by SEC-009.

**Reads.** `pg_roles`

**Why it matters.** Each of these attributes is a distinct escalation path. `CREATEROLE` can create and alter other roles — and before PostgreSQL 16 it could grant itself membership in almost any of them, which is superuser by two steps. `REPLICATION` can open a replication connection and stream the entire cluster, bypassing every table-level grant. `BYPASSRLS` ignores every row-level security policy. `CREATEDB` is the mildest and is still a way to consume the disk.

**How to fix.** Review each holder against what it does. `REPLICATION` belongs only on replication roles; `BYPASSRLS` should be exceptional and documented.

**False positives and caveats.** Review row, not a defect. It is here so a security reviewer signs off on the list.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/role-attributes.html)

---

<a id="pg-sec-011"></a>
### PG-SEC-011 — Non-superuser roles with server file access
**Priority 100** · Security · scope: role · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 11+

**What fires it.** Members of pg_read_server_files, pg_write_server_files or pg_execute_server_program that are not superusers. Each of those is effectively superuser.

**Reads.** `pg_auth_members, pg_roles`

**Why it matters.** `pg_read_server_files`, `pg_write_server_files` and `pg_execute_server_program` are each equivalent to superuser in practice: read any file the server account can read (including `pg_hba.conf` and the TLS private key), write any file it can write (including the configuration and the libraries it loads), or run arbitrary programs as the server account. The role does not appear in the superuser list, so it is easy to miss.

**How to fix.** Revoke unless there is a documented need. Where a job genuinely needs to read a file, a `COPY` from a fixed path executed by a `SECURITY DEFINER` function with a pinned `search_path` (PG-SEC-014) is a much narrower grant.

**False positives and caveats.** PostgreSQL 11 and newer.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/predefined-roles.html)

---

<a id="pg-sec-012"></a>
### PG-SEC-012 — pg_hba.conf not readable: authentication exposure unverified
**Priority 0** · Security · scope: cluster · cost 0 · source: derived · pass: fast · effort S / risk low · since 0.1.0 · PostgreSQL 10+

**What fires it.** Reading pg_hba_file_rules raised a permission error or the view is unavailable, so SEC-001, 002, 003, 006 and 007 are blind. Emitted in the META band so the reader knows.

**Reads.** `pg_hba_file_rules`

**Why it matters.** `pg_hba_file_rules` needs superuser, and `pg_read_all_settings` does not grant it. When it cannot be read, PG-SEC-001, 002, 003, 006 and 007 do not run — so the report has *no information* about how clients authenticate. This row exists so that absence is stated rather than read as "no authentication problems found".

**How to fix.** Either run one pass as a superuser, or accept the gap and record separately how the instance is reachable. On managed platforms superuser is not available at all, and the network rules in the provider console are the substitute.

**False positives and caveats.** Reported in the META band because it is a statement about the run, not about the database.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html)

---

<a id="pg-sec-013"></a>
### PG-SEC-013 — PUBLIC can CREATE in schema public
**Priority 100** · Security · scope: schema · cost 0 · source: sql · pass: fast · effort S / risk med · since 0.1.0

**What fires it.** PUBLIC holds CREATE on schema public. This is the CVE-2018-1058 trojan-function vector; PostgreSQL 15 removed the default grant.

**Reads.** `pg_namespace.nspacl via aclexplode`

**Why it matters.** In a schema where `PUBLIC` holds `CREATE`, any role that can connect can create objects. Combined with a `search_path` that puts `public` before `pg_catalog` — the default — that role can define a function or operator that shadows a built-in one and have it executed by other users, including superusers. This is CVE-2018-1058, and it is a privilege-escalation path, not a tidiness issue.

**How to confirm.** `SELECT nspname, nspacl FROM pg_namespace WHERE nspname='public';`

**How to fix.** `REVOKE CREATE ON SCHEMA public FROM PUBLIC;` and give each application its own schema that it owns. PostgreSQL 15 removed the default grant for new databases; a database created earlier, or restored from an earlier dump, still has it.

**False positives and caveats.** Revoking breaks anything that creates temporary working tables in `public`. Check before doing it in one step.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/ddl-schemas.html#DDL-SCHEMAS-PATTERNS)

---

<a id="pg-sec-014"></a>
### PG-SEC-014 — SECURITY DEFINER functions without a fixed search_path
**Priority 100** · Security · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** pg_proc.prosecdef is true and proconfig has no search_path entry, excluding pg_catalog and extension-owned functions. Same vulnerability class as SEC-013.

**Reads.** `pg_proc, pg_depend, pg_namespace`

**Why it matters.** A `SECURITY DEFINER` function runs with its owner's privileges but resolves unqualified names using the *caller's* `search_path`. A caller who can create objects in any schema on that path (PG-SEC-013) can substitute their own table, function or operator and have the owner execute it. If the owner is a superuser, that is full compromise from an ordinary login.

**How to confirm.** `SELECT n.nspname, p.proname, p.proconfig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.prosecdef;`

**How to fix.** `ALTER FUNCTION f(args) SET search_path = pg_catalog, <the schemas it actually needs>;` on every one. Then check who holds `EXECUTE`: the default grant is to `PUBLIC`, which is rarely intended on a definer function.

**False positives and caveats.** Extension-owned functions are excluded: they are the extension author's responsibility and are generally written correctly.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-createfunction.html)

---

<a id="pg-sec-015"></a>
### PG-SEC-015 — User tables granting write privileges to PUBLIC
**Priority 50** · Security · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** A relation in a user schema with INSERT, UPDATE, DELETE or TRUNCATE granted to PUBLIC. Every role that can connect can write to it.

**Reads.** `pg_class.relacl via aclexplode`

**Why it matters.** `PUBLIC` is every role that can connect, including roles created later by someone who has not read this report. A write grant to `PUBLIC` means the monitoring user, the read-only reporting user and the intern's ad-hoc account can all modify the table.

**How to fix.** `REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON <table> FROM PUBLIC;` and grant to the specific roles that need it. Check which roles were relying on the `PUBLIC` grant first — that is what makes this a change to plan rather than to apply.

**False positives and caveats.** Default privileges in some migration frameworks grant to `PUBLIC` for convenience; the grant then propagates to every new table via `ALTER DEFAULT PRIVILEGES`.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/ddl-priv.html)

---

<a id="pg-sec-016"></a>
### PG-SEC-016 — User tables readable by PUBLIC
**Priority 150** · Security · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** A relation in a user schema with SELECT granted to PUBLIC. Sometimes deliberate; listed for review.

**Reads.** `pg_class.relacl via aclexplode`

**Why it matters.** A read grant to `PUBLIC` is sometimes exactly right — a reference table of country codes — and sometimes means a table of personal data is readable by every role in the cluster. The catalog cannot tell the difference, which is why this is a P150 review row rather than a finding.

**How to fix.** Review the list against what the tables hold. Revoke where the answer is not obviously "yes, everyone should read this".

**False positives and caveats.** Review row.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/ddl-priv.html)

---

<a id="pg-sec-017"></a>
### PG-SEC-017 — Untrusted procedural languages or risky extensions installed
**Priority 150** · Security · scope: database · cost 0 · source: sql · pass: fast · effort L / risk med · since 0.1.0

**What fires it.** An untrusted language (plpython3u, plperlu, pltclu) or a high-risk extension (adminpack, file_fdw, dblink) is installed. Function authors in those languages can run arbitrary code as the server account.

**Reads.** `pg_language, pg_extension`

**Why it matters.** Code in an untrusted language runs as the operating-system account that owns the server, outside every SQL permission check: it can read and write files, open network sockets and execute programs. The same is true in effect for `file_fdw` (reads arbitrary server files as tables), `adminpack` (writes files in the data directory over a normal connection) and `dblink` (opens outbound connections from the server, which can reach services the client cannot and can authenticate to local `trust` rules).

**How to fix.** Only superusers can create functions in an untrusted language by default, so this is a review row rather than a defect. Confirm the functions that exist are ones you meant to have, and check that `EXECUTE` on the risky extensions' functions is not held by `PUBLIC`.

**False positives and caveats.** Review row. `plpython3u` in particular is often installed for one legitimate job and then forgotten.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/xplang.html)

---

<a id="pg-sec-018"></a>
### PG-SEC-018 — Login roles with no password set
**Priority 230** · Security · scope: role · cost 0 · source: sql · pass: inventory · effort M / risk med · since 0.1.0 · needs superuser

**What fires it.** Login roles whose pg_authid.rolpassword is null. Correct with peer, cert or LDAP authentication; a lockout or an exposure signal otherwise. The password column is tested for null only and never read into the report.

**Reads.** `pg_authid`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** A login role with no password authenticates by something else — peer, cert, LDAP, GSSAPI or an IAM plugin — which is correct and common. It can also mean the role was created and forgotten, or that a `trust` rule (PG-SEC-001, PG-SEC-007) is what lets it in. The two look identical from the catalog, which is why this is a review row.

**How to fix.** Check each against how it is supposed to authenticate. A role that has no password *and* no matching non-password HBA rule cannot log in at all and should be dropped.

**False positives and caveats.** db-triage tests `pg_authid.rolpassword` for null only. The value is never read into a column, a details string or the evidence object.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/auth-password.html)

---

<a id="pg-sec-019"></a>
### PG-SEC-019 — Login roles with expired passwords
**Priority 200** · Security · scope: role · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Login roles with rolvaliduntil in the past. Cleanup candidates: the role still exists and still holds its grants.

**Reads.** `pg_roles`

**Why it matters.** An expired password stops the role authenticating with a password. It does not remove the role, its grants, or its group memberships — so extending the expiry brings all of that straight back, and in the meantime any non-password authentication path still works.

**How to fix.** Drop the roles that are genuinely finished, and reset the expiry on the ones that are not. An expired role left in place is a grant nobody is reviewing.

**False positives and caveats.** Inventory row.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/role-attributes.html)

---

<a id="pg-sec-020"></a>
### PG-SEC-020 — Login roles with no password expiry
**Priority 200** · Security · scope: role · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Count of login roles with rolvaliduntil null. Expiry is uncommon in PostgreSQL because secret managers rotate instead, so this is a review row and not a problem.

**Reads.** `pg_roles`

**Why it matters.** PostgreSQL has no password-age or rotation policy of its own; `rolvaliduntil` is the only server-side control over how long a credential stays valid. Most estates rotate secrets outside the database instead, which is why this is inventory rather than a finding — it tells a reviewer that nothing here will expire on its own.

**How to fix.** Nothing, if rotation happens elsewhere. If it does not, `rolvaliduntil` plus a rotation job is the minimum.

**False positives and caveats.** Inventory row.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/role-attributes.html)

---

<a id="pg-sec-021"></a>
### PG-SEC-021 — Connection logging disabled
**Priority 200** · Security · scope: setting · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** log_connections and log_disconnections are both off. Post-incident forensics on who connected from where is impossible.

**Reads.** `pg_settings`

**Why it matters.** With connection logging off, nothing records who connected, from where, as which role, or when they left. After an incident there is no way to answer "which credential was used and from which address" from this server's own logs, and no way to establish that an account was *not* used.

**How to fix.** `ALTER SYSTEM SET log_connections = on; ALTER SYSTEM SET log_disconnections = on; SELECT pg_reload_conf();`. The cost is one log line per connection, which matters only where connection churn is already high (PG-CONN-005) — and if it is, that is worth fixing anyway.

**False positives and caveats.** Inventory band, because whether it is required is a compliance question rather than a database one.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-logging.html)

---


## Indexes (`IDX`)

<a id="pg-idx-001"></a>
### PG-IDX-001 — Invalid index
**Priority 50** · Indexes · scope: index · cost 1 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** pg_index.indisvalid = false or indisready = false. Left behind by a failed CREATE INDEX CONCURRENTLY: maintained on every write, never used by the planner, and if unique it still blocks conflicting inserts.

**Reads.** `pg_index, pg_class`

**Why it matters.** An invalid index is the worst of both worlds: the planner will not use it, and every insert, update and delete still maintains it. If it is unique it goes further and rejects conflicting inserts, so it changes behaviour while providing nothing. It is almost always the debris of a `CREATE INDEX CONCURRENTLY` that failed or was interrupted — which is easy to miss, because the session that ran it saw one error and moved on.

**How to confirm.** `SELECT c.relname, i.indisvalid, i.indisready FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid WHERE NOT i.indisvalid;`

**How to fix.** `REINDEX INDEX CONCURRENTLY <schema>.<index>;` on PostgreSQL 12 and newer rebuilds it without blocking writes. Below 12, `DROP INDEX CONCURRENTLY` then recreate. Both are writes. Find out why the original build failed first: a unique index on non-unique data will fail again the same way.

**False positives and caveats.** An index being built right now is briefly invalid; check `pg_stat_progress_create_index` (PG-IDX-017) before dropping anything.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-createindex.html)

---

<a id="pg-idx-002"></a>
### PG-IDX-002 — Unused index 1 GB or larger
**Priority 50** · Indexes · scope: index · cost 1 · source: sql · pass: fast · effort S / risk med · since 0.1.0 · primary only

**What fires it.** idx_scan = 0, size >= 1 GB, statistics age >= 30 days, and the index is not unique, primary or a replica identity. Usage counters are per instance: verify on every replica before dropping.

**Thresholds.** `min_bytes` = 1,073,741,824, `stats_age_days` = 30

**Reads.** `pg_stat_user_indexes, pg_index, pg_class`

**Why it matters.** An index that has never been scanned costs a write on every insert and on every non-HOT update, occupies buffer cache, lengthens vacuum, and adds to the time of every `REINDEX` and every restore. A gigabyte of it is worth removing — but only once you are sure it is really unused.

**How to confirm.** `SELECT schemaname, relname, indexrelname, idx_scan, pg_size_pretty(pg_relation_size(indexrelid)) FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY pg_relation_size(indexrelid) DESC;` on the primary **and** on each standby.

**How to fix.** 1. Check the same index on **every replica**: usage counters are per instance, and an index unused on the primary may be carrying the reporting replica's entire workload. 2. Check that it does not back a constraint (the check already excludes those) and is not a replica identity. 3. Then `DROP INDEX CONCURRENTLY`. A reversible intermediate step is to rename it and wait a release cycle: nothing will use it, and recreating it is a rename back rather than a rebuild.

**False positives and caveats.** **Counters are per instance and since the last statistics reset.** The check requires a 30-day window before firing at this priority. An index used only by a quarterly job will look unused for 89 days of every 90.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ALL-INDEXES-VIEW)

---

<a id="pg-idx-003"></a>
### PG-IDX-003 — Unused index (small, or usage statistics too young)
**Priority 150** · Indexes · scope: index · cost 1 · source: sql · pass: fast · effort S / risk med · since 0.1.0

**What fires it.** idx_scan = 0 and size >= 50 MB, not already reported by IDX-002 (smaller than 1 GB or statistics younger than 30 days). Summary form.

**Thresholds.** `min_bytes` = 52,428,800, `big_bytes` = 1,073,741,824, `stats_age_days` = 30, `top_n` = 20

**Reads.** `pg_stat_user_indexes, pg_index, pg_class`

**Why it matters.** The same measurement below the size threshold, or with a statistics window too young to be trusted. Grouped as a summary because a database can easily have dozens, and dozens of individual findings is noise rather than information.

**How to fix.** Review the list rather than acting on it. When the statistics window is short, the right action is to wait and re-run.

**False positives and caveats.** `confidence: low` when the window is under 30 days. Same per-instance caveat as PG-IDX-002.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ALL-INDEXES-VIEW)

---

<a id="pg-idx-004"></a>
### PG-IDX-004 — Duplicate indexes
**Priority 50** · Indexes · scope: index · cost 1 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** Two or more indexes on the same table identical in indkey, indclass, indoption, indexprs, indpred and uniqueness. Pure write amplification and storage waste; keep the one backing a constraint.

**Reads.** `pg_index, pg_class`

**Why it matters.** Two indexes identical in access method, key columns, operator classes, sort options, expression, predicate and uniqueness answer exactly the same questions. One of them is pure cost: a write on every modification, space on disk and in cache, and time in every vacuum and every rebuild. They usually arrive from a migration that created an index the ORM had already created, or from a rename that copied rather than moved.

**How to confirm.** The finding lists the members with their sizes and scan counts.

**How to fix.** Keep the one that backs a constraint — dropping that one drops the constraint — or, failing that, the one with recorded usage. `DROP INDEX CONCURRENTLY` the other.

**False positives and caveats.** Two indexes differing only in name are duplicates; two differing in `INCLUDE` columns, sort direction or opclass are not, and the check compares all of those.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/indexes.html)

---

<a id="pg-idx-005"></a>
### PG-IDX-005 — Overlapping indexes (leading-column prefix)
**Priority 100** · Indexes · scope: index · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** Index A's key columns, opclasses and options are a strict prefix of index B's, with the same predicate, A not unique and neither an expression index. A is usually redundant, but prefixes are sometimes deliberate (INCLUDE columns, sort order), so this is P100 not P50.

**Reads.** `pg_index, pg_class`

**Why it matters.** An index on `(a)` can answer nothing that an index on `(a, b)` cannot, so the narrower one is usually redundant. Usually — not always: a narrower index is cheaper to maintain and fits more entries per page, so on a very hot table it can be the better choice for the queries that only need `a`. That is why this is P100 and why it says to check the plans.

**How to fix.** Compare the recorded scan counts (in the finding) and, for the queries that matter, compare `EXPLAIN` with and without. Then `DROP INDEX CONCURRENTLY` the narrower one if the wider one serves it.

**False positives and caveats.** Expression indexes are excluded because prefix comparison is not meaningful for them. `INCLUDE` columns make the wider index bigger without making it more capable for filtering, which can flip the decision.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/indexes.html)

---

<a id="pg-idx-006"></a>
### PG-IDX-006 — Estimated B-tree bloat over 50 percent (500 MB or more wasted)
**Priority 50** · Indexes · scope: index · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** Catalog-only estimator: estimated index bloat >= 50% and >= 500 MB wasted. Estimated, not measured. Fix with REINDEX INDEX CONCURRENTLY (12+).

**Thresholds.** `bloat_pct` = 50, `wasted_bytes` = 524,288,000, `top_n` = 10

**Reads.** `pg_index, pg_class, pg_attribute, pg_stats`

**Why it matters.** A B-tree index accumulates dead entries and partially empty pages as rows are updated and deleted. Unlike a heap, an index cannot reuse that space as freely, so it grows and stays grown. Fifty per cent bloat means every index scan reads roughly twice the pages it needs and the cache holds half as much useful index.

**How to confirm.** `SELECT * FROM pgstatindex('<index>');` (needs `pgstattuple`) for the measured figure — `avg_leaf_density` well below the fillfactor is the confirmation.

**How to fix.** `REINDEX INDEX CONCURRENTLY <schema>.<index>;` on PostgreSQL 12 and newer — it builds a new index alongside and swaps, so it needs disk for both copies but does not block writes. Below 12, build a new index under a different name and drop the old one.

**False positives and caveats.** **Estimated, not measured.** Deduplication (PostgreSQL 13 and newer) packs equal keys into posting lists, so a low-cardinality index is reported as far more bloated than it is — treat any hit that also appears in PG-IDX-015 as suspect. A freshly built B-tree sits at fillfactor 90 by design, so roughly 10 % is the intended state.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-reindex.html)

---

<a id="pg-idx-007"></a>
### PG-IDX-007 — Estimated B-tree bloat over 30 percent (100 MB or more wasted)
**Priority 150** · Indexes · scope: index · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** Estimated index bloat >= 30% and >= 100 MB wasted, excluding indexes already reported by IDX-006.

**Thresholds.** `bloat_pct` = 30, `wasted_bytes` = 104,857,600, `bloat_pct_high` = 50, `wasted_bytes_high` = 524,288,000, `top_n` = 10

**Reads.** `pg_index, pg_class, pg_attribute, pg_stats`

**Why it matters.** The same estimator at a lower threshold: worth knowing, rarely worth a rebuild on its own.

**How to fix.** Usually nothing. Rising across runs on the same index means the write pattern is producing bloat faster than vacuum can reclaim it.

**False positives and caveats.** Same estimator caveats as PG-IDX-006, with a higher false-positive rate at this threshold.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-reindex.html)

---

<a id="pg-idx-008"></a>
### PG-IDX-008 — Unindexed foreign key on a large table
**Priority 50** · Indexes · scope: relation · cost 1 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · threshold changed 0.2.0

**What fires it.** A foreign-key constraint with no index whose leading key columns equal conkey in order, on a child table of 100 MB or more. A parent DELETE or key UPDATE then sequentially scans the child under a share lock, and at this size one such scan is expensive whatever the parent's write rate is.

**Thresholds.** `min_bytes` = 104,857,600

**Reads.** `pg_constraint, pg_index, pg_class`

**Why it matters.** PostgreSQL indexes the referenced side of a foreign key automatically and the referencing side not at all. So a `DELETE` on the parent, or an `UPDATE` of its key, has to check the child for rows that reference it — and with no matching index that is a sequential scan of the child, holding a `KEY SHARE` lock, once per affected parent row. With `ON DELETE CASCADE` it is once per parent row *and* a delete pass. This turns a single-row parent delete into minutes of blocking on a large child.

**How to confirm.** `EXPLAIN` a `DELETE` of one parent row in a transaction you roll back, and look for a sequential scan of the child.

**How to fix.** `CREATE INDEX CONCURRENTLY ON <child> (<the foreign-key columns, in constraint order>);`. The order matters: PostgreSQL can only use an index whose *leading* columns match the constraint, so an index on `(b, a)` does not serve a foreign key on `(a, b)`.

**False positives and caveats.** A child table that is never affected by parent deletes or key updates does not need the index at all, and this check does not look at the parent's activity: it fires on size alone, because at 100 MB a single such scan is already worth an index. A child that is large but whose parent is genuinely append-only is the false positive to expect here.

**What changed in 0.2.0.** Until 0.2.0 this check fired on `child ≥ 100 MB` **or** `parent lifetime writes ≥ 1,000`, so its title was false of most of what it reported: in the field run that prompted the change, *no* child table reached 100 MB and all 129 findings came from the write arm, 108 of them because a `users` table had accumulated 1,290 writes in four months. The write arm now has its own ID and its own band — see PG-IDX-018 — and this ID means what its title says. The ID, title, priority and `object` format are unchanged, so existing suppressions on PG-IDX-008 keep working; what they no longer suppress is the mild tier, which is the point of splitting it.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK)

---

<a id="pg-idx-018"></a>
### PG-IDX-018 — Unindexed foreign key on a write-active parent
**Priority 100** · Indexes · scope: relation · cost 1 · source: sql · pass: fast · effort S / risk low · since 0.2.0

**What fires it.** As PG-IDX-008 but the child is smaller than 100 MB: the referenced table takes 10,000 or more updates plus deletes a day averaged over the statistics window, **and** the child holds 100,000 or more rows. A child that has never been analyzed has no row estimate (`reltuples` is −1 on PostgreSQL 14+, 0 before) and is not evaluated here — PG-VAC-004 is the check for that.

**Thresholds.** `max_bytes` = 104,857,600, `parent_writes_per_day` = 10,000, `min_child_rows` = 100,000, `top_n` = 20

**Reads.** `pg_constraint, pg_index, pg_class, pg_stat_user_tables, pg_stat_database`

**Why it matters.** Here the scan is not expensive because the child is big. It is expensive because it happens often, on enough rows to cost something each time. Every parent `DELETE` or key `UPDATE` runs the referential-integrity trigger, which with no usable index is a sequential scan of the child under a `KEY SHARE` lock. A child of 100,000 narrow rows scans in roughly 10 ms even fully cached; at 10,000 parent writes a day that is on the order of **100 seconds a day** of pure constraint-checking, all of it inside the parent's transaction and all of it taking locks on the child. That is a real cost, and it is not an emergency — hence P100 rather than PG-IDX-008's P50.

**Why a rate and not a counter.** `n_tup_upd + n_tup_del` is cumulative since the last statistics reset, so a fixed lifetime threshold measures the age of the counters as much as the workload. The old threshold of 1,000 lifetime writes is satisfied by **eight writes a day for four months** — an idle table — which is exactly how 108 eight-kilobyte tables ended up in a P50 band claiming to be about large tables. Dividing by the statistics window makes the number mean the same thing on a cluster reset last night and on one reset last spring, and 10,000 a day is an order of magnitude above the old figure at any plausible window. The row's `confidence` falls to `medium` when the window is under 7 days and `low` under 24 hours, because a rate extrapolated from a few hours of counters is a guess.

**How to confirm.** `SELECT n_tup_upd + n_tup_del, stats_reset FROM pg_stat_user_tables t, pg_stat_database d WHERE t.relname = '<parent>' AND d.datname = current_database();` and divide. Then `EXPLAIN` a rolled-back single-row `DELETE` on the parent and look for the sequential scan of the child.

**How to fix.** `CREATE INDEX CONCURRENTLY ON <child> (<the foreign-key columns, in constraint order>);` — the same fix as PG-IDX-008, and cheap while the child is still small.

**False positives and caveats.** The parent's write counters do not distinguish updates that touch the key from updates that do not; only key updates and deletes actually run the check, so the rate is an upper bound. `confidence: medium` below a 7-day statistics window. Partitioned parents report per-partition counters, so a heavily written partitioned parent can be spread thin enough to fall under the threshold.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK)

---

<a id="pg-idx-009"></a>
### PG-IDX-009 — Unindexed foreign key (small table)
**Priority 150** · Indexes · scope: relation · cost 1 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · threshold changed 0.2.0

**What fires it.** As PG-IDX-008 but the child is smaller than 100 MB and it does not reach PG-IDX-018 either — the parent is below 10,000 updates plus deletes a day, or the child holds fewer than 100,000 rows. Capped at the 20 largest.

**Thresholds.** `min_bytes` = 104,857,600, `parent_writes_per_day` = 10,000, `min_child_rows` = 100,000, `top_n` = 20

**Reads.** `pg_constraint, pg_index, pg_class, pg_stat_user_tables, pg_stat_database`

**Why it matters.** The same missing index on a table small enough, and a parent quiet enough, that the scan is cheap today. It is listed because tables grow, and the day the child crosses a few hundred megabytes or the parent gets busy this becomes PG-IDX-008 or PG-IDX-018 during whatever operation is running at the time.

**How to fix.** Add the index when convenient; it is cheap to create while the table is small.

**False positives and caveats.** The 20 rows shown are the 20 largest children, but `details` and `evidence.unindexed_fk_total` carry the **full** count for the database, so the cap never hides the size of the backlog — which the 0.1.0 form did. This is the tier to suppress wholesale if your schema deliberately leaves small lookup-table foreign keys unindexed; suppressing it does not touch PG-IDX-008 or PG-IDX-018.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK)

---

<a id="pg-idx-010"></a>
### PG-IDX-010 — Large table with heavy sequential scans
**Priority 50** · Indexes · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** Table 1 GB or larger, seq_scan >= 100 since reset, average rows per sequential scan >= 100,000, and sequential scans are at least 5% of all scans. Confidence medium: batch jobs scan legitimately.

**Thresholds.** `min_bytes` = 1,073,741,824, `min_seq_scans` = 100, `rows_per_scan` = 100,000, `seq_fraction` = 0.05, `top_n` = 10

**Reads.** `pg_stat_user_tables, pg_class`

**Why it matters.** A large table read by repeated sequential scans, each returning a large fraction of its rows, is the signature of a missing index or of a predicate the planner cannot use — a function on the column, a type mismatch, or a `LIKE` with a leading wildcard. It is also the signature of a nightly export doing exactly what it should, which is why confidence is medium.

**How to confirm.** `SELECT relname, seq_scan, seq_tup_read, seq_tup_read/nullif(seq_scan,0) AS rows_per_scan, idx_scan FROM pg_stat_user_tables ORDER BY seq_tup_read DESC LIMIT 20;`

**How to fix.** Find the statements. `pg_stat_statements` (PG-QRY-003 and PG-QRY-005) shows what is reading this table; `EXPLAIN` the top one. If the predicate is unusable, an expression index or a rewritten predicate fixes it; if there is genuinely no predicate, the scan is correct and nothing is wrong.

**False positives and caveats.** **Do not create an index from this finding alone.** It says a table is being scanned, not which column would help. Counters are cumulative since the statistics reset.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ALL-TABLES-VIEW)

---

<a id="pg-idx-011"></a>
### PG-IDX-011 — Sequential scans on mid-size tables
**Priority 150** · Indexes · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** As IDX-010 for tables between 100 MB and 1 GB. Summary form.

**Thresholds.** `min_bytes` = 104,857,600, `max_bytes` = 1,073,741,824, `min_seq_scans` = 100, `rows_per_scan` = 100,000, `seq_fraction` = 0.05, `top_n` = 20

**Reads.** `pg_stat_user_tables, pg_class`

**Why it matters.** The same pattern on tables between 100 MB and 1 GB, where the cost is real but small. Summarised rather than listed individually.

**How to fix.** Worth a look when the same tables appear run after run and are growing.

**False positives and caveats.** Summary form.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ALL-TABLES-VIEW)

---

<a id="pg-idx-012"></a>
### PG-IDX-012 — Write-heavy table with many indexes
**Priority 100** · Indexes · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** At least 10 indexes on a table with 1,000,000 or more writes since the statistics reset. Every insert and every non-HOT update touches every index.

**Thresholds.** `min_indexes` = 10, `min_writes` = 1,000,000

**Reads.** `pg_index, pg_stat_user_tables`

**Why it matters.** Every insert writes an entry into every index on the table, and every update that cannot be heap-only does the same. Ten indexes on a table taking a million writes means ten million index writes, each with its own WAL, its own page dirtying and its own eventual vacuum. The cost is invisible in the statement's own timing and shows up as write throughput that does not match the hardware.

**How to fix.** Use this next to PG-IDX-002 and PG-IDX-004: the finding reports how many of the indexes have never been scanned, which is usually where the answer is. Consolidating two narrow indexes into one composite is the other common win (PG-IDX-005 from the other direction).

**False positives and caveats.** Ten indexes on a table that is genuinely queried ten different ways is not a defect. The write count is what makes it one.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/indexes.html)

---

<a id="pg-idx-013"></a>
### PG-IDX-013 — Index footprint more than twice the heap on a large table
**Priority 150** · Indexes · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** Table 1 GB or larger with pg_indexes_size >= 2 x pg_table_size. An informational pointer to IDX-002, 004, 005 and 012.

**Thresholds.** `min_bytes` = 1,073,741,824, `index_multiple` = 2

**Reads.** `pg_class, pg_indexes_size(), pg_table_size()`

**Why it matters.** Indexes larger than twice the heap is not wrong on its own — a covering index or a wide composite key legitimately costs this. It is the *shape* that PG-IDX-002 (unused), PG-IDX-004 (duplicate), PG-IDX-005 (overlapping) and PG-IDX-006 (bloated) tend to produce together, so it is a good place to start reading those.

**How to fix.** Work through the index-specific findings for this table. The finding reports how many of the indexes have never been scanned and names the three largest.

**False positives and caveats.** Informational pointer.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/indexes.html)

---

<a id="pg-idx-014"></a>
### PG-IDX-014 — Wide B-tree indexes
**Priority 150** · Indexes · scope: index · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 11+

**What fires it.** A B-tree index with 6 or more key columns and a size of 100 MB or more. Each entry carries every key column in every leaf and internal page.

**Thresholds.** `min_key_columns` = 6, `min_bytes` = 104,857,600

**Reads.** `pg_index, pg_class`

**Why it matters.** Every key column appears in every leaf entry and in every internal page, so a six-column index is wide, its fan-out is low, and its tree is deeper than it needs to be. Only queries whose predicate matches a leading prefix can use it at all, so the trailing columns frequently earn nothing.

**How to fix.** If the trailing columns exist to make the index covering, `INCLUDE` columns (PostgreSQL 11 and newer) give the same index-only-scan benefit without widening the key or the internal pages.

**False positives and caveats.** A six-column key that exactly matches a compound uniqueness requirement is correct. Check what the index is for before narrowing it.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/indexes.html)

---

<a id="pg-idx-015"></a>
### PG-IDX-015 — Single-column index on a very low-cardinality column
**Priority 150** · Indexes · scope: index · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** A single-column, non-partial B-tree index whose column has pg_stats.n_distinct between 1 and 3 (booleans, status flags) on a table 100 MB or larger. A partial index is usually the better shape.

**Thresholds.** `max_distinct` = 3, `min_bytes` = 104,857,600

**Reads.** `pg_index, pg_stats, pg_class`

**Why it matters.** An index whose column has three or fewer distinct values cannot help the planner for the common values — a sequential scan is cheaper than an index scan returning a third of the table — so it earns its keep only for the rare ones. It is still maintained on every write.

**How to confirm.** `SELECT attname, n_distinct, most_common_freqs[1] FROM pg_stats WHERE schemaname='...' AND tablename='...';`

**How to fix.** A partial index is usually the right shape: `CREATE INDEX CONCURRENTLY ... WHERE status = 'pending';` is a fraction of the size, is maintained only for the rows that match, and serves exactly the queries that were using the full index.

**False positives and caveats.** `n_distinct` comes from the last ANALYZE and is an estimate. A boolean column with a 99/1 split is a good partial-index candidate; a 50/50 split is a good candidate for having no index at all.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/indexes.html)

---

<a id="pg-idx-016"></a>
### PG-IDX-016 — GIN index with a large pending list
**Priority 150** · Indexes · scope: index · cost 2 · source: sql · pass: deep · effort S / risk low · since 0.1.0 · needs ext:pgstattuple · **status: planned**

**What fires it.** pgstatginindex().pending_pages x 8 kB >= 64 MB on GIN indexes of 100 MB or more. Deep pass; requires the pgstattuple extension.

**Thresholds.** `pending_bytes` = 67,108,864, `min_bytes` = 104,857,600

**Reads.** `pgstatginindex(), pg_index, pg_class`

**Why it matters.** A GIN index buffers new entries in a pending list and merges them into the main structure during vacuum or when the list exceeds `gin_pending_list_limit`. A large pending list means every search of that index has to scan the list linearly in addition to the index proper, so query time degrades until the merge happens.

**How to fix.** `VACUUM` the underlying table, which flushes the pending list. If it recurs, lower `gin_pending_list_limit` on the index or set `fastupdate = off` to disable the buffer entirely — which trades slower inserts for consistent search latency.

**False positives and caveats.** **Not implemented in this release** (`status=planned`): it needs `pgstatginindex()` from the `pgstattuple` extension, which is not present by default, and it reads index pages, so it is a cost-2 deep-pass check. The registry row exists so the identifier is reserved and the gap is visible.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/gin-implementation.html)

---

<a id="pg-idx-017"></a>
### PG-IDX-017 — Index build in progress
**Priority 200** · Indexes · scope: index · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0 · PostgreSQL 12+ · needs pg_monitor

**What fires it.** Any row in pg_stat_progress_create_index. Context for the operator: it explains locks, load and WAL volume during the run.

**Reads.** `pg_stat_progress_create_index`

**Why it matters.** An index build holds a lock on the table, generates WAL, and — if `CONCURRENTLY` — waits for every transaction older than itself to finish before it can proceed. That last part is why a single long-running transaction (PG-LOCK-005) can stall a concurrent index build indefinitely while everything looks like it is progressing.

**How to fix.** Nothing: this is context for the operator. If a `CONCURRENTLY` build is stuck at the wait phase, PG-LOCK-005 names what it is waiting for.

**False positives and caveats.** PostgreSQL 12 and newer.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/progress-reporting.html)

---


## Schema design (`SCHEMA`)

<a id="pg-schema-001"></a>
### PG-SCHEMA-001 — Sequence or integer key at 90 percent or more of its range
**Priority 5** · Schema design · scope: relation · cost 1 · source: sql · pass: fast · effort L / risk high · since 0.1.0 · PostgreSQL 10+

**What fires it.** last_value / effective_max >= 0.90, where effective_max is min(max_value, the maximum of the owning column's type: 32,767 / 2,147,483,647 / 9.22e18). Inserts fail with 'nextval: reached maximum value' or 'integer out of range'.

**Thresholds.** `exhaustion_fraction` = 0.90

**Reads.** `pg_sequences, pg_depend, pg_attribute`

**Why it matters.** When a sequence reaches its maximum, every `INSERT` that calls `nextval` fails — not slowly, and not for some rows. If the binding limit is an `integer` column rather than the sequence's own `max_value`, the error is `integer out of range` instead, which is the same outage with a more confusing message. At 90 % there is very little time, and the fix is not fast: widening an `int4` primary key to `bigint` rewrites the table and every index on it.

**How to confirm.** `SELECT last_value, max_value, round(100.0*last_value/max_value,1) FROM pg_sequences ORDER BY 3 DESC;`

**How to fix.** The safe migration, in order: 1. Add a new `bigint` column. 2. Backfill it in batches. 3. Add a unique index concurrently on the new column. 4. Switch the foreign keys, one at a time, with `NOT VALID` then `VALIDATE`. 5. Swap the primary key in a short lock window. The unsafe fast version — `ALTER TABLE ... ALTER COLUMN id TYPE bigint` — rewrites the whole table under an ACCESS EXCLUSIVE lock and is an outage proportional to the table size.

**False positives and caveats.** A sequence with a large `increment_by`, or one advanced by cached blocks in many sessions, consumes its range faster than the row count suggests. `CYCLE` sequences are excluded — they wrap by design, which is a different problem.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-createsequence.html)

---

<a id="pg-schema-002"></a>
### PG-SCHEMA-002 — Sequence or integer key at 70 percent or more of its range
**Priority 50** · Schema design · scope: relation · cost 1 · source: sql · pass: fast · effort L / risk high · since 0.1.0 · PostgreSQL 10+

**What fires it.** As SCHEMA-001 but between 70% and 90%. Time to plan the bigint migration, which is a full table rewrite on a large table.

**Thresholds.** `exhaustion_fraction` = 0.70, `exhaustion_fraction_high` = 0.90

**Reads.** `pg_sequences, pg_depend, pg_attribute`

**Why it matters.** The same measurement at 70 %, which is where the bigint migration should be *planned* rather than executed under pressure. The migration takes weeks of elapsed time on a large table if it is done safely, so 70 % is not early.

**How to fix.** Start the migration described in PG-SCHEMA-001. There is nothing to do urgently and a great deal to do eventually.

**False positives and caveats.** Same caveats as PG-SCHEMA-001.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-createsequence.html)

---

<a id="pg-schema-003"></a>
### PG-SCHEMA-003 — Tables without a primary key or unique index
**Priority 150** · Schema design · scope: relation · cost 1 · source: sql · pass: fast · effort L / risk med · since 0.1.0

**What fires it.** An ordinary table with no valid indisprimary or indisunique index. Logical replication cannot replicate UPDATE or DELETE, de-duplication is manual, and many ORMs and CDC tools misbehave. Summary form listing the 10 largest.

**Thresholds.** `top_n` = 10

**Reads.** `pg_class, pg_index`

**Why it matters.** Without a primary key or unique index there is no way to address a single row from outside the database. Logical replication cannot replicate `UPDATE` or `DELETE` (PG-REPL-013 fires if the table is published), CDC tools either refuse or fall back to shipping whole rows, deduplication becomes a manual `ctid` exercise, and most ORMs degrade. It is P150 because an append-only event log legitimately has none.

**How to fix.** Add one. If there is a natural key, use it; if not, an identity column is cheap. `ALTER TABLE t ADD COLUMN id bigint GENERATED ALWAYS AS IDENTITY` rewrites the table, so on anything large do it as a backfilled column plus a concurrent unique index and then attach the constraint.

**False positives and caveats.** Partitions are excluded — the parent carries the key. An append-only log table is the legitimate case; the finding lists sizes so it is easy to separate from the accidental ones.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-altertable.html)

---

<a id="pg-schema-004"></a>
### PG-SCHEMA-004 — REPLICA IDENTITY FULL on published tables
**Priority 150** · Schema design · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 10+ · primary only

**What fires it.** A published table with relreplident = 'f'. Every UPDATE and DELETE ships the whole old row and the subscriber does a full-table lookup unless it has a matching index.

**Reads.** `pg_class, pg_publication_tables`

**Why it matters.** `REPLICA IDENTITY FULL` makes every `UPDATE` and `DELETE` write the complete old row into WAL, so WAL volume scales with row width rather than with the size of the change. On the subscriber side it is worse: matching a row means comparing every column, which is a sequential scan per change unless the subscriber happens to have an index that helps.

**How to fix.** If the table has a primary key, `ALTER TABLE t REPLICA IDENTITY DEFAULT;`. If it has a unique, non-partial, `NOT NULL` index, `REPLICA IDENTITY USING INDEX <name>`. `FULL` is the fallback for tables that have neither, and the better fix for those is PG-SCHEMA-003.

**False positives and caveats.** `FULL` is sometimes deliberate because a CDC consumer wants before-images of every column. That is a real requirement; it has this cost.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/logical-replication-publication.html)

---

<a id="pg-schema-005"></a>
### PG-SCHEMA-005 — Very large table not partitioned
**Priority 100** · Schema design · scope: relation · cost 1 · source: sql · pass: fast · effort L / risk med · since 0.1.0 · PostgreSQL 10+

**What fires it.** pg_total_relation_size >= 200 GB and the relation is neither partitioned nor a partition. Vacuum, freeze, index builds and REINDEX all scale with the single relation. Advisory only.

**Thresholds.** `min_bytes` = 214,748,364,800

**Reads.** `pg_class, pg_partitioned_table, pg_inherits`

**Why it matters.** Everything that has to touch a whole relation — a vacuum, a freeze, an index build, a `REINDEX`, an `ALTER TABLE` that rewrites — is one long single operation on a 200 GB table. Deleting old rows means a `DELETE` plus a vacuum rather than dropping a partition, and the anti-wraparound freeze has the whole thing to do at once.

**How to fix.** Partition it, if there is a natural range key and a retention policy — those two conditions are what make partitioning pay. Converting an existing table is a migration: create the partitioned parent, attach the existing table as one partition or copy in batches, then switch. It is not a setting.

**False positives and caveats.** Advisory. Partitioning a table with no natural partition key makes planning slower and nothing else better.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/ddl-partitioning.html)

---

<a id="pg-schema-006"></a>
### PG-SCHEMA-006 — Rows accumulating in a DEFAULT partition
**Priority 100** · Schema design · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 11+

**What fires it.** A default partition of 1 GB or more, or holding 10% or more of the parent's live tuples. Someone forgot to create the next partition, and every new ATTACH PARTITION must scan the default partition.

**Thresholds.** `min_bytes` = 1,073,741,824, `parent_fraction` = 0.10

**Reads.** `pg_class, pg_inherits, pg_stat_user_tables`

**Why it matters.** Rows land in the `DEFAULT` partition when no other partition's bounds match them, which almost always means the next period's partition was never created. Two things follow: queries that should prune to one partition now also scan the default one, and every future `ATTACH PARTITION` has to scan the entire default partition to prove no row belongs in the new one — holding an ACCESS EXCLUSIVE lock while it does.

**How to fix.** Create the missing partitions, then move the rows out of the default one and back into the correct partitions. Automate partition creation (`pg_partman` or a scheduled job) so it cannot happen again; a default partition should be empty and exist only as a safety net.

**False positives and caveats.** PostgreSQL 11 and newer for default partitions.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/ddl-partitioning.html)

---

<a id="pg-schema-007"></a>
### PG-SCHEMA-007 — Partitioned table with more than 1,000 partitions
**Priority 150** · Schema design · scope: relation · cost 1 · source: sql · pass: fast · effort L / risk med · since 0.1.0 · PostgreSQL 10+

**What fires it.** A partitioned table with 1,000 or more direct children. Planning time and lock acquisition scale with the partition count on queries that cannot be pruned.

**Thresholds.** `max_partitions` = 1,000

**Reads.** `pg_inherits, pg_class`

**Why it matters.** The planner takes a lock on every partition it cannot prune away, per query. At a thousand partitions, planning time and lock-manager traffic are visible even on queries whose execution is fast — and any query that cannot prune (a non-constant partition-key predicate, a prepared generic plan) touches all of them.

**How to fix.** Use a coarser interval, or sub-partition so pruning happens in two cheap steps. Detaching and archiving old partitions is usually easier than either.

**False positives and caveats.** `enable_partition_pruning` and `plan_cache_mode` both change how badly this bites. A thousand partitions with reliable pruning is much less painful than a hundred without.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/ddl-partitioning.html)

---

<a id="pg-schema-008"></a>
### PG-SCHEMA-008 — Foreign keys or check constraints NOT VALID
**Priority 200** · Schema design · scope: relation · cost 1 · source: sql · pass: inventory · effort M / risk med · since 0.1.0

**What fires it.** pg_constraint.convalidated = false. Integrity is enforced for new rows only; existing rows were never checked.

**Reads.** `pg_constraint`

**Why it matters.** A `NOT VALID` constraint is enforced for new and modified rows and was never checked against the rows that existed when it was added. It documents an intention rather than guaranteeing anything, and the planner will not use a `NOT VALID` check constraint for constraint exclusion.

**How to fix.** `ALTER TABLE t VALIDATE CONSTRAINT c;` — it scans the table under a `SHARE UPDATE EXCLUSIVE` lock, which does not block reads or writes. This is almost always a migration that added the constraint safely and never came back for the second step.

**False positives and caveats.** Inventory row. Validation can fail if existing rows violate the constraint, which is itself the useful finding.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-altertable.html)

---

<a id="pg-schema-009"></a>
### PG-SCHEMA-009 — Triggers on high-write tables
**Priority 150** · Schema design · scope: relation · cost 1 · source: sql · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** A table with 1,000,000 or more writes since the statistics reset carrying at least one non-internal trigger. Informational: triggers are where surprising write latency hides.

**Thresholds.** `min_writes` = 1,000,000

**Reads.** `pg_trigger, pg_stat_user_tables`

**Why it matters.** Trigger work happens inside the statement but is invisible in the statement's own timing and in most application metrics, so a slow trigger looks like a slow `INSERT`. Row-level triggers also disable the fast paths for `COPY` and multi-row `INSERT`, which is why a bulk load into a triggered table is an order of magnitude slower than into an untriggered one.

**How to fix.** Informational: it tells you where to look first when write latency on this table does not match the statement. `EXPLAIN (ANALYZE)` reports trigger time separately, which is the measurement.

**False positives and caveats.** Triggers are a normal and correct tool. This row exists to make them visible on tables where the write volume makes their cost significant.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/trigger-definition.html)

---

<a id="pg-schema-010"></a>
### PG-SCHEMA-010 — Database with more than 10,000 relations
**Priority 150** · Schema design · scope: database · cost 1 · source: sql · pass: fast · effort L / risk med · since 0.1.0

**What fires it.** 10,000 or more entries in pg_class for tables, indexes, toast tables and partitions in one database. Catalog bloat, autovacuum scheduling latency and slow information_schema queries follow.

**Thresholds.** `max_relations` = 10,000

**Reads.** `pg_class`

**Why it matters.** Every entry in `pg_class` is a catalog row autovacuum considers each cycle, that every backend's relcache may hold, and that `information_schema` has to walk. Past ten thousand, autovacuum scheduling latency, connection startup cost and catalog bloat all become visible — and the catalog itself needs vacuuming, which is easy to forget.

**How to fix.** The usual cause is a schema per tenant or per customer. The alternatives are a shared schema with a tenant column plus row-level security, or splitting tenants across databases or clusters. Both are architecture changes; the interim mitigation is to make sure the catalog tables themselves are being vacuumed and analyzed.

**False positives and caveats.** Includes indexes, TOAST tables and partitions, which is correct — they are all catalog rows — but means the number is several times the table count.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/diskusage.html)

---

<a id="pg-schema-011"></a>
### PG-SCHEMA-011 — Unpopulated materialized view
**Priority 150** · Schema design · scope: relation · cost 1 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** pg_class with relkind = 'm' and relispopulated = false. Any query against it raises an error.

**Reads.** `pg_class`

**Why it matters.** A materialized view created `WITH NO DATA` errors on every query against it: "materialized view has not been populated". This is usually a migration that created the view and never ran the first refresh.

**How to fix.** `REFRESH MATERIALIZED VIEW <name>;` — a write, and it takes an ACCESS EXCLUSIVE lock unless refreshed `CONCURRENTLY`, which in turn requires a unique index on the view.

**False positives and caveats.** A view deliberately left unpopulated as a placeholder will fire this every run; suppress it with a reason if that is the case.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-creatematerializedview.html)

---

<a id="pg-schema-012"></a>
### PG-SCHEMA-012 — Legacy inheritance-based partitioning
**Priority 200** · Schema design · scope: relation · cost 1 · source: sql · pass: inventory · effort L / risk med · since 0.1.0 · PostgreSQL 10+

**What fires it.** A pg_inherits parent that is not in pg_partitioned_table. Inventory: constraint exclusion rather than partition pruning, and no declarative partition maintenance.

**Reads.** `pg_inherits, pg_partitioned_table, pg_class`

**Why it matters.** Inheritance-based partitioning predates declarative partitioning. Row routing depends on triggers or rules that someone installed, pruning depends on `constraint_exclusion` finding usable `CHECK` constraints rather than on partition bounds, and there is no `ATTACH`/`DETACH PARTITION`. It still works; it is more fragile and slower to plan.

**How to fix.** Migrating to declarative partitioning is a planned change, not a fix: create the partitioned parent, attach the existing children as partitions where the bounds allow, and remove the routing triggers.

**False positives and caveats.** Inventory row. Some inheritance hierarchies are not partitioning at all — they are genuine table inheritance — and the check cannot distinguish them.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/ddl-partitioning.html)

---

<a id="pg-schema-013"></a>
### PG-SCHEMA-013 — Large objects present (vacuumlo candidate)
**Priority 100** · Schema design · scope: database · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** pg_largeobject is 10 GB or larger. Large objects orphaned by a deleted referencing row are never reclaimed without running vacuumlo.

**Thresholds.** `min_bytes` = 10,737,418,240

**Reads.** `pg_largeobject_metadata, pg_total_relation_size()`

**Why it matters.** A large object is not owned by the row that references its OID. Deleting the referencing row leaves the object behind forever, and nothing in the server ever notices. `pg_largeobject` is also an ordinary table for vacuum purposes, so it bloats and needs freezing like one — on a cluster where nobody thinks of it as a table.

**How to fix.** Run `vacuumlo` against the databases that use large objects: it finds OIDs no column references and unlinks them. That is a write, so schedule it. Then check that `pg_largeobject` itself is being vacuumed.

**False positives and caveats.** `vacuumlo` decides what is orphaned by scanning every `oid` and `lo` column in the database. If your application stores large-object OIDs in a text column, `vacuumlo` will consider them unreferenced and delete the objects.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/vacuumlo.html)

---


## Queries and workload visibility (`QRY`)

<a id="pg-qry-001"></a>
### PG-QRY-001 — pg_stat_statements not available
**Priority 100** · Queries and workload visibility · scope: database · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** pg_stat_statements is not in shared_preload_libraries, or is preloaded but not created in this database. Without it there is no per-query workload view and every other QRY check is skipped. Enabling the preload needs a restart.

**Reads.** `pg_settings, pg_extension, pg_available_extensions`

**Why it matters.** Without `pg_stat_statements` there is no per-statement view of the workload at all. The only evidence about where the server spends its time is the aggregate counters in `pg_stat_database` and whatever the slow-query log has captured — which means every question of the form "what should we tune first" is unanswerable. Eleven of the checks in this catalog depend on it.

**How to confirm.** `SELECT count(*) FROM pg_stat_statements;`

**How to fix.** Add it to `shared_preload_libraries` (needs a restart), then `CREATE EXTENSION pg_stat_statements;` in each database you want to observe. The cost is a small fixed amount of shared memory and a hash lookup per statement. Most managed platforms preload it already, so only the `CREATE EXTENSION` is needed there.

**False positives and caveats.** It must be preloaded *and* created in the specific database. A cluster where it is created in `postgres` but not in the application database gives an empty view and no error.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)

---

<a id="pg-qry-002"></a>
### PG-QRY-002 — pg_stat_statements evicting entries
**Priority 150** · Queries and workload visibility · scope: database · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 14+

**What fires it.** pg_stat_statements_info.dealloc >= 1,000 since reset, or 100 or more per day. The top-N lists are unreliable while entries are being evicted; raise pg_stat_statements.max (needs a restart).

**Thresholds.** `min_dealloc` = 1,000, `dealloc_per_day` = 100

**Reads.** `pg_stat_statements_info`

**Why it matters.** `pg_stat_statements` holds a fixed number of entries. When it fills, it discards the least-executed half — so the "top 10 by total time" list is missing whatever was evicted, and the total it is a percentage *of* is also wrong. High eviction almost always means unparameterised SQL: each distinct literal produces a distinct `queryid`, so a few thousand ad-hoc queries can flush the entire table.

**How to fix.** Raise `pg_stat_statements.max` (needs a restart) as the immediate fix, and find the unparameterised statements as the real one — they are also defeating the plan cache. `pg_stat_statements.track = top` reduces churn from nested statements.

**False positives and caveats.** PostgreSQL 14 and newer for `pg_stat_statements_info`. Below that, eviction is invisible.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)

---

<a id="pg-qry-003"></a>
### PG-QRY-003 — Top 10 statements by total execution time
**Priority 240** · Queries and workload visibility · scope: query · cost 1 · source: sql · pass: inventory · effort M / risk low · since 0.1.0 · needs pg_monitor

**What fires it.** Always, when pg_stat_statements is readable: the 10 statements with the highest total execution time, with percentage of total, calls, mean ms, rows per call, shared blocks read, temp blocks written and WAL bytes.

**Thresholds.** `top_n` = 10

**Reads.** `pg_stat_statements`

**Why it matters.** Total execution time is the ranking that answers "where does this server spend its time". It is deliberately not mean time: a statement taking 2 ms a million times costs more than one taking 20 seconds once, and it is usually easier to fix.

**How to fix.** Start at the top. `EXPLAIN (ANALYZE, BUFFERS)` the first entry with realistic parameters, on a replica or a copy if the statement is expensive.

**False positives and caveats.** Cumulative since the `pg_stat_statements` reset, which is independent of the `pg_stat_database` reset. If PG-QRY-002 fired, this ranking is incomplete.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)

---

<a id="pg-qry-004"></a>
### PG-QRY-004 — Top 10 statements by mean execution time
**Priority 240** · Queries and workload visibility · scope: query · cost 1 · source: sql · pass: inventory · effort M / risk low · since 0.1.0 · needs pg_monitor

**What fires it.** The 10 statements with the highest mean execution time among those with at least 100 calls.

**Thresholds.** `top_n` = 10, `min_calls` = 100

**Reads.** `pg_stat_statements`

**Why it matters.** Mean time finds the individually slow statements that total time hides. A statement with a 4-second mean and 200 calls does not appear in the total-time list and is very much felt by whoever waits for it.

**How to fix.** Read alongside PG-QRY-013: a high mean with a high standard deviation is a plan problem, and a high mean with a low one is a workload problem.

**False positives and caveats.** Restricted to statements with at least 100 calls, because a mean over three executions is not a mean.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)

---

<a id="pg-qry-005"></a>
### PG-QRY-005 — Top 10 statements by I/O
**Priority 240** · Queries and workload visibility · scope: query · cost 1 · source: sql · pass: inventory · effort M / risk low · since 0.1.0 · needs pg_monitor

**What fires it.** The 10 statements with the highest shared_blks_read + temp_blks_read + temp_blks_written.

**Thresholds.** `top_n` = 10

**Reads.** `pg_stat_statements`

**Why it matters.** Blocks read plus temp blocks is where the storage time goes. A statement high in this list and low in the total-time list is one whose I/O is currently being absorbed by the operating-system page cache — which will stop being true the moment the working set grows or the host is restarted.

**How to fix.** Cross-reference against PG-IDX-010: a statement doing large sequential reads of one table usually explains that table's scan counters.

**False positives and caveats.** With `track_io_timing` off (PG-QRY-012) this is block counts only, with no time attached, so it cannot distinguish a cached read from a disk read.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)

---

<a id="pg-qry-006"></a>
### PG-QRY-006 — Top 10 statements by call count
**Priority 240** · Queries and workload visibility · scope: query · cost 1 · source: sql · pass: inventory · effort M / risk low · since 0.1.0 · needs pg_monitor

**What fires it.** The 10 most frequently executed statements. N+1 query patterns and polling loops surface here.

**Thresholds.** `top_n` = 10

**Reads.** `pg_stat_statements`

**Why it matters.** Call count is where N+1 query patterns and polling loops surface. A statement called ten million times is worth attention even at a 0.1 ms mean: it is a second of server time per thousand calls, plus a round trip and a snapshot each.

**How to fix.** Look for a query that should have been a join, a cache, or a notification. PG-QRY-016 filters this list down to the calls that return almost nothing, which is the strongest form of the signal.

**False positives and caveats.** Cumulative since reset.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)

---

<a id="pg-qry-007"></a>
### PG-QRY-007 — Top 10 statements by WAL generated
**Priority 240** · Queries and workload visibility · scope: query · cost 1 · source: sql · pass: inventory · effort M / risk low · since 0.1.0 · PostgreSQL 13+ · primary only · needs pg_monitor

**What fires it.** The 10 statements with the highest wal_bytes (pg_stat_statements 1.8, PostgreSQL 13+). Write amplification and replication load come from here.

**Thresholds.** `top_n` = 10

**Reads.** `pg_stat_statements`

**Why it matters.** WAL bytes per statement shows write amplification: which statements generate replication traffic, archive volume and checkpoint pressure. A statement high here and low in total time is cheap to run and expensive to replicate.

**How to fix.** Common causes are updates to indexed columns (every index gets a WAL record), updates immediately after a checkpoint (full-page images, PG-WAL-008), and updates that rewrite unchanged columns.

**False positives and caveats.** PostgreSQL 13 and newer (`pg_stat_statements` 1.8). Primary only.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)

---

<a id="pg-qry-008"></a>
### PG-QRY-008 — One statement dominates execution time
**Priority 100** · Queries and workload visibility · scope: query · cost 1 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · needs pg_monitor

**What fires it.** A single queryid accounts for 25% or more of the sum of total execution time, with at least 1,000 calls. Tune this one before anything else.

**Thresholds.** `dominance` = 0.25, `min_calls` = 1,000

**Reads.** `pg_stat_statements`

**Why it matters.** When one statement is a quarter of everything, the tuning priority is not a judgement call. Halving it removes an eighth of the server's recorded query time, which is more than any configuration change is likely to give.

**How to fix.** `EXPLAIN (ANALYZE, BUFFERS)` it with realistic parameters. Look at the row-count estimates against actuals first — a large mis-estimate is the most common cause and often has a cheap fix in statistics or an expression index.

**False positives and caveats.** The percentage is of *recorded* time, so it is wrong if PG-QRY-002 fired. Cumulative since reset, so a one-off migration can dominate for weeks.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)

---

<a id="pg-qry-009"></a>
### PG-QRY-009 — Statements spilling to temp files
**Priority 100** · Queries and workload visibility · scope: query · cost 1 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · needs pg_monitor

**What fires it.** A statement with 1 GB or more of temp_blks_written since the statistics reset; top 5. Pairs with MEM-004: raise work_mem for the role that runs these, not globally.

**Thresholds.** `temp_bytes` = 1,073,741,824, `top_n` = 5

**Reads.** `pg_stat_statements`

**Why it matters.** Temp blocks written are sorts, hashes and materialise steps that exceeded `work_mem` and went to disk: the data was written out and read back, turning a memory operation into two I/O operations. This is the statement-level view of PG-MEM-004.

**How to fix.** Raise `work_mem` for the role that runs these, not globally. Or fix the query: a spill is often a sign that the planner expected far fewer rows than it got, which is a statistics problem rather than a memory one.

**False positives and caveats.** Cumulative. A single monthly report can dominate this list.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)

---

<a id="pg-qry-010"></a>
### PG-QRY-010 — Plan-hostile patterns in top statements
**Priority 150** · Queries and workload visibility · scope: query · cost 1 · source: sql · pass: fast · effort L / risk low · since 0.1.0 · needs pg_monitor

**What fires it.** Regular-expression scan of the top 50 statements by total time for: leading-wildcard LIKE, lower()/upper() equality without a matching expression index, NOT IN (SELECT, ORDER BY random(), OFFSET of five digits or more, SELECT * on large tables, and unfiltered count(*). Confidence low: these are regexes over normalised text.

**Thresholds.** `top_n` = 50

**Reads.** `pg_stat_statements`

**Why it matters.** Some query shapes are hostile to the planner regardless of indexes: a leading-wildcard `LIKE` cannot use a B-tree; `NOT IN (SELECT ...)` over a nullable subquery returns no rows at all when a NULL appears and cannot be turned into an anti-join; `ORDER BY random()` sorts everything to return a few rows; a large `OFFSET` produces and discards every skipped row; a function around an indexed column in `WHERE` prevents the index being used.

**How to fix.** Treat each as a candidate to read, not a defect. The fixes are standard: a trigram or full-text index for leading wildcards, `NOT EXISTS` for `NOT IN`, keyset pagination for large offsets, an expression index matching the function.

**False positives and caveats.** **Confidence is low by construction.** These are regular expressions over normalised statement text: they misread as often as any regex over SQL does, and `pg_stat_statements` replaces literals with `$n`, so a pattern supplied as a bound parameter is invisible here. This check never appears in "Fix first".

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/using-explain.html)

---

<a id="pg-qry-011"></a>
### PG-QRY-011 — High transaction rollback ratio
**Priority 100** · Queries and workload visibility · scope: database · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** xact_rollback / (xact_commit + xact_rollback) >= 0.10 with at least 10,000 transactions. Application errors, or an aborted-transaction retry loop.

**Thresholds.** `rollback_ratio` = 0.10, `min_transactions` = 10,000

**Reads.** `pg_stat_database`

**Why it matters.** PostgreSQL rolls a transaction back when the application asks, and also whenever any statement in it raises an error — after which every subsequent statement fails with "current transaction is aborted" until the block ends. A tenth of all transactions failing is usually one recurring application error, a retry loop around a constraint violation, or a health check that deliberately aborts.

**How to fix.** Find the errors in the server log. If they are expected (an upsert implemented as insert-then-catch), consider `ON CONFLICT` instead: it avoids the aborted-transaction path entirely.

**False positives and caveats.** Some frameworks deliberately roll back read-only transactions, which inflates this without indicating anything wrong.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-DATABASE-VIEW)

---

<a id="pg-qry-012"></a>
### PG-QRY-012 — track_io_timing disabled
**Priority 150** · Queries and workload visibility · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** track_io_timing = off. The I/O-time columns of pg_stat_statements are zero and EXPLAIN (ANALYZE, BUFFERS) has no timing. The cost of enabling it is small on modern clocks; measure with pg_test_timing first.

**Reads.** `pg_settings`

**Why it matters.** With `track_io_timing` off, every I/O-time column is zero: `blk_read_time` in `pg_stat_database`, the corresponding columns in `pg_stat_statements`, and the "I/O Timings" line in `EXPLAIN (ANALYZE, BUFFERS)`. Without them there is no way to tell a query that is slow because it waits on storage from one that is slow because it burns CPU — which is the first fork in every performance investigation.

**How to fix.** Measure the cost first with `pg_test_timing`: on modern hardware with a TSC clocksource it is a few nanoseconds per call and the overhead is negligible. Then `ALTER SYSTEM SET track_io_timing = on; SELECT pg_reload_conf();`.

**False positives and caveats.** On a host where `clocksource` is `hpet` or `acpi_pm` rather than `tsc`, the cost is real. `pg_test_timing` is the check, and it takes a minute.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html)

---

<a id="pg-qry-013"></a>
### PG-QRY-013 — Plan-instability candidates (high standard deviation)
**Priority 150** · Queries and workload visibility · scope: query · cost 1 · source: sql · pass: fast · effort L / risk low · since 0.1.0 · needs pg_monitor

**What fires it.** Statements with at least 1,000 calls where stddev_exec_time >= 3 x mean_exec_time and mean >= 10 ms. Parameter-sensitive plans, cache effects, or wildly varying result sizes.

**Thresholds.** `stddev_multiple` = 3, `min_calls` = 1,000, `min_mean_ms` = 10, `top_n` = 10

**Reads.** `pg_stat_statements`

**Why it matters.** A standard deviation three times the mean means the same normalised statement sometimes runs quickly and sometimes does not. The usual causes are parameter values that select wildly different row counts, a generic plan chosen after five executions of a prepared statement, and a working set that is sometimes cached and sometimes not. The mean hides all three, and so does a ranking by total time.

**How to fix.** Reproduce with the slow parameter values. If a generic plan is the cause, `plan_cache_mode = force_custom_plan` for that role or session is the test; extended statistics or a partial index is usually the durable fix.

**False positives and caveats.** `confidence: low`. High variance is normal for a statement whose result size legitimately varies.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)

---

<a id="pg-qry-014"></a>
### PG-QRY-014 — JIT overhead significant
**Priority 100** · Queries and workload visibility · scope: query · cost 1 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · PostgreSQL 15+ · needs pg_monitor

**What fires it.** Sum of jit_generation_time + jit_inlining_time + jit_optimization_time + jit_emission_time is 5% or more of total execution time. Common on OLTP workloads where jit has been on by default since 12.

**Thresholds.** `jit_fraction` = 0.05

**Reads.** `pg_stat_statements`

**Why it matters.** JIT compilation pays for itself on long analytical queries and is pure overhead on short ones. The planner decides from an estimated cost, so an over-estimate on an OLTP statement buys a compilation that takes longer than the query. Five per cent of total execution time spent compiling is a workload where the estimate is wrong more often than it is right.

**How to fix.** Raise `jit_above_cost` (and `jit_inline_above_cost`, `jit_optimize_above_cost`) rather than turning JIT off — the analytical queries that benefit are usually still there. On a purely OLTP database, `jit = off` is defensible.

**False positives and caveats.** PostgreSQL 15 and newer for the `pg_stat_statements` JIT columns.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/jit.html)

---

<a id="pg-qry-015"></a>
### PG-QRY-015 — compute_query_id off
**Priority 150** · Queries and workload visibility · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · PostgreSQL 14+

**What fires it.** compute_query_id is 'off', or 'auto' with no query-id provider loaded. pg_stat_activity.query_id is then null and log correlation to pg_stat_statements is impossible.

**Reads.** `pg_settings`

**Why it matters.** Without a query id, `pg_stat_activity.query_id` is null and `%Q` in `log_line_prefix` produces nothing — so a slow line in the log, a session seen in `pg_stat_activity`, and a row in `pg_stat_statements` cannot be joined to each other except by matching query text by hand.

**How to fix.** `ALTER SYSTEM SET compute_query_id = 'on'; SELECT pg_reload_conf();` and add `%Q` to `log_line_prefix`. The cost is one hash per parse. On `auto`, the id is computed only when an extension asks for it, which `pg_stat_statements` does — so `auto` is sufficient when it is loaded.

**False positives and caveats.** PostgreSQL 14 and newer.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)

---

<a id="pg-qry-016"></a>
### PG-QRY-016 — High-frequency statements returning almost no rows
**Priority 150** · Queries and workload visibility · scope: query · cost 1 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · needs pg_monitor

**What fires it.** At least 1,000,000 calls with fewer than 0.01 rows returned per call. Polling loops and existence checks that should be cached or event-driven.

**Thresholds.** `min_calls` = 1,000,000, `rows_per_call` = 0.01, `top_n` = 10

**Reads.** `pg_stat_statements`

**Why it matters.** A million calls returning under 0.01 rows each is a polling loop, a health check, or an existence test in application code. Each call is individually trivial and collectively costs a measurable share of the server's time, plus a round trip and a snapshot each.

**How to fix.** Replace polling with `LISTEN`/`NOTIFY` or a message queue, cache the answer, or batch the checks. If it is a health check, make it cheaper — `SELECT 1` rather than a query against a real table.

**False positives and caveats.** Some of these are correct and unavoidable (a connection-validation query in a pool). The finding reports the share of total time so you can judge.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)

---

<a id="pg-qry-017"></a>
### PG-QRY-017 — Wait-event snapshot
**Priority 240** · Queries and workload visibility · scope: cluster · cost 0 · source: sql · pass: inventory · effort M / risk low · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** Always: a histogram of wait_event_type and wait_event for active non-background sessions at snapshot time. In deep mode this is sampled three times at one-second intervals.

**Reads.** `pg_stat_activity`

**Why it matters.** The wait-event histogram says what the server is *waiting on* right now, which is the fastest way to classify a performance problem: `Lock` means concurrency, `IO` means storage, `LWLock` means internal contention, `Client` means the application or the network rather than the database, and no wait event means CPU.

**How to fix.** Use it to choose where to look next, not as evidence on its own. `Lock` sends you to PG-LOCK-001; `IO` to PG-WAL-004 and the storage; `Client` to the application.

**False positives and caveats.** **One sample.** A single snapshot can miss a storm and can catch a coincidence. Deep mode samples three times over ten seconds, which is better and still not a profile — `pg_wait_sampling` or `pgsentinel` is the tool for that.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW)

---


## Capacity and growth (`CAP`)

<a id="pg-cap-001"></a>
### PG-CAP-001 — Data or WAL volume 90 percent or more full
**Priority 1** · Capacity and growth · scope: host · cost 0 · source: os · pass: fast · effort M / risk high · since 0.1.0 · needs os

**What fires it.** df of the data directory or of pg_wal (following symlinks) shows 90% or more used. PostgreSQL PANICs when pg_wal cannot extend.

**Thresholds.** `used_fraction` = 0.90

**Reads.** `df of data_directory and pg_wal`

**Why it matters.** PostgreSQL cannot extend a WAL segment on a full volume, and its response to that is a PANIC and shutdown. Recovery from a full `pg_wal` is genuinely difficult, because the usual instinct — delete some WAL — is what makes the cluster unrecoverable.

**How to confirm.** `df -h <data_directory>` and `df -h <data_directory>/pg_wal` — they are frequently different volumes and the WAL one fills first.

**How to fix.** Add space, and separately find out what filled it: an archiving failure (PG-BAK-002), a replication slot (PG-REPL-002), unbounded logs (PG-CAP-007), or ordinary growth (PG-CAP-004). Never delete files from `pg_wal` by hand; `pg_archivecleanup` is the supported way and it needs to know what is safe to remove.

**False positives and caveats.** Needs shell access on the database host: PostgreSQL has no disk-free function. Skipped otherwise, which is itself worth stating.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/diskusage.html)

---

<a id="pg-cap-002"></a>
### PG-CAP-002 — Data or WAL volume 80 percent or more full
**Priority 20** · Capacity and growth · scope: host · cost 0 · source: os · pass: fast · effort M / risk med · since 0.1.0 · needs os

**What fires it.** As CAP-001 at 80% or more and below 90%.

**Thresholds.** `used_fraction` = 0.80, `used_fraction_high` = 0.90

**Reads.** `df of data_directory and pg_wal`

**Why it matters.** Eighty per cent is where the remaining headroom stops being enough to absorb a surprise — a large batch load, a failing archiver, a slot that stops being consumed. It is the point at which adding space is a planned change rather than an incident.

**How to fix.** Add space, or find and remove what is growing. PG-CAP-004 and PG-CAP-005 show where the space actually is.

**False positives and caveats.** Needs shell access.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/diskusage.html)

---

<a id="pg-cap-003"></a>
### PG-CAP-003 — Projected disk-full within 30 days
**Priority 20** · Capacity and growth · scope: host · cost 0 · source: derived · pass: fast · effort M / risk med · since 0.1.0 · needs os

**What fires it.** Growth measured between two saved snapshots projects 100% usage within 30 days. Confidence low with fewer than 7 days between snapshots.

**Thresholds.** `projection_days` = 30, `min_snapshot_days` = 7

**Reads.** `saved snapshots plus CAP-001 inputs`

**Why it matters.** Growth measured between two saved snapshots, projected forwards. It is a straight-line projection and the world is not straight-line — but a projection that says thirty days is a useful prompt to look at the trend properly.

**How to fix.** Confirm the trend against a longer history if you have one, then plan the capacity. `--save` on every run makes the next projection better.

**False positives and caveats.** Needs at least two snapshots. `confidence: low` with fewer than seven days between them, and any step change (a bulk load, a partition drop) invalidates it entirely.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/diskusage.html)

---

<a id="pg-cap-004"></a>
### PG-CAP-004 — Database sizes
**Priority 250** · Capacity and growth · scope: database · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Always: pg_database_size() per database, the cluster total, and the tablespace each database lives in.

**Reads.** `pg_database, pg_database_size()`

**Why it matters.** Database sizes, the cluster total, and which tablespace each database lives in. This is the row that tells you whether the 500 GB is one database or fifty, and whether any of it is on a volume you have not thought about.

**How to fix.** Nothing. Inventory.

**False positives and caveats.** `pg_database_size` includes indexes, TOAST and free space inside pages, so it is bigger than the sum of the live data.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/diskusage.html)

---

<a id="pg-cap-005"></a>
### PG-CAP-005 — Largest 20 relations
**Priority 250** · Capacity and growth · scope: relation · cost 1 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Always, per scanned database: the 20 largest by pg_total_relation_size, split into heap, index and toast bytes.

**Thresholds.** `top_n` = 20

**Reads.** `pg_class, pg_total_relation_size()`

**Why it matters.** The twenty largest relations, split into heap, index and TOAST. The split is the useful part: a table whose index bytes exceed its heap is PG-IDX-013, and one whose TOAST dominates is a table of large values where the bloat estimator (PG-VAC-006) is least reliable.

**How to fix.** Nothing. Inventory, and the starting point for any capacity conversation.

**False positives and caveats.** Per scanned database.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/diskusage.html)

---

<a id="pg-cap-006"></a>
### PG-CAP-006 — Growth since last snapshot
**Priority 250** · Capacity and growth · scope: database · cost 0 · source: derived · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** When a previous snapshot exists: per-database and top-relation growth per day between the two runs.

**Reads.** `saved snapshots`

**Why it matters.** Per-database and per-relation growth per day between two runs. Growth rate is what turns "the database is 400 GB" into "the volume fills in five weeks".

**How to fix.** Nothing. Feed it into PG-CAP-003.

**False positives and caveats.** Needs a previous snapshot from `--save`.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/diskusage.html)

---

<a id="pg-cap-007"></a>
### PG-CAP-007 — Log directory large
**Priority 150** · Capacity and growth · scope: cluster · cost 1 · source: sql · pass: fast · effort S / risk low · since 0.1.0 · PostgreSQL 10+ · needs pg_monitor

**What fires it.** Sum of pg_ls_logdir() sizes is 10 GB or more. Check log_rotation_age, log_rotation_size, log_truncate_on_rotation and log_min_duration_statement.

**Thresholds.** `min_bytes` = 10,737,418,240

**Reads.** `pg_ls_logdir()`

**Why it matters.** On most installations the log directory shares a volume with the data directory, so this is disk the database cannot use. Ten gigabytes of it usually means either rotation is not configured or something is logging far more than intended — `log_statement = 'all'` on a busy server can produce that in hours.

**How to fix.** Set `log_rotation_age`, `log_rotation_size` and `log_truncate_on_rotation`, and check `log_min_duration_statement` and `log_statement` for the cause. Shipping logs off the host is the durable answer.

**False positives and caveats.** Needs `pg_monitor` and is unavailable on most managed platforms.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-logging.html)

---

<a id="pg-cap-008"></a>
### PG-CAP-008 — Temp-file volume high
**Priority 100** · Capacity and growth · scope: database · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0

**What fires it.** pg_stat_database.temp_bytes divided by the statistics window is 50 GB/day or more. Pairs with MEM-004 and QRY-009, and is a disk-space risk while MEM-009 holds.

**Thresholds.** `temp_bytes_per_day` = 53,687,091,200

**Reads.** `pg_stat_database`

**Why it matters.** Fifty gigabytes a day of temporary files is I/O the queries did not need and disk that could fill the volume, since `temp_file_limit` is frequently unlimited (PG-MEM-009). It is the aggregate view of what PG-QRY-009 attributes to individual statements.

**How to fix.** Raise `work_mem` for the roles that spill (PG-MEM-004), or fix the queries PG-QRY-009 names. Set `log_temp_files` so future spills are attributed in the log.

**False positives and caveats.** Cumulative since reset, divided by that window.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-DATABASE-VIEW)

---


## Reliability and operations (`REL`)

<a id="pg-rel-001"></a>
### PG-REL-001 — Major version past end of life
**Priority 20** · Reliability and operations · scope: cluster · cost 0 · source: derived · pass: fast · effort L / risk med · since 0.1.0

**What fires it.** The running major version's end-of-life date in reference/versions.yml is in the past. No security fixes are issued. Escalates to REL-002 at P1 when SEC-003 also fired.

**Reads.** `server_version_num, reference/versions.yml`

**Why it matters.** A major version past end of life receives no fixes at all — not security fixes, not data-corruption fixes. Every bug found after that date stays in this server permanently, and the upgrade only gets harder as the version recedes.

**How to confirm.** `SELECT version();` against https://www.postgresql.org/support/versioning/

**How to fix.** Plan a major upgrade. `pg_upgrade --link` is minutes of downtime rather than hours; logical replication to a new-version instance is near-zero downtime at the cost of considerably more setup. Both need testing against your extensions, which is usually what determines the timeline.

**False positives and caveats.** Depends on `reference/versions.yml`, which is transcribed data with a date on it: XX-META-004 fires when it is stale and this drops to `confidence: low`.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/support/versioning/)

---

<a id="pg-rel-002"></a>
### PG-REL-002 — End-of-life major version reachable from the network
**Priority 1** · Reliability and operations · scope: cluster · cost 0 · source: derived · pass: fast · effort L / risk med · since 0.1.0 · needs superuser

**What fires it.** Derived: REL-001 and SEC-003 both fired. An unpatchable server is reachable from beyond the host.

**Reads.** `REL-001, SEC-003`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** An unpatchable server reachable from beyond its own host is the combination that turns a schedule problem into an exposure. Derived from PG-REL-001 and PG-SEC-003 both firing.

**How to fix.** Reduce the exposure first — it is faster than an upgrade and buys the time to do the upgrade properly. Then upgrade.

**False positives and caveats.** Derived; inherits the caveats of both inputs, including PG-SEC-003's low confidence about what is actually in front of the port.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/support/versioning/)

---

<a id="pg-rel-003"></a>
### PG-REL-003 — Major version within 6 months of end of life
**Priority 100** · Reliability and operations · scope: cluster · cost 0 · source: derived · pass: fast · effort L / risk med · since 0.1.0

**What fires it.** End-of-life date minus today is 180 days or fewer. Major upgrades take planning; start now.

**Thresholds.** `eol_days` = 180

**Reads.** `server_version_num, reference/versions.yml`

**Why it matters.** Six months is roughly the minimum realistic lead time for a major upgrade in an environment that tests it: extension compatibility, application testing, a rehearsal, and a window. Starting at end of life means running unsupported for the duration.

**How to fix.** Start the upgrade project. The first step is inventorying the extensions, because that is usually what blocks.

**False positives and caveats.** Same version-data caveat as PG-REL-001.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/support/versioning/)

---

<a id="pg-rel-004"></a>
### PG-REL-004 — Minor version behind
**Priority 100** · Reliability and operations · scope: cluster · cost 0 · source: derived · pass: fast · effort M / risk low · since 0.1.0

**What fires it.** Two or more minor releases behind the latest for this major, or one behind where the missing release carries a CVE flag in versions.yml. Minor upgrades are a binary swap and a restart.

**Thresholds.** `minors_behind` = 2

**Reads.** `server_version_num, reference/versions.yml`

**Platform.** This check is reported at **P150** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** Minor releases fix bugs, including data-corruption and security bugs, and never change the on-disk format — so a minor upgrade is a binary swap and a restart, with no application testing required. Being several behind means carrying known, fixed bugs for no benefit.

**How to fix.** Schedule the restart. Read the release notes between your version and the latest: they are short, and they occasionally contain a `REINDEX` instruction that matters.

**False positives and caveats.** Depends on `reference/versions.yml`. Managed platforms apply minors on their own schedule, sometimes lagging upstream by months.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/support/versioning/)

---

<a id="pg-rel-005"></a>
### PG-REL-005 — Server restarted within the last 24 hours
**Priority 10** · Reliability and operations · scope: cluster · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** now() - pg_postmaster_start_time() < 24 hours. Every counter-based check is low confidence, and the reason for the restart is itself worth knowing (see REL-011).

**Thresholds.** `uptime_seconds` = 86,400

**Reads.** `pg_postmaster_start_time()`

**Platform.** This check is reported at **P200** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** A restart in the last 24 hours has two consequences for this report. Every counter-based finding covers only that window, so rates are unreliable and "0 index scans since reset" means nothing yet. And the restart itself is worth explaining: a planned restart for a configuration change looks identical from here to a crash, an automatic recovery, or an OOM kill.

**How to confirm.** `SELECT pg_postmaster_start_time();` and the server log around that time.

**How to fix.** Find out which it was. `PG-REL-011` reads the log for crash evidence in the deep pass; the operating system's journal has the rest. If it was planned, check `pending_restart` settings actually took effect (PG-REL-010).

**False positives and caveats.** Every counter-based check in this report should be re-read after the counters have covered a representative period.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/server-start.html)

---

<a id="pg-rel-006"></a>
### PG-REL-006 — Slow-query logging disabled
**Priority 100** · Reliability and operations · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** log_min_duration_statement = -1 and auto_explain is not loaded. 250-1000 ms plus log_min_duration_sample (13+) on busy systems is a workable starting point.

**Reads.** `pg_settings`

**Why it matters.** With no slow-query logging and no `auto_explain`, no statement is ever logged for being slow. When someone reports that the application was slow at 3am, there is nothing on the server to look at: `pg_stat_statements` gives cumulative totals, not the individual slow execution, its parameters, or its timestamp.

**How to fix.** `ALTER SYSTEM SET log_min_duration_statement = '1s'; SELECT pg_reload_conf();` and lower it once you see the volume. On a busy server, `log_min_duration_sample` plus `log_statement_sample_rate` (PostgreSQL 13 and newer) bound the volume while keeping a representative sample.

**False positives and caveats.** Set too low on a busy server this generates enormous logs and becomes its own capacity problem (PG-CAP-007). Start high.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-logging.html)

---

<a id="pg-rel-007"></a>
### PG-REL-007 — Diagnostic logging off
**Priority 150** · Reliability and operations · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** Any of log_checkpoints = off (the pre-15 default), log_lock_waits = off, log_autovacuum_min_duration = -1, log_temp_files = -1, or a log_line_prefix lacking %m or %p. One finding listing which.

**Reads.** `pg_settings`

**Why it matters.** Each of these costs nothing measurable and each one is evidence that will not exist the next time something goes wrong. `log_checkpoints` is how you find out checkpoints were the cause; `log_lock_waits` is how a blocking chain leaves a trace after the session is gone; `log_autovacuum_min_duration` is how you see which tables autovacuum actually works on; `log_temp_files` attributes a spill to a statement; `%m` and `%p` in `log_line_prefix` are what make lines correlatable at all.

**How to fix.** Turn them on: `log_checkpoints = on`, `log_lock_waits = on`, `log_autovacuum_min_duration = '10s'`, `log_temp_files = 0`, and a `log_line_prefix` including `%m [%p] %q%u@%d`.

**False positives and caveats.** `log_checkpoints` defaults to on from PostgreSQL 15. `log_temp_files = 0` logs every spill, which on a spill-heavy server is a lot; start with a size threshold.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-logging.html)

---

<a id="pg-rel-008"></a>
### PG-REL-008 — Extension updates available
**Priority 150** · Reliability and operations · scope: database · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** pg_available_extensions.default_version differs from installed_version for an installed extension. ALTER EXTENSION ... UPDATE applies it.

**Reads.** `pg_available_extensions, pg_extension`

**Why it matters.** An extension has two halves: a shared library on disk and a set of SQL objects in the database. A package upgrade replaces the library; only `ALTER EXTENSION ... UPDATE` replaces the SQL objects. When they are out of step, any function signature, view or default that changed between the two versions is still the old one — which is where "the extension worked yesterday" comes from after a routine package upgrade.

**How to fix.** `ALTER EXTENSION <name> UPDATE;` in each database. Read the extension's own upgrade notes first for anything that needs more than that.

**False positives and caveats.** Some extensions require a restart between the package upgrade and the `ALTER`. Check the extension's documentation.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-createextension.html)

---

<a id="pg-rel-009"></a>
### PG-REL-009 — No evidence of a monitoring agent
**Priority 100** · Reliability and operations · scope: cluster · cost 0 · source: sql · pass: fast · effort M / risk low · since 0.1.0 · PostgreSQL 10+

**What fires it.** No role or application_name matching a known agent (datadog, newrelic, pgwatch, postgres_exporter, prometheus, pganalyze, zabbix, nagios, check_postgres, grafana, percona, pmm, sentry, dynatrace) and no monitoring extension. Confidence low: agents connect intermittently, or via a replica.

**Reads.** `pg_stat_activity, pg_roles, pg_extension`

**Platform.** This check is reported at **P150** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** Every rate in this report is a since-reset average. Without a time series there is no way to tell a problem that started this morning from one that has been there for a year, and no way to see the trend that would have predicted it.

**How to fix.** If there genuinely is no monitoring, that is the finding. If there is, record it under `interview:` so this stops firing and the report stops implying otherwise.

**False positives and caveats.** **Confidence is low by design.** An agent that polls every minute is simply not connected at the instant this ran, and many estates monitor from a replica. This is "no evidence of", not "none exists".

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html)

---

<a id="pg-rel-010"></a>
### PG-REL-010 — Settings changed but awaiting restart
**Priority 100** · Reliability and operations · scope: setting · cost 0 · source: sql · pass: fast · effort M / risk med · since 0.1.0 · PostgreSQL 9.5+

**What fires it.** pg_settings.pending_restart = true for at least one setting. Someone believes a value is live; it is not.

**Reads.** `pg_settings`

**Why it matters.** A setting marked `pending_restart` is in the configuration file and is not in effect. Anyone reading `postgresql.conf`, or an infrastructure-as-code diff, will believe the new value is live. For settings like `shared_buffers`, `max_connections` or `wal_level` the difference is not a performance detail — it changes what the server can do.

**How to confirm.** `SELECT name, setting, reset_val, pending_restart FROM pg_settings WHERE pending_restart;`

**How to fix.** Restart in a planned window, and check the value afterwards rather than assuming. If the restart already happened, something re-wrote the configuration after it.

**False positives and caveats.** Cleared by a restart, so this is a real-time state rather than a history.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/config-setting.html)

---

<a id="pg-rel-011"></a>
### PG-REL-011 — Crash or OOM-kill evidence in the recent server log
**Priority 20** · Reliability and operations · scope: cluster · cost 2 · source: log · pass: deep · effort M / risk med · since 0.1.0 · PostgreSQL 10+ · needs superuser, os

**What fires it.** Any of 'was terminated by signal 9', 'server process ... was terminated by signal', 'database system was not properly shut down', 'terminating any other active server processes' in the recent log. Deep pass only.

**Thresholds.** `scan_bytes` = 52,428,800

**Reads.** `server log`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** "Terminated by signal 9" is the Linux OOM killer, and on PostgreSQL it usually takes the postmaster, which restarts the whole cluster and drops every session. "Database system was not properly shut down" means the last stop was a crash. Either way the cluster ran crash recovery, and the cause — almost always memory (PG-MEM-003) or storage — is still there.

**How to fix.** For an OOM kill: PG-MEM-003, then `vm.overcommit_memory = 2` on Linux so an allocation fails in one backend instead of the kernel choosing a victim. For a crash: the log lines immediately before it are the evidence.

**False positives and caveats.** Deep pass only; needs log access.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/error-message-reporting.html)

---

<a id="pg-rel-012"></a>
### PG-REL-012 — restart_after_crash disabled
**Priority 100** · Reliability and operations · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** restart_after_crash = off with no external supervisor recorded in baseline.supervisor. After any backend crash the cluster stays down until a human intervenes.

**Reads.** `pg_settings`

**Platform.** This check is reported at **P200** on neon. The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** With `restart_after_crash = off`, any backend dying abnormally shuts the whole cluster down and leaves it down, rather than running crash recovery and coming back. That is correct when an external cluster manager — Patroni, repmgr, a Kubernetes operator — needs to make the failover decision itself, and it is an outage waiting to happen when nothing external is watching.

**How to fix.** Record the supervisor in `baseline.supervisor` to silence this if one exists. If none does, `ALTER SYSTEM RESET restart_after_crash;`.

**False positives and caveats.** Patroni sets this deliberately, and setting it back would break Patroni's failover logic. Confirm what manages the cluster before changing it.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-resource.html)

---

<a id="pg-rel-013"></a>
### PG-REL-013 — Logging collector off with a stderr-only destination
**Priority 150** · Reliability and operations · scope: setting · cost 0 · source: sql · pass: fast · effort S / risk low · since 0.1.0

**What fires it.** logging_collector = off and log_destination is stderr only. On a self-managed host outside a container this usually means the log is going nowhere useful. Confidence low.

**Reads.** `pg_settings`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.


**Why it matters.** With the logging collector off and `log_destination = stderr`, the server writes to whatever standard error it inherited. Under systemd that reaches the journal; under a container runtime it reaches the container log; started by hand from a shell that has since closed, it goes nowhere and is unrecoverable.

**How to fix.** Confirm where stderr actually points. If it is nowhere, either enable `logging_collector` or run under a supervisor that captures it. Without logs, PG-CORR-005, PG-REL-011 and PG-REL-014 have nothing to read, and neither will you.

**False positives and caveats.** **Confidence is low**: db-triage cannot see the process supervisor from inside SQL. In a container this configuration is normally correct.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-logging.html)

---

<a id="pg-rel-014"></a>
### PG-REL-014 — Error rate in the server log high
**Priority 100** · Reliability and operations · scope: cluster · cost 2 · source: log · pass: deep · effort M / risk low · since 0.1.0 · PostgreSQL 10+ · needs superuser, os

**What fires it.** 100 or more ERROR lines per hour on average over the last 24 hours, or any FATAL that is not connection-authentication noise. Deep pass; reports the top 5 message classes.

**Thresholds.** `errors_per_hour` = 100, `window_hours` = 24

**Reads.** `server log`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** A hundred errors an hour is a workload that is failing at a rate someone has stopped noticing. The distribution matters more than the count: a hundred an hour of one message is a single broken thing, and a hundred spread across twenty messages is a system nobody is watching.

**How to fix.** Group by message class — the finding reports the top five — and work down. Authentication failures, constraint violations and statement timeouts have entirely different owners.

**False positives and caveats.** Deep pass only; needs log access. Connection-authentication noise is excluded from the FATAL count because a monitoring agent probing a closed port produces a steady stream of it.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/error-message-reporting.html)

---


## Non-default configuration (`CFG`)

<a id="pg-cfg-001"></a>
### PG-CFG-001 — Non-default server settings
**Priority 200** · Non-default configuration · scope: setting · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** pg_settings where source is not 'default' or 'override' and the current value differs from boot_val, excluding an identity and locale noise list. One finding per setting; the renderer collapses these into a summary when there are more than 60.

**Reads.** `pg_settings`

**Why it matters.** This is not a list of problems; it is the answer to "why does this server behave the way it does". Read it after the problems, when something in the ranked list does not make sense. An identity and locale noise list is excluded so that what remains is the settings someone chose.

**How to fix.** Nothing. Review the list against what you expect to be set, and note anything you cannot explain.

**False positives and caveats.** Inventory. `source` and `sourcefile` tell you whether a value came from `postgresql.conf`, from `ALTER SYSTEM` (PG-CFG-004), or from the command line.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/config-setting.html)

---

<a id="pg-cfg-002"></a>
### PG-CFG-002 — Per-database and per-role setting overrides
**Priority 200** · Non-default configuration · scope: setting · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Any row in pg_db_role_setting. Overrides of synchronous_commit, work_mem and statement_timeout especially change how the server behaves for one application without appearing in postgresql.conf.

**Reads.** `pg_db_role_setting, pg_database, pg_roles`

**Why it matters.** Per-database and per-role settings do not appear in `postgresql.conf` and do not show up in `pg_settings` for any other session — so a server that looks correctly configured can behave completely differently for one application. Overrides of `synchronous_commit`, `work_mem`, `statement_timeout` and `search_path` are the ones that most often surprise.

**How to fix.** Nothing. Read them, because they explain findings elsewhere: a `synchronous_commit = off` override is PG-DUR-003 for one role only, and a `search_path` override changes what PG-SEC-013 means for that role.

**False positives and caveats.** Inventory.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/config-setting.html)

---

<a id="pg-cfg-003"></a>
### PG-CFG-003 — Per-relation storage parameters
**Priority 200** · Non-default configuration · scope: relation · cost 1 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Any non-toast relation with a non-null reloptions: fillfactor, autovacuum_*, parallel_workers, toast_tuple_target.

**Reads.** `pg_class`

**Why it matters.** Per-relation storage parameters override the server-wide autovacuum and vacuum settings for that object only. A table that is not being vacuumed the way the global configuration says it should be usually has its answer here.

**How to fix.** Nothing. Cross-reference with PG-VAC-009 and PG-VAC-010.

**False positives and caveats.** Inventory.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-createtable.html#SQL-CREATETABLE-STORAGE-PARAMETERS)

---

<a id="pg-cfg-004"></a>
### PG-CFG-004 — Settings applied via ALTER SYSTEM
**Priority 200** · Non-default configuration · scope: setting · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0 · PostgreSQL 9.4+

**What fires it.** pg_settings.sourcefile ends in postgresql.auto.conf. Distinguishes configuration-management-owned settings from ad-hoc ones applied at a psql prompt.

**Reads.** `pg_settings`

**Why it matters.** `postgresql.auto.conf` is read last, so an `ALTER SYSTEM` value wins over anything configuration management writes into `postgresql.conf` — and configuration management will not see it, will not diff it, and will not restore it when the host is rebuilt. That is how a setting applied during an incident quietly becomes permanent.

**How to fix.** Move anything that should be permanent into managed configuration, and `ALTER SYSTEM RESET` it. Keep `ALTER SYSTEM` for temporary changes you intend to remove.

**False positives and caveats.** Inventory. `ALTER SYSTEM` is the right tool for a change you need now; the problem is only the ones nobody came back for.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/config-setting.html)

---

<a id="pg-cfg-005"></a>
### PG-CFG-005 — Settings differing from the supplied baseline
**Priority 200** · Non-default configuration · scope: setting · cost 0 · source: derived · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Any difference from baseline.settings in .db-triage.yml, or from a --baseline JSONL run. A fleet-consistency tool: it answers 'why is this node different'.

**Reads.** `.db-triage.yml baseline.settings`

**Why it matters.** Fleet consistency. Given a baseline — from `.db-triage.yml` or from another run's JSONL — this answers "why is this node different from the others", which is usually the first question when one node in a fleet misbehaves.

**How to fix.** Reconcile the differences, or update the baseline if this node is the correct one.

**False positives and caveats.** Requires a baseline to compare against; otherwise it does not run.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/config-setting.html)

---


## Environment inventory (`INFO`)

<a id="pg-info-001"></a>
### PG-INFO-001 — Server identity
**Priority 250** · Environment inventory · scope: cluster · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Always: version, server_version_num, start time and uptime, recovery state, system identifier, cluster_name, data_checksums, wal_level, max_connections, shared_buffers, TimeZone and server encoding.

**Reads.** `version(), pg_settings, pg_postmaster_start_time(), pg_is_in_recovery()`

**Why it matters.** Version, role, uptime, and the handful of settings that determine what everything else in the report means. It also carries the worst-case memory figure so that number is available even when RAM is unknown and PG-MEM-003 could not run.

**How to fix.** Nothing. Inventory.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html)

---

<a id="pg-info-002"></a>
### PG-INFO-002 — Host resources
**Priority 250** · Environment inventory · scope: host · cost 0 · source: os · pass: inventory · effort S / risk low · since 0.1.0 · needs os

**What fires it.** CPU count, RAM, swap, storage rotational flag, filesystem of the data directory and container detection, from the host helper; otherwise 'unknown, supply baseline.ram_gb'.

**Reads.** `/proc/meminfo, /proc/cpuinfo, /sys/block`

**Why it matters.** CPU count, RAM, swap, storage type, filesystem and container detection. These are the inputs several checks need and cannot get from SQL; supplying them in `baseline` is the alternative when no shell is available.

**How to fix.** Nothing. Inventory.

**False positives and caveats.** Needs shell access on the database host.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-resource.html)

---

<a id="pg-info-003"></a>
### PG-INFO-003 — Installed extensions
**Priority 250** · Environment inventory · scope: database · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Always, per scanned database: installed extensions with their installed and default versions, flagging those that require shared_preload_libraries.

**Reads.** `pg_extension, pg_available_extensions`

**Why it matters.** Installed extensions with their installed and available versions. Extensions are the most common blocker for a major upgrade and the most common source of a version mismatch after a package update (PG-REL-008).

**How to fix.** Nothing. Inventory.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/sql-createextension.html)

---

<a id="pg-info-004"></a>
### PG-INFO-004 — Replication topology
**Priority 250** · Environment inventory · scope: cluster · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0 · needs pg_monitor

**What fires it.** Always: this node's role, connected standbys with application name, address, state, sync_state and lag; replication slots with type, plugin, activity and retained WAL; subscriptions and publications; synchronous_standby_names. primary_conninfo is reported with any password masked.

**Reads.** `pg_stat_replication, pg_replication_slots, pg_stat_wal_receiver, pg_subscription, pg_publication`

**Why it matters.** The topology: this node's role, its standbys with their lag and sync state, its slots, its publications and subscriptions, and its upstream. Half of the replication findings only make sense against this picture.

**How to fix.** Nothing. Inventory.

**False positives and caveats.** `primary_conninfo` is reported with the password redacted; db-triage never emits a credential.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/warm-standby.html)

---

<a id="pg-info-005"></a>
### PG-INFO-005 — Connection summary
**Priority 250** · Environment inventory · scope: cluster · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0 · PostgreSQL 10+

**What fires it.** Always: connection counts by state and by database, the top 10 application names, the number of distinct client addresses and the oldest backend_start.

**Thresholds.** `top_n` = 10

**Reads.** `pg_stat_activity`

**Why it matters.** Connection counts by state and by database, the top application names, and the oldest connection. `application_name` is the field that makes every other diagnostic in this report better, and "(none)" dominating this list is itself worth fixing.

**How to fix.** Set `application_name` in your connection strings.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW)

---

<a id="pg-info-006"></a>
### PG-INFO-006 — Autovacuum configuration
**Priority 250** · Environment inventory · scope: setting · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Always: every autovacuum and vacuum setting with its value and source, so the VAC and WRAP findings can be read against the configuration that produced them.

**Reads.** `pg_settings`

**Why it matters.** Every autovacuum and vacuum setting with its value, plus the dirty-page throughput they imply. The VAC and WRAP findings should be read against this: they are consequences of these numbers.

**How to fix.** Nothing. Inventory.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/runtime-config-autovacuum.html)

---

<a id="pg-info-007"></a>
### PG-INFO-007 — Object counts
**Priority 250** · Environment inventory · scope: database · cost 1 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Always, per scanned database: pg_class counts by relkind, schema count, partition count and user function count.

**Reads.** `pg_class, pg_namespace, pg_proc`

**Why it matters.** Object counts by kind. Useful as a shape check — a database with 40,000 indexes and 800 tables is telling you something — and as the input to PG-SCHEMA-010.

**How to fix.** Nothing. Inventory.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/diskusage.html)

---

<a id="pg-info-008"></a>
### PG-INFO-008 — Checkpoint, background writer, WAL and archiver rates
**Priority 250** · Environment inventory · scope: cluster · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Always: per-hour rates since the statistics reset for checkpoints (timed and requested), buffers written, WAL bytes and records (14+), and archived and failed WAL files, each with the reset timestamp it is measured from.

**Reads.** `pg_stat_bgwriter / pg_stat_checkpointer, pg_stat_wal, pg_stat_archiver`

**Why it matters.** Checkpoint, background writer, WAL and archiver rates, each with the reset timestamp it is measured from. This is where you check whether the WAL and checkpoint findings are describing a busy hour or a busy year.

**How to fix.** Nothing. Inventory.

**False positives and caveats.** `pg_stat_wal` is PostgreSQL 14 and newer; PostgreSQL 17 moved the checkpoint counters to `pg_stat_checkpointer`. The check reads whichever exists.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html)

---

<a id="pg-info-009"></a>
### PG-INFO-009 — Roles summary
**Priority 250** · Environment inventory · scope: role · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Always: counts of total, login-capable, superuser, replication, createrole, createdb and bypassrls roles, with platform-owned roles counted separately.

**Reads.** `pg_roles`

**Why it matters.** Role counts by attribute, with predefined and platform-owned roles counted separately so the numbers describe your roles rather than PostgreSQL's.

**How to fix.** Nothing. Inventory.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/role-attributes.html)

---

<a id="pg-info-010"></a>
### PG-INFO-010 — pg_hba summary
**Priority 250** · Environment inventory · scope: cluster · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0 · PostgreSQL 10+ · needs superuser

**What fires it.** One row per (connection type, authentication method) with the rule count, the line numbers, and the addresses, databases and roles matched. Skipped without the privilege to read pg_hba_file_rules; SEC-012 then says so.

**Reads.** `pg_hba_file_rules`

**Platform.** This check is **not run** on rds, aurora, cloudsql, azure, supabase, neon, crunchy, timescale, alloydb, heroku (the finding is dropped and listed in XX-META-001 with reason `platform`). The reason for each is in [reference/platforms.md](platforms.md#per-platform-adaptations), and it is carried into the report next to this finding.

**Why it matters.** `pg_hba.conf` grouped by connection type and authentication method, with line numbers. The shape of the file is usually more informative than any individual rule.

**How to fix.** Nothing. Inventory.

**False positives and caveats.** Needs superuser; skipped otherwise, and PG-SEC-012 says so.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html)

---

<a id="pg-info-011"></a>
### PG-INFO-011 — Tablespaces
**Priority 250** · Environment inventory · scope: cluster · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Always: tablespace names, owners, locations and sizes. A non-default tablespace is usually a different volume with its own free space and its own failure mode.

**Reads.** `pg_tablespace, pg_tablespace_location(), pg_tablespace_size()`

**Why it matters.** Tablespaces with their locations and sizes. A tablespace outside the data directory is usually a different volume with its own free space and its own failure mode — and it must exist and be mounted before the server will start.

**How to fix.** Nothing. Inventory.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/manage-ag-tablespaces.html)

---

<a id="pg-info-012"></a>
### PG-INFO-012 — Statistics window
**Priority 250** · Environment inventory · scope: cluster · cost 0 · source: sql · pass: inventory · effort S / risk low · since 0.1.0

**What fires it.** Always: the earliest stats_reset across the statistics views and the server uptime, expressed as 'counters cover N days'. Every rate in this report depends on it, so it is printed near the top.

**Reads.** `pg_stat_database, pg_stat_bgwriter, pg_postmaster_start_time()`

**Why it matters.** The statistics window: how long the counters have been accumulating. Every rate in this report depends on it, which is why it is printed near the top. A window under 24 hours makes every counter-based finding low confidence; a window of years hides recent change inside a long average.

**How to fix.** Nothing. Inventory, and the first thing to read.

**Further reading.** [PostgreSQL documentation](https://www.postgresql.org/docs/current/monitoring-stats.html)

---

