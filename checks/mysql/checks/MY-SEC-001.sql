-- check: MY-SEC-001
-- title: Accounts with no password
-- priority: 1 | category: SEC | scope: role | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src (01_session.sql §6d)
-- PRIVACY: this check tests only whether the credential is empty. No hash value
-- is read, compared, echoed or stored, on either fork.
-- Excluded, because an empty credential is correct for them:
--   * external/socket authentication plugins (unix_socket, auth_socket, PAM,
--     LDAP, Kerberos, GSSAPI, AWS IAM) — the credential lives elsewhere;
--   * locked accounts;
--   * MariaDB roles (is_role), which never authenticate;
--   * MariaDB's literal 'invalid' credential marker, which means "this method is
--     deliberately unusable" and implies another auth_or method exists — the
--     default MariaDB root@localhost is exactly this and is not a finding.
-- What remains is an account anyone who can reach the port can log in as.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-001' AS check_id,
  'role'       AS scope,
  CONCAT(IF(a.acct_user = '', '(anonymous)', a.acct_user), '@', a.acct_host) AS object,
  CONCAT('Account ', IF(a.acct_user = '', '(anonymous)', CONCAT('''', a.acct_user, '''')),
         '@''', a.acct_host, ''' has an empty credential and authenticates with plugin ',
         a.acct_plugin, ', which is not an external or socket method. ',
         'Anyone who can reach ', @@GLOBAL.bind_address, ':', @@GLOBAL.port,
         ' from a host matching ''', a.acct_host, ''' can connect as it',
         IF(a.has_all_privs, ' WITH FULL PRIVILEGES', IF(a.priv_list <> '',
            CONCAT(' with ', a.priv_list), ' with no global privileges')),
         '. Account is not locked.') AS details,
  JSON_OBJECT(
    'user', a.acct_user,
    'host', a.acct_host,
    'plugin', a.acct_plugin,
    'has_credential', a.has_credential,
    'account_locked', a.account_locked,
    'has_all_privileges', a.has_all_privs,
    'global_privileges', a.priv_list,
    'bind_address', @@GLOBAL.bind_address) AS evidence_json,
  'high' AS confidence
FROM (ACCTSRC) AS a
WHERE a.has_credential = 0
  AND a.auth_marker <> 'invalid'
  AND a.account_locked = 0
  AND a.is_role = 0
  AND LOWER(a.acct_plugin) NOT IN ('unix_socket', 'auth_socket', 'auth_pam', 'auth_pam_v1',
        'pam', 'gssapi', 'auth_gssapi', 'authentication_kerberos', 'authentication_ldap_simple',
        'authentication_ldap_sasl', 'authentication_fido', 'authentication_webauthn',
        'auth_ed25519', 'ed25519', 'aws_authentication_plugin', 'mysql_no_login', 'auth_0x0100')
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
