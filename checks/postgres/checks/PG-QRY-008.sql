-- check: PG-QRY-008
-- title: One statement dominates execution time
-- priority: 100
-- scope: query
-- cost: 1
-- thresholds: dominance, min_calls
\set ON_ERROR_STOP off
SELECT (to_regclass('pg_stat_statements') IS NOT NULL) AS pg_qry_008_pgss \gset
\if :pg_qry_008_pgss
SELECT EXISTS (SELECT 1 FROM pg_attribute
               WHERE attrelid = to_regclass('pg_stat_statements')
                 AND attname = 'total_exec_time' AND NOT attisdropped) AS pg_qry_008_v18 \gset
WITH q AS (
\if :pg_qry_008_v18
  SELECT queryid, query, calls, rows,
         total_exec_time::numeric AS total_ms, mean_exec_time::numeric AS mean_ms,
         stddev_exec_time::numeric AS stddev_ms,
         shared_blks_read, shared_blks_hit, temp_blks_read, temp_blks_written, userid
  FROM pg_stat_statements WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
\else
  SELECT queryid, query, calls, rows,
         total_time::numeric AS total_ms, mean_time::numeric AS mean_ms,
         stddev_time::numeric AS stddev_ms,
         shared_blks_read, shared_blks_hit, temp_blks_read, temp_blks_written, userid
  FROM pg_stat_statements WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
\endif
),
tot AS (SELECT sum(total_ms) AS all_ms, sum(calls) AS all_calls FROM q)

SELECT 'PG-QRY-008'::text AS check_id,
       'query'::text      AS scope,
       ('queryid:' || q.queryid::text)::text AS object,
       format('One statement accounts for %s%% of all execution time recorded for database %s (threshold %s%%): %s ms across %s calls, mean %s ms, %s rows per call. Total recorded across all statements: %s ms over %s calls. Whatever else is on the tuning list, this is the statement where an improvement is worth the most: halving it removes %s%% of the server''s recorded query time. Run by role %s. Statement: %s',
              round(100.0 * q.total_ms / nullif(t.all_ms, 0), 1)::text, current_database(),
              round(100 * :'pg_qry_008_dominance'::numeric)::text,
              to_char(round(q.total_ms), 'FM999,999,999,999'),
              to_char(q.calls, 'FM999,999,999,999'),
              round(q.mean_ms, 2)::text,
              round(q.rows::numeric / nullif(q.calls, 0), 1)::text,
              to_char(round(t.all_ms), 'FM999,999,999,999'),
              to_char(t.all_calls, 'FM999,999,999,999'),
              round(50.0 * q.total_ms / nullif(t.all_ms, 0), 1)::text,
              coalesce((SELECT rolname FROM pg_roles WHERE oid = q.userid), 'unknown'),
              left(regexp_replace(q.query, '\s+', ' ', 'g'), 300)) AS details,
       json_build_object('queryid', q.queryid, 'calls', q.calls,
                         'total_ms', round(q.total_ms, 2), 'mean_ms', round(q.mean_ms, 3),
                         'pct_of_total_time', round(100.0 * q.total_ms / nullif(t.all_ms, 0), 2),
                         'threshold_fraction', :'pg_qry_008_dominance'::numeric,
                         'all_statements_ms', round(t.all_ms, 2), 'all_calls', t.all_calls,
                         'rows_per_call', round(q.rows::numeric / nullif(q.calls, 0), 2),
                         'query', left(regexp_replace(q.query, '\s+', ' ', 'g'), 300))::text AS evidence_json,
       'medium'::text AS confidence
FROM q CROSS JOIN tot t
WHERE q.calls >= :'pg_qry_008_min_calls'::bigint
  AND q.total_ms >= :'pg_qry_008_dominance'::numeric * t.all_ms
ORDER BY q.total_ms DESC;
\endif
