-- check: MY-SEC-003
-- title: Anonymous accounts present
-- priority: 5 | category: SEC | scope: role | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src
-- An account with an empty User matches ANY username at authentication time.
-- Two consequences people are routinely surprised by: anyone can connect without
-- supplying a valid username, and — because MySQL sorts the user table
-- most-specific-host-first — an anonymous ''@'localhost' entry is matched BEFORE
-- a real 'app'@'%' entry for a connection from localhost, so a legitimate user
-- silently authenticates as the anonymous one and loses their privileges.
-- MariaDB's mariadb-install-db still creates these on some packagings; MySQL
-- 5.7+ does not, and mysql_secure_installation removes them.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-003' AS check_id,
  'role'       AS scope,
  CONCAT('(anonymous)@', a.acct_host) AS object,
  CONCAT('An anonymous account exists for host ''', a.acct_host,
         ''' (empty User), credential set: ', IF(a.has_credential, 'yes', 'no'),
         ', plugin ', a.acct_plugin, '. ',
         'An empty username matches any supplied username. Because account matching sorts the most specific host first, a connection from ''',
         a.acct_host, ''' will match this row BEFORE a real account with a wildcard host — so a legitimate user can silently authenticate as the anonymous account and lose their privileges. ',
         'Global privileges here: ', IF(a.priv_list = '', 'none', a.priv_list), '.') AS details,
  JSON_OBJECT(
    'user', '',
    'host', a.acct_host,
    'plugin', a.acct_plugin,
    'has_credential', a.has_credential,
    'global_privileges', a.priv_list) AS evidence_json,
  'high' AS confidence
FROM (ACCTSRC) AS a
WHERE a.acct_user = ''
  AND a.is_role = 0
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
