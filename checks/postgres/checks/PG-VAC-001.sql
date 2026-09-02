-- check: PG-VAC-001
-- title: Autovacuum running more than 6 hours on one relation
-- priority: 50
-- scope: relation
-- cost: 0
-- min_version: 9.6
-- thresholds: duration_seconds
WITH cfg AS (
  SELECT (SELECT setting::numeric FROM pg_settings WHERE name = 'autovacuum_vacuum_cost_delay') AS delay_ms,
         CASE WHEN (SELECT setting::int FROM pg_settings WHERE name = 'autovacuum_vacuum_cost_limit') < 0
              THEN (SELECT setting::numeric FROM pg_settings WHERE name = 'vacuum_cost_limit')
              ELSE (SELECT setting::numeric FROM pg_settings WHERE name = 'autovacuum_vacuum_cost_limit') END AS eff_limit,
         (SELECT setting::numeric FROM pg_settings WHERE name = 'vacuum_cost_page_dirty') AS dirty_cost,
         current_setting('block_size')::numeric AS bs
)
SELECT 'PG-VAC-001'::text AS check_id,
       'relation'::text   AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('Vacuum has been running for %s (threshold %s). Phase "%s", %s of %s heap blocks scanned (%s%%), %s index vacuum cycles so far. Backend pid %s, %s. With autovacuum_vacuum_cost_delay = %s and cost limit %s the worker moves roughly %s MB/s of dirty pages, so this relation needs its own cost settings or partitioning.',
              justify_interval(date_trunc('second', now() - a.xact_start)),
              (:'pg_vac_001_duration_seconds'::int || ' seconds')::interval,
              p.phase,
              to_char(p.heap_blks_scanned, 'FM999,999,999,999'),
              to_char(p.heap_blks_total, 'FM999,999,999,999'),
              round(100.0 * p.heap_blks_scanned / nullif(p.heap_blks_total, 0), 1)::text,
              p.index_vacuum_count, p.pid,
              coalesce(a.backend_type, 'unknown backend'),
              cfg.delay_ms::text || ' ms',
              cfg.eff_limit::text,
              round((cfg.eff_limit / cfg.dirty_cost) * (1000.0 / greatest(cfg.delay_ms, 0.1)) * cfg.bs / 1048576.0, 1)::text) AS details,
       json_build_object(
              'pid', p.pid, 'phase', p.phase,
              'duration_seconds', round(extract(epoch FROM now() - a.xact_start))::bigint,
              'threshold_seconds', :'pg_vac_001_duration_seconds'::int,
              'heap_blks_total', p.heap_blks_total, 'heap_blks_scanned', p.heap_blks_scanned,
              'index_vacuum_count', p.index_vacuum_count,
              'total_bytes', pg_total_relation_size(c.oid),
              'backend_type', a.backend_type,
              'autovacuum_vacuum_cost_delay_ms', cfg.delay_ms,
              'effective_cost_limit', cfg.eff_limit,
              'vacuum_cost_page_dirty', cfg.dirty_cost,
              'dirty_mb_per_sec', round((cfg.eff_limit / cfg.dirty_cost) * (1000.0 / greatest(cfg.delay_ms, 0.1)) * cfg.bs / 1048576.0, 2))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_progress_vacuum p
JOIN pg_class c     ON c.oid = p.relid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_stat_activity a ON a.pid = p.pid
CROSS JOIN cfg
WHERE a.xact_start IS NOT NULL
  AND now() - a.xact_start >= (:'pg_vac_001_duration_seconds'::int || ' seconds')::interval
ORDER BY a.xact_start;
