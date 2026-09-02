-- check: PG-BAK-006
-- title: wal_level = minimal
-- priority: 20
-- scope: setting
-- cost: 0
SELECT 'PG-BAK-006'::text  AS check_id,
       'setting'::text     AS scope,
       'wal_level'::text   AS object,
       format('wal_level = minimal (set in %s%s). Minimal WAL omits the information a standby or an archive recovery needs, so this cluster cannot stream replication, cannot take an online base backup, and cannot do point-in-time recovery. Raising it to replica requires a restart. max_wal_senders = %s, archive_mode = %s.',
              s.source, coalesce(', ' || s.sourcefile || ':' || s.sourceline::text, ''),
              current_setting('max_wal_senders'), current_setting('archive_mode')) AS details,
       json_build_object('wal_level', s.setting, 'source', s.source,
                         'max_wal_senders', current_setting('max_wal_senders')::int,
                         'archive_mode', current_setting('archive_mode'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'wal_level' AND s.setting = 'minimal';
