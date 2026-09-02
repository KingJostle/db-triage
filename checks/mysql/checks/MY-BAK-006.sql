-- check: MY-BAK-006
-- title: Binary log checksums off
-- priority: 100 | category: BAK | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.binlog_checksum, @@GLOBAL.master_verify_checksum equivalents
-- binlog_checksum=NONE means a truncated or bit-rotted binlog event is replayed
-- rather than rejected. Both forks default to CRC32; NONE is only needed for
-- replicas older than MySQL 5.6, which no supported topology has.
SELECT
  'MY-BAK-006' AS check_id,
  'setting'    AS scope,
  'binlog_checksum' AS object,
  CONCAT('binlog_checksum = NONE with binary logging ON. ',
         'Binary log events carry no integrity check, so a truncated or corrupted event is applied by a replica or a PITR restore instead of being rejected. ',
         'Both MySQL 5.6+ and MariaDB 10.x default to CRC32; NONE is only required for pre-5.6 replicas.') AS details,
  JSON_OBJECT(
    'binlog_checksum', @@GLOBAL.binlog_checksum,
    'log_bin', CAST(@@GLOBAL.log_bin AS CHAR),
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.log_bin = 1
  AND UPPER(@@GLOBAL.binlog_checksum) = 'NONE';
