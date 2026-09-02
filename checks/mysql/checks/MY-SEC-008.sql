-- check: MY-SEC-008
-- title: Application connections running as a privileged account
-- priority: 50 | category: SEC | scope: role | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS, SELECT ON mysql.*
-- thresholds: privileged_conn_count=5
-- reads: information_schema.PROCESSLIST joined to the normalised account source
-- The difference between "a privileged account exists" (MY-SEC-007, a review
-- item) and "the application is using one right now" (this, a finding). Five or
-- more concurrent non-local connections from an account holding SUPER or the
-- full privilege set is an application connecting as an administrator: every SQL
-- injection is then a server compromise rather than a data leak, and no
-- least-privilege boundary exists to contain a bad deployment.
-- Localhost connections are excluded — that is where a DBA and the backup tool
-- legitimately live.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-008' AS check_id,
  'role'       AS scope,
  CONCAT(x.acct_user, '@', x.acct_host) AS object,
  CONCAT(x.conns, ' concurrent non-local connection(s) are running as ''',
         x.acct_user, '''@''', x.acct_host, ''', which holds ', x.priv_list,
         '. Client hosts: ', x.client_hosts,
         '. An application connected as an administrator turns any SQL injection into full server control and removes every least-privilege boundary. ',
         'Schemas in use: ', IFNULL(x.dbs, 'none reported'), '.') AS details,
  JSON_OBJECT(
    'user', x.acct_user,
    'host_pattern', x.acct_host,
    'concurrent_connections', x.conns,
    'client_hosts', x.client_hosts,
    'global_privileges', x.priv_list,
    'schemas', IFNULL(x.dbs, ''),
    'threshold', COALESCE(@privileged_conn_count, 5),
    'measured', 'snapshot') AS evidence_json,
  'high' AS confidence
FROM (
  SELECT a.acct_user, a.acct_host, a.priv_list,
         COUNT(*) AS conns,
         SUBSTRING(GROUP_CONCAT(DISTINCT SUBSTRING_INDEX(p.HOST, ':', 1) SEPARATOR ', '), 1, 200) AS client_hosts,
         SUBSTRING(GROUP_CONCAT(DISTINCT p.DB SEPARATOR ', '), 1, 200) AS dbs
  FROM information_schema.PROCESSLIST AS p
  JOIN (ACCTSRC) AS a ON a.acct_user = p.USER
  WHERE p.HOST IS NOT NULL
    AND p.HOST <> ''
    AND SUBSTRING_INDEX(p.HOST, ':', 1) NOT IN ('localhost', '127.0.0.1', '::1')
    AND (a.Super_priv = 'Y' OR a.has_all_privs)
    AND a.acct_user NOT IN ACCTSYS
  GROUP BY a.acct_user, a.acct_host, a.priv_list
) AS x
WHERE x.conns >= COALESCE(@privileged_conn_count, 5)
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
