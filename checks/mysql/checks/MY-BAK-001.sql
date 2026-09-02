-- check: MY-BAK-001
-- title: Binary logging disabled — point-in-time recovery impossible
-- priority: 1 | category: BAK | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- platform_skip: rds;aurora;cloudsql;azure  (the platform archives outside the
--   server; MY-BAK-007 fires there instead)
-- thresholds: (none)
-- reads: @@GLOBAL.log_bin, @dbt_platform, @dbt_is_replica
-- Default divergence: MySQL 8.0+ ships log_bin=ON; MySQL 5.7 and every MariaDB
-- release ship it OFF. A MariaDB server with no explicit log_bin therefore has
-- no PITR and no ability to add a replica, and nobody chose that.
-- Without binary logs the recoverable window is exactly "the last full backup",
-- whatever the backup schedule claims. Skipped on a replica: a replica's own
-- binlog is optional unless it is also a source (log_slave_updates).
SELECT
  'MY-BAK-001' AS check_id,
  'cluster'    AS scope,
  NULL         AS object,
  CONCAT('log_bin = OFF on a ', @dbt_platform,
         ' server. There is no binary log, so point-in-time recovery is impossible: ',
         'the best achievable RPO is the age of the newest full backup, and no replica can be attached. ',
         'InnoDB data size ', ROUND(s.bytes / 1073741824, 1), ' GB across ',
         s.tables, ' tables. ',
         IF(@dbt_is_mariadb,
            'MariaDB ships log_bin OFF by default, so this may be an unreviewed default rather than a decision.',
            'MySQL 8.0 ships log_bin ON by default, so this was switched off deliberately.')) AS details,
  JSON_OBJECT(
    'log_bin', 'OFF',
    'platform', @dbt_platform,
    'fork', @dbt_fork,
    'data_bytes', s.bytes,
    'table_count', s.tables,
    'is_replica', IFNULL(@dbt_is_replica, 0)) AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes, COUNT(*) AS tables
  FROM information_schema.TABLES
  WHERE TABLE_TYPE = 'BASE TABLE'
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS s
WHERE @@GLOBAL.log_bin = 0
  AND IFNULL(@dbt_is_replica, 0) = 0;
