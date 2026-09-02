-- check: PG-DUR-001
-- title: fsync disabled
-- priority: 1
-- scope: setting
-- cost: 0
SELECT 'PG-DUR-001'::text AS check_id,
       'setting'::text    AS scope,
       'fsync'::text      AS object,
       format('fsync = off (set in %s%s). The server never asks the operating system to flush WAL or data pages to durable storage, so an operating-system crash or power loss can leave the cluster in a state recovery cannot repair: this is cluster loss, not the loss of recent transactions. full_page_writes = %s, synchronous_commit = %s, data_checksums = %s. Cluster holds %s.',
              s.source, coalesce(', ' || s.sourcefile || ':' || s.sourceline::text, ''),
              current_setting('full_page_writes'), current_setting('synchronous_commit'),
              current_setting('data_checksums'),
              pg_size_pretty((SELECT sum(pg_database_size(oid)) FROM pg_database))) AS details,
       json_build_object('fsync', s.setting, 'source', s.source,
                         'sourcefile', s.sourcefile, 'sourceline', s.sourceline,
                         'full_page_writes', current_setting('full_page_writes'),
                         'synchronous_commit', current_setting('synchronous_commit'),
                         'cluster_bytes', (SELECT sum(pg_database_size(oid)) FROM pg_database))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'fsync' AND s.setting = 'off';
