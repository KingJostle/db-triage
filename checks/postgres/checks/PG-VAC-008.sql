-- check: PG-VAC-008
-- title: Autovacuum throttled at defaults on a large database
-- priority: 100
-- scope: setting
-- cost: 0
-- thresholds: total_bytes, cost_delay_ms
WITH s AS (
  SELECT (SELECT sum(pg_database_size(oid)) FROM pg_database WHERE datallowconn) AS total_bytes,
         (SELECT setting::numeric FROM pg_settings WHERE name = 'autovacuum_vacuum_cost_delay') AS delay_ms,
         (SELECT setting::int FROM pg_settings WHERE name = 'autovacuum_vacuum_cost_limit') AS av_limit,
         (SELECT setting::int FROM pg_settings WHERE name = 'vacuum_cost_limit')            AS vac_limit,
         (SELECT setting::numeric FROM pg_settings WHERE name = 'vacuum_cost_page_dirty')   AS dirty_cost,
         current_setting('block_size')::numeric                                             AS bs
)
SELECT 'PG-VAC-008'::text                      AS check_id,
       'setting'::text                         AS scope,
       'autovacuum_vacuum_cost_limit'::text    AS object,
       format('Cluster holds %s of connectable databases (threshold %s) while autovacuum runs at the shipped cost settings: autovacuum_vacuum_cost_delay = %s ms, effective cost limit %s%s. That is roughly %s MB/s of dirty pages per worker across %s workers, which cannot keep up with hundreds of GB of churn.',
              pg_size_pretty(s.total_bytes), pg_size_pretty(:'pg_vac_008_total_bytes'::bigint),
              s.delay_ms::text,
              CASE WHEN s.av_limit < 0 THEN s.vac_limit ELSE s.av_limit END,
              CASE WHEN s.av_limit < 0 THEN ' (inherited from vacuum_cost_limit)' ELSE '' END,
              round(((CASE WHEN s.av_limit < 0 THEN s.vac_limit ELSE s.av_limit END)::numeric / s.dirty_cost)
                    * (1000.0 / greatest(s.delay_ms, 0.1)) * s.bs / 1048576.0, 1)::text,
              current_setting('autovacuum_max_workers')) AS details,
       json_build_object('total_bytes', s.total_bytes, 'threshold_bytes', :'pg_vac_008_total_bytes'::bigint,
                         'autovacuum_vacuum_cost_delay_ms', s.delay_ms,
                         'autovacuum_vacuum_cost_limit', s.av_limit,
                         'vacuum_cost_limit', s.vac_limit,
                         'vacuum_cost_page_dirty', s.dirty_cost,
                         'dirty_mb_per_sec_per_worker',
                            round(((CASE WHEN s.av_limit < 0 THEN s.vac_limit ELSE s.av_limit END)::numeric / s.dirty_cost)
                                  * (1000.0 / greatest(s.delay_ms, 0.1)) * s.bs / 1048576.0, 2),
                         'autovacuum_max_workers', current_setting('autovacuum_max_workers')::int)::text AS evidence_json,
       'medium'::text AS confidence
FROM s
WHERE s.total_bytes >= :'pg_vac_008_total_bytes'::bigint
  AND s.delay_ms >= :'pg_vac_008_cost_delay_ms'::numeric
  AND s.av_limit < 0 AND s.vac_limit <= 200;
