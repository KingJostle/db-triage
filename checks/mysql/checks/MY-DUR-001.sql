-- check: MY-DUR-001
-- title: innodb_flush_log_at_trx_commit not 1
-- priority: 10 | category: DUR | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none — the safe value is fixed by the engine, not by opinion)
-- reads: @@GLOBAL.innodb_flush_log_at_trx_commit, @@GLOBAL.innodb_flush_log_at_timeout
-- Universal: the variable exists in every MySQL 5.x-9.x and MariaDB 10.x-11.x.
-- Value 1 = flush+fsync the redo log at every commit (the only durable setting).
-- Value 2 = write to the OS page cache, fsync once per second: an OS crash or
-- power loss loses up to innodb_flush_log_at_timeout seconds of commits.
-- Value 0 = write AND fsync once per second: a mysqld crash alone loses them.
SELECT
  'MY-DUR-001' AS check_id,
  'setting'    AS scope,
  'innodb_flush_log_at_trx_commit' AS object,
  CONCAT('innodb_flush_log_at_trx_commit = ', v.val,
         CASE v.val
           WHEN 0 THEN ': redo is written and fsynced once per second, so a mysqld crash (not just an OS crash) loses every commit since the last flush'
           WHEN 2 THEN ': redo is written to the OS page cache at commit but fsynced once per second, so an OS crash or power loss loses committed transactions'
           ELSE ''
         END,
         '. Worst-case loss window is innodb_flush_log_at_timeout = ',
         @@GLOBAL.innodb_flush_log_at_timeout, ' s.',
         IF(@@GLOBAL.log_bin = 1 AND @@GLOBAL.sync_binlog <> 1,
            ' sync_binlog is also ', ''),
         IF(@@GLOBAL.log_bin = 1 AND @@GLOBAL.sync_binlog <> 1,
            CONCAT(@@GLOBAL.sync_binlog, ' (MY-DUR-002); see MY-DUR-003.'), '')) AS details,
  JSON_OBJECT(
    'innodb_flush_log_at_trx_commit', v.val,
    'innodb_flush_log_at_timeout_seconds', @@GLOBAL.innodb_flush_log_at_timeout,
    'sync_binlog', @@GLOBAL.sync_binlog,
    'log_bin', CAST(@@GLOBAL.log_bin AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM (SELECT @@GLOBAL.innodb_flush_log_at_trx_commit AS val) AS v
WHERE v.val <> 1;
