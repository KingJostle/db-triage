-- check: MY-SEC-011
-- title: No password validation policy
-- priority: 150 | category: SEC | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.PLUGINS, mysql.component (MySQL 8.0+)
-- Fork divergence in both the mechanism and the name:
--   MySQL 5.7        validate_password PLUGIN
--   MySQL 8.0+       validate_password COMPONENT, registered in mysql.component
--                    (the plugin form still loads but is deprecated)
--   MariaDB          simple_password_check and/or cracklib_password_check
--                    plugins; there is no validate_password at all
-- All three are probed; the component table is only consulted where it exists.
-- Without any of them the server accepts a one-character password, which matters
-- most for the accounts MY-SEC-002/004 says are reachable from anywhere.
-- Password EXPIRY is deliberately not part of this finding: forced rotation is
-- reported as a review row at P200 (MY-SEC-013) rather than as a defect, because
-- current guidance does not treat expiry as a control.
SET @dbt_q := "
SELECT
  'MY-SEC-011' AS check_id,
  'cluster'    AS scope,
  'password-policy' AS object,
  CONCAT('No password validation plugin or component is active: ',
         IF(@dbt_is_mariadb,
            'neither simple_password_check nor cracklib_password_check is loaded',
            'validate_password is loaded as neither a component nor a plugin'),
         '. The server will accept any password, including a single character, for every account — including the ',
         a.wildcard_accounts, ' account(s) reachable from any host (MY-SEC-004). ',
         'Active authentication-related plugins: ', IFNULL(p.auth_plugins, 'none'), '.') AS details,
  JSON_OBJECT(
    'validation_active', 0,
    'fork', @dbt_fork,
    'active_auth_plugins', IFNULL(p.auth_plugins, ''),
    'wildcard_host_accounts', a.wildcard_accounts) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT SUM(PLUGIN_STATUS = 'ACTIVE'
             AND (PLUGIN_NAME LIKE 'validate\\_password%'
               OR PLUGIN_NAME LIKE '%password\\_check%')) AS validators,
         SUBSTRING(GROUP_CONCAT(IF(PLUGIN_TYPE = 'AUTHENTICATION' AND PLUGIN_STATUS = 'ACTIVE',
                                   PLUGIN_NAME, NULL) SEPARATOR ', '), 1, 300) AS auth_plugins
    FROM information_schema.PLUGINS
) AS p,
(
  SELECT COUNT(*) AS wildcard_accounts FROM information_schema.USER_PRIVILEGES
   WHERE GRANTEE LIKE '%@''%'
) AS a
WHERE IFNULL(p.validators, 0) = 0
  AND IFNULL(@dbt_component_validate_password, 0) = 0";

-- mysql.component exists only on MySQL 8.0+; MariaDB has no component registry.
SET @dbt_component_validate_password := 0;
SET @dbt_q2 := IF(IFNULL(@dbt_has_mysql_component, 0) = 1 AND IFNULL(@dbt_priv_mysql_schema, 0) = 1,
  "SELECT COUNT(*) INTO @dbt_component_validate_password FROM mysql.component
     WHERE component_urn LIKE '%validate_password%'",
  'DO 1');
PREPARE dbt_stmt FROM @dbt_q2; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
PREPARE dbt_stmt FROM @dbt_q;  EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
