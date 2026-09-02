-- check: PG-QRY-014
-- title: JIT overhead significant
-- priority: 100
-- scope: query
-- cost: 1
-- min_version: 15
-- thresholds: jit_fraction
\set ON_ERROR_STOP off
SELECT (to_regclass('pg_stat_statements') IS NOT NULL) AS pg_qry_014_pgss \gset
\if :pg_qry_014_pgss
SELECT EXISTS (SELECT 1 FROM pg_attribute
               WHERE attrelid = to_regclass('pg_stat_statements')
                 AND attname = 'jit_generation_time' AND NOT attisdropped) AS pg_qry_014_has_jit \gset
\if :pg_qry_014_has_jit
WITH j AS (
  SELECT sum(jit_generation_time + jit_inlining_time + jit_optimization_time + jit_emission_time)::numeric AS jit_ms,
         sum(total_exec_time)::numeric AS total_ms,
         sum(jit_functions) AS jit_functions,
         count(*) FILTER (WHERE jit_functions > 0) AS jitted_statements
  FROM pg_stat_statements
  WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
)
SELECT 'PG-QRY-014'::text AS check_id,
       'query'::text      AS scope,
       'jit'::text        AS object,
       format('JIT compilation accounts for %s ms of the %s ms of execution time recorded for this database (%s%%, threshold %s%%), across %s statements and %s compiled functions. JIT pays for itself on long analytical queries and costs pure overhead on short ones: the planner decides from an estimated cost (jit_above_cost = %s), and an over-estimate on an OLTP statement buys a compilation that outlasts the query. Settings: jit = %s, jit_above_cost = %s, jit_inline_above_cost = %s, jit_optimize_above_cost = %s. Raising the thresholds is usually better than turning JIT off.',
              to_char(round(j.jit_ms), 'FM999,999,999,999'),
              to_char(round(j.total_ms), 'FM999,999,999,999'),
              round(100.0 * j.jit_ms / nullif(j.total_ms, 0), 1)::text,
              round(100 * :'pg_qry_014_jit_fraction'::numeric)::text,
              j.jitted_statements, to_char(j.jit_functions, 'FM999,999,999,999'),
              current_setting('jit_above_cost'), current_setting('jit'),
              current_setting('jit_above_cost'), current_setting('jit_inline_above_cost'),
              current_setting('jit_optimize_above_cost')) AS details,
       json_build_object('jit_ms', round(j.jit_ms, 2), 'total_ms', round(j.total_ms, 2),
                         'jit_fraction', round(j.jit_ms / nullif(j.total_ms, 0), 4),
                         'threshold_fraction', :'pg_qry_014_jit_fraction'::numeric,
                         'jit_functions', j.jit_functions, 'jitted_statements', j.jitted_statements,
                         'jit', current_setting('jit'),
                         'jit_above_cost', current_setting('jit_above_cost'),
                         'jit_inline_above_cost', current_setting('jit_inline_above_cost'),
                         'jit_optimize_above_cost', current_setting('jit_optimize_above_cost'))::text AS evidence_json,
       'medium'::text AS confidence
FROM j
WHERE j.total_ms > 0
  AND j.jit_ms >= :'pg_qry_014_jit_fraction'::numeric * j.total_ms;
\endif
\endif
