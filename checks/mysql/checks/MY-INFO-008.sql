-- check: MY-INFO-008
-- title: Accounts summary
-- priority: 250 | category: INFO | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src (01_session.sql §6d)
-- Always emitted. Aggregate shape of the account catalog, so the individual SEC
-- findings can be read in proportion: "3 of 400 accounts have a wildcard host"
-- reads very differently from "3 of 4".
-- PRIVACY: counts only. No credential value is read; has_credential is derived
-- from emptiness alone, as documented in 01_session.sql §6d.
SET @dbt_q := REPLACE("
SELECT
  'MY-INFO-008' AS check_id,
  'cluster'     AS scope,
  'accounts'    AS object,
  CONCAT(a.n_total, ' account(s)', IF(a.n_roles > 0, CONCAT(' plus ', a.n_roles, ' role(s)'), ''),
         '. By authentication plugin: ', a.n_by_plugin,
         '. Host patterns: ', a.n_wildcard, ' wildcard, ', a.n_localhost, ' localhost-only, ',
         a.n_specific, ' specific host or address. ',
         a.n_locked, ' locked, ', a.n_no_credential, ' with an empty credential, ',
         a.n_anonymous, ' anonymous. ',
         a.n_superusers, ' hold SUPER or the full global privilege set, ',
         a.n_with_grant, ' hold GRANT OPTION, ', a.n_with_file, ' hold FILE. ',
         'Read the SEC findings against these totals: a proportion means more than a count.') AS details,
  JSON_OBJECT(
    'total_accounts', a.n_total, 'roles', a.n_roles,
    'by_plugin', a.n_by_plugin,
    'wildcard_host', a.n_wildcard, 'localhost_only', a.n_localhost, 'specific_host', a.n_specific,
    'locked', a.n_locked, 'empty_credential', a.n_no_credential, 'anonymous', a.n_anonymous,
    'superuser_equivalent', a.n_superusers, 'grant_option', a.n_with_grant, 'file_privilege', a.n_with_file) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    SUM(is_role = 0) AS n_total,
    SUM(is_role = 1) AS n_roles,
    SUM(is_role = 0 AND (acct_host IN ('%', '') OR acct_host LIKE '%\\%%')) AS n_wildcard,
    SUM(is_role = 0 AND acct_host IN ('localhost', '127.0.0.1', '::1')) AS n_localhost,
    SUM(is_role = 0 AND acct_host NOT IN ('%', '', 'localhost', '127.0.0.1', '::1')
        AND acct_host NOT LIKE '%\\%%') AS n_specific,
    SUM(is_role = 0 AND account_locked = 1) AS n_locked,
    SUM(is_role = 0 AND has_credential = 0 AND auth_marker <> 'invalid') AS n_no_credential,
    SUM(is_role = 0 AND acct_user = '') AS n_anonymous,
    SUM(is_role = 0 AND (Super_priv = 'Y' OR has_all_privs)) AS n_superusers,
    SUM(is_role = 0 AND Grant_priv = 'Y') AS n_with_grant,
    SUM(is_role = 0 AND File_priv = 'Y') AS n_with_file,
    (SELECT SUBSTRING(GROUP_CONCAT(CONCAT(p, '=', n) ORDER BY n DESC SEPARATOR ', '), 1, 300)
       FROM (SELECT acct_plugin AS p, COUNT(*) AS n FROM (ACCTSRC) AS b
              WHERE b.is_role = 0 GROUP BY acct_plugin) AS t) AS n_by_plugin
  FROM (ACCTSRC) AS c
) AS a
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
