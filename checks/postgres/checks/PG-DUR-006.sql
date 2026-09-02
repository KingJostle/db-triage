-- check: PG-DUR-006
-- title: wal_sync_method changed from the platform default
-- priority: 150
-- scope: setting
-- cost: 0
SELECT 'PG-DUR-006'::text         AS check_id,
       'setting'::text            AS scope,
       'wal_sync_method'::text    AS object,
       format('wal_sync_method = %s, changed from the platform default of %s (set in %s%s). PostgreSQL picks the fastest method its build detected as safe on this platform; overriding it is occasionally right for a specific storage stack and is more often a copied setting whose original justification is gone. fsync = %s.',
              s.setting, s.boot_val, s.source,
              coalesce(', ' || s.sourcefile || ':' || s.sourceline::text, ''),
              current_setting('fsync')) AS details,
       json_build_object('wal_sync_method', s.setting, 'default', s.boot_val,
                         'source', s.source, 'sourcefile', s.sourcefile,
                         'fsync', current_setting('fsync'))::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_settings s
WHERE s.name = 'wal_sync_method' AND s.source <> 'default' AND s.setting IS DISTINCT FROM s.boot_val;
