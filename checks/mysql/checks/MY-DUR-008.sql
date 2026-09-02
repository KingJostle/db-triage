-- check: MY-DUR-008
-- title: Replica not crash-safe
-- priority: 100 | category: DUR | scope: replica | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @dbt_v_relay_log_recovery, @dbt_v_master_info_repository,
--        @dbt_v_relay_log_info_repository, @dbt_is_replica
-- Only meaningful on a replica (@dbt_is_replica comes from
-- performance_schema.replication_connection_configuration, which exists on both
-- forks and is empty on a non-replica).
-- Version divergence: master_info_repository / relay_log_info_repository were
-- removed in MySQL 8.4 (positions are always in InnoDB tables there) and never
-- existed under those names on MariaDB, which uses relay_log_recovery plus
-- crash-safe rpl.* tables. NULL from the bundle therefore means "this fork does
-- not have the FILE-vs-TABLE hazard", and only relay_log_recovery is judged.
SELECT
  'MY-DUR-008' AS check_id,
  'replica'    AS scope,
  'replication-position' AS object,
  CONCAT('This instance is a replica and ',
         CONCAT_WS('; ',
           IF(LOWER(IFNULL(@dbt_v_relay_log_recovery, 'on')) IN ('off', '0'),
              'relay_log_recovery = OFF, so after a crash the relay log is reused as-is and any partially written event is replayed or skipped', NULL),
           IF(UPPER(IFNULL(@dbt_v_master_info_repository, 'TABLE')) = 'FILE',
              'master_info_repository = FILE, so the source position is written to master.info outside any transaction', NULL),
           IF(UPPER(IFNULL(@dbt_v_relay_log_info_repository, 'TABLE')) = 'FILE',
              'relay_log_info_repository = FILE, so the applied position is not committed atomically with the data', NULL)),
         '. A replica crash can then leave the recorded position and the applied data disagreeing, which silently duplicates or skips transactions.') AS details,
  JSON_OBJECT(
    'relay_log_recovery', IFNULL(@dbt_v_relay_log_recovery, 'n/a'),
    'master_info_repository', IFNULL(@dbt_v_master_info_repository, 'n/a'),
    'relay_log_info_repository', IFNULL(@dbt_v_relay_log_info_repository, 'n/a'),
    'fork', @dbt_fork) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND (LOWER(IFNULL(@dbt_v_relay_log_recovery, 'on')) IN ('off', '0')
       OR UPPER(IFNULL(@dbt_v_master_info_repository, 'TABLE')) = 'FILE'
       OR UPPER(IFNULL(@dbt_v_relay_log_info_repository, 'TABLE')) = 'FILE');
