-- check: MY-DUR-002
-- title: sync_binlog not 1
-- priority: 10 | category: DUR | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.sync_binlog, @@GLOBAL.log_bin
-- Only meaningful when binary logging is on. sync_binlog=1 fsyncs the binlog at
-- every commit group; anything else lets the binlog fall behind the redo log, so
-- after a crash the server has transactions its own binlog never recorded —
-- replicas and any PITR restore silently diverge from the source of truth.
-- sync_binlog=0 means "never fsync, leave it to the OS".
SELECT
  'MY-DUR-002' AS check_id,
  'setting'    AS scope,
  'sync_binlog' AS object,
  CONCAT('sync_binlog = ', @@GLOBAL.sync_binlog,
         ' with binary logging ON. ',
         IF(@@GLOBAL.sync_binlog = 0,
            'The binary log is fsynced only when the OS chooses to.',
            CONCAT('The binary log is fsynced once every ', @@GLOBAL.sync_binlog,
                   ' commit groups.')),
         ' After a crash the redo log can contain transactions the binary log does not, so replicas and point-in-time restores diverge from this server.') AS details,
  JSON_OBJECT(
    'sync_binlog', @@GLOBAL.sync_binlog,
    'log_bin', CAST(@@GLOBAL.log_bin AS CHAR),
    'binlog_format', @@GLOBAL.binlog_format,
    'innodb_flush_log_at_trx_commit', @@GLOBAL.innodb_flush_log_at_trx_commit,
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.log_bin = 1 AND @@GLOBAL.sync_binlog <> 1;
