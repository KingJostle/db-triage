-- check: MY-MEM-008
-- title: Table open cache too small, or open-file limit at risk
-- priority: 100 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: overflows_per_minute=1;opened_tables_per_second=10;open_files_ratio=0.80
-- reads: @dbt_s_table_open_cache_overflows, @dbt_s_opened_tables, @dbt_s_open_files,
--        @@GLOBAL.table_open_cache, @@GLOBAL.open_files_limit, @dbt_v_table_definition_cache
-- Covers both halves of the design's row: cache pressure and the file-descriptor
-- ceiling behind it. Table_open_cache_overflows exists in MySQL 5.6.6+ and
-- MariaDB 10.1+; where it is missing the Opened_tables rate carries the check.
-- Every cache miss reopens a table: a file descriptor, a metadata lock and a
-- .frm/data-dictionary read. At tens per second that is pure overhead, and it
-- also multiplies the open-file count, which is capped by open_files_limit and
-- ultimately by the OS.
SELECT
  'MY-MEM-008' AS check_id,
  'setting'    AS scope,
  IF(f.fd_ratio >= COALESCE(@open_files_ratio, 0.80), 'open_files_limit', 'table_open_cache') AS object,
  CONCAT(CONCAT_WS('; ',
    IF(f.overflow_per_min >= COALESCE(@overflows_per_minute, 1),
       CONCAT('Table_open_cache_overflows = ', FORMAT(f.overflows, 0), ' (',
              ROUND(f.overflow_per_min, 1), '/min) against table_open_cache = ',
              @@GLOBAL.table_open_cache), NULL),
    IF(f.opened_per_sec >= COALESCE(@opened_tables_per_second, 10),
       CONCAT('Opened_tables = ', FORMAT(f.opened, 0), ' (', ROUND(f.opened_per_sec, 1),
              '/s) — tables are being reopened continuously'), NULL),
    IF(f.fd_ratio >= COALESCE(@open_files_ratio, 0.80),
       CONCAT('Open_files = ', FORMAT(f.open_files, 0), ' of open_files_limit ',
              @@GLOBAL.open_files_limit, ' (', ROUND(100 * f.fd_ratio, 0),
              '%) — new connections and table opens fail once this is reached'), NULL)),
    '. Measured over ', ROUND(@dbt_uptime_s / 3600, 1), ' h of uptime. table_definition_cache = ',
    IFNULL(@dbt_v_table_definition_cache, 'unknown'),
    '. Raising table_open_cache also raises the file-descriptor requirement.') AS details,
  JSON_OBJECT(
    'table_open_cache_overflows', f.overflows,
    'overflows_per_minute', ROUND(f.overflow_per_min, 2),
    'opened_tables', f.opened,
    'opened_tables_per_second', ROUND(f.opened_per_sec, 2),
    'open_files', f.open_files,
    'open_files_limit', @@GLOBAL.open_files_limit,
    'table_open_cache', @@GLOBAL.table_open_cache,
    'table_definition_cache', IFNULL(@dbt_v_table_definition_cache, 'n/a')) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT
    CAST(IFNULL(@dbt_s_table_open_cache_overflows, 0) AS DECIMAL(30, 0)) AS overflows,
    CAST(IFNULL(@dbt_s_table_open_cache_overflows, 0) AS DECIMAL(30, 0)) / (@dbt_uptime_h * 60) AS overflow_per_min,
    CAST(IFNULL(@dbt_s_opened_tables, 0) AS DECIMAL(30, 0)) AS opened,
    CAST(IFNULL(@dbt_s_opened_tables, 0) AS DECIMAL(30, 0)) / GREATEST(@dbt_uptime_s, 1) AS opened_per_sec,
    CAST(IFNULL(@dbt_s_open_files, 0) AS DECIMAL(30, 0)) AS open_files,
    CAST(IFNULL(@dbt_s_open_files, 0) AS DECIMAL(30, 0)) / GREATEST(@@GLOBAL.open_files_limit, 1) AS fd_ratio
) AS f
WHERE f.overflow_per_min >= COALESCE(@overflows_per_minute, 1)
   OR f.opened_per_sec >= COALESCE(@opened_tables_per_second, 10)
   OR f.fd_ratio >= COALESCE(@open_files_ratio, 0.80);
