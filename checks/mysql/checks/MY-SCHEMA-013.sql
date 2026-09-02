-- check: MY-SCHEMA-013
-- title: Shared InnoDB tablespace in use
-- priority: 50 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.innodb_file_per_table, information_schema.INNODB_TABLES (MySQL 8.0)
--        or information_schema.INNODB_SYS_TABLES (MySQL 5.7 / MariaDB)
-- Catalog rename, verified: MySQL 8.0 renamed every INNODB_SYS_* table to
-- INNODB_* (INNODB_SYS_TABLES became INNODB_TABLES). MariaDB 10.11 kept the
-- INNODB_SYS_* names (verified present). The check probes for whichever exists
-- and emits nothing if neither does.
-- Why it matters: ibdata1 only ever grows. Dropping a table stored inside it
-- returns the space to InnoDB's free list, never to the filesystem, and the only
-- way to shrink it is a full logical dump and reload of the entire instance.
-- Per-table tablespaces also unlock transportable tablespaces, per-table
-- compression, and TRUNCATE actually freeing space.
SET @dbt_q := "
SELECT
  'MY-SCHEMA-013' AS check_id,
  'relation'      AS scope,
  'innodb_system' AS object,
  CONCAT(IF(@@GLOBAL.innodb_file_per_table = 0,
            'innodb_file_per_table = OFF, so every new InnoDB table is created inside the shared system tablespace. ',
            'innodb_file_per_table = ON, but '),
         x.n, ' existing table(s) still live in the shared system tablespace: ', x.list,
         '. ibdata1 never shrinks: dropping or truncating a table inside it returns the space to InnoDB''s internal free list, not to the filesystem, and the only way to reclaim it is a full logical dump and reload of the whole instance. ',
         'Per-table tablespaces also enable transportable tablespaces and per-table compression.') AS details,
  JSON_OBJECT(
    'innodb_file_per_table', CAST(@@GLOBAL.innodb_file_per_table AS CHAR),
    'tables_in_system_tablespace', x.n,
    'tables', x.list,
    'catalog', x.src) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n,
         SUBSTRING(GROUP_CONCAT(NAME ORDER BY NAME SEPARATOR ', '), 1, 500) AS list,
         'CATALOGNAME' AS src
    FROM information_schema.CATALOGNAME
   WHERE SPACE = 0
     AND NAME NOT LIKE 'mysql/%'
     AND NAME NOT LIKE 'sys/%'
     AND NAME LIKE '%/%'
) AS x
WHERE x.n > 0 OR @@GLOBAL.innodb_file_per_table = 0";

SET @dbt_q := CASE
  WHEN IFNULL(@dbt_has_innodb_tables, 0) = 1     THEN REPLACE(@dbt_q, 'CATALOGNAME', 'INNODB_TABLES')
  WHEN IFNULL(@dbt_has_innodb_sys_tables, 0) = 1 THEN REPLACE(@dbt_q, 'CATALOGNAME', 'INNODB_SYS_TABLES')
  ELSE 'DO 1'
END;
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
