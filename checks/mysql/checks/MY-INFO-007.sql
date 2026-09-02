-- check: MY-INFO-007
-- title: Object counts
-- priority: 250 | category: INFO | scope: cluster | cost: 1 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema TABLES, VIEWS, ROUTINES, TRIGGERS, EVENTS, PARTITIONS,
--        STATISTICS, TABLE_CONSTRAINTS
-- Always emitted, and the storage-engine breakdown here is the inventory half of
-- MY-DUR-007 (which is the finding half): DUR-007 fires only on non-transactional
-- engines, whereas this row shows the whole picture including how many tables are
-- InnoDB, so "all 4,000 tables are InnoDB" is visible as a positive fact.
-- The relation count also drives the design's XX-META-007 sampling rule: above
-- 50,000 relations the per-relation checks are expected to fall back to top-N.
SELECT
  'MY-INFO-007' AS check_id,
  'cluster'     AS scope,
  'object-counts' AS object,
  CONCAT(o.n_tables, ' base table(s) across ', o.n_schemas, ' user schema(s), by engine: ',
         o.n_by_engine, '. ',
         o.n_views, ' view(s), ', o.n_routines, ' routine(s) (', o.n_procs, ' procedures, ',
         o.n_funcs, ' functions), ', o.n_triggers, ' trigger(s), ', o.n_events, ' event(s), ',
         o.n_partitions, ' partition(s) across ', o.n_partitioned, ' partitioned table(s). ',
         o.n_indexes, ' index(es), ', o.n_pks, ' primary key(s), ', o.n_fks, ' foreign key(s), ',
         o.n_uniques, ' unique constraint(s). ',
         IF(o.n_tables > o.n_pks, CONCAT(o.n_tables - o.n_pks, ' table(s) have no primary key — see MY-SCHEMA-001/002. '), ''),
         IF(o.n_tables >= 50000,
            'Over 50,000 relations: per-relation checks fall back to top-N sampling (XX-META-007). ', '')) AS details,
  JSON_OBJECT(
    'base_tables', o.n_tables, 'user_schemas', o.n_schemas, 'by_engine', o.n_by_engine,
    'views', o.n_views, 'routines', o.n_routines, 'procedures', o.n_procs, 'functions', o.n_funcs,
    'triggers', o.n_triggers, 'events', o.n_events,
    'partitions', o.n_partitions, 'partitioned_tables', o.n_partitioned,
    'indexes', o.n_indexes, 'primary_keys', o.n_pks, 'foreign_keys', o.n_fks,
    'unique_constraints', o.n_uniques,
    'tables_without_pk', GREATEST(o.n_tables - o.n_pks, 0)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    (SELECT COUNT(*) FROM information_schema.TABLES
      WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_tables,
    (SELECT COUNT(DISTINCT TABLE_SCHEMA) FROM information_schema.TABLES
      WHERE TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_schemas,
    (SELECT SUBSTRING(GROUP_CONCAT(CONCAT(ENGINE, '=', n) ORDER BY n DESC SEPARATOR ', '), 1, 300)
       FROM (SELECT ENGINE, COUNT(*) AS n FROM information_schema.TABLES
              WHERE TABLE_TYPE = 'BASE TABLE' AND ENGINE IS NOT NULL
                AND TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')
              GROUP BY ENGINE) AS t) AS n_by_engine,
    (SELECT COUNT(*) FROM information_schema.VIEWS
      WHERE TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_views,
    (SELECT COUNT(*) FROM information_schema.ROUTINES
      WHERE ROUTINE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_routines,
    (SELECT COUNT(*) FROM information_schema.ROUTINES
      WHERE ROUTINE_TYPE = 'PROCEDURE' AND ROUTINE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_procs,
    (SELECT COUNT(*) FROM information_schema.ROUTINES
      WHERE ROUTINE_TYPE = 'FUNCTION' AND ROUTINE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_funcs,
    (SELECT COUNT(*) FROM information_schema.TRIGGERS
      WHERE TRIGGER_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_triggers,
    (SELECT COUNT(*) FROM information_schema.EVENTS
      WHERE EVENT_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_events,
    (SELECT COUNT(*) FROM information_schema.PARTITIONS
      WHERE PARTITION_NAME IS NOT NULL AND TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_partitions,
    (SELECT COUNT(DISTINCT CONCAT(TABLE_SCHEMA, '.', TABLE_NAME)) FROM information_schema.PARTITIONS
      WHERE PARTITION_NAME IS NOT NULL AND TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_partitioned,
    (SELECT COUNT(DISTINCT CONCAT(TABLE_SCHEMA, '.', TABLE_NAME, '.', INDEX_NAME)) FROM information_schema.STATISTICS
      WHERE TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_indexes,
    (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
      WHERE CONSTRAINT_TYPE = 'PRIMARY KEY' AND CONSTRAINT_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_pks,
    (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
      WHERE CONSTRAINT_TYPE = 'FOREIGN KEY' AND CONSTRAINT_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_fks,
    (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
      WHERE CONSTRAINT_TYPE = 'UNIQUE' AND CONSTRAINT_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_uniques
) AS o;
