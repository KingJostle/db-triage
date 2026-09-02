-- check: MY-SEC-006
-- title: Deprecated or weak authentication plugins
-- priority: 150 | category: SEC | scope: role | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src
-- Version divergence that turns this from hygiene into a migration deadline:
--   MySQL 8.0     mysql_native_password deprecated, still enabled by default
--   MySQL 8.4     DISABLED by default (--mysql-native-password=OFF); accounts
--                 using it cannot authenticate until it is explicitly re-enabled
--   MySQL 9.0     REMOVED entirely; those accounts must be re-created
--   MariaDB       mysql_native_password remains supported and is still the
--                 default for many packagings, so there is no deadline there —
--                 only the cryptographic argument
-- Why it is weak regardless of deadline: mysql_native_password is unsalted
-- SHA1(SHA1(password)). The stored hash is password-equivalent for the
-- challenge-response handshake, so an attacker who reads mysql.user does not
-- need to crack anything. sha256_password (as distinct from
-- caching_sha2_password) additionally requires TLS or RSA key exchange to be
-- safe and is deprecated in 8.0.16+.
-- Summary shape: one row per plugin with a count, not one row per account.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-006' AS check_id,
  'role'       AS scope,
  x.acct_plugin AS object,
  CONCAT(x.n, ' account(s) authenticate with ', x.acct_plugin, ': ', x.list, '. ',
         CASE LOWER(x.acct_plugin)
           WHEN 'mysql_native_password' THEN
             CONCAT('This is unsalted SHA1(SHA1(password)); the stored hash is password-equivalent for the handshake, so reading mysql.user is enough to authenticate. ',
                    IF(@dbt_is_mariadb,
                       'MariaDB still supports it, so there is no removal deadline — but ed25519 or PAM is the stronger choice.',
                       'MySQL 8.4 disables it by default and 9.0 removed it, so these accounts will stop being able to connect on upgrade.'))
           WHEN 'sha256_password' THEN
             'Deprecated since MySQL 8.0.16 and only safe over TLS or with RSA key exchange; caching_sha2_password supersedes it.'
           WHEN 'mysql_old_password' THEN
             'The pre-4.1 16-byte hash. It is trivially breakable and was removed in MySQL 5.7.5.'
           ELSE 'This plugin is deprecated.'
         END) AS details,
  JSON_OBJECT(
    'plugin', x.acct_plugin,
    'account_count', x.n,
    'accounts', x.list,
    'fork', @dbt_fork,
    'server_version', @@GLOBAL.version) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT a.acct_plugin, COUNT(*) AS n,
         SUBSTRING(GROUP_CONCAT(CONCAT('''', a.acct_user, '''@''', a.acct_host, '''')
           ORDER BY a.acct_user SEPARATOR ', '), 1, 500) AS list
  FROM (ACCTSRC) AS a
  WHERE a.is_role = 0
    AND LOWER(a.acct_plugin) IN ('mysql_native_password', 'mysql_old_password', 'sha256_password')
    AND a.acct_user NOT IN ACCTSYS
  GROUP BY a.acct_plugin
) AS x
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
