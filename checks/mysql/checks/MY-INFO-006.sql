-- check: MY-INFO-006
-- title: InnoDB summary
-- priority: 250 | category: INFO | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: InnoDB settings (universal ones inline, fork-specific ones from the
--        bundle), information_schema.TABLES for data size by engine
-- Always emitted. Every number the MEM, WAL and UNDO findings are computed from,
-- in one place, so a reader can check the arithmetic rather than trust it.
-- Fork-specific values print as their bundle value or 'n/a': innodb_redo_log_capacity
-- is MySQL 8.0.30+, innodb_buffer_pool_instances was removed in MariaDB 10.6,
-- innodb_log_files_in_group was removed in MariaDB 10.5.
SELECT
  'MY-INFO-006' AS check_id,
  'cluster'     AS scope,
  'innodb'      AS object,
  CONCAT('Buffer pool ', ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 2), ' GB in ',
         IFNULL(@dbt_v_innodb_buffer_pool_instances, 'n/a (removed in MariaDB 10.6)'),
         ' instance(s), chunk size ', ROUND(@@GLOBAL.innodb_buffer_pool_chunk_size / 1048576, 0),
         ' MB; ', FORMAT(CAST(IFNULL(@dbt_s_innodb_buffer_pool_pages_total, 0) AS UNSIGNED), 0),
         ' pages of which ', FORMAT(CAST(IFNULL(@dbt_s_innodb_buffer_pool_pages_dirty, 0) AS UNSIGNED), 0),
         ' dirty. Read hit rate since restart: ',
         IF(CAST(IFNULL(@dbt_s_innodb_buffer_pool_read_requests, 0) AS DECIMAL(30, 0)) > 0,
            CONCAT(ROUND(100.0 * (1 - CAST(IFNULL(@dbt_s_innodb_buffer_pool_reads, 0) AS DECIMAL(30, 0))
                 / CAST(@dbt_s_innodb_buffer_pool_read_requests AS DECIMAL(30, 0))), 2), '%'),
            'not measurable'),
         '. Redo: ', IF(@dbt_v_innodb_redo_log_capacity IS NOT NULL,
            CONCAT('innodb_redo_log_capacity ', ROUND(CAST(@dbt_v_innodb_redo_log_capacity AS DECIMAL(30, 0)) / 1048576, 0), ' MB'),
            CONCAT('innodb_log_file_size ', ROUND(CAST(IFNULL(@dbt_v_innodb_log_file_size, 0) AS DECIMAL(30, 0)) / 1048576, 0),
                   ' MB x ', IFNULL(@dbt_v_innodb_log_files_in_group, '1'), ' file(s)')),
         ', log buffer ', ROUND(@@GLOBAL.innodb_log_buffer_size / 1048576, 1), ' MB, ',
         FORMAT(CAST(IFNULL(@dbt_s_innodb_os_log_written, 0) AS DECIMAL(30, 0)) / 1073741824, 2),
         ' GB written since restart. ',
         'Storage: innodb_file_per_table = ', CAST(@@GLOBAL.innodb_file_per_table AS CHAR),
         ', innodb_flush_method = ', IFNULL(@dbt_v_innodb_flush_method, 'n/a'),
         ', innodb_page_size = ', @@GLOBAL.innodb_page_size,
         ', innodb_io_capacity = ', @@GLOBAL.innodb_io_capacity, '/', @@GLOBAL.innodb_io_capacity_max,
         ', innodb_checksum_algorithm = ', IFNULL(@dbt_v_innodb_checksum_algorithm, 'n/a'), '. ',
         'Undo: ', @@GLOBAL.innodb_undo_tablespaces, ' tablespace(s), truncate = ',
         CAST(@@GLOBAL.innodb_undo_log_truncate AS CHAR), ', purge threads = ',
         @@GLOBAL.innodb_purge_threads, ', history list length = ',
         IFNULL(FORMAT(@dbt_hll, 0), 'not readable'), '. ',
         'Data by engine: ', e.by_engine, '.') AS details,
  JSON_OBJECT(
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'innodb_buffer_pool_instances', IFNULL(@dbt_v_innodb_buffer_pool_instances, 'n/a'),
    'innodb_buffer_pool_chunk_size', @@GLOBAL.innodb_buffer_pool_chunk_size,
    'buffer_pool_pages_total', CAST(IFNULL(@dbt_s_innodb_buffer_pool_pages_total, 0) AS UNSIGNED),
    'buffer_pool_pages_dirty', CAST(IFNULL(@dbt_s_innodb_buffer_pool_pages_dirty, 0) AS UNSIGNED),
    'innodb_redo_log_capacity', IFNULL(@dbt_v_innodb_redo_log_capacity, 'n/a'),
    'innodb_log_file_size', IFNULL(@dbt_v_innodb_log_file_size, 'n/a'),
    'innodb_log_files_in_group', IFNULL(@dbt_v_innodb_log_files_in_group, 'n/a'),
    'innodb_log_buffer_size', @@GLOBAL.innodb_log_buffer_size,
    'innodb_os_log_written', CAST(IFNULL(@dbt_s_innodb_os_log_written, 0) AS UNSIGNED),
    'innodb_file_per_table', CAST(@@GLOBAL.innodb_file_per_table AS CHAR),
    'innodb_flush_method', IFNULL(@dbt_v_innodb_flush_method, 'n/a'),
    'innodb_page_size', @@GLOBAL.innodb_page_size,
    'innodb_io_capacity', @@GLOBAL.innodb_io_capacity,
    'innodb_io_capacity_max', @@GLOBAL.innodb_io_capacity_max,
    'innodb_checksum_algorithm', IFNULL(@dbt_v_innodb_checksum_algorithm, 'n/a'),
    'innodb_undo_tablespaces', @@GLOBAL.innodb_undo_tablespaces,
    'innodb_undo_log_truncate', CAST(@@GLOBAL.innodb_undo_log_truncate AS CHAR),
    'innodb_purge_threads', @@GLOBAL.innodb_purge_threads,
    'history_list_length', @dbt_hll,
    'data_by_engine', e.by_engine) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT SUBSTRING(GROUP_CONCAT(CONCAT(ENGINE, ' ', ROUND(bytes / 1073741824, 2), ' GB in ', n, ' table(s)')
           ORDER BY bytes DESC SEPARATOR ', '), 1, 400) AS by_engine
  FROM (
    SELECT ENGINE, COUNT(*) AS n, IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes
    FROM information_schema.TABLES
    WHERE TABLE_TYPE = 'BASE TABLE' AND ENGINE IS NOT NULL
      AND TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'sys')
    GROUP BY ENGINE
  ) AS t
) AS e;
