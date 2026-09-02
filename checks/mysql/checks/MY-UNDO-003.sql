-- check: MY-UNDO-003
-- title: Undo tablespaces large
-- priority: 50 | category: UNDO | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: undo_bytes=10737418240;undo_bytes_no_truncate=2147483648
-- reads: information_schema.FILES (MySQL 8.0, FILE_TYPE='UNDO LOG');
--        information_schema.INNODB_SYS_TABLESPACES (MariaDB, NAME LIKE 'innodb_undo%');
--        @@GLOBAL.innodb_undo_tablespaces, @@GLOBAL.innodb_undo_log_truncate
-- Fork divergence, verified on MariaDB 10.11: information_schema.FILES returns
-- ZERO rows there (it is an NDB-era table MariaDB does not populate for InnoDB),
-- so the MySQL query would silently never fire. MariaDB therefore reads
-- INNODB_SYS_TABLESPACES.FILE_SIZE for the separate undo tablespaces, and when
-- innodb_undo_tablespaces = 0 (the MariaDB default) undo lives inside ibdata1
-- and cannot be sized separately at all — that case is reported at low
-- confidence against the system tablespace rather than guessed at.
-- Undo space is never returned to the filesystem unless innodb_undo_log_truncate
-- is ON and the tablespaces are separate, which is why OFF halves the threshold.
SET @dbt_q := "
SELECT
  'MY-UNDO-003' AS check_id,
  'cluster'     AS scope,
  u.name        AS object,
  CONCAT('Undo storage is ', ROUND(u.bytes / 1073741824, 2), ' GB (', u.what, '). ',
         'innodb_undo_tablespaces = ', @@GLOBAL.innodb_undo_tablespaces,
         ', innodb_undo_log_truncate = ', @@GLOBAL.innodb_undo_log_truncate,
         '. Threshold ', ROUND(u.threshold / 1073741824, 1), ' GB. ',
         IF(@@GLOBAL.innodb_undo_log_truncate IN (0, 'OFF'),
            'With truncation OFF this space is never returned, even after purge catches up.',
            'Truncation is ON, so this space is reclaimable once the history list drains (MY-UNDO-001/002).')) AS details,
  JSON_OBJECT(
    'undo_bytes', u.bytes,
    'source', u.what,
    'threshold_bytes', u.threshold,
    'innodb_undo_tablespaces', @@GLOBAL.innodb_undo_tablespaces,
    'innodb_undo_log_truncate', CAST(@@GLOBAL.innodb_undo_log_truncate AS CHAR),
    'history_list_length', @dbt_hll) AS evidence_json,
  u.conf AS confidence
FROM (SRC) AS u
WHERE u.bytes >= u.threshold";

SET @dbt_src_mysql := "
  SELECT 'undo tablespaces' AS name,
         IFNULL(SUM(TOTAL_EXTENTS * EXTENT_SIZE), 0) AS bytes,
         'information_schema.FILES FILE_TYPE=UNDO LOG' AS what,
         IF(@@GLOBAL.innodb_undo_log_truncate IN (0, 'OFF'),
            COALESCE(@undo_bytes_no_truncate, 2147483648),
            COALESCE(@undo_bytes, 10737418240)) AS threshold,
         'high' AS conf
    FROM information_schema.FILES
   WHERE FILE_TYPE = 'UNDO LOG'";

SET @dbt_src_maria := "
  SELECT IF(@@GLOBAL.innodb_undo_tablespaces > 0, 'undo tablespaces', 'innodb_system (ibdata1)') AS name,
         IFNULL(SUM(FILE_SIZE), 0) AS bytes,
         IF(@@GLOBAL.innodb_undo_tablespaces > 0,
            'information_schema.INNODB_SYS_TABLESPACES innodb_undo*',
            'information_schema.INNODB_SYS_TABLESPACES innodb_system: undo is inside the system tablespace and cannot be sized separately, so this figure includes non-undo data') AS what,
         IF(@@GLOBAL.innodb_undo_log_truncate IN (0, 'OFF'),
            COALESCE(@undo_bytes_no_truncate, 2147483648),
            COALESCE(@undo_bytes, 10737418240)) AS threshold,
         IF(@@GLOBAL.innodb_undo_tablespaces > 0, 'high', 'low') AS conf
    FROM information_schema.INNODB_SYS_TABLESPACES
   WHERE NAME LIKE IF(@@GLOBAL.innodb_undo_tablespaces > 0, 'innodb_undo%', 'innodb_system')";

SET @dbt_q := CASE
  WHEN IFNULL(@dbt_has_is_files, 0) = 1 AND IFNULL(@dbt_is_mariadb, 0) = 0
    THEN REPLACE(@dbt_q, 'SRC', @dbt_src_mysql)
  WHEN IFNULL(@dbt_has_innodb_sys_tablespaces, 0) = 1
    THEN REPLACE(@dbt_q, 'SRC', @dbt_src_maria)
  ELSE 'DO 1'
END;
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
