-- check: MY-DUR-003
-- title: Crash-unsafe replication source
-- priority: 5 | category: DUR | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: (none)
-- reads: @@GLOBAL.innodb_flush_log_at_trx_commit, @@GLOBAL.sync_binlog, @@GLOBAL.log_bin,
--        information_schema.PROCESSLIST (Binlog Dump threads, via @dbt_binlog_dump_threads)
-- Derived from MY-DUR-001 and MY-DUR-002. Neither alone justifies P5; together,
-- on a server that other servers replicate from, they do: after a crash the
-- source rolls back transactions it already shipped, so every replica is ahead
-- of its source and the topology can only be repaired by rebuilding replicas.
-- "Has replicas" is proved by a live Binlog Dump thread, which needs PROCESS.
-- Without PROCESS the count reads 0 here and the check stays silent rather than
-- guessing; MY-DUR-001/002 still fire on their own.
SELECT
  'MY-DUR-003' AS check_id,
  'cluster'    AS scope,
  NULL         AS object,
  CONCAT('This server has ', @dbt_binlog_dump_threads,
         ' replica(s) connected and both durability settings are relaxed: ',
         'innodb_flush_log_at_trx_commit = ', @@GLOBAL.innodb_flush_log_at_trx_commit,
         ', sync_binlog = ', @@GLOBAL.sync_binlog,
         '. After a crash this source can lose transactions its replicas have already applied, leaving every replica ahead of it.') AS details,
  JSON_OBJECT(
    'innodb_flush_log_at_trx_commit', @@GLOBAL.innodb_flush_log_at_trx_commit,
    'sync_binlog', @@GLOBAL.sync_binlog,
    'connected_replicas', @dbt_binlog_dump_threads,
    'semi_sync_status', IFNULL(@dbt_s_rpl_semi_sync_source_status,
                        IFNULL(@dbt_s_rpl_semi_sync_master_status, 'not-enabled'))) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.log_bin = 1
  AND IFNULL(@dbt_binlog_dump_threads, 0) > 0
  AND @@GLOBAL.innodb_flush_log_at_trx_commit <> 1
  AND @@GLOBAL.sync_binlog <> 1;
