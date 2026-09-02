-- check: MY-REL-010
-- title: Persisted variables override the configuration files
-- priority: 100 | category: REL | scope: setting | cost: 0 | pass: fast
-- engine: mysql | min_version: 8.0 | requires: SELECT ON performance_schema.*
-- thresholds: (none)
-- reads: performance_schema.persisted_variables, performance_schema.variables_info
-- MySQL 8.0 only. SET PERSIST writes to mysqld-auto.cnf in the data directory,
-- which is read AFTER every other configuration file — so a persisted value
-- silently wins over my.cnf, over the packaging defaults and over whatever the
-- configuration-management system believes it applied.
-- MariaDB has no SET PERSIST and no persisted_variables table (verified absent
-- on 10.11), so the check emits nothing there.
-- The failure this catches: someone fixes an incident at 03:00 with SET PERSIST,
-- the change is invisible in every file under version control, and six months
-- later a rebuilt server behaves differently from its predecessor for reasons
-- nobody can find. VARIABLE_SOURCE in variables_info distinguishes PERSISTED
-- from EXPLICIT (a file) and shows which file and line a file-sourced value
-- came from.
SET @dbt_q := "
SELECT
  'MY-REL-010' AS check_id,
  'setting'    AS scope,
  p.VARIABLE_NAME AS object,
  CONCAT('`', p.VARIABLE_NAME, '` is persisted in mysqld-auto.cnf with value ''',
         SUBSTRING(p.VARIABLE_VALUE, 1, 120), '''',
         IFNULL(CONCAT(', set by ', p.SET_USER, '@', p.SET_HOST, ' on ', p.SET_TIME), ''),
         '. The running value is ''', SUBSTRING(IFNULL(g.VARIABLE_VALUE, ''), 1, 120),
         ''' with source ', IFNULL(i.VARIABLE_SOURCE, 'unknown'),
         IF(IFNULL(i.VARIABLE_PATH, '') <> '', CONCAT(' (', i.VARIABLE_PATH, ')'), ''), '. ',
         'mysqld-auto.cnf is read after every other configuration file, so this value wins over my.cnf and over anything configuration management applies. ',
         'A change made this way is invisible in version control, which is how a rebuilt server ends up behaving differently from its predecessor for no findable reason. ',
         'RESET PERSIST <name> removes it.') AS details,
  JSON_OBJECT(
    'variable', p.VARIABLE_NAME,
    'persisted_value', SUBSTRING(p.VARIABLE_VALUE, 1, 500),
    'running_value', SUBSTRING(IFNULL(g.VARIABLE_VALUE, ''), 1, 500),
    'variable_source', IFNULL(i.VARIABLE_SOURCE, 'unknown'),
    'variable_path', IFNULL(i.VARIABLE_PATH, ''),
    'set_by', CONCAT(IFNULL(p.SET_USER, ''), '@', IFNULL(p.SET_HOST, '')),
    'set_time', CAST(p.SET_TIME AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM performance_schema.persisted_variables AS p
LEFT JOIN performance_schema.global_variables AS g ON g.VARIABLE_NAME = p.VARIABLE_NAME
LEFT JOIN performance_schema.variables_info  AS i ON i.VARIABLE_NAME = p.VARIABLE_NAME
ORDER BY p.VARIABLE_NAME";
SET @dbt_q := IF(IFNULL(@dbt_has_persisted_variables, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1,
                 @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
