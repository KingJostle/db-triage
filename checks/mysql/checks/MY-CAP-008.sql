-- check: MY-CAP-008
-- title: InnoDB temporary tablespace large
-- priority: 100 | category: CAP | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: temp_tablespace_bytes=10737418240
-- reads: information_schema.FILES (MySQL 8.0, FILE_TYPE='TEMPORARY') or
--        information_schema.INNODB_SYS_TABLESPACES (MariaDB, NAME='innodb_temporary');
--        @dbt_v_innodb_temp_data_file_path
-- Same fork split as MY-UNDO-003 and for the same verified reason:
-- information_schema.FILES returns ZERO rows on MariaDB 10.11, so the MySQL
-- query would silently never fire there. MariaDB's size comes from
-- INNODB_SYS_TABLESPACES.FILE_SIZE for the innodb_temporary space.
-- The trap: ibtmp1 autoextends by default (innodb_temp_data_file_path is
-- `ibtmp1:12M:autoextend` on both forks) and IS NEVER SHRUNK WHILE THE SERVER
-- RUNS. One badly written report that spills a huge sort or GROUP BY can grow it
-- to tens of gigabytes, and that space stays allocated until the next restart —
-- there is no online way to reclaim it.
-- Setting a max in innodb_temp_data_file_path (e.g. `ibtmp1:12M:autoextend:max:8G`)
-- converts an unbounded disk-full risk into a failed query, which is the right
-- trade on most servers. MySQL 8.0.16+ additionally has session temporary
-- tablespaces, which are reclaimed when the session ends.
SET @dbt_q := "
SELECT
  'MY-CAP-008' AS check_id,
  'cluster'    AS scope,
  'innodb-temporary-tablespace' AS object,
  CONCAT('The InnoDB temporary tablespace is ', ROUND(x.bytes / 1073741824, 2),
         ' GB (threshold ', ROUND(COALESCE(@temp_tablespace_bytes, 10737418240) / 1073741824, 0),
         ' GB), read from ', x.src, '. ',
         'innodb_temp_data_file_path = ', IFNULL(@dbt_v_innodb_temp_data_file_path, 'unknown'), '. ',
         'This file autoextends and is never shrunk while the server runs: a single report that spills a large sort or GROUP BY grows it, and the space stays allocated until the next restart with no online way to reclaim it. ',
         'Disk temp tables since restart: ',
         FORMAT(CAST(IFNULL(@dbt_s_created_tmp_disk_tables, 0) AS DECIMAL(30, 0)), 0),
         ' (see MY-MEM-005 and MY-QRY-007 for what is spilling). ',
         'Adding :max:<size> to innodb_temp_data_file_path turns an unbounded disk-full risk into a failed query.') AS details,
  JSON_OBJECT(
    'temp_tablespace_bytes', x.bytes,
    'source', x.src,
    'innodb_temp_data_file_path', IFNULL(@dbt_v_innodb_temp_data_file_path, 'unknown'),
    'created_tmp_disk_tables', CAST(IFNULL(@dbt_s_created_tmp_disk_tables, 0) AS UNSIGNED),
    'threshold_bytes', COALESCE(@temp_tablespace_bytes, 10737418240)) AS evidence_json,
  'high' AS confidence
FROM (SRC) AS x
WHERE x.bytes >= COALESCE(@temp_tablespace_bytes, 10737418240)";

SET @dbt_src_mysql := "
  SELECT IFNULL(SUM(TOTAL_EXTENTS * EXTENT_SIZE), 0) AS bytes,
         'information_schema.FILES FILE_TYPE=TEMPORARY' AS src
    FROM information_schema.FILES WHERE FILE_TYPE = 'TEMPORARY'";
SET @dbt_src_maria := "
  SELECT IFNULL(SUM(FILE_SIZE), 0) AS bytes,
         'information_schema.INNODB_SYS_TABLESPACES innodb_temporary' AS src
    FROM information_schema.INNODB_SYS_TABLESPACES WHERE NAME = 'innodb_temporary'";

SET @dbt_q := CASE
  WHEN IFNULL(@dbt_has_is_files, 0) = 1 AND IFNULL(@dbt_is_mariadb, 0) = 0
    THEN REPLACE(@dbt_q, 'SRC', @dbt_src_mysql)
  WHEN IFNULL(@dbt_has_innodb_sys_tablespaces, 0) = 1
    THEN REPLACE(@dbt_q, 'SRC', @dbt_src_maria)
  ELSE 'DO 1'
END;
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
