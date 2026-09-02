-- check: MY-IDX-005
-- title: Write-heavy table carrying many indexes
-- priority: 100 | category: IDX | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: many_indexes=10;min_writes=1000000
-- reads: information_schema.STATISTICS (index count), sys.schema_table_statistics
--        (rows_inserted + rows_updated + rows_deleted)
-- Availability: sys.schema_table_statistics exists on MySQL 5.7+ and MariaDB
-- 10.6+ (verified) with these column names. Without sys the check emits nothing,
-- because an index count with no write volume behind it is not a finding.
-- Every secondary index is a second B-tree that every INSERT must add to, every
-- DELETE must remove from, and every UPDATE of an indexed column must maintain —
-- plus a change-buffer entry or a random read if the index page is not in the
-- buffer pool. Ten indexes on a table taking a million writes means ten times
-- the write amplification of the table itself.
-- This is the input to an index review, not a verdict: MY-IDX-001/002 say which
-- of them are unused and MY-IDX-003 says which are redundant. Read all three
-- together before dropping anything.
SET @dbt_q := "
SELECT
  'MY-IDX-005' AS check_id,
  'relation'   AS scope,
  CONCAT(x.sch, '.', x.tbl) AS object,
  CONCAT('`', x.sch, '`.`', x.tbl, '` has ', x.idx_count, ' indexes (threshold ',
         COALESCE(@many_indexes, 10), ') and has taken ', FORMAT(x.writes, 0),
         ' row write(s) since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago: ',
         FORMAT(x.ins, 0), ' inserted, ', FORMAT(x.upd, 0), ' updated, ',
         FORMAT(x.del, 0), ' deleted. Table size ',
         ROUND(x.bytes / 1073741824, 2), ' GB. ',
         'Every secondary index is a separate B-tree maintained on each of those writes, so the write cost of this table is a multiple of the row cost. ',
         'Indexes: ', x.idx_list, '. ',
         'Cross-reference MY-IDX-001/002 (unused) and MY-IDX-003 (redundant) before dropping any of them.') AS details,
  JSON_OBJECT(
    'schema', x.sch, 'table', x.tbl,
    'index_count', x.idx_count, 'indexes', x.idx_list,
    'writes', x.writes, 'rows_inserted', x.ins, 'rows_updated', x.upd, 'rows_deleted', x.del,
    'table_bytes', x.bytes,
    'threshold_indexes', COALESCE(@many_indexes, 10),
    'threshold_writes', COALESCE(@min_writes, 1000000),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT i.TABLE_SCHEMA AS sch, i.TABLE_NAME AS tbl,
         i.n AS idx_count, i.idx_list,
         IFNULL(t.DATA_LENGTH + t.INDEX_LENGTH, 0) AS bytes,
         IFNULL(s.rows_inserted, 0) AS ins,
         IFNULL(s.rows_updated, 0)  AS upd,
         IFNULL(s.rows_deleted, 0)  AS del,
         IFNULL(s.rows_inserted, 0) + IFNULL(s.rows_updated, 0) + IFNULL(s.rows_deleted, 0) AS writes
    FROM (
      SELECT TABLE_SCHEMA, TABLE_NAME, COUNT(DISTINCT INDEX_NAME) AS n,
             SUBSTRING(GROUP_CONCAT(DISTINCT INDEX_NAME SEPARATOR ', '), 1, 300) AS idx_list
        FROM information_schema.STATISTICS
       WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
       GROUP BY TABLE_SCHEMA, TABLE_NAME
    ) AS i
    JOIN information_schema.TABLES AS t
      ON t.TABLE_SCHEMA = i.TABLE_SCHEMA AND t.TABLE_NAME = i.TABLE_NAME
    LEFT JOIN sys.schema_table_statistics AS s
      ON s.table_schema = i.TABLE_SCHEMA AND s.table_name = i.TABLE_NAME
) AS x
WHERE x.idx_count >= COALESCE(@many_indexes, 10)
  AND x.writes >= COALESCE(@min_writes, 1000000)
ORDER BY x.writes DESC
LIMIT 20";
SET @dbt_q := IF(IFNULL(@dbt_sys_table_stats, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
