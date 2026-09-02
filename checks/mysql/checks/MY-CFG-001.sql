-- check: MY-CFG-001
-- title: Non-default global variables
-- priority: 200 | category: CFG | scope: setting | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: (none)
-- reads: MySQL: performance_schema.variables_info joined to global_variables;
--        MariaDB: information_schema.SYSTEM_VARIABLES (GLOBAL_VALUE vs DEFAULT_VALUE)
-- THE fork divergence for configuration inventory, and there is no common path:
--   MySQL 5.7.9+  performance_schema.variables_info gives VARIABLE_SOURCE
--                 (COMPILED / GLOBAL / SERVER / EXPLICIT / PERSISTED / DYNAMIC /
--                 COMMAND_LINE / LOGIN / USER) plus VARIABLE_PATH and the file
--                 line number, but NOT the compiled default value.
--   MariaDB       has no variables_info at all (verified absent on 10.11) but
--                 information_schema.SYSTEM_VARIABLES carries DEFAULT_VALUE and
--                 GLOBAL_VALUE_ORIGIN, which is the better shape for this check.
-- So MySQL answers "where did this come from" and MariaDB answers "what was it
-- before" — the finding says which question it could answer.
-- This is P200 inventory, not a problem list: it is what a reader consults AFTER
-- the findings, to understand why the server behaves as it does. The noise list
-- below removes the values that differ on every server by construction
-- (hostnames, paths, ports, UUIDs, locale and timezone).
SET @dbt_cfg_noise := "('hostname','server_uuid','datadir','socket','pid_file','port',
  'log_error','basedir','plugin_dir','tmpdir','time_zone','system_time_zone','server_id',
  'general_log_file','slow_query_log_file','log_bin_basename','log_bin_index','relay_log',
  'relay_log_basename','relay_log_index','secure_file_priv','innodb_data_home_dir',
  'innodb_log_group_home_dir','innodb_temp_data_file_path','innodb_undo_directory',
  'character_sets_dir','lc_messages_dir','version','version_comment','version_compile_os',
  'version_compile_machine','version_suffix','version_source_revision','version_ssl_library',
  'version_malloc_library','report_host','report_port','open_files_limit','gtid_executed',
  'gtid_purged','gtid_binlog_pos','gtid_binlog_state','gtid_slave_pos','gtid_current_pos')";

SET @dbt_q_mysql := "
SELECT
  'MY-CFG-001' AS check_id,
  'setting'    AS scope,
  i.VARIABLE_NAME AS object,
  CONCAT('`', i.VARIABLE_NAME, '` = ''', SUBSTRING(IFNULL(g.VARIABLE_VALUE, ''), 1, 200),
         ''', source ', i.VARIABLE_SOURCE,
         IF(IFNULL(i.VARIABLE_PATH, '') <> '',
            CONCAT(' (', i.VARIABLE_PATH,
                   IF(i.VARIABLE_PATH IS NOT NULL, CONCAT(':', i.VARIABLE_SOURCE_LINE), ''), ')'), ''),
         IF(IFNULL(i.SET_USER, '') <> '',
            CONCAT(', last set by ', i.SET_USER, '@', IFNULL(i.SET_HOST, ''), ' at ', i.SET_TIME), ''),
         '. Not a finding: this is the configuration inventory, listing every variable this server did not take from its compiled default. ',
         'performance_schema.variables_info reports where a value came from but not what the compiled default was, so the previous value is not shown.') AS details,
  JSON_OBJECT(
    'variable', i.VARIABLE_NAME,
    'value', SUBSTRING(IFNULL(g.VARIABLE_VALUE, ''), 1, 500),
    'source', i.VARIABLE_SOURCE,
    'path', IFNULL(i.VARIABLE_PATH, ''),
    'source_line', i.VARIABLE_SOURCE_LINE,
    'set_user', IFNULL(i.SET_USER, ''),
    'set_time', CAST(i.SET_TIME AS CHAR),
    'catalog', 'performance_schema.variables_info') AS evidence_json,
  'high' AS confidence
FROM performance_schema.variables_info AS i
JOIN performance_schema.global_variables AS g ON g.VARIABLE_NAME = i.VARIABLE_NAME
WHERE i.VARIABLE_SOURCE <> 'COMPILED'
  AND i.VARIABLE_NAME NOT IN NOISE
ORDER BY i.VARIABLE_NAME";

SET @dbt_q_maria := "
SELECT
  'MY-CFG-001' AS check_id,
  'setting'    AS scope,
  LOWER(v.VARIABLE_NAME) AS object,
  CONCAT('`', LOWER(v.VARIABLE_NAME), '` = ''', SUBSTRING(IFNULL(v.GLOBAL_VALUE, ''), 1, 200),
         ''' (compiled default ''', SUBSTRING(IFNULL(v.DEFAULT_VALUE, '(none)'), 1, 200),
         '''), origin ', v.GLOBAL_VALUE_ORIGIN,
         IF(IFNULL(v.GLOBAL_VALUE_PATH, '') <> '', CONCAT(' from ', v.GLOBAL_VALUE_PATH), ''),
         ', scope ', v.VARIABLE_SCOPE, ', ',
         IF(v.READ_ONLY = 'YES', 'read-only (needs a restart to change)', 'dynamic'),
         '. Not a finding: this is the configuration inventory, listing every variable whose global value differs from the compiled default. ',
         'information_schema.SYSTEM_VARIABLES gives the default value but a coarser provenance than MySQL''s variables_info.') AS details,
  JSON_OBJECT(
    'variable', LOWER(v.VARIABLE_NAME),
    'value', SUBSTRING(IFNULL(v.GLOBAL_VALUE, ''), 1, 500),
    'default_value', SUBSTRING(IFNULL(v.DEFAULT_VALUE, ''), 1, 500),
    'origin', v.GLOBAL_VALUE_ORIGIN,
    'path', IFNULL(v.GLOBAL_VALUE_PATH, ''),
    'scope', v.VARIABLE_SCOPE,
    'read_only', v.READ_ONLY,
    'catalog', 'information_schema.SYSTEM_VARIABLES') AS evidence_json,
  'high' AS confidence
FROM information_schema.SYSTEM_VARIABLES AS v
WHERE v.VARIABLE_SCOPE IN ('GLOBAL', 'SESSION')
  AND v.GLOBAL_VALUE_ORIGIN <> 'COMPILED'
  AND NOT (IFNULL(v.GLOBAL_VALUE, '') <=> IFNULL(v.DEFAULT_VALUE, ''))
  AND LOWER(v.VARIABLE_NAME) NOT IN NOISE
ORDER BY v.VARIABLE_NAME";

SET @dbt_q := CASE
  WHEN IFNULL(@dbt_has_variables_info, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1
    THEN REPLACE(@dbt_q_mysql, 'NOISE', @dbt_cfg_noise)
  WHEN IFNULL(@dbt_has_is_sysvars, 0) = 1
    THEN REPLACE(@dbt_q_maria, 'NOISE', @dbt_cfg_noise)
  ELSE 'DO 1'
END;
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
