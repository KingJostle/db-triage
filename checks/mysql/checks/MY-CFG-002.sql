-- check: MY-CFG-002
-- title: Persisted variables (inventory)
-- priority: 200 | category: CFG | scope: setting | cost: 0 | pass: inventory
-- engine: mysql | min_version: 8.0 | requires: SELECT ON performance_schema.*
-- thresholds: (none)
-- reads: performance_schema.persisted_variables
-- MySQL 8.0 only; MariaDB has no SET PERSIST and no such table (verified absent
-- on 10.11), so this emits nothing there.
-- The plain inventory of what is in mysqld-auto.cnf. MY-REL-010 is the FINDING
-- for the subset that conflicts with a file-sourced value; this row lists every
-- persisted variable regardless, because a reviewer comparing a server against
-- its configuration repository needs the whole list, not just the conflicts.
SET @dbt_q := "
SELECT
  'MY-CFG-002' AS check_id,
  'setting'    AS scope,
  p.VARIABLE_NAME AS object,
  CONCAT('`', p.VARIABLE_NAME, '` is persisted in mysqld-auto.cnf as ''',
         SUBSTRING(p.VARIABLE_VALUE, 1, 200), '''',
         IF(IFNULL(p.SET_USER, '') <> '',
            CONCAT(', set by ', p.SET_USER, '@', IFNULL(p.SET_HOST, ''), ' at ', p.SET_TIME), ''),
         '. Inventory only. mysqld-auto.cnf lives in the data directory and is read after every other configuration file, so anything here overrides my.cnf. ',
         'MY-REL-010 reports the subset that actually conflicts with a file-sourced value. ',
         'To remove one: RESET PERSIST `', p.VARIABLE_NAME, '`.') AS details,
  JSON_OBJECT(
    'variable', p.VARIABLE_NAME,
    'persisted_value', SUBSTRING(p.VARIABLE_VALUE, 1, 500),
    'set_user', IFNULL(p.SET_USER, ''),
    'set_host', IFNULL(p.SET_HOST, ''),
    'set_time', CAST(p.SET_TIME AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM performance_schema.persisted_variables AS p
ORDER BY p.VARIABLE_NAME";
SET @dbt_q := IF(IFNULL(@dbt_has_persisted_variables, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1,
                 @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
