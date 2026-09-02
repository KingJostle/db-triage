-- check: PG-VAC-012
-- title: Low HOT-update ratio on update-heavy tables
-- priority: 150
-- scope: relation
-- cost: 1
-- thresholds: min_updates, hot_ratio
SELECT 'PG-VAC-012'::text AS check_id,
       'relation'::text   AS scope,
       format('%I.%I.%I', current_database(), t.schemaname, t.relname)::text AS object,
       format('%s updates since the statistics reset, of which %s (%s%%, threshold %s%%) were heap-only. fillfactor is at the default 100, so an update that does not fit on the page must write a new tuple in a new page and add an entry to every index. Size %s, %s indexes. A lower fillfactor helps only if the updated columns are not themselves indexed, which cannot be determined from the catalog.',
              to_char(t.n_tup_upd, 'FM999,999,999,999'),
              to_char(t.n_tup_hot_upd, 'FM999,999,999,999'),
              round(100.0 * t.n_tup_hot_upd / nullif(t.n_tup_upd, 0), 1)::text,
              round(100 * :'pg_vac_012_hot_ratio'::numeric)::text,
              pg_size_pretty(pg_total_relation_size(t.relid)),
              (SELECT count(*) FROM pg_index i WHERE i.indrelid = t.relid)) AS details,
       json_build_object('n_tup_upd', t.n_tup_upd, 'n_tup_hot_upd', t.n_tup_hot_upd,
                         'hot_ratio', round(t.n_tup_hot_upd::numeric / nullif(t.n_tup_upd, 0), 4),
                         'threshold_ratio', :'pg_vac_012_hot_ratio'::numeric,
                         'total_bytes', pg_total_relation_size(t.relid),
                         'index_count', (SELECT count(*) FROM pg_index i WHERE i.indrelid = t.relid))::text AS evidence_json,
       'low'::text AS confidence
FROM pg_stat_user_tables t
JOIN pg_class c ON c.oid = t.relid
WHERE t.n_tup_upd >= :'pg_vac_012_min_updates'::bigint
  AND t.n_tup_hot_upd::numeric / nullif(t.n_tup_upd, 0) < :'pg_vac_012_hot_ratio'::numeric
  AND coalesce(array_to_string(c.reloptions, ' '), '') !~ 'fillfactor'
ORDER BY t.n_tup_upd DESC
LIMIT 10;
