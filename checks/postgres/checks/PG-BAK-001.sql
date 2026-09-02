-- check: PG-BAK-001
-- title: No WAL archiving: point-in-time recovery impossible
-- priority: 1
-- scope: setting
-- cost: 0
-- run_on: primary
SELECT 'PG-BAK-001'::text  AS check_id,
       'setting'::text     AS scope,
       'archive_mode'::text AS object,
       format('archive_mode = off (set in %s%s) on a primary. Without archived WAL there is no point-in-time recovery: the only recoverable states are whatever full backups exist, and every transaction since the newest one is unrecoverable. wal_level = %s, cluster size %s, WAL generated since the last checkpoint statistics reset is visible in PG-INFO-008. A pg_dump is a logical export, not PITR.',
              s.source, coalesce(', ' || s.sourcefile || ':' || s.sourceline::text, ''),
              current_setting('wal_level'),
              pg_size_pretty((SELECT sum(pg_database_size(oid)) FROM pg_database))) AS details,
       json_build_object('archive_mode', s.setting, 'source', s.source,
                         'wal_level', current_setting('wal_level'),
                         'archive_command', current_setting('archive_command'),
                         'cluster_bytes', (SELECT sum(pg_database_size(oid)) FROM pg_database))::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_settings s
WHERE s.name = 'archive_mode' AND s.setting = 'off'
  AND NOT pg_is_in_recovery();
