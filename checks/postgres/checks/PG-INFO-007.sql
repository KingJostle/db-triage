-- check: PG-INFO-007
-- title: Object counts
-- priority: 250
-- scope: database
-- cost: 1
SELECT 'PG-INFO-007'::text  AS check_id,
       'database'::text     AS scope,
       current_database()::text AS object,
       format('Database %s (%s): %s ordinary tables, %s partitioned tables, %s partitions, %s indexes, %s views, %s materialized views, %s sequences, %s foreign tables, %s toast tables. %s user schemas, %s user functions, %s triggers, %s foreign-key constraints. Total pg_class rows: %s.',
              current_database(), pg_size_pretty(pg_database_size(current_database())),
              c.tables, c.partitioned, c.partitions, c.indexes, c.views, c.matviews,
              c.sequences, c.foreign_tables, c.toast,
              (SELECT count(*) FROM pg_namespace WHERE nspname NOT LIKE 'pg\_%' AND nspname <> 'information_schema'),
              (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')),
              (SELECT count(*) FROM pg_trigger WHERE NOT tgisinternal),
              (SELECT count(*) FROM pg_constraint WHERE contype = 'f'),
              c.total) AS details,
       json_build_object('database', current_database(),
                         'database_bytes', pg_database_size(current_database()),
                         'tables', c.tables, 'partitioned_tables', c.partitioned, 'partitions', c.partitions,
                         'indexes', c.indexes, 'views', c.views, 'matviews', c.matviews,
                         'sequences', c.sequences, 'foreign_tables', c.foreign_tables,
                         'toast_tables', c.toast, 'pg_class_rows', c.total,
                         'schemas', (SELECT count(*) FROM pg_namespace
                                     WHERE nspname NOT LIKE 'pg\_%' AND nspname <> 'information_schema'),
                         'functions', (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                                       WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')),
                         'triggers', (SELECT count(*) FROM pg_trigger WHERE NOT tgisinternal),
                         'foreign_keys', (SELECT count(*) FROM pg_constraint WHERE contype = 'f'))::text AS evidence_json,
       'high'::text AS confidence
FROM (
  SELECT count(*) AS total,
         count(*) FILTER (WHERE relkind = 'r' AND NOT relispartition) AS tables,
         count(*) FILTER (WHERE relkind = 'p')                        AS partitioned,
         count(*) FILTER (WHERE relispartition)                       AS partitions,
         count(*) FILTER (WHERE relkind = 'i')                        AS indexes,
         count(*) FILTER (WHERE relkind = 'v')                        AS views,
         count(*) FILTER (WHERE relkind = 'm')                        AS matviews,
         count(*) FILTER (WHERE relkind = 'S')                        AS sequences,
         count(*) FILTER (WHERE relkind = 'f')                        AS foreign_tables,
         count(*) FILTER (WHERE relkind = 't')                        AS toast
  FROM pg_class
) c;
