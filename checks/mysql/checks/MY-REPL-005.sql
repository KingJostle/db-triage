-- check: MY-REPL-005
-- title: Replica is writable
-- priority: 10 | category: REPL | scope: replica | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.read_only, @dbt_v_super_read_only, @dbt_is_replica
-- Fork divergence: super_read_only exists in MySQL 5.7+ but NOT in MariaDB
-- (verified absent on 10.11). It is read from the bundle, so on MariaDB it is
-- NULL and only read_only is judged — with the details saying so, because on
-- MariaDB an account holding SUPER can still write to a read_only replica and
-- there is no second lock to close that hole.
-- A writable replica is one typo or one misrouted connection away from a split
-- brain that replication will not detect and cannot merge.
SELECT
  'MY-REPL-005' AS check_id,
  'replica'     AS scope,
  IF(@@GLOBAL.read_only = 0, 'read_only', 'super_read_only') AS object,
  CONCAT('This instance replicates from ', IFNULL(@dbt_repl_source, 'a source'),
         ' but accepts writes: read_only = ', IF(@@GLOBAL.read_only = 1, 'ON', 'OFF'),
         ', super_read_only = ',
         IFNULL(@dbt_v_super_read_only, 'not available on this fork'), '. ',
         IF(@@GLOBAL.read_only = 1,
            'read_only is ON but privileged accounts bypass it; only super_read_only stops them.',
            'Any account with write privileges can write here, and those writes will not exist on the source.'),
         IF(@dbt_is_mariadb,
            ' MariaDB has no super_read_only, so read_only plus tightly held SUPER/READ_ONLY ADMIN is the strongest available guard.',
            '')) AS details,
  JSON_OBJECT(
    'read_only', CAST(@@GLOBAL.read_only AS CHAR),
    'super_read_only', IFNULL(@dbt_v_super_read_only, 'n/a'),
    'fork', @dbt_fork,
    'source', IFNULL(@dbt_repl_source, 'unknown')) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND (@@GLOBAL.read_only = 0
       OR LOWER(IFNULL(@dbt_v_super_read_only, 'on')) IN ('off', '0'));
