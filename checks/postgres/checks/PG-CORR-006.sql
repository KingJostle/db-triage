-- check: PG-CORR-006
-- title: Collation version mismatch (index corruption risk)
-- priority: 20
-- scope: database
-- cost: 0
-- min_version: 13
\set ON_ERROR_STOP off
SELECT (current_setting('server_version_num')::int >= 150000) AS pg_corr_006_has_db_collversion \gset
\if :pg_corr_006_has_db_collversion
SELECT 'PG-CORR-006'::text AS check_id,
       'database'::text    AS scope,
       d.datname::text     AS object,
       format('Database %s was created against collation version %s of %s, but the operating system now provides version %s. A collation upgrade changes sort order, so B-tree indexes on text columns built before the change may no longer be in the order the planner assumes: equality and range lookups can silently miss rows. Rebuild the affected text indexes with REINDEX, then run ALTER DATABASE %s REFRESH COLLATION VERSION.',
              d.datname, coalesce(d.datcollversion, 'unknown'), d.datcollate,
              coalesce(pg_database_collation_actual_version(d.oid), 'unknown'),
              quote_ident(d.datname)) AS details,
       json_build_object('object_kind', 'database', 'datname', d.datname,
                         'recorded_version', d.datcollversion,
                         'actual_version', pg_database_collation_actual_version(d.oid),
                         'datcollate', d.datcollate, 'datctype', d.datctype)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_database d
WHERE d.datcollversion IS NOT NULL
  AND pg_database_collation_actual_version(d.oid) IS NOT NULL
  AND d.datcollversion IS DISTINCT FROM pg_database_collation_actual_version(d.oid);
\endif

SELECT 'PG-CORR-006'::text AS check_id,
       'database'::text    AS scope,
       format('%I.collation:%s', current_database(), c.collname)::text AS object,
       format('Collation %s (provider %s) records version %s but the operating system now provides version %s. Every text index using this collation was built under the old sort order. %s index(es) in this database reference it. Rebuild them with REINDEX, then ALTER COLLATION %s REFRESH VERSION.',
              c.collname,
              CASE c.collprovider WHEN 'c' THEN 'libc' WHEN 'i' THEN 'icu' WHEN 'b' THEN 'builtin' ELSE c.collprovider::text END,
              coalesce(c.collversion, 'unknown'),
              coalesce(pg_collation_actual_version(c.oid), 'unknown'),
              (SELECT count(*) FROM pg_index i WHERE c.oid = ANY (i.indcollation::oid[])),
              quote_ident(c.collname)) AS details,
       json_build_object('object_kind', 'collation', 'collname', c.collname,
                         'collprovider', c.collprovider::text,
                         'recorded_version', c.collversion,
                         'actual_version', pg_collation_actual_version(c.oid),
                         'dependent_indexes', (SELECT count(*) FROM pg_index i WHERE c.oid = ANY (i.indcollation::oid[])))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_collation c
WHERE c.collversion IS NOT NULL
  AND pg_collation_actual_version(c.oid) IS NOT NULL
  AND c.collversion IS DISTINCT FROM pg_collation_actual_version(c.oid);
