-- check: MY-UNDO-002
-- title: InnoDB history list length elevated
-- priority: 50 | category: UNDO | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: hll_elevated=100000;hll_critical=1000000
-- reads: information_schema.INNODB_METRICS trx_rseg_history_len (via @dbt_hll)
-- Magnitude tier below MY-UNDO-001, with its own ID so suppressing the noisy
-- tier can never hide the severe one (DESIGN §2.2). 100,000 is roughly where
-- purge lag becomes visible as extra read latency on a busy OLTP server; below
-- that a healthy server routinely sits in the thousands.
SELECT
  'MY-UNDO-002' AS check_id,
  'cluster'     AS scope,
  NULL          AS object,
  CONCAT('InnoDB history list length is ', FORMAT(@dbt_hll, 0),
         ' undo records (threshold ', FORMAT(COALESCE(@hll_elevated, 100000), 0),
         '; the P5 tier MY-UNDO-001 starts at ', FORMAT(COALESCE(@hll_critical, 1000000), 0),
         '). Purge is falling behind. innodb_purge_threads = ',
         @@GLOBAL.innodb_purge_threads, '.') AS details,
  JSON_OBJECT(
    'history_list_length', @dbt_hll,
    'threshold', COALESCE(@hll_elevated, 100000),
    'innodb_purge_threads', @@GLOBAL.innodb_purge_threads) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_metrics_enabled, 0) = 1
  AND @dbt_hll >= COALESCE(@hll_elevated, 100000)
  AND @dbt_hll <  COALESCE(@hll_critical, 1000000);
