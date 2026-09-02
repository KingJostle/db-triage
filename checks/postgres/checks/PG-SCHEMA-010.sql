-- check: PG-SCHEMA-010
-- title: Database with more than 10,000 relations
-- priority: 150
-- scope: database
-- cost: 1
-- thresholds: max_relations
SELECT 'PG-SCHEMA-010'::text  AS check_id,
       'database'::text       AS scope,
       current_database()::text AS object,
       format('Database %s contains %s entries in pg_class (threshold %s): %s tables, %s indexes, %s toast tables, %s partitions, %s views and materialized views, %s sequences, across %s schemas. Every one is a catalog row that autovacuum has to consider on each cycle, that relcache has to hold per backend, and that information_schema has to walk. Past this scale, autovacuum scheduling latency, connection startup cost and catalog bloat all become visible. Frequently the cause is one schema per tenant or per customer.',
              current_database(), c.total, :'pg_schema_010_max_relations'::text,
              c.tables, c.indexes, c.toast, c.partitions, c.views, c.sequences,
              (SELECT count(*) FROM pg_namespace WHERE nspname NOT LIKE 'pg_%' AND nspname <> 'information_schema')) AS details,
       json_build_object('database', current_database(), 'pg_class_rows', c.total,
                         'tables', c.tables, 'indexes', c.indexes, 'toast_tables', c.toast,
                         'partitions', c.partitions, 'views', c.views, 'sequences', c.sequences,
                         'schemas', (SELECT count(*) FROM pg_namespace
                                     WHERE nspname NOT LIKE 'pg_%' AND nspname <> 'information_schema'),
                         'threshold', :'pg_schema_010_max_relations'::int)::text AS evidence_json,
       'high'::text AS confidence
FROM (
  SELECT count(*) AS total,
         count(*) FILTER (WHERE relkind IN ('r', 'p')) AS tables,
         count(*) FILTER (WHERE relkind = 'i')         AS indexes,
         count(*) FILTER (WHERE relkind = 't')         AS toast,
         count(*) FILTER (WHERE relispartition)        AS partitions,
         count(*) FILTER (WHERE relkind IN ('v', 'm')) AS views,
         count(*) FILTER (WHERE relkind = 'S')         AS sequences
  FROM pg_class
) c
WHERE c.total >= :'pg_schema_010_max_relations'::int;
