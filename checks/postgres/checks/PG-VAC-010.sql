-- check: PG-VAC-010
-- title: Very large tables using the default vacuum scale factor
-- priority: 100
-- scope: relation
-- cost: 1
-- thresholds: min_tuples
SELECT 'PG-VAC-010'::text AS check_id,
       'relation'::text   AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('Estimated %s rows (threshold %s), size %s, with no per-table autovacuum_vacuum_scale_factor or autovacuum_vacuum_threshold. At the cluster default scale factor of %s the table accumulates about %s dead tuples before autovacuum starts, and each of those runs then has to scan the whole relation.',
              to_char(c.reltuples::bigint, 'FM999,999,999,999'),
              to_char(:'pg_vac_010_min_tuples'::bigint, 'FM999,999,999,999'),
              pg_size_pretty(pg_total_relation_size(c.oid)),
              current_setting('autovacuum_vacuum_scale_factor'),
              to_char((c.reltuples * current_setting('autovacuum_vacuum_scale_factor')::numeric)::bigint, 'FM999,999,999,999')) AS details,
       json_build_object('reltuples', c.reltuples::bigint,
                         'threshold_tuples', :'pg_vac_010_min_tuples'::bigint,
                         'total_bytes', pg_total_relation_size(c.oid),
                         'cluster_scale_factor', current_setting('autovacuum_vacuum_scale_factor')::numeric,
                         'reloptions', array_to_string(c.reloptions, ';'))::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'm')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  AND c.reltuples >= :'pg_vac_010_min_tuples'::bigint
  AND coalesce(array_to_string(c.reloptions, ' '), '') !~ 'autovacuum_vacuum_(scale_factor|threshold)'
ORDER BY c.reltuples DESC;
