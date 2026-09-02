-- check: MY-IDX-008
-- title: InnoDB persistent statistics stale
-- priority: 150 | category: IDX | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: stats_age_days=30;stats_table_bytes=1073741824
-- reads: mysql.innodb_table_stats (last_update), @@GLOBAL.innodb_stats_persistent,
--        @@GLOBAL.innodb_stats_auto_recalc
-- mysql.innodb_table_stats exists on both forks (MySQL 5.6+, MariaDB 10.0+) with
-- the same last_update column.
-- Two distinct causes, distinguished in the text because the fixes differ:
--   innodb_stats_persistent = OFF — statistics are recomputed by sampling on
--     every server restart and on some metadata operations, so they are both
--     unstable and never durable. Plans change after a restart for no reason.
--   innodb_stats_auto_recalc = ON but last_update is old — automatic
--     recalculation only triggers when more than 10% of the rows have changed.
--     A large append-only table never reaches 10% in any reasonable time, so its
--     statistics silently describe the table as it was months ago.
-- Stale statistics are what makes the optimizer choose the wrong index on a
-- table that has grown, and they are the input to MY-IDX-007's cardinality
-- figures — which is why that check is medium confidence.
-- The fix (ANALYZE TABLE) is a write operation and is on db-triage's forbidden
-- list; the human runs it.
SET @dbt_q := "
SELECT
  'MY-IDX-008' AS check_id,
  'relation'   AS scope,
  CONCAT(st.database_name, '.', st.table_name) AS object,
  CONCAT('`', st.database_name, '`.`', st.table_name, '` is ',
         ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1073741824, 2),
         ' GB and its InnoDB statistics were last updated ', st.last_update, ' — ',
         DATEDIFF(NOW(), st.last_update), ' days ago (threshold ',
         COALESCE(@stats_age_days, 30), ' days). Recorded rows: ',
         FORMAT(st.n_rows, 0), '. ',
         IF(@@GLOBAL.innodb_stats_persistent = 0,
            'innodb_stats_persistent = OFF, so statistics are re-sampled at every restart and are never durable — query plans can change after a restart with no other cause. ',
            CONCAT('innodb_stats_auto_recalc = ', CAST(@@GLOBAL.innodb_stats_auto_recalc AS CHAR),
                   '; automatic recalculation only fires once more than 10% of rows have changed, which an append-only or slowly-changing table of this size never reaches. ')),
         'The optimizer is planning against a description of this table as it was ',
         DATEDIFF(NOW(), st.last_update),
         ' days ago, which is also the basis for the cardinality figures in MY-IDX-007. ',
         'ANALYZE TABLE refreshes it; db-triage does not run it because it is a write.') AS details,
  JSON_OBJECT(
    'schema', st.database_name, 'table', st.table_name,
    'stats_last_update', CAST(st.last_update AS CHAR),
    'stats_age_days', DATEDIFF(NOW(), st.last_update),
    'recorded_rows', st.n_rows,
    'table_bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'innodb_stats_persistent', CAST(@@GLOBAL.innodb_stats_persistent AS CHAR),
    'innodb_stats_auto_recalc', CAST(@@GLOBAL.innodb_stats_auto_recalc AS CHAR),
    'threshold_days', COALESCE(@stats_age_days, 30)) AS evidence_json,
  'high' AS confidence
FROM mysql.innodb_table_stats AS st
JOIN information_schema.TABLES AS t
  ON t.TABLE_SCHEMA = st.database_name AND t.TABLE_NAME = st.table_name
WHERE st.database_name NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND t.DATA_LENGTH + t.INDEX_LENGTH >= COALESCE(@stats_table_bytes, 1073741824)
  AND (DATEDIFF(NOW(), st.last_update) >= COALESCE(@stats_age_days, 30)
       OR @@GLOBAL.innodb_stats_persistent = 0)
ORDER BY t.DATA_LENGTH + t.INDEX_LENGTH DESC
LIMIT 20";
SET @dbt_q := IF(IFNULL(@dbt_has_innodb_table_stats, 0) = 1 AND IFNULL(@dbt_priv_mysql_schema, 0) = 1,
                 @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
