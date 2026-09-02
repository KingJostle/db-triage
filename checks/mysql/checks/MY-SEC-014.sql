-- check: MY-SEC-014
-- title: Listening on all interfaces (review)
-- priority: 200 | category: SEC | scope: setting | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.bind_address, @@GLOBAL.port, @@GLOBAL.skip_networking
-- Inventory, at P200, because a database on a private network legitimately binds
-- to every interface and db-triage cannot see the firewall. It is recorded
-- because it is the context in which MY-SEC-002 and MY-SEC-004 are read: a
-- wildcard-host superuser account matters far more when the port answers on
-- every interface than when it answers only on loopback.
-- MySQL 8.0.13+ accepts a comma-separated list and the special values '*',
-- '0.0.0.0' and '::'; MariaDB accepts '*' and a single address. All the
-- unrestricted spellings are matched.
SELECT
  'MY-SEC-014' AS check_id,
  'setting'    AS scope,
  'bind_address' AS object,
  CONCAT('bind_address = ', IF(@@GLOBAL.bind_address = '', '(empty, meaning all interfaces)', @@GLOBAL.bind_address),
         ' on port ', @@GLOBAL.port, ', skip_networking = ',
         CAST(@@GLOBAL.skip_networking AS CHAR),
         ': the server answers on every network interface. ',
         'Read this together with MY-SEC-002 and MY-SEC-004 — ', w.n,
         ' account(s) have a wildcard host pattern. ',
         'require_secure_transport = ', IFNULL(@dbt_v_require_secure_transport, 'n/a'),
         '. Recorded for context, not as a defect: a private network or security group may already be the boundary.') AS details,
  JSON_OBJECT(
    'bind_address', @@GLOBAL.bind_address,
    'port', @@GLOBAL.port,
    'skip_networking', CAST(@@GLOBAL.skip_networking AS CHAR),
    'wildcard_host_accounts', w.n,
    'require_secure_transport', IFNULL(@dbt_v_require_secure_transport, 'n/a')) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n FROM information_schema.USER_PRIVILEGES WHERE GRANTEE LIKE '%@''%''%'
) AS w
WHERE @@GLOBAL.skip_networking = 0
  AND (@@GLOBAL.bind_address IN ('*', '0.0.0.0', '::', '') OR @@GLOBAL.bind_address LIKE '%0.0.0.0%');
