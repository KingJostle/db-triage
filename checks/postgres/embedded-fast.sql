-- db-triage embedded fast pass (PostgreSQL). SOURCE OF THE SKILL.md BLOCK.
--
-- WHY THIS FILE EXISTS SEPARATELY FROM checks/postgres/checks/*.sql.
-- The canonical per-check files build a long, specific `details` string for
-- each finding, which is right for the full catalog and far too large to embed
-- in a skill file that must stay under 900 lines. This file covers the same
-- highest-priority checks in a compact form: one statement per catalog family,
-- with the measured values still interpolated into `details`.
--
-- bin/build.py enforces the relationship: every `-- CHECK <id> P<n> <title>`
-- marker below must match a registry row exactly on id, priority and title, and
-- every check in the required embedded set must have a marker here. A renamed
-- title or a changed priority fails the build.
--
-- Read-only. Runs on PostgreSQL 11 through 17 without version gating: every
-- setting is read through pg_settings (which simply has no row for a setting
-- that does not exist on this version) rather than through current_setting().
--
-- Output columns, on every statement: check_id, scope, object, details,
-- evidence_json, confidence.

\echo '@@CHECK-BLOCK settings-boolean'
-- CHECK PG-DUR-001 P1 fsync disabled
-- CHECK PG-DUR-002 P1 full_page_writes disabled
-- CHECK PG-CORR-002 P1 zero_damaged_pages enabled
-- CHECK PG-CORR-003 P1 ignore_checksum_failure enabled
-- CHECK PG-WRAP-005 P5 Autovacuum disabled
-- CHECK PG-WRAP-006 P5 Statistics tracking disabled (autovacuum blind)
-- CHECK PG-DUR-003 P10 synchronous_commit off cluster-wide
-- CHECK PG-BAK-006 P20 wal_level = minimal
SELECT r.check_id::text                          AS check_id,
       'setting'::text                           AS scope,
       s.name::text                              AS object,
       format('%s = %s (default %s), set in %s%s. %s',
              s.name, s.setting, s.boot_val, s.source,
              coalesce(' at ' || s.sourcefile || ':' || s.sourceline::text, ''), r.why) AS details,
       json_build_object('setting', s.name, 'value', s.setting, 'default', s.boot_val,
                         'source', s.source, 'sourcefile', s.sourcefile)::text AS evidence_json,
       'high'::text                              AS confidence
FROM pg_settings s
JOIN (VALUES
  ('fsync', 'off', 'PG-DUR-001', 'The server never flushes WAL or data pages to durable storage. An operating-system crash or power loss can leave the cluster unrecoverable - this is cluster loss, not the loss of recent transactions.'),
  ('full_page_writes', 'off', 'PG-DUR-002', 'A page torn by a crash mid-write cannot be reconstructed from WAL. Only safe where the filesystem guarantees atomic 8 kB writes (ZFS does; ext4, xfs and most cloud block devices do not). Confirm the filesystem.'),
  ('zero_damaged_pages', 'on', 'PG-CORR-002', 'A page that fails header validation is replaced with zeros on read and the query continues with a WARNING. Every row on that page silently disappears. This is a supervised-salvage setting, not a running-server setting.'),
  ('ignore_checksum_failure', 'on', 'PG-CORR-003', 'A page whose checksum does not match is used anyway. Corrupt data then flows into results, into indexes built from it, and into every backup and replica taken afterwards.'),
  ('autovacuum', 'off', 'PG-WRAP-005', 'Dead tuples are never reclaimed and planner statistics are never refreshed. Only the emergency anti-wraparound path will vacuum, which is the sole reason this is P5 rather than P1.'),
  ('track_counts', 'off', 'PG-WRAP-006', 'Autovacuum cannot see dead tuples or modified rows, so nothing but the anti-wraparound path will ever vacuum and ANALYZE will never run automatically.'),
  ('synchronous_commit', 'off', 'PG-DUR-003', 'COMMIT returns before the WAL record is flushed, so a crash loses roughly the last three wal_writer_delay intervals of committed transactions. Bounded, silent, and often deliberate.'),
  ('wal_level', 'minimal', 'PG-BAK-006', 'Minimal WAL omits what a standby or an archive recovery needs: no streaming replication, no online base backup and no point-in-time recovery are possible. Raising it requires a restart.')
) r(setting_name, bad_value, check_id, why) ON r.setting_name = s.name AND s.setting = r.bad_value;

\echo '@@CHECK-BLOCK wraparound'
-- CHECK PG-WRAP-001 P1 Transaction ID or MultiXact wraparound imminent
-- CHECK PG-WRAP-002 P10 Transaction ID or MultiXact age high
-- CHECK PG-WRAP-007 P20 autovacuum_freeze_max_age raised to 1 billion or more
WITH d AS (
  SELECT datname, age(datfrozenxid) AS xid_age, mxid_age(datminmxid) AS mxid_age,
         greatest(age(datfrozenxid), mxid_age(datminmxid)) AS worst,
         pg_database_size(oid) AS bytes
  FROM pg_database
)
SELECT CASE WHEN d.worst >= 1500000000 THEN 'PG-WRAP-001' ELSE 'PG-WRAP-002' END::text AS check_id,
       'database'::text AS scope,
       d.datname::text  AS object,
       format('age(datfrozenxid) = %s, mxid_age(datminmxid) = %s; worst is %s%% of the 2,147,483,648 XID limit (P1 at 1,500,000,000, P10 at 1,000,000,000). autovacuum_freeze_max_age = %s. Database size %s. At the limit the cluster refuses new write transactions until an offline VACUUM completes.',
              to_char(d.xid_age, 'FM999,999,999,999'), to_char(d.mxid_age, 'FM999,999,999,999'),
              round(100.0 * d.worst / 2147483648.0, 1)::text,
              (SELECT setting FROM pg_settings WHERE name = 'autovacuum_freeze_max_age'),
              pg_size_pretty(d.bytes)) AS details,
       json_build_object('xid_age', d.xid_age, 'mxid_age', d.mxid_age, 'worst_age', d.worst,
                         'pct_of_limit', round(100.0 * d.worst / 2147483648.0, 2),
                         'database_bytes', d.bytes)::text AS evidence_json,
       'high'::text AS confidence
FROM d WHERE d.worst >= 1000000000
UNION ALL
SELECT 'PG-WRAP-007', 'setting', s.name,
       format('%s = %s (default %s), set in %s. The forced anti-wraparound vacuum starts that much later, leaving %s XIDs of headroom before the 2,147,483,648 limit instead of the %s the default gives.',
              s.name, to_char(s.setting::bigint, 'FM999,999,999,999'),
              to_char(s.boot_val::bigint, 'FM999,999,999,999'), s.source,
              to_char(2147483648::bigint - s.setting::bigint, 'FM999,999,999,999'),
              to_char(2147483648::bigint - s.boot_val::bigint, 'FM999,999,999,999')),
       json_build_object('setting', s.name, 'value', s.setting::bigint, 'default', s.boot_val::bigint)::text,
       'high'
FROM pg_settings s
WHERE s.name IN ('autovacuum_freeze_max_age', 'autovacuum_multixact_freeze_max_age')
  AND s.setting::bigint >= 1000000000;

\echo '@@CHECK-BLOCK backup-archiving'
-- CHECK PG-BAK-001 P1 No WAL archiving: point-in-time recovery impossible
-- CHECK PG-BAK-002 P1 archive_command is failing
-- CHECK PG-BAK-004 P1 archive_command is a no-op (WAL archived to nowhere)
-- CHECK PG-BAK-005 P5 Archiving enabled but no archive_command or archive_library set
SELECT 'PG-BAK-001'::text AS check_id, 'setting'::text AS scope, 'archive_mode'::text AS object,
       format('archive_mode = off on a primary. Without archived WAL there is no point-in-time recovery: the recoverable states are whatever full backups exist, and every transaction after the newest one is unrecoverable. wal_level = %s, cluster size %s. A pg_dump is a logical export, not PITR. On a managed platform the provider archives outside PostgreSQL - confirm retention and PITR in the console instead.',
              (SELECT setting FROM pg_settings WHERE name = 'wal_level'),
              pg_size_pretty((SELECT sum(pg_database_size(oid)) FROM pg_database))) AS details,
       json_build_object('archive_mode', 'off',
                         'wal_level', (SELECT setting FROM pg_settings WHERE name = 'wal_level'))::text AS evidence_json,
       'medium'::text AS confidence
WHERE (SELECT setting FROM pg_settings WHERE name = 'archive_mode') = 'off' AND NOT pg_is_in_recovery()
UNION ALL
SELECT 'PG-BAK-002', 'cluster', NULL,
       format('pg_stat_archiver reports %s failures; the last was at %s (%s ago) on WAL file %s, and the last success was %s. WAL segments cannot be recycled while archiving fails: pg_wal grows until the volume fills and the server PANICs.',
              to_char(a.failed_count, 'FM999,999,999,999'), a.last_failed_time,
              justify_interval(date_trunc('second', now() - a.last_failed_time)),
              coalesce(a.last_failed_wal, 'unknown'),
              coalesce(a.last_archived_time::text, 'never')),
       json_build_object('failed_count', a.failed_count, 'archived_count', a.archived_count,
                         'last_failed_time', a.last_failed_time, 'last_failed_wal', a.last_failed_wal,
                         'last_archived_time', a.last_archived_time)::text,
       'high'
FROM pg_stat_archiver a
WHERE a.failed_count > 0 AND a.last_failed_time > coalesce(a.last_archived_time, '-infinity'::timestamptz)
UNION ALL
SELECT 'PG-BAK-004', 'setting', 'archive_command',
       format('archive_mode = %s but archive_command is %s, which succeeds without storing anything. pg_stat_archiver reports %s segments archived and %s failures, so every counter looks healthy while no WAL is kept and PITR is impossible.',
              (SELECT setting FROM pg_settings WHERE name = 'archive_mode'), quote_literal(s.setting),
              (SELECT archived_count::text FROM pg_stat_archiver),
              (SELECT failed_count::text FROM pg_stat_archiver)),
       json_build_object('archive_command', s.setting)::text, 'high'
FROM pg_settings s
WHERE s.name = 'archive_command' AND NOT pg_is_in_recovery()
  AND (SELECT setting FROM pg_settings WHERE name = 'archive_mode') <> 'off'
  AND (s.setting ~ '^\s*(/bin/|/usr/bin/)?(true|:)\s*$' OR s.setting ~ '^\s*exit\s+0\s*$'
    OR s.setting ~ '^\s*cd\s+\.\s*$' OR s.setting ~ '^\s*#' OR s.setting ~ '>\s*/dev/null\s*$')
UNION ALL
SELECT 'PG-BAK-005', 'setting', 'archive_command',
       format('archive_mode = %s but neither archive_command nor archive_library is set. Every completed WAL segment stays in pg_wal waiting for an archiver that will never succeed, and the log fills with warnings.',
              (SELECT setting FROM pg_settings WHERE name = 'archive_mode')),
       json_build_object('archive_mode', (SELECT setting FROM pg_settings WHERE name = 'archive_mode'))::text, 'high'
WHERE NOT pg_is_in_recovery()
  AND (SELECT setting FROM pg_settings WHERE name = 'archive_mode') <> 'off'
  AND coalesce(nullif(trim((SELECT setting FROM pg_settings WHERE name = 'archive_command')), ''), '') = ''
  AND coalesce(nullif(trim(coalesce((SELECT setting FROM pg_settings WHERE name = 'archive_library'), '')), ''), '') = '';

\echo '@@CHECK-BLOCK corruption-checksums'
-- CHECK PG-CORR-001 P1 Data checksum failures reported
-- CHECK PG-CORR-004 P50 Data checksums disabled
SELECT 'PG-CORR-001'::text AS check_id, 'database'::text AS scope,
       coalesce(d.datname, 'shared objects')::text AS object,
       format('pg_stat_database reports %s checksum failures for %s; the most recent was at %s. The storage layer returned a page whose checksum did not match its contents. This is a report from the server, not an inference.',
              to_char(d.checksum_failures, 'FM999,999,999,999'),
              coalesce('database ' || d.datname, 'shared catalogs'), d.checksum_last_failure) AS details,
       json_build_object('checksum_failures', d.checksum_failures,
                         'checksum_last_failure', d.checksum_last_failure, 'datname', d.datname)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_database d WHERE d.checksum_failures > 0
UNION ALL
SELECT 'PG-CORR-004', 'cluster', 'data_checksums',
       format('data_checksums = off. Pages carry no checksum, so storage corruption is detected only when it happens to break a structure PostgreSQL validates; otherwise a flipped bit returns a wrong answer rather than an error. Cluster holds %s. Enabling needs pg_checksums with the cluster shut down (PostgreSQL 12+) or a dump and reload.',
              pg_size_pretty((SELECT sum(pg_database_size(oid)) FROM pg_database))),
       json_build_object('data_checksums', 'off',
                         'cluster_bytes', (SELECT sum(pg_database_size(oid)) FROM pg_database))::text, 'high'
WHERE (SELECT setting FROM pg_settings WHERE name = 'data_checksums') = 'off';

\echo '@@CHECK-BLOCK replication'
-- CHECK PG-REPL-001 P1 Synchronous replication configured but no synchronous standby connected
-- CHECK PG-REPL-002 P1 Inactive replication slot retaining more than 10 GB of WAL
-- CHECK PG-REPL-003 P5 Inactive replication slot retaining more than 1 GB of WAL
-- CHECK PG-REPL-004 P50 Inactive replication slot
-- CHECK PG-REPL-006 P5 Streaming replica lagging badly
SELECT 'PG-REPL-001'::text AS check_id, 'cluster'::text AS scope,
       'synchronous_standby_names'::text AS object,
       format('synchronous_standby_names = %s and synchronous_commit = %s, but no connected standby has sync_state sync or quorum. Every commit that needs a synchronous confirmation is hanging right now. Connected standbys: %s.',
              quote_literal((SELECT setting FROM pg_settings WHERE name = 'synchronous_standby_names')),
              (SELECT setting FROM pg_settings WHERE name = 'synchronous_commit'),
              coalesce((SELECT string_agg(coalesce(nullif(application_name, ''), 'unnamed') || ' (' || sync_state || ')', '; ')
                        FROM pg_stat_replication), 'none')) AS details,
       json_build_object('synchronous_standby_names', (SELECT setting FROM pg_settings WHERE name = 'synchronous_standby_names'),
                         'connected_standbys', (SELECT count(*) FROM pg_stat_replication))::text AS evidence_json,
       'high'::text AS confidence
WHERE NOT pg_is_in_recovery()
  AND coalesce(nullif(trim((SELECT setting FROM pg_settings WHERE name = 'synchronous_standby_names')), ''), '') <> ''
  AND (SELECT setting FROM pg_settings WHERE name = 'synchronous_commit') NOT IN ('off', 'local')
  AND NOT EXISTS (SELECT 1 FROM pg_stat_replication WHERE sync_state IN ('sync', 'quorum'))
UNION ALL
SELECT CASE WHEN coalesce(r.retained, 0) >= 10737418240 THEN 'PG-REPL-002'
            WHEN coalesce(r.retained, 0) >= 1073741824  THEN 'PG-REPL-003'
            ELSE 'PG-REPL-004' END,
       'slot', r.slot_name,
       format('Replication slot %s (%s%s) is inactive and is holding back %s of WAL (P1 at 10 GB, P5 at 1 GB). restart_lsn %s against current %s. Until it is consumed or dropped the WAL it pins cannot be recycled or archived away; max_slot_wal_keep_size = %s.',
              r.slot_name, r.slot_type, coalesce(', plugin ' || r.plugin, ''),
              coalesce(pg_size_pretty(r.retained), 'an unknown amount'),
              coalesce(r.restart_lsn::text, 'none'), r.cur::text,
              coalesce((SELECT setting FROM pg_settings WHERE name = 'max_slot_wal_keep_size'), 'n/a before PostgreSQL 13')),
       json_build_object('slot_name', r.slot_name, 'slot_type', r.slot_type, 'plugin', r.plugin,
                         'active', false, 'retained_bytes', r.retained)::text, 'high'
FROM (SELECT s.slot_name, s.slot_type, s.plugin, s.restart_lsn,
             CASE WHEN pg_is_in_recovery() THEN pg_last_wal_receive_lsn() ELSE pg_current_wal_lsn() END AS cur,
             CASE WHEN s.restart_lsn IS NULL THEN NULL
                  ELSE pg_wal_lsn_diff(CASE WHEN pg_is_in_recovery() THEN pg_last_wal_receive_lsn()
                                            ELSE pg_current_wal_lsn() END, s.restart_lsn)::bigint END AS retained
      FROM pg_replication_slots s WHERE NOT s.active) r
UNION ALL
SELECT 'PG-REPL-006', 'replica', coalesce(nullif(rr.application_name, ''), 'pid:' || rr.pid::text),
       format('Standby %s at %s is %s behind on replay and %s behind in time (thresholds 1 GB / 5 min). state %s, sync_state %s. A failover now loses everything after its replay position.',
              coalesce(nullif(rr.application_name, ''), 'unnamed'), coalesce(host(rr.client_addr), 'local socket'),
              pg_size_pretty(greatest(pg_wal_lsn_diff(rr.sent_lsn, rr.replay_lsn), 0)::bigint),
              coalesce(rr.replay_lag::text, 'an unknown interval'), rr.state, rr.sync_state),
       json_build_object('application_name', rr.application_name, 'state', rr.state,
                         'lag_bytes', greatest(pg_wal_lsn_diff(rr.sent_lsn, rr.replay_lsn), 0)::bigint,
                         'replay_lag_seconds', round(extract(epoch FROM rr.replay_lag))::bigint)::text, 'high'
FROM pg_stat_replication rr
WHERE greatest(pg_wal_lsn_diff(rr.sent_lsn, rr.replay_lsn), 0) >= 1073741824
   OR rr.replay_lag >= interval '5 minutes';

\echo '@@CHECK-BLOCK sessions-locks'
-- CHECK PG-LOCK-001 P10 Blocking chain: session blocked more than 5 minutes
-- CHECK PG-LOCK-003 P10 Idle in transaction for more than 1 hour
-- CHECK PG-LOCK-005 P20 Client transaction open for more than 1 hour
-- CHECK PG-LOCK-006 P5 Orphaned prepared transactions
-- CHECK PG-VAC-005 P50 Old transaction horizon holding back vacuum
-- CHECK PG-CONN-001 P5 Connections at 90 percent or more of max_connections
SELECT 'PG-LOCK-001'::text AS check_id, 'session'::text AS scope, ('pid:' || a.pid)::text AS object,
       format('pid %s (%s / %s) has been blocked for %s waiting on %s, by pid(s) %s. Root blocker query: %s',
              a.pid, coalesce(nullif(a.usename, ''), '?'), coalesce(nullif(a.application_name, ''), 'no application_name'),
              justify_interval(date_trunc('second', now() - a.state_change)),
              coalesce(a.wait_event_type || '/' || a.wait_event, 'a lock'),
              array_to_string(pg_blocking_pids(a.pid), ', '),
              coalesce((SELECT left(regexp_replace(b.query, '\s+', ' ', 'g'), 200) FROM pg_stat_activity b
                        WHERE b.pid = (pg_blocking_pids(a.pid))[1]), 'unknown')) AS details,
       json_build_object('blocked_pid', a.pid, 'blocking_pids', pg_blocking_pids(a.pid),
                         'blocked_seconds', round(extract(epoch FROM now() - a.state_change))::bigint)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_activity a
WHERE cardinality(pg_blocking_pids(a.pid)) > 0 AND now() - a.state_change >= interval '5 minutes'
UNION ALL
SELECT CASE WHEN a.state LIKE 'idle in transaction%' THEN 'PG-LOCK-003' ELSE 'PG-LOCK-005' END,
       'session', 'pid:' || a.pid::text,
       format('pid %s (%s / %s, database %s) has been in state "%s" with a transaction open for %s. It holds its locks and pins the cluster xmin horizon at age %s, so vacuum cannot clean past it in any database. Last statement: %s',
              a.pid, coalesce(nullif(a.usename, ''), '?'), coalesce(nullif(a.application_name, ''), 'no application_name'),
              coalesce(a.datname, '?'), a.state,
              justify_interval(date_trunc('second', now() - a.xact_start)),
              coalesce(age(a.backend_xmin)::text, 'none held'),
              left(regexp_replace(coalesce(a.query, ''), '\s+', ' ', 'g'), 200)),
       json_build_object('pid', a.pid, 'state', a.state, 'datname', a.datname,
                         'xact_seconds', round(extract(epoch FROM now() - a.xact_start))::bigint,
                         'backend_xmin_age', CASE WHEN a.backend_xmin IS NULL THEN NULL ELSE age(a.backend_xmin) END)::text,
       'high'
FROM pg_stat_activity a
WHERE a.backend_type = 'client backend' AND a.xact_start IS NOT NULL
  AND now() - a.xact_start >= interval '1 hour'
  AND coalesce(a.query, '') !~* '^\s*(VACUUM|ANALYZE|CREATE\s+(UNIQUE\s+)?INDEX|REINDEX|CLUSTER|COPY)'
  AND coalesce(a.application_name, '') !~* '(basebackup|pg_dump|pg_restore|db-triage)'
UNION ALL
SELECT 'PG-LOCK-006', 'cluster', p.gid,
       format('Prepared transaction "%s" in database %s, owned by %s, prepared %s ago, xmin age %s. It holds its locks and the xmin horizon until it is committed or rolled back: it survives restarts, does not appear in pg_stat_activity, and nothing will ever time it out.',
              p.gid, p.database, p.owner,
              justify_interval(date_trunc('second', now() - p.prepared)),
              to_char(age(p.transaction), 'FM999,999,999,999')),
       json_build_object('gid', p.gid, 'database', p.database, 'owner', p.owner,
                         'prepared', p.prepared, 'xid_age', age(p.transaction))::text, 'high'
FROM pg_prepared_xacts p WHERE now() - p.prepared >= interval '1 hour'
UNION ALL
SELECT 'PG-VAC-005', 'cluster', NULL,
       format('The oldest xmin horizon in the cluster is %s XIDs old (threshold 50,000,000), held by %s. Vacuum cannot remove any row version newer than that horizon in any database.',
              to_char(h.xmin_age, 'FM999,999,999,999'), h.src),
       json_build_object('xmin_age', h.xmin_age, 'source', h.src)::text, 'high'
FROM (
  SELECT age(a.backend_xmin) AS xmin_age,
         format('backend pid %s (%s)', a.pid, coalesce(nullif(a.application_name, ''), '?')) AS src
  FROM pg_stat_activity a WHERE a.backend_xmin IS NOT NULL AND a.pid <> pg_backend_pid()
  UNION ALL
  SELECT greatest(age(s.xmin), age(s.catalog_xmin)), format('replication slot %s', s.slot_name)
  FROM pg_replication_slots s WHERE s.xmin IS NOT NULL OR s.catalog_xmin IS NOT NULL
  UNION ALL
  SELECT age(p.transaction), format('prepared transaction %s', p.gid) FROM pg_prepared_xacts p
) h
WHERE h.xmin_age >= 50000000
UNION ALL
SELECT 'PG-CONN-001', 'cluster', 'max_connections',
       format('%s client backends against a usable ceiling of %s (max_connections %s less %s reserved): %s%%. The next connection past the ceiling is refused with "FATAL: sorry, too many clients already".',
              c.n, c.ceiling, c.maxc, c.maxc - c.ceiling,
              round(100.0 * c.n / nullif(c.ceiling, 0), 1)::text),
       json_build_object('client_backends', c.n, 'usable_ceiling', c.ceiling, 'max_connections', c.maxc)::text, 'high'
FROM (SELECT (SELECT count(*) FROM pg_stat_activity WHERE backend_type = 'client backend') AS n,
             (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') AS maxc,
             (SELECT setting::int FROM pg_settings WHERE name = 'max_connections')
             - coalesce((SELECT setting::int FROM pg_settings WHERE name = 'superuser_reserved_connections'), 3)
             - coalesce((SELECT setting::int FROM pg_settings WHERE name = 'reserved_connections'), 0) AS ceiling) c
WHERE c.n >= 0.90 * c.ceiling;

\echo '@@CHECK-BLOCK schema-index'
-- CHECK PG-SCHEMA-001 P5 Sequence or integer key at 90 percent or more of its range
-- CHECK PG-IDX-001 P50 Invalid index
-- CHECK PG-MEM-001 P20 shared_buffers at the shipped default
-- CHECK PG-REL-005 P10 Server restarted within the last 24 hours
SELECT 'PG-SCHEMA-001'::text AS check_id, 'relation'::text AS scope,
       format('%I.%I.%I', current_database(), s.schemaname, s.sequencename)::text AS object,
       format('Sequence %s.%s is at %s of a maximum of %s (%s%%). When it runs out every INSERT that calls nextval fails with "nextval: reached maximum value" or "integer out of range". Widening an int4 key to bigint rewrites the whole table and every index on it.',
              s.schemaname, s.sequencename,
              to_char(s.last_value, 'FM999,999,999,999,999,999'),
              to_char(s.max_value, 'FM999,999,999,999,999,999'),
              round(100.0 * s.last_value / nullif(s.max_value, 0), 1)::text) AS details,
       json_build_object('schema', s.schemaname, 'sequence', s.sequencename,
                         'last_value', s.last_value, 'max_value', s.max_value)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_sequences s
WHERE s.last_value IS NOT NULL AND NOT s.cycle AND s.last_value >= 0.90 * s.max_value
UNION ALL
SELECT 'PG-IDX-001', 'index', format('%I.%I.%I', current_database(), n.nspname, ic.relname),
       format('Index %s on %s.%s is invalid (indisvalid = %s, indisready = %s), size %s. It is maintained on every write, never used by the planner, and if unique it still rejects conflicting inserts. Almost always the debris of a failed CREATE INDEX CONCURRENTLY. Definition: %s',
              ic.relname, n.nspname, tc.relname, i.indisvalid, i.indisready,
              pg_size_pretty(pg_relation_size(i.indexrelid)), pg_get_indexdef(i.indexrelid)),
       json_build_object('schema', n.nspname, 'table', tc.relname, 'index', ic.relname,
                         'indisvalid', i.indisvalid, 'indisready', i.indisready,
                         'index_bytes', pg_relation_size(i.indexrelid))::text, 'high'
FROM pg_index i
JOIN pg_class ic ON ic.oid = i.indexrelid
JOIN pg_class tc ON tc.oid = i.indrelid
JOIN pg_namespace n ON n.oid = ic.relnamespace
WHERE (NOT i.indisvalid OR NOT i.indisready)
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
UNION ALL
SELECT 'PG-MEM-001', 'setting', 'shared_buffers',
       format('shared_buffers = %s (the shipped default), source %s, against a cluster holding %s. The default is sized so the server starts anywhere, not so it performs here. Changing it requires a restart. effective_cache_size = %s.',
              pg_size_pretty(s.setting::bigint * 8192), s.source,
              pg_size_pretty((SELECT sum(pg_database_size(oid)) FROM pg_database)),
              (SELECT setting::bigint * 8192 FROM pg_settings WHERE name = 'effective_cache_size')::text),
       json_build_object('shared_buffers_bytes', s.setting::bigint * 8192, 'source', s.source,
                         'cluster_bytes', (SELECT sum(pg_database_size(oid)) FROM pg_database))::text, 'high'
FROM pg_settings s WHERE s.name = 'shared_buffers' AND s.setting::bigint * 8192 <= 134217728
UNION ALL
SELECT 'PG-REL-005', 'cluster', NULL,
       format('The postmaster started at %s, %s ago. Every counter-based finding below covers only that window, so rates are unreliable and "0 scans since reset" means nothing yet. The restart itself is worth explaining: a planned restart looks identical from here to a crash, an automatic recovery or an OOM kill. %s setting(s) are pending_restart.',
              pg_postmaster_start_time(),
              justify_interval(date_trunc('second', now() - pg_postmaster_start_time())),
              (SELECT count(*) FROM pg_settings WHERE pending_restart)),
       json_build_object('postmaster_start_time', pg_postmaster_start_time(),
                         'uptime_seconds', round(extract(epoch FROM now() - pg_postmaster_start_time()))::bigint)::text, 'high'
WHERE now() - pg_postmaster_start_time() < interval '24 hours';

\echo '@@CHECK-BLOCK archiving-queue'
-- CHECK PG-BAK-003 P1 WAL archiving stalled
-- PostgreSQL 12 and newer only: pg_ls_archive_statusdir() does not exist before
-- that, so this statement is skipped rather than run on older servers.
SELECT (current_setting('server_version_num')::int >= 120000 AND NOT pg_is_in_recovery()) AS emb_bak003 \gset
\if :emb_bak003
SELECT 'PG-BAK-003'::text AS check_id, 'cluster'::text AS scope, NULL::text AS object,
       format('%s WAL segments are queued for archiving in pg_wal/archive_status (threshold 10). Last archived %s at %s; current WAL position is %s. archive_timeout = %s. The queue drains only as fast as the archive command succeeds, and pg_wal grows with it while it does not.',
              r.ready, coalesce(a.last_archived_wal, 'nothing'),
              coalesce(a.last_archived_time::text, 'never'),
              pg_walfile_name(pg_current_wal_lsn()),
              (SELECT setting FROM pg_settings WHERE name = 'archive_timeout')) AS details,
       json_build_object('ready_files', r.ready, 'last_archived_wal', a.last_archived_wal,
                         'last_archived_time', a.last_archived_time,
                         'failed_count', a.failed_count)::text AS evidence_json,
       'high'::text AS confidence
FROM (SELECT count(*) FILTER (WHERE name LIKE '%.ready') AS ready FROM pg_ls_archive_statusdir()) r
CROSS JOIN pg_stat_archiver a
WHERE (SELECT setting FROM pg_settings WHERE name = 'archive_mode') <> 'off'
  AND (r.ready >= 10
       OR (a.last_archived_time IS NOT NULL
           AND (SELECT setting::int FROM pg_settings WHERE name = 'archive_timeout') > 0
           AND now() - a.last_archived_time > greatest(interval '1 hour',
                 3 * (SELECT setting::int FROM pg_settings WHERE name = 'archive_timeout') * interval '1 second')));
\endif

\echo '@@CHECK-BLOCK replication-health'
-- CHECK PG-REPL-005 P10 Replication slot invalidated or lost
-- CHECK PG-REPL-008 P5 Standby not streaming
-- CHECK PG-REPL-012 P10 Logical subscription disabled or erroring
-- CHECK PG-REPL-013 P10 Published table without a usable replica identity
SELECT (current_setting('server_version_num')::int >= 130000) AS emb_repl005 \gset
\if :emb_repl005
SELECT 'PG-REPL-005'::text AS check_id, 'slot'::text AS scope, s.slot_name::text AS object,
       format('Replication slot %s (%s) is no longer usable: wal_status = %s. The WAL it needed has been removed, so its consumer cannot resume and must be re-initialised from a fresh snapshot. The slot still exists, so anything that only checks "does the slot exist" reports it as healthy. active = %s.',
              s.slot_name, s.slot_type, s.wal_status, s.active) AS details,
       json_build_object('slot_name', s.slot_name, 'slot_type', s.slot_type,
                         'wal_status', s.wal_status, 'active', s.active)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_replication_slots s WHERE s.wal_status = 'lost';
\endif

SELECT 'PG-REPL-008'::text AS check_id, 'cluster'::text AS scope, NULL::text AS object,
       format('This standby is not keeping up with its source. WAL receiver: %s. restore_command: %s. Received %s, replayed %s, gap %s. Last replayed transaction committed %s. Until this is fixed the node is stale both as a failover target and as a read replica.',
              CASE WHEN w.pid IS NULL THEN 'not running'
                   ELSE format('pid %s, status %s, source %s', w.pid, w.status, coalesce(w.sender_host, '?')) END,
              coalesce(nullif((SELECT setting FROM pg_settings WHERE name = 'restore_command'), ''), '(empty)'),
              coalesce(pg_last_wal_receive_lsn()::text, 'none'),
              coalesce(pg_last_wal_replay_lsn()::text, 'none'),
              coalesce(pg_size_pretty(greatest(pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn()), 0)::bigint), 'unknown'),
              coalesce(pg_last_xact_replay_timestamp()::text, 'unknown')) AS details,
       json_build_object('receiver_pid', w.pid, 'receiver_status', w.status,
                         'last_wal_receive_lsn', pg_last_wal_receive_lsn()::text,
                         'last_wal_replay_lsn', pg_last_wal_replay_lsn()::text)::text AS evidence_json,
       'high'::text AS confidence
FROM (SELECT NULL::int AS pid, NULL::text AS status, NULL::text AS sender_host
      WHERE NOT EXISTS (SELECT 1 FROM pg_stat_wal_receiver)
      UNION ALL SELECT pid, status, sender_host FROM pg_stat_wal_receiver) w
WHERE pg_is_in_recovery()
  AND ((w.status IS DISTINCT FROM 'streaming'
        AND coalesce(nullif(trim((SELECT setting FROM pg_settings WHERE name = 'restore_command')), ''), '') = '')
       OR greatest(pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn()), 0) >= 1073741824);

SELECT 'PG-REPL-012'::text AS check_id, 'cluster'::text AS scope, s.subname::text AS object,
       format('Logical subscription %s: enabled = %s, %s apply worker(s) running, publications %s. While a subscription is stopped or erroring the subscriber diverges from the publisher and the publisher''s replication slot keeps retaining WAL for it.',
              s.subname, s.subenabled,
              (SELECT count(*) FROM pg_stat_subscription ss WHERE ss.subid = s.oid AND ss.pid IS NOT NULL),
              coalesce(array_to_string(s.subpublications, ', '), 'none')) AS details,
       json_build_object('subname', s.subname, 'subenabled', s.subenabled,
                         'workers', (SELECT count(*) FROM pg_stat_subscription ss
                                     WHERE ss.subid = s.oid AND ss.pid IS NOT NULL))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_subscription s
WHERE s.subdbid = (SELECT oid FROM pg_database WHERE datname = current_database())
  AND (NOT s.subenabled
       OR NOT EXISTS (SELECT 1 FROM pg_stat_subscription ss WHERE ss.subid = s.oid AND ss.pid IS NOT NULL));

SELECT 'PG-REPL-013'::text AS check_id, 'relation'::text AS scope,
       format('%I.%I.%I', current_database(), pt.schemaname, pt.tablename)::text AS object,
       format('Table %s.%s is published by %s for UPDATE and/or DELETE but its REPLICA IDENTITY is %s. UPDATE and DELETE against it fail outright with "cannot update table ... because it does not have a replica identity and publishes updates".',
              pt.schemaname, pt.tablename, p.pubname,
              CASE c.relreplident WHEN 'n' THEN 'NOTHING'
                                  WHEN 'd' THEN 'DEFAULT with no primary key'
                                  ELSE 'USING INDEX with no valid replica-identity index' END) AS details,
       json_build_object('schema', pt.schemaname, 'table', pt.tablename,
                         'publication', p.pubname, 'relreplident', c.relreplident::text)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_publication_tables pt
JOIN pg_publication p ON p.pubname = pt.pubname
JOIN pg_namespace n   ON n.nspname = pt.schemaname
JOIN pg_class c       ON c.relname = pt.tablename AND c.relnamespace = n.oid
WHERE (p.pubupdate OR p.pubdelete)
  AND (c.relreplident = 'n'
    OR (c.relreplident = 'd' AND NOT EXISTS (SELECT 1 FROM pg_index i
                                             WHERE i.indrelid = c.oid AND i.indisprimary AND i.indisvalid))
    OR (c.relreplident = 'i' AND NOT EXISTS (SELECT 1 FROM pg_index i
                                             WHERE i.indrelid = c.oid AND i.indisreplident AND i.indisvalid)));

\echo '@@CHECK-BLOCK hba-exposure'
-- CHECK PG-SEC-001 P1 trust authentication reachable over the network
-- CHECK PG-SEC-002 P5 Cleartext password authentication over the network
-- pg_hba_file_rules requires superuser. Without it this statement raises a
-- permission error, which IS the PG-SEC-012 finding: record that the
-- authentication checks were blind and carry on.
SELECT (current_setting('server_version_num')::int >= 100000) AS emb_hba \gset
\if :emb_hba
SELECT CASE WHEN r.auth_method = 'trust' THEN 'PG-SEC-001' ELSE 'PG-SEC-002' END::text AS check_id,
       'cluster'::text AS scope,
       format('pg_hba.conf:%s', r.line_number)::text AS object,
       format('pg_hba.conf line %s: %s %s %s %s %s. %s listen_addresses = %s, ssl = %s, port %s.',
              r.line_number, r.type, array_to_string(r.database, ','),
              array_to_string(r.user_name, ','),
              coalesce(r.address || coalesce('/' || r.netmask, ''), 'all addresses'), r.auth_method,
              CASE r.auth_method
                WHEN 'trust' THEN 'Anyone who can open a connection to the port becomes any role they name, with no password and no certificate.'
                ELSE 'The "password" method sends the password across the connection in clear text; anyone on the path reads it.' END,
              (SELECT setting FROM pg_settings WHERE name = 'listen_addresses'),
              (SELECT setting FROM pg_settings WHERE name = 'ssl'),
              (SELECT setting FROM pg_settings WHERE name = 'port')) AS details,
       json_build_object('line_number', r.line_number, 'type', r.type, 'address', r.address,
                         'auth_method', r.auth_method,
                         'database', array_to_string(r.database, ';'),
                         'user_name', array_to_string(r.user_name, ';'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_hba_file_rules r
WHERE r.error IS NULL
  AND r.type IN ('host', 'hostssl', 'hostnossl', 'hostgssenc', 'hostnogssenc')
  AND ((r.auth_method = 'trust'
        AND coalesce(r.address, '') NOT IN ('127.0.0.1', '::1', 'localhost', 'samehost'))
    OR (r.auth_method = 'password' AND r.type IN ('host', 'hostnossl', 'hostnogssenc')));
\endif

\echo '@@CHECK-BLOCK inventory'
-- CHECK PG-INFO-001 P250 Server identity
-- CHECK PG-INFO-012 P250 Statistics window
SELECT 'PG-INFO-001'::text AS check_id, 'cluster'::text AS scope, NULL::text AS object,
       format('%s. Role: %s. Started %s (up %s). data_checksums = %s, wal_level = %s, max_connections = %s, shared_buffers = %s, work_mem = %s. Cluster holds %s across %s database(s). Connected as %s (superuser = %s). Standbys: %s, replication slots: %s (%s inactive).',
              version(), CASE WHEN pg_is_in_recovery() THEN 'STANDBY (in recovery)' ELSE 'PRIMARY' END,
              pg_postmaster_start_time(),
              justify_interval(date_trunc('second', now() - pg_postmaster_start_time())),
              (SELECT setting FROM pg_settings WHERE name = 'data_checksums'),
              (SELECT setting FROM pg_settings WHERE name = 'wal_level'),
              (SELECT setting FROM pg_settings WHERE name = 'max_connections'),
              pg_size_pretty((SELECT setting::bigint * 8192 FROM pg_settings WHERE name = 'shared_buffers')),
              pg_size_pretty((SELECT setting::bigint * 1024 FROM pg_settings WHERE name = 'work_mem')),
              pg_size_pretty((SELECT sum(pg_database_size(oid)) FROM pg_database)),
              (SELECT count(*) FROM pg_database), current_user,
              (SELECT setting FROM pg_settings WHERE name = 'is_superuser'),
              (SELECT count(*) FROM pg_stat_replication),
              (SELECT count(*) FROM pg_replication_slots),
              (SELECT count(*) FROM pg_replication_slots WHERE NOT active)) AS details,
       json_build_object('version', version(), 'in_recovery', pg_is_in_recovery(),
                         'server_version_num', (SELECT setting::int FROM pg_settings WHERE name = 'server_version_num'),
                         'cluster_bytes', (SELECT sum(pg_database_size(oid)) FROM pg_database),
                         'connected_role', current_user)::text AS evidence_json,
       'high'::text AS confidence
UNION ALL
SELECT 'PG-INFO-012', 'cluster', NULL,
       format('Counters cover %s days: the earliest statistics reset is %s and the server has been up for %s. Every rate below - checkpoints per hour, deadlocks per day, "0 index scans since reset" - is measured over this window and means nothing outside it.',
              round(extract(epoch FROM now() - coalesce(x.earliest, pg_postmaster_start_time())) / 86400.0, 1)::text,
              coalesce(x.earliest::text, 'unknown'),
              justify_interval(date_trunc('second', now() - pg_postmaster_start_time()))),
       json_build_object('earliest_stats_reset', x.earliest,
                         'window_days', round(extract(epoch FROM now() - coalesce(x.earliest, pg_postmaster_start_time())) / 86400.0, 3))::text,
       'high'
FROM (SELECT min(stats_reset) AS earliest FROM pg_stat_database) x;
