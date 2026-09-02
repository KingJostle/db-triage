-- check: PG-IDX-004
-- title: Duplicate indexes
-- priority: 50
-- scope: index
-- cost: 1
WITH sig AS (
  SELECT i.indexrelid, i.indrelid,
         n.nspname, tc.relname AS table_name, ic.relname AS index_name,
         pg_relation_size(i.indexrelid) AS index_bytes,
         s.idx_scan,
         i.indisunique, i.indisprimary,
         EXISTS (SELECT 1 FROM pg_constraint con WHERE con.conindid = i.indexrelid) AS backs_constraint,
         format('%s|%s|%s|%s|%s|%s|%s',
                ic.relam, i.indkey::text, i.indclass::text, i.indoption::text,
                coalesce(pg_get_expr(i.indexprs, i.indrelid), ''),
                coalesce(pg_get_expr(i.indpred, i.indrelid), ''),
                i.indisunique) AS signature
  FROM pg_index i
  JOIN pg_class ic    ON ic.oid = i.indexrelid
  JOIN pg_class tc    ON tc.oid = i.indrelid
  JOIN pg_namespace n ON n.oid = ic.relnamespace
  LEFT JOIN pg_stat_user_indexes s ON s.indexrelid = i.indexrelid
  WHERE i.indisvalid
    AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
),
grp AS (
  SELECT indrelid, nspname, table_name, signature, count(*) AS n,
         sum(index_bytes) AS total_bytes,
         string_agg(format('%s (%s, %s scans%s)', index_name, pg_size_pretty(index_bytes),
                           coalesce(idx_scan::text, 'unknown'),
                           CASE WHEN backs_constraint THEN ', backs a constraint' ELSE '' END),
                    '; ' ORDER BY backs_constraint DESC, index_bytes DESC) AS members,
         (array_agg(index_name ORDER BY backs_constraint DESC, idx_scan DESC NULLS LAST, index_bytes DESC))[1] AS keeper
  FROM sig GROUP BY 1, 2, 3, 4 HAVING count(*) > 1
)
SELECT 'PG-IDX-004'::text AS check_id,
       'index'::text      AS scope,
       format('%I.%I.%I', current_database(), g.nspname, g.table_name)::text AS object,
       format('%s indexes on %s.%s are identical in every catalog column that determines what an index can answer - access method, key columns, operator classes, sort options, expression, predicate and uniqueness: %s. Together they occupy %s and every write to the table maintains all of them. Keep %s (it backs a constraint or has the most recorded use) and drop the rest with DROP INDEX CONCURRENTLY. Usage counters are per instance: check the standbys first.',
              g.n, g.nspname, g.table_name, g.members,
              pg_size_pretty(g.total_bytes), g.keeper) AS details,
       json_build_object('schema', g.nspname, 'table', g.table_name,
                         'duplicate_count', g.n, 'total_bytes', g.total_bytes,
                         'members', g.members, 'suggested_keeper', g.keeper,
                         'signature', g.signature)::text AS evidence_json,
       'high'::text AS confidence
FROM grp g
ORDER BY g.total_bytes DESC;
