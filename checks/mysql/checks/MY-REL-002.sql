-- check: MY-REL-002
-- title: End-of-life server reachable from any network interface
-- priority: 1 | category: REL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: eol_as_of=2026-09-02
-- reads: as MY-REL-001, plus @@GLOBAL.bind_address, @@GLOBAL.skip_networking,
--        and the wildcard-host account count
-- Derived: MY-REL-001 (no more security patches) AND MY-SEC-014 (listening on
-- every interface) AND at least one account reachable from any host. Each alone
-- is a P20 or a P200 review row; together they are the sp_Blitz "you get fired"
-- shape — a server with known-unpatchable vulnerabilities and an open front door.
-- The combination is what raises it to P1, so suppressing MY-REL-001 for a
-- deliberate upgrade freeze does not also suppress this.
SET @dbt_eol_as_of := IFNULL(@dbt_eol_as_of, '2026-09-02');
SET @dbt_q := "
SELECT
  'MY-REL-002' AS check_id,
  'cluster'    AS scope,
  CONCAT(v.fork, ' ', v.branch) AS object,
  CONCAT(v.fork, ' ', @@GLOBAL.version, ' passed end of life on ', v.eol, ' (',
         DATEDIFF(CURDATE(), v.eol), ' days ago, no further security patches) AND it listens on ',
         @@GLOBAL.bind_address, ':', @@GLOBAL.port, ' — every network interface — with ',
         w.n, ' account(s) whose host pattern accepts any host. ',
         'require_secure_transport = ', IFNULL(@dbt_v_require_secure_transport, 'n/a'), '. ',
         'Individually these are MY-REL-001 (P20) and MY-SEC-014 (P200 review). Together they are an unpatchable server with an open front door, which is why this is P1. ',
         'If a firewall or security group already restricts reachability, record it in .db-triage.yml so this stops firing; if not, restricting the network is faster than the major upgrade and buys time for it.') AS details,
  JSON_OBJECT(
    'fork', v.fork, 'version', @@GLOBAL.version, 'branch', v.branch,
    'eol_date', v.eol, 'days_past_eol', DATEDIFF(CURDATE(), v.eol),
    'bind_address', @@GLOBAL.bind_address, 'port', @@GLOBAL.port,
    'skip_networking', CAST(@@GLOBAL.skip_networking AS CHAR),
    'wildcard_host_accounts', w.n,
    'require_secure_transport', IFNULL(@dbt_v_require_secure_transport, 'n/a'),
    'release_data_as_of', @dbt_eol_as_of) AS evidence_json,
  IF(DATEDIFF(CURDATE(), @dbt_eol_as_of) > 365, 'low', 'high') AS confidence
FROM (BRANCHES) AS v,
(
  SELECT COUNT(*) AS n FROM information_schema.USER_PRIVILEGES WHERE GRANTEE LIKE '%@''%''%'
) AS w
WHERE v.eol < CURDATE()
  AND @@GLOBAL.skip_networking = 0
  AND (@@GLOBAL.bind_address IN ('*', '0.0.0.0', '::', '') OR @@GLOBAL.bind_address LIKE '%0.0.0.0%')
  AND w.n > 0";
-- The release table is redefined here rather than inherited from MY-REL-001,
-- so this check still works when the runner is invoked with --only MY-REL-002.
-- The release table. Matched on fork + major.minor.
SET @dbt_branches := "
  SELECT b.* FROM (
              SELECT 'mysql'   AS fork, '5.7'   AS branch, '2023-10-31' AS eol, '8.4 LTS' AS successor
    UNION ALL SELECT 'mysql',   '8.0',   '2026-04-30', '8.4 LTS'
    UNION ALL SELECT 'mysql',   '8.4',   '2032-04-30', '9.x innovation / the next LTS'
    UNION ALL SELECT 'percona', '5.7',   '2023-10-31', '8.4 LTS'
    UNION ALL SELECT 'percona', '8.0',   '2026-04-30', '8.4 LTS'
    UNION ALL SELECT 'percona', '8.4',   '2032-04-30', 'the next LTS'
    UNION ALL SELECT 'mariadb', '10.4',  '2024-06-18', '10.11 LTS'
    UNION ALL SELECT 'mariadb', '10.5',  '2025-06-24', '10.11 LTS'
    UNION ALL SELECT 'mariadb', '10.6',  '2026-07-06', '10.11 LTS or 11.4 LTS'
    UNION ALL SELECT 'mariadb', '10.11', '2028-02-16', '11.4 LTS'
    UNION ALL SELECT 'mariadb', '11.4',  '2029-05-29', '11.8 LTS'
    UNION ALL SELECT 'mariadb', '11.8',  '2030-06-04', 'the next LTS'
  ) AS b
  WHERE b.fork = @dbt_fork
    AND b.branch = CONCAT(@dbt_vmajor, '.', @dbt_vminor)";

SET @dbt_q := REPLACE(@dbt_q, 'BRANCHES', @dbt_branches);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
