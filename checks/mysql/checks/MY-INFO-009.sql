-- check: MY-INFO-009
-- title: Statistics window
-- priority: 250 | category: INFO | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @dbt_uptime_s, @dbt_counter_conf, performance_schema lost-instrument counters
-- Always emitted, and it is the row that makes every rate in this report
-- interpretable. Neither MySQL nor MariaDB has PostgreSQL's per-view stats_reset
-- timestamp: status counters, performance_schema aggregates and InnoDB metrics
-- all begin at zero on startup, and FLUSH STATUS or a TRUNCATE of a
-- performance_schema summary table resets some of them with no record that it
-- happened. Uptime is therefore an UPPER BOUND on the window, not a measurement
-- of it, and this row says so explicitly.
-- The lost-instrument counters matter for the same reason: when
-- performance_schema runs out of its preallocated memory it silently drops
-- instrumentation, so a digest or index-usage figure can be incomplete without
-- any error being raised.
SELECT
  'MY-INFO-009' AS check_id,
  'cluster'     AS scope,
  'statistics-window' AS object,
  CONCAT('Counters cover at most ', ROUND(@dbt_uptime_s / 86400, 2), ' days (',
         ROUND(@dbt_uptime_s / 3600, 1), ' h) — the server has been up that long, ',
         'and neither fork records when a counter window actually started. ',
         'FLUSH STATUS and TRUNCATE on a performance_schema summary table both reset counters without leaving a trace, so this is an UPPER BOUND on the window, not a measurement of it. ',
         'Confidence assigned to every rate-based finding in this report: ', @dbt_counter_conf,
         ' (low under 1 day, medium under 7 days, high above). ',
         'performance_schema = ', CAST(@@GLOBAL.performance_schema AS CHAR),
         '; digests lost: ', CAST(IFNULL(@dbt_s_performance_schema_digest_lost, 0) AS UNSIGNED),
         ', index statistics lost: ', CAST(IFNULL(@dbt_s_performance_schema_index_stat_lost, 0) AS UNSIGNED),
         ' — a non-zero value means performance_schema ran out of its preallocated memory and silently dropped instrumentation, so the workload and index findings are incomplete by an unknown amount. ',
         'Sizes reported from information_schema are ',
         IF(@dbt_is_mariadb, 'read live from the storage engine on MariaDB',
            CONCAT('cached for up to ',
                   ROUND(CAST(IFNULL(@dbt_v_information_schema_stats_expiry, 86400) AS DECIMAL(20, 0)) / 3600, 1),
                   ' h on MySQL 8.0 (information_schema_stats_expiry)')),
         ', and row counts are InnoDB estimates in all cases.') AS details,
  JSON_OBJECT(
    'uptime_seconds', @dbt_uptime_s,
    'window_is_upper_bound', 1,
    'counter_confidence', @dbt_counter_conf,
    'performance_schema', CAST(@@GLOBAL.performance_schema AS CHAR),
    'digest_lost', CAST(IFNULL(@dbt_s_performance_schema_digest_lost, 0) AS UNSIGNED),
    'index_stat_lost', CAST(IFNULL(@dbt_s_performance_schema_index_stat_lost, 0) AS UNSIGNED),
    'information_schema_stats_expiry', IFNULL(@dbt_v_information_schema_stats_expiry, 'n/a'),
    'sizes_cached', IF(@dbt_is_mariadb, 0, 1)) AS evidence_json,
  'high' AS confidence
FROM DUAL;
