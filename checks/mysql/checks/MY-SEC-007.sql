-- check: MY-SEC-007
-- title: Privileged accounts (review list)
-- priority: 230 | category: SEC | scope: role | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src
-- Not a problem: the list a security reviewer signs off on, in the P230 review
-- band. One row per account so each can be individually accepted or challenged.
-- Covers the global privileges that let an account escape its own scope: SUPER
-- (and its MySQL 8.0 replacements, which are dynamic privileges not visible in
-- mysql.user — noted in the details rather than silently missed), FILE (read and
-- write any file the server user can), PROCESS (see every other session's SQL),
-- GRANT OPTION (privilege escalation), SHUTDOWN, RELOAD, CREATE USER,
-- REPLICATION SLAVE (read the entire change stream).
-- Platform-managed accounts are excluded.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-007' AS check_id,
  'role'       AS scope,
  CONCAT(a.acct_user, '@', a.acct_host) AS object,
  CONCAT('''', a.acct_user, '''@''', a.acct_host, ''' holds ', a.priv_list,
         IF(a.has_all_privs, ' (the complete global privilege set)', ''),
         '. Plugin ', a.acct_plugin, ', credential ', IF(a.has_credential, 'set', 'EMPTY'),
         ', ', IF(a.account_locked, 'locked', 'not locked'), '. ',
         IF(@dbt_is_mariadb,
            'MariaDB splits SUPER into named privileges (SET USER, CONNECTION ADMIN, BINLOG ADMIN, READ_ONLY ADMIN and others); those are held in mysql.global_priv and are not all visible in this list.',
            'MySQL 8.0 replaced much of SUPER with dynamic privileges (SYSTEM_VARIABLES_ADMIN, SYSTEM_USER, BACKUP_ADMIN, CLONE_ADMIN and others) which live in mysql.global_grants, not mysql.user, and are not shown here.'),
         ' Confirm this account is still required.') AS details,
  JSON_OBJECT(
    'user', a.acct_user,
    'host', a.acct_host,
    'plugin', a.acct_plugin,
    'global_privileges', a.priv_list,
    'has_all_privileges', a.has_all_privs,
    'has_credential', a.has_credential,
    'account_locked', a.account_locked) AS evidence_json,
  'medium' AS confidence
FROM (ACCTSRC) AS a
WHERE a.is_role = 0
  AND a.priv_list <> ''
  AND a.acct_user NOT IN ACCTSYS
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
