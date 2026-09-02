-- check: PG-SCHEMA-009
-- title: Triggers on high-write tables
-- priority: 150
-- scope: relation
-- cost: 1
-- thresholds: min_writes
SELECT 'PG-SCHEMA-009'::text AS check_id,
       'relation'::text      AS scope,
       format('%I.%I.%I', current_database(), t.schemaname, t.relname)::text AS object,
       format('Table %s.%s has taken %s writes since the statistics reset (threshold %s) and carries %s user trigger(s): %s. Trigger work is invisible in the statement''s own timing and in most application metrics, so a slow trigger looks like a slow INSERT. Row-level triggers also disable the fast paths for COPY and multi-row INSERT. This is informational: it tells you where to look first when write latency on this table does not match the statement.',
              t.schemaname, t.relname,
              to_char(t.n_tup_ins + t.n_tup_upd + t.n_tup_del, 'FM999,999,999,999'),
              to_char(:'pg_schema_009_min_writes'::bigint, 'FM999,999,999,999'),
              g.n, g.names) AS details,
       json_build_object('schema', t.schemaname, 'table', t.relname,
                         'writes', t.n_tup_ins + t.n_tup_upd + t.n_tup_del,
                         'trigger_count', g.n, 'triggers', g.names,
                         'threshold_writes', :'pg_schema_009_min_writes'::bigint)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_user_tables t
CROSS JOIN LATERAL (
  SELECT count(*) AS n,
         string_agg(format('%s (%s)', tg.tgname, p.proname), ', ' ORDER BY tg.tgname) AS names
  FROM pg_trigger tg JOIN pg_proc p ON p.oid = tg.tgfoid
  WHERE tg.tgrelid = t.relid AND NOT tg.tgisinternal
) g
WHERE g.n > 0
  AND t.n_tup_ins + t.n_tup_upd + t.n_tup_del >= :'pg_schema_009_min_writes'::bigint
ORDER BY t.n_tup_ins + t.n_tup_upd + t.n_tup_del DESC;
