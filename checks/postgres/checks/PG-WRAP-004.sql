-- check: PG-WRAP-004
-- title: Tables driving transaction ID age
-- priority: 50
-- scope: relation
-- cost: 1
-- min_version: 9.6
-- thresholds: top_n, min_age
-- Emitted only when the relation ages in this database are themselves notable;
-- the report presents it under whichever of PG-WRAP-001/002/003 fired.
SELECT 'PG-WRAP-004'::text AS check_id,
       'relation'::text    AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('%s %s: age(relfrozenxid) = %s, mxid_age(relminmxid) = %s, size %s. %s',
              CASE c.relkind WHEN 'r' THEN 'table' WHEN 'm' THEN 'materialized view'
                             WHEN 't' THEN 'toast table' WHEN 'p' THEN 'partitioned table'
                             ELSE c.relkind::text END,
              c.relname,
              to_char(age(c.relfrozenxid), 'FM999,999,999,999'),
              to_char(mxid_age(c.relminmxid), 'FM999,999,999,999'),
              pg_size_pretty(pg_total_relation_size(c.oid)),
              coalesce('an autovacuum is processing it now, phase "' || p.phase || '", ' ||
                       round(100.0 * p.heap_blks_scanned / nullif(p.heap_blks_total, 0), 1)::text || '% of heap scanned',
                       'no vacuum is currently running on it')) AS details,
       json_build_object(
              'relkind', c.relkind,
              'relfrozenxid_age', age(c.relfrozenxid),
              'relminmxid_age', mxid_age(c.relminmxid),
              'total_bytes', pg_total_relation_size(c.oid),
              'vacuum_phase', p.phase,
              'heap_blks_total', p.heap_blks_total,
              'heap_blks_scanned', p.heap_blks_scanned,
              'reloptions', array_to_string(c.reloptions, ';'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_stat_progress_vacuum p ON p.relid = c.oid
WHERE c.relkind IN ('r', 'm', 't', 'p')
  AND c.relfrozenxid <> '0'::xid
  AND greatest(age(c.relfrozenxid), mxid_age(c.relminmxid)) >= :'pg_wrap_004_min_age'::bigint
ORDER BY greatest(age(c.relfrozenxid), mxid_age(c.relminmxid)) DESC
LIMIT :'pg_wrap_004_top_n'::int;
