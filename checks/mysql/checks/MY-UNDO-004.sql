-- check: MY-UNDO-004
-- title: Purge threads at default on a server that is not purging fast enough
-- priority: 100 | category: UNDO | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: hll_elevated=100000;purge_threads=4
-- reads: @@GLOBAL.innodb_purge_threads, @dbt_hll
-- Derived: only meaningful once the history list is already elevated, so it
-- never fires on a healthy server that happens to run the default. MySQL 8.0
-- defaults innodb_purge_threads to 4, MariaDB to 4 as well; on a write-heavy
-- server with a growing history list more threads is the first lever, and it
-- needs a restart, which is why this is P100 and not P50.
SELECT
  'MY-UNDO-004' AS check_id,
  'setting'     AS scope,
  'innodb_purge_threads' AS object,
  CONCAT('innodb_purge_threads = ', @@GLOBAL.innodb_purge_threads,
         ' while the history list length is ', FORMAT(@dbt_hll, 0),
         ' (above the ', FORMAT(COALESCE(@hll_elevated, 100000), 0),
         ' elevated threshold). Purge is the only consumer of undo and it is behind.',
         ' innodb_max_purge_lag = ', @@GLOBAL.innodb_max_purge_lag,
         ' (0 = no throttling of writers to let purge catch up).') AS details,
  JSON_OBJECT(
    'innodb_purge_threads', @@GLOBAL.innodb_purge_threads,
    'history_list_length', @dbt_hll,
    'innodb_max_purge_lag', @@GLOBAL.innodb_max_purge_lag,
    'innodb_max_purge_lag_delay', @@GLOBAL.innodb_max_purge_lag_delay) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_metrics_enabled, 0) = 1
  AND @dbt_hll >= COALESCE(@hll_elevated, 100000)
  AND @@GLOBAL.innodb_purge_threads <= COALESCE(@purge_threads, 4);
