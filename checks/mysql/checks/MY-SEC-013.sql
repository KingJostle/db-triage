-- check: MY-SEC-013
-- title: Accounts without password expiry (review)
-- priority: 200 | category: SEC | scope: role | cost: 0 | pass: inventory
-- engine: mysql | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source (password_lifetime), @dbt_v_default_password_lifetime
-- Reported as a P200 review row, NOT as a problem. Forced rotation is no longer
-- recommended by NIST SP 800-63B or by most corporate standards, so db-triage
-- states the position rather than asserting a defect — which is what the design
-- asks for.
-- Fork divergence: mysql.user.password_lifetime is a MySQL column. MariaDB's
-- mysql.user view does not have it (verified absent on 10.11) — MariaDB does
-- support ALTER USER ... PASSWORD EXPIRE INTERVAL but stores it in the
-- global_priv JSON under a different key — so the normalised source returns NULL
-- there and this check emits nothing on MariaDB.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-013' AS check_id,
  'role'       AS scope,
  'password-expiry' AS object,
  CONCAT(x.n, ' account(s) inherit the global password lifetime, which is ',
         IF(CAST(IFNULL(@dbt_v_default_password_lifetime, 0) AS SIGNED) = 0,
            'unlimited (default_password_lifetime = 0)',
            CONCAT(@dbt_v_default_password_lifetime, ' days')),
         ': ', x.list,
         '. Recorded for review, not as a defect — current guidance (NIST SP 800-63B) treats scheduled rotation as harmful rather than protective, so the useful controls are MY-SEC-011 (validation), MY-SEC-005 (TLS) and MY-SEC-002/004 (reachability).') AS details,
  JSON_OBJECT(
    'accounts_without_explicit_expiry', x.n,
    'accounts', x.list,
    'default_password_lifetime', CAST(IFNULL(@dbt_v_default_password_lifetime, 0) AS SIGNED)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n,
         SUBSTRING(GROUP_CONCAT(CONCAT('''', a.acct_user, '''@''', a.acct_host, '''')
           ORDER BY a.acct_user SEPARATOR ', '), 1, 500) AS list
  FROM (ACCTSRC) AS a
  WHERE a.is_role = 0
    AND a.password_lifetime IS NULL
    AND a.acct_user <> ''
    AND a.acct_user NOT IN ACCTSYS
) AS x
WHERE x.n > 0
  AND CAST(IFNULL(@dbt_v_default_password_lifetime, 0) AS SIGNED) = 0
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0 OR @dbt_is_mariadb, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
