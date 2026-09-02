-- check: PG-VAC-003
-- title: Tables overdue for vacuum
-- priority: 50
-- scope: relation
-- cost: 1
-- thresholds: dead_multiple, min_dead_tuples, min_bytes, top_n
WITH eff AS (
  SELECT t.relid, t.schemaname, t.relname, t.n_dead_tup, t.n_live_tup,
         t.last_vacuum, t.last_autovacuum, t.n_mod_since_analyze,
         pg_relation_size(t.relid) AS rel_bytes,
         coalesce(substring(array_to_string(c.reloptions, ' ') from 'autovacuum_vacuum_threshold=([0-9.]+)')::numeric,
                  current_setting('autovacuum_vacuum_threshold')::numeric) AS thr,
         coalesce(substring(array_to_string(c.reloptions, ' ') from 'autovacuum_vacuum_scale_factor=([0-9.]+)')::numeric,
                  current_setting('autovacuum_vacuum_scale_factor')::numeric) AS scale
  FROM pg_stat_user_tables t
  JOIN pg_class c ON c.oid = t.relid
)
SELECT 'PG-VAC-003'::text AS check_id,
       'relation'::text   AS scope,
       format('%I.%I.%I', current_database(), e.schemaname, e.relname)::text AS object,
       format('%s dead tuples against %s live (%s%% dead), %s of the effective autovacuum threshold of %s rows (threshold + scale_factor x live = %s + %s x %s). Relation size %s. Last vacuum %s, last autovacuum %s.',
              to_char(e.n_dead_tup, 'FM999,999,999,999'),
              to_char(e.n_live_tup, 'FM999,999,999,999'),
              round(100.0 * e.n_dead_tup / nullif(e.n_dead_tup + e.n_live_tup, 0), 1)::text,
              round(e.n_dead_tup / nullif(e.thr + e.scale * greatest(e.n_live_tup, 0), 0), 1)::text || 'x',
              to_char(round(e.thr + e.scale * greatest(e.n_live_tup, 0)), 'FM999,999,999,999'),
              e.thr::text, e.scale::text, to_char(e.n_live_tup, 'FM999,999,999,999'),
              pg_size_pretty(e.rel_bytes),
              coalesce(e.last_vacuum::text, 'never'),
              coalesce(e.last_autovacuum::text, 'never')) AS details,
       json_build_object('n_dead_tup', e.n_dead_tup, 'n_live_tup', e.n_live_tup,
                         'effective_threshold', round(e.thr + e.scale * greatest(e.n_live_tup, 0)),
                         'threshold_multiple', :'pg_vac_003_dead_multiple'::numeric,
                         'autovacuum_vacuum_threshold', e.thr,
                         'autovacuum_vacuum_scale_factor', e.scale,
                         'relation_bytes', e.rel_bytes,
                         'last_vacuum', e.last_vacuum, 'last_autovacuum', e.last_autovacuum)::text AS evidence_json,
       'medium'::text AS confidence
FROM eff e
WHERE e.n_dead_tup >= :'pg_vac_003_min_dead_tuples'::bigint
  AND e.rel_bytes  >= :'pg_vac_003_min_bytes'::bigint
  AND e.n_dead_tup >  :'pg_vac_003_dead_multiple'::numeric * (e.thr + e.scale * greatest(e.n_live_tup, 0))
ORDER BY e.n_dead_tup DESC
LIMIT :'pg_vac_003_top_n'::int;
