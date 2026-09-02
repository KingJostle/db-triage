-- check: PG-MEM-001
-- title: shared_buffers at the shipped default
-- priority: 20
-- scope: setting
-- cost: 0
-- thresholds: shared_buffers_bytes
SELECT 'PG-MEM-001'::text       AS check_id,
       'setting'::text          AS scope,
       'shared_buffers'::text   AS object,
       format('shared_buffers = %s (threshold %s), source %s. The shipped default is chosen so the server starts on any machine, not so it performs on this one. This cluster holds %s of data, so at %s the buffer cache can hold %s%% of it and almost every read goes to the operating-system cache or the disk. effective_cache_size = %s. Changing shared_buffers requires a restart.',
              pg_size_pretty(s.bytes::bigint), pg_size_pretty(:'pg_mem_001_shared_buffers_bytes'::bigint), s.source,
              pg_size_pretty((SELECT sum(pg_database_size(oid)) FROM pg_database)),
              pg_size_pretty(s.bytes::bigint),
              round(100.0 * s.bytes / nullif((SELECT sum(pg_database_size(oid)) FROM pg_database), 0), 1)::text,
              current_setting('effective_cache_size')) AS details,
       json_build_object('shared_buffers_bytes', s.bytes::bigint,
                         'threshold_bytes', :'pg_mem_001_shared_buffers_bytes'::bigint,
                         'source', s.source,
                         'cluster_bytes', (SELECT sum(pg_database_size(oid)) FROM pg_database),
                         'effective_cache_size', current_setting('effective_cache_size'))::text AS evidence_json,
       'high'::text AS confidence
FROM (SELECT setting::numeric * 8192 AS bytes, source FROM pg_settings WHERE name = 'shared_buffers') s
WHERE s.bytes <= :'pg_mem_001_shared_buffers_bytes'::bigint;
