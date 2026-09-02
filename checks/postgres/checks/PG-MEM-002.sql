-- check: PG-MEM-002
-- title: shared_buffers above 40 percent of RAM
-- priority: 100
-- scope: setting
-- cost: 0
-- thresholds: ram_fraction, ram_bytes
-- Requires RAM: pass -v pg_mem_002_ram_bytes=<bytes> (bin/db-triage supplies it
-- from the host helper or from baseline.ram_gb). With RAM unknown (0) the check
-- emits nothing and the runner records it skipped with reason no-input.
SELECT 'PG-MEM-002'::text     AS check_id,
       'setting'::text        AS scope,
       'shared_buffers'::text AS object,
       format('shared_buffers = %s, which is %s%% of the %s of RAM reported for this host (threshold %s%%). Past roughly 40%% the buffer cache mostly duplicates pages the operating-system cache already holds, while leaving less room for work_mem allocations and for the page cache that backs sequential reads; checkpoints also have more dirty pages to write. effective_cache_size = %s.',
              pg_size_pretty(s.bytes::bigint),
              round(100.0 * s.bytes / :'pg_mem_002_ram_bytes'::numeric, 1)::text,
              pg_size_pretty(:'pg_mem_002_ram_bytes'::bigint),
              round(100 * :'pg_mem_002_ram_fraction'::numeric)::text,
              current_setting('effective_cache_size')) AS details,
       json_build_object('shared_buffers_bytes', s.bytes::bigint,
                         'ram_bytes', :'pg_mem_002_ram_bytes'::bigint,
                         'fraction_of_ram', round(s.bytes / :'pg_mem_002_ram_bytes'::numeric, 4),
                         'threshold_fraction', :'pg_mem_002_ram_fraction'::numeric,
                         'source', s.source)::text AS evidence_json,
       'high'::text AS confidence
FROM (SELECT setting::numeric * 8192 AS bytes, source FROM pg_settings WHERE name = 'shared_buffers') s
WHERE :'pg_mem_002_ram_bytes'::bigint > 0
  AND s.bytes > :'pg_mem_002_ram_fraction'::numeric * :'pg_mem_002_ram_bytes'::bigint;
