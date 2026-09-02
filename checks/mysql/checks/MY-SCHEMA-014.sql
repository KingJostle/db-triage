-- check: MY-SCHEMA-014
-- title: Character set or collation inconsistent within a schema
-- priority: 150 | category: SCHEMA | scope: schema | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.SCHEMATA, information_schema.TABLES, information_schema.COLUMNS
-- NOT in the design's §5.2 table. Added as the next free number in the category
-- because collation drift is a correctness and performance defect in its own
-- right, distinct from MY-SCHEMA-012's "these are legacy" inventory.
-- The mechanism, which is the part that surprises people: joining or comparing
-- two string columns with different collations forces MySQL to convert one side
-- at runtime. A converted column is a function of a column, so ANY INDEX ON IT
-- IS UNUSABLE. A join that has always used an index starts full-scanning the
-- moment one table is converted to utf8mb4 and the other is not — and EXPLAIN
-- shows the scan without ever saying why.
-- The second effect is correctness: two rows equal under utf8mb4_general_ci can
-- be unequal under utf8mb4_0900_ai_ci, so a UNIQUE constraint means different
-- things on different tables in the same schema.
-- Reported per schema, with the dominant collation and the exceptions named, so
-- the fix list is immediately actionable.
SELECT
  'MY-SCHEMA-014' AS check_id,
  'schema'        AS scope,
  x.sch           AS object,
  CONCAT('Schema `', x.sch, '` mixes ', x.n_collations,
         ' table collations across ', x.total, ' tables. Schema default: ',
         x.schema_collation, '. Dominant table collation: ', x.dominant,
         ' (', x.dominant_n, ' tables). Exceptions: ', x.exceptions, '. ',
         c.col_note,
         'Comparing or joining string columns whose collations differ forces a runtime conversion of one side, and a converted column cannot use its index — so a join that has always been indexed silently becomes a full scan, and EXPLAIN shows the scan without explaining it. ',
         'Collations also disagree about equality, so a UNIQUE constraint means different things on different tables here.') AS details,
  JSON_OBJECT(
    'schema', x.sch,
    'schema_collation', x.schema_collation,
    'table_count', x.total,
    'distinct_table_collations', x.n_collations,
    'dominant_collation', x.dominant,
    'dominant_table_count', x.dominant_n,
    'exceptions', x.exceptions,
    'distinct_column_collations', c.n_col_collations) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT t.TABLE_SCHEMA AS sch,
         s.DEFAULT_COLLATION_NAME AS schema_collation,
         COUNT(*) AS total,
         COUNT(DISTINCT t.TABLE_COLLATION) AS n_collations,
         (SELECT t2.TABLE_COLLATION FROM information_schema.TABLES AS t2
           WHERE t2.TABLE_SCHEMA = t.TABLE_SCHEMA AND t2.TABLE_TYPE = 'BASE TABLE'
           GROUP BY t2.TABLE_COLLATION ORDER BY COUNT(*) DESC LIMIT 1) AS dominant,
         (SELECT COUNT(*) FROM information_schema.TABLES AS t3
           WHERE t3.TABLE_SCHEMA = t.TABLE_SCHEMA AND t3.TABLE_TYPE = 'BASE TABLE'
             AND t3.TABLE_COLLATION = (SELECT t4.TABLE_COLLATION FROM information_schema.TABLES AS t4
                WHERE t4.TABLE_SCHEMA = t.TABLE_SCHEMA AND t4.TABLE_TYPE = 'BASE TABLE'
                GROUP BY t4.TABLE_COLLATION ORDER BY COUNT(*) DESC LIMIT 1)) AS dominant_n,
         SUBSTRING(GROUP_CONCAT(DISTINCT CONCAT(t.TABLE_NAME, ' = ', t.TABLE_COLLATION)
           SEPARATOR '; '), 1, 400) AS exceptions
  FROM information_schema.TABLES AS t
  JOIN information_schema.SCHEMATA AS s ON s.SCHEMA_NAME = t.TABLE_SCHEMA
  WHERE t.TABLE_TYPE = 'BASE TABLE'
    AND t.TABLE_COLLATION IS NOT NULL
    AND t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  GROUP BY t.TABLE_SCHEMA, s.DEFAULT_COLLATION_NAME
) AS x
LEFT JOIN (
  SELECT TABLE_SCHEMA AS sch,
         COUNT(DISTINCT COLLATION_NAME) AS n_col_collations,
         IF(COUNT(DISTINCT COLLATION_NAME) > 1,
            CONCAT('Column level is worse: ', COUNT(DISTINCT COLLATION_NAME),
                   ' distinct collations across string columns. '), '') AS col_note
  FROM information_schema.COLUMNS
  WHERE COLLATION_NAME IS NOT NULL
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  GROUP BY TABLE_SCHEMA
) AS c ON c.sch = x.sch
WHERE x.n_collations > 1;
