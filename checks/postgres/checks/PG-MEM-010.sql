-- check: PG-MEM-010
-- title: Buffer cache hit ratio below 90 percent
-- priority: 150
-- scope: database
-- cost: 0
-- thresholds: hit_ratio, min_reads
SELECT 'PG-MEM-010'::text AS check_id,
       'database'::text   AS scope,
       d.datname::text    AS object,
       format('Buffer cache hit ratio %s%% in database %s (threshold %s%%): %s blocks found in shared_buffers against %s read from outside it, since %s. "Read from outside" includes blocks served by the operating-system page cache, which this counter cannot distinguish from a real disk read, so a low ratio on a host with plenty of free memory may cost nothing at all. Read this next to PG-MEM-001 and PG-MEM-002 rather than as a target to tune towards. shared_buffers = %s, database size %s.',
              round(100.0 * d.blks_hit / nullif(d.blks_hit + d.blks_read, 0), 1)::text,
              d.datname, round(100 * :'pg_mem_010_hit_ratio'::numeric)::text,
              to_char(d.blks_hit, 'FM999,999,999,999'), to_char(d.blks_read, 'FM999,999,999,999'),
              coalesce(d.stats_reset::text, 'the last statistics reset'),
              current_setting('shared_buffers'),
              pg_size_pretty(pg_database_size(d.datname))) AS details,
       json_build_object('datname', d.datname, 'blks_hit', d.blks_hit, 'blks_read', d.blks_read,
                         'hit_ratio', round(d.blks_hit::numeric / nullif(d.blks_hit + d.blks_read, 0), 4),
                         'threshold_ratio', :'pg_mem_010_hit_ratio'::numeric,
                         'threshold_min_reads', :'pg_mem_010_min_reads'::bigint,
                         'stats_reset', d.stats_reset,
                         'database_bytes', pg_database_size(d.datname))::text AS evidence_json,
       'low'::text AS confidence
FROM pg_stat_database d
WHERE d.datname IS NOT NULL
  AND d.blks_read >= :'pg_mem_010_min_reads'::bigint
  AND d.blks_hit::numeric / nullif(d.blks_hit + d.blks_read, 0) < :'pg_mem_010_hit_ratio'::numeric
ORDER BY d.blks_read DESC;
