-- check: PG-CFG-003
-- title: Per-relation storage parameters
-- priority: 200
-- scope: relation
-- cost: 1
SELECT 'PG-CFG-003'::text AS check_id,
       'relation'::text   AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('%s %s.%s carries storage parameters: %s. Size %s. Per-relation parameters override the server-wide autovacuum and vacuum settings for this object only, so a table that is not being vacuumed the way the global configuration says it should be usually has its answer here (see PG-VAC-009 and PG-VAC-010).',
              CASE c.relkind WHEN 'r' THEN 'Table' WHEN 'p' THEN 'Partitioned table'
                             WHEN 'm' THEN 'Materialized view' WHEN 'i' THEN 'Index'
                             ELSE c.relkind::text END,
              n.nspname, c.relname,
              array_to_string(c.reloptions, ', '),
              pg_size_pretty(pg_total_relation_size(c.oid))) AS details,
       json_build_object('schema', n.nspname, 'relname', c.relname, 'relkind', c.relkind,
                         'reloptions', array_to_string(c.reloptions, ';'),
                         'total_bytes', pg_total_relation_size(c.oid))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.reloptions IS NOT NULL
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY pg_total_relation_size(c.oid) DESC;
