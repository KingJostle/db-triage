-- check: MY-REPL-012
-- title: server_id left at its default in a replicated topology
-- priority: 200 | category: REPL | scope: setting | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.server_id, @dbt_v_server_uuid
-- Inventory, not a fault: nothing readable from one node can prove another node
-- shares this id. It is recorded because duplicate server_ids are a classic
-- cause of replicas that connect, disconnect and reconnect in a loop, and the
-- symptom (I/O thread flapping) rarely points at the cause.
-- Fork divergence: MySQL has @@server_uuid, which is generated per data
-- directory and is genuinely unique; MariaDB has no server_uuid at all, so the
-- numeric server_id is the only identity it has.
SELECT
  'MY-REPL-012' AS check_id,
  'setting'     AS scope,
  'server_id'   AS object,
  CONCAT('server_id = ', @@GLOBAL.server_id,
         IF(@@GLOBAL.server_id = 1, ' (the default)', ''),
         ' on a server that participates in replication. ',
         IF(@dbt_v_server_uuid IS NOT NULL,
            CONCAT('server_uuid = ', @dbt_v_server_uuid, ' is unique per data directory, so GTID-based replication is unaffected; only file-and-position replication and SHOW REPLICAS are.'),
            'MariaDB has no server_uuid, so server_id is this node''s only identity in the topology. Two nodes sharing it will fight over the same replication stream.'),
         ' Verify it is unique across the fleet; this cannot be checked from one node.') AS details,
  JSON_OBJECT(
    'server_id', @@GLOBAL.server_id,
    'server_uuid', IFNULL(@dbt_v_server_uuid, 'n/a'),
    'is_replica', IFNULL(@dbt_is_replica, 0),
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0)) AS evidence_json,
  'low' AS confidence
FROM DUAL
WHERE (IFNULL(@dbt_is_replica, 0) = 1 OR IFNULL(@dbt_binlog_dump_threads, 0) > 0)
  AND @@GLOBAL.server_id IN (0, 1);
