-- check: MY-SEC-002
-- title: Superuser-equivalent account reachable from any host
-- priority: 1 | category: SEC | scope: role | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src
-- The classic root@'%'. Two conditions must both hold: the account holds SUPER
-- or the full global privilege set, AND its host pattern is a wildcard rather
-- than a specific address. Either alone is defensible; together they mean a
-- single leaked or guessed credential is complete control of the server, from
-- anywhere the network allows.
-- Host patterns treated as unrestricted: '%', '', '%.%', and wildcards that
-- cover whole public ranges. A bare IP or a fully qualified name is not flagged
-- here — MY-SEC-007 lists all privileged accounts for review regardless.
-- Platform-managed accounts (rdsadmin, cloudsqladmin, mysql.sys, mariadb.sys...)
-- are excluded; they are created by the vendor and cannot be removed.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-002' AS check_id,
  'role'       AS scope,
  CONCAT(a.acct_user, '@', a.acct_host) AS object,
  CONCAT('Account ''', a.acct_user, '''@''', a.acct_host,
         ''' holds ', IF(a.has_all_privs, 'the full global privilege set', 'SUPER'),
         ' (', a.priv_list, ') and its host pattern matches any host. ',
         'Authentication plugin: ', a.acct_plugin,
         ', credential set: ', IF(a.has_credential, 'yes', 'NO — see MY-SEC-001'),
         ', account locked: ', IF(a.account_locked, 'yes', 'no'), '. ',
         'The server listens on ', @@GLOBAL.bind_address, ':', @@GLOBAL.port,
         ', so one leaked credential is complete control of this instance from anywhere the network permits.') AS details,
  JSON_OBJECT(
    'user', a.acct_user,
    'host', a.acct_host,
    'plugin', a.acct_plugin,
    'has_all_privileges', a.has_all_privs,
    'global_privileges', a.priv_list,
    'has_credential', a.has_credential,
    'account_locked', a.account_locked,
    'bind_address', @@GLOBAL.bind_address,
    'port', @@GLOBAL.port) AS evidence_json,
  'high' AS confidence
FROM (ACCTSRC) AS a
WHERE a.is_role = 0
  AND a.account_locked = 0
  AND (a.Super_priv = 'Y' OR a.has_all_privs)
  AND (a.acct_host IN ('%', '') OR a.acct_host LIKE '%\\%%')
  AND a.acct_user NOT IN ACCTSYS
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
