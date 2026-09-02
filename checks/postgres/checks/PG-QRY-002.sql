-- check: PG-QRY-002
-- title: pg_stat_statements evicting entries
-- priority: 150
-- scope: database
-- cost: 0
-- min_version: 14
-- thresholds: min_dealloc, dealloc_per_day
\set ON_ERROR_STOP off
SELECT (to_regclass('pg_stat_statements_info') IS NOT NULL) AS pg_qry_002_has_info \gset
\if :pg_qry_002_has_info
WITH w AS (
  SELECT i.dealloc, i.stats_reset,
         greatest(extract(epoch FROM now() - coalesce(i.stats_reset, pg_postmaster_start_time())) / 86400.0, 0.01) AS days
  FROM pg_stat_statements_info i
)
SELECT 'PG-QRY-002'::text AS check_id,
       'database'::text   AS scope,
       'pg_stat_statements'::text AS object,
       format('pg_stat_statements has evicted entries %s times since %s (%s per day; thresholds %s total, %s per day). pg_stat_statements.max is %s and the hash currently holds %s entries. Eviction discards the least-executed half of the table, so any "top 10 by total time" list is missing whatever was evicted, and the totals it is a percentage of are wrong too. Raising pg_stat_statements.max requires a restart. High eviction usually means unparameterised SQL: each literal produces a distinct queryid.',
              to_char(w.dealloc, 'FM999,999,999,999'),
              coalesce(w.stats_reset::text, 'the last reset'),
              round(w.dealloc / w.days, 1)::text,
              to_char(:'pg_qry_002_min_dealloc'::bigint, 'FM999,999,999,999'),
              :'pg_qry_002_dealloc_per_day'::text,
              current_setting('pg_stat_statements.max'),
              to_char((SELECT count(*) FROM pg_stat_statements), 'FM999,999,999,999')) AS details,
       json_build_object('dealloc', w.dealloc, 'stats_reset', w.stats_reset,
                         'window_days', round(w.days, 2),
                         'dealloc_per_day', round(w.dealloc / w.days, 2),
                         'threshold_total', :'pg_qry_002_min_dealloc'::bigint,
                         'threshold_per_day', :'pg_qry_002_dealloc_per_day'::numeric,
                         'pgss_max', current_setting('pg_stat_statements.max')::int,
                         'current_entries', (SELECT count(*) FROM pg_stat_statements))::text AS evidence_json,
       'high'::text AS confidence
FROM w
WHERE w.dealloc >= :'pg_qry_002_min_dealloc'::bigint
   OR w.dealloc / w.days >= :'pg_qry_002_dealloc_per_day'::numeric;
\endif
