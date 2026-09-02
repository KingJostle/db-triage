-- check: MY-WAL-004
-- title: Checkpoint age near redo capacity
-- priority: 100 | category: WAL | scope: cluster | cost: 0 | pass: fast
-- engine: mariadb | requires: (none)
-- thresholds: checkpoint_age_ratio=0.75
-- reads: @dbt_s_innodb_checkpoint_age, @dbt_s_innodb_checkpoint_max_age
-- Fork divergence, and a deliberate narrowing of the design's row: the design
-- specifies parsing "Log sequence number" minus "Last checkpoint at" out of
-- SHOW ENGINE INNODB STATUS, which cannot be done from SQL (a SHOW cannot be
-- selected from) and needs PROCESS. MariaDB and Percona Server expose the same
-- figure directly as the status variables Innodb_checkpoint_age and
-- Innodb_checkpoint_max_age, so this check reads those and emits nothing on
-- stock MySQL, where the runner records it as skipped with reason `version`.
-- Checkpoint age approaching its maximum is the state immediately before InnoDB
-- starts blocking writers to force flushing — the stall that MY-WAL-001 predicts
-- from sizing, observed directly.
SELECT
  'MY-WAL-004' AS check_id,
  'cluster'    AS scope,
  'checkpoint-age' AS object,
  CONCAT('Checkpoint age is ', ROUND(c.age / 1048576, 0), ' MB of a ',
         ROUND(c.maxage / 1048576, 0), ' MB maximum (',
         ROUND(100.0 * c.age / c.maxage, 1), '%, threshold ',
         ROUND(100 * COALESCE(@checkpoint_age_ratio, 0.75), 0),
         '%) at snapshot time. InnoDB throttles and then blocks writers as this approaches 100%. ',
         'Redo capacity and the write rate are assessed by MY-WAL-001; innodb_io_capacity_max = ',
         @@GLOBAL.innodb_io_capacity_max, ' governs how fast it can drain.') AS details,
  JSON_OBJECT(
    'checkpoint_age_bytes', c.age,
    'checkpoint_max_age_bytes', c.maxage,
    'ratio', ROUND(c.age / c.maxage, 4),
    'threshold_ratio', COALESCE(@checkpoint_age_ratio, 0.75),
    'innodb_io_capacity_max', @@GLOBAL.innodb_io_capacity_max) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_innodb_checkpoint_age, 0) AS DECIMAL(30, 0))     AS age,
         CAST(IFNULL(@dbt_s_innodb_checkpoint_max_age, 0) AS DECIMAL(30, 0)) AS maxage
) AS c
WHERE c.maxage > 0
  AND c.age / c.maxage >= COALESCE(@checkpoint_age_ratio, 0.75);
