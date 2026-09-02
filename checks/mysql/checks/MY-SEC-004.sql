-- check: MY-SEC-004
-- title: Application accounts allowed from any host
-- priority: 100 | category: SEC | scope: role | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src
-- Summary shape (DESIGN §2.1 form b): one finding with a count and the list,
-- because a fleet legitimately has many such accounts and one row each would
-- bury the report.
-- Confidence is LOW on purpose: a wildcard host is normal when a security group,
-- VPC or firewall already constrains who can reach the port, and db-triage
-- cannot see any of that. This is a review item, not a defect — which is exactly
-- how the design says absence-of-evidence checks must be phrased.
-- Accounts already reported by MY-SEC-002 (privileged AND wildcard) are excluded
-- so the P1 finding is not diluted by being restated at P100.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-004' AS check_id,
  'role'       AS scope,
  'wildcard-host-accounts' AS object,
  CONCAT(x.n, ' non-privileged account(s) may connect from any host: ', x.list,
         '. The server listens on ', @@GLOBAL.bind_address, ':', @@GLOBAL.port,
         ' and skip_name_resolve = ', CAST(@@GLOBAL.skip_name_resolve AS CHAR),
         '. This is only safe if a firewall, security group or private network already restricts who can reach the port — db-triage cannot see those, so confirm rather than assume.') AS details,
  JSON_OBJECT(
    'account_count', x.n,
    'accounts', x.list,
    'bind_address', @@GLOBAL.bind_address,
    'port', @@GLOBAL.port,
    'skip_name_resolve', CAST(@@GLOBAL.skip_name_resolve AS CHAR)) AS evidence_json,
  'low' AS confidence
FROM (
  SELECT COUNT(*) AS n,
         SUBSTRING(GROUP_CONCAT(CONCAT('''', a.acct_user, '''@''', a.acct_host, '''')
           ORDER BY a.acct_user SEPARATOR ', '), 1, 600) AS list
  FROM (ACCTSRC) AS a
  WHERE a.is_role = 0
    AND a.account_locked = 0
    AND a.acct_user <> ''
    AND (a.acct_host IN ('%', '') OR a.acct_host LIKE '%\\%%')
    AND a.Super_priv <> 'Y'
    AND NOT a.has_all_privs
    AND a.acct_user NOT IN ACCTSYS
) AS x
WHERE x.n > 0
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
