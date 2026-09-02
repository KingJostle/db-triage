-- check: PG-MEM-003
-- title: Worst-case memory commitment exceeds RAM (OOM risk)
-- priority: 50
-- scope: setting
-- cost: 0
-- thresholds: ram_bytes, ram_fraction
-- Requires RAM: pass -v pg_mem_003_ram_bytes=<bytes>. With RAM unknown (0) the
-- check emits nothing; the computed worst-case figure is still reported in
-- PG-INFO-001 evidence so it is never lost.
WITH s AS (
  SELECT (SELECT setting::numeric * 8192 FROM pg_settings WHERE name = 'shared_buffers')          AS shared_buffers,
         (SELECT setting::numeric * 8192 FROM pg_settings WHERE name = 'wal_buffers')             AS wal_buffers,
         (SELECT setting::int       FROM pg_settings WHERE name = 'max_connections')              AS max_connections,
         (SELECT setting::numeric * 1024 FROM pg_settings WHERE name = 'work_mem')                AS work_mem,
         coalesce((SELECT setting::numeric FROM pg_settings WHERE name = 'hash_mem_multiplier'), 1) AS hash_mult,
         (SELECT setting::numeric * 1024 FROM pg_settings WHERE name = 'maintenance_work_mem')    AS maint_mem,
         (SELECT setting::numeric FROM pg_settings WHERE name = 'autovacuum_work_mem')            AS av_mem_raw,
         (SELECT setting::int FROM pg_settings WHERE name = 'autovacuum_max_workers')             AS av_workers
),
calc AS (
  SELECT s.*,
         CASE WHEN s.av_mem_raw < 0 THEN s.maint_mem ELSE s.av_mem_raw * 1024 END AS av_mem,
         s.shared_buffers + s.wal_buffers
           + s.max_connections * s.work_mem * greatest(2, s.hash_mult)
           + s.av_workers * (CASE WHEN s.av_mem_raw < 0 THEN s.maint_mem ELSE s.av_mem_raw * 1024 END) AS worst_case
  FROM s
)
SELECT 'PG-MEM-003'::text AS check_id,
       'setting'::text    AS scope,
       'max_connections'::text AS object,
       format('Worst-case memory commitment is %s against %s of RAM (%s%%). That is shared_buffers %s + wal_buffers %s + max_connections %s x work_mem %s x hash_mem_multiplier factor %s + %s autovacuum workers x %s. A single backend can use work_mem once per sort, hash or materialise node, so the real ceiling is higher still. When the Linux OOM killer fires it usually takes the postmaster, which restarts the whole cluster and disconnects every session.',
              pg_size_pretty(c.worst_case::bigint),
              pg_size_pretty(:'pg_mem_003_ram_bytes'::bigint),
              round(100.0 * c.worst_case / :'pg_mem_003_ram_bytes'::numeric)::text,
              pg_size_pretty(c.shared_buffers::bigint), pg_size_pretty(c.wal_buffers::bigint),
              c.max_connections, pg_size_pretty(c.work_mem::bigint), greatest(2, c.hash_mult)::text,
              c.av_workers, pg_size_pretty(c.av_mem::bigint)) AS details,
       json_build_object('worst_case_bytes', c.worst_case::bigint,
                         'ram_bytes', :'pg_mem_003_ram_bytes'::bigint,
                         'fraction_of_ram', round(c.worst_case / :'pg_mem_003_ram_bytes'::numeric, 3),
                         'shared_buffers_bytes', c.shared_buffers::bigint,
                         'wal_buffers_bytes', c.wal_buffers::bigint,
                         'max_connections', c.max_connections,
                         'work_mem_bytes', c.work_mem::bigint,
                         'hash_mem_multiplier', c.hash_mult,
                         'autovacuum_max_workers', c.av_workers,
                         'autovacuum_work_mem_bytes', c.av_mem::bigint)::text AS evidence_json,
       'medium'::text AS confidence
FROM calc c
WHERE :'pg_mem_003_ram_bytes'::bigint > 0
  AND c.worst_case >= :'pg_mem_003_ram_fraction'::numeric * :'pg_mem_003_ram_bytes'::bigint;
