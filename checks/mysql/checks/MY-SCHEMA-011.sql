-- check: MY-SCHEMA-011
-- title: Triggers on high-write tables
-- priority: 150 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: min_writes=1000000
-- reads: information_schema.TRIGGERS, sys.schema_table_statistics
-- Requires the sys schema for the write counts (present on MySQL 5.7+ and
-- MariaDB 10.6+, verified); without it the check emits nothing rather than
-- listing every trigger regardless of traffic, which would be noise.
-- Triggers in MySQL run row-by-row inside the writing transaction: they extend
-- its duration (MY-LOCK-003), take their own locks in a different order than the
-- statement did (MY-LOCK-007), and are invisible in the statement digest, so the
-- statement that appears to take 5 ms in MY-QRY-004 may actually be doing far
-- more work. On a table taking a million writes that cost is structural.
SET @dbt_q := "
SELECT
  'MY-SCHEMA-011' AS check_id,
  'relation'      AS scope,
  CONCAT(x.sch, '.', x.tbl) AS object,
  CONCAT('`', x.sch, '`.`', x.tbl, '` has ', x.n_triggers, ' trigger(s) (', x.trig_list,
         ') and has taken ', FORMAT(x.writes, 0),
         ' write(s) since restart (threshold ', FORMAT(COALESCE(@min_writes, 1000000), 0), '). ',
         'MySQL triggers execute row by row inside the writing transaction: they lengthen it, take locks the statement itself did not, and do not appear in the statement digest — so the write latency measured in MY-QRY-004 excludes the trigger body. ',
         'Breakdown: ', FORMAT(x.ins, 0), ' inserted, ', FORMAT(x.upd, 0), ' updated, ',
         FORMAT(x.del, 0), ' deleted.') AS details,
  JSON_OBJECT(
    'schema', x.sch, 'table', x.tbl,
    'trigger_count', x.n_triggers, 'triggers', x.trig_list,
    'writes', x.writes, 'rows_inserted', x.ins, 'rows_updated', x.upd, 'rows_deleted', x.del,
    'threshold_writes', COALESCE(@min_writes, 1000000)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT g.EVENT_OBJECT_SCHEMA AS sch, g.EVENT_OBJECT_TABLE AS tbl,
         COUNT(*) AS n_triggers,
         SUBSTRING(GROUP_CONCAT(g.TRIGGER_NAME SEPARATOR ', '), 1, 200) AS trig_list,
         IFNULL(s.rows_inserted, 0) AS ins,
         IFNULL(s.rows_updated, 0)  AS upd,
         IFNULL(s.rows_deleted, 0)  AS del,
         IFNULL(s.rows_inserted, 0) + IFNULL(s.rows_updated, 0) + IFNULL(s.rows_deleted, 0) AS writes
    FROM information_schema.TRIGGERS AS g
    LEFT JOIN sys.schema_table_statistics AS s
      ON s.table_schema = g.EVENT_OBJECT_SCHEMA AND s.table_name = g.EVENT_OBJECT_TABLE
   WHERE g.EVENT_OBJECT_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
   GROUP BY g.EVENT_OBJECT_SCHEMA, g.EVENT_OBJECT_TABLE,
            s.rows_inserted, s.rows_updated, s.rows_deleted
) AS x
WHERE x.writes >= COALESCE(@min_writes, 1000000)
ORDER BY x.writes DESC
LIMIT 20";
SET @dbt_q := IF(IFNULL(@dbt_sys_table_stats, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
