-- check: MY-UNDO-001
-- title: InnoDB history list length very high
-- priority: 5 | category: UNDO | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: hll_critical=1000000
-- reads: information_schema.INNODB_METRICS trx_rseg_history_len (via @dbt_hll)
-- The history list is the queue of undo records the purge threads have not yet
-- reclaimed. It grows when purge cannot keep up — almost always because one old
-- read view (a long or forgotten transaction, MY-LOCK-003) pins it. Every
-- consistent read then walks a longer version chain, undo tablespaces grow and
-- never shrink without truncation, and the server slows toward a stall.
-- Column-name divergence between forks (STATUS vs ENABLED) is resolved once in
-- 01_session.sql. @dbt_metrics_enabled = 0 means the metric is off and COUNT is
-- a meaningless zero, so this check stays silent rather than reporting all-clear.
SELECT
  'MY-UNDO-001' AS check_id,
  'cluster'     AS scope,
  NULL          AS object,
  CONCAT('InnoDB history list length is ', FORMAT(@dbt_hll, 0),
         ' undo records (threshold ', FORMAT(COALESCE(@hll_critical, 1000000), 0),
         '). Purge is not keeping up. innodb_purge_threads = ', @@GLOBAL.innodb_purge_threads,
         ', innodb_undo_log_truncate = ', @@GLOBAL.innodb_undo_log_truncate,
         '. Oldest open transaction: ', IFNULL(t.oldest, 'none visible'),
         '. Check MY-LOCK-003/004 for the transaction pinning the read view.') AS details,
  JSON_OBJECT(
    'history_list_length', @dbt_hll,
    'threshold', COALESCE(@hll_critical, 1000000),
    'innodb_purge_threads', @@GLOBAL.innodb_purge_threads,
    'innodb_undo_log_truncate', CAST(@@GLOBAL.innodb_undo_log_truncate AS CHAR),
    'oldest_transaction_seconds', t.oldest_s) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    MAX(TIMESTAMPDIFF(SECOND, trx_started, NOW()))                       AS oldest_s,
    CONCAT(MAX(TIMESTAMPDIFF(SECOND, trx_started, NOW())), ' s old')     AS oldest
  FROM information_schema.INNODB_TRX
) AS t
WHERE IFNULL(@dbt_metrics_enabled, 0) = 1
  AND @dbt_hll >= COALESCE(@hll_critical, 1000000);
