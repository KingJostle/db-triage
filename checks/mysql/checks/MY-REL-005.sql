-- check: MY-REL-005
-- title: Server restarted within the last 24 hours
-- priority: 10 | category: REL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: recent_restart_seconds=86400
-- reads: @dbt_s_uptime
-- This is a META-shaped finding at P10 rather than P0 because it is a fact about
-- the SERVER, not about the run: something restarted this database recently and
-- that is worth knowing on its own. Its effect on the report is the larger point.
-- MySQL and MariaDB have no equivalent of PostgreSQL's per-view stats_reset
-- timestamp: every status counter, every performance_schema aggregate and every
-- InnoDB metric starts from zero at startup and there is no record of when a
-- previous window ended. So a short uptime does not merely reduce confidence in
-- the rate-based findings — it means the buffer pool is still cold, the digest
-- table is nearly empty, and index usage counters (MY-IDX-001/002) show almost
-- everything as unused. Acting on any of those now would be wrong.
-- Whether the restart was clean is a separate question: MY-CORR-002 reads the
-- error log for crash-recovery messages where the fork allows it.
SELECT
  'MY-REL-005' AS check_id,
  'cluster'    AS scope,
  'uptime'     AS object,
  CONCAT('The server has been up for ', ROUND(@dbt_uptime_s / 3600, 1),
         ' h (started approximately ', DATE_FORMAT(NOW() - INTERVAL @dbt_uptime_s SECOND, '%Y-%m-%d %H:%i UTC'),
         '), under the ', ROUND(COALESCE(@recent_restart_seconds, 86400) / 3600, 0), ' h threshold. ',
         'Neither MySQL nor MariaDB records when the previous counter window ended, so every rate in this report covers only these ',
         ROUND(@dbt_uptime_s / 3600, 1), ' hours. Specifically: the buffer pool is still warming (MY-MEM-004 will overstate the miss rate), ',
         'the statement digest table is nearly empty (MY-QRY-004 to MY-QRY-011), ',
         'and per-index usage counters show almost every index as unused (MY-IDX-001/002) — do not drop anything on that basis. ',
         'Whether the restart was clean is a separate question; MY-CORR-002 reads the error log where the fork exposes it.') AS details,
  JSON_OBJECT(
    'uptime_seconds', @dbt_uptime_s,
    'started_approximately', DATE_FORMAT(NOW() - INTERVAL @dbt_uptime_s SECOND, '%Y-%m-%dT%H:%i:%sZ'),
    'threshold_seconds', COALESCE(@recent_restart_seconds, 86400),
    'counter_confidence', @dbt_counter_conf,
    'affected_checks', 'MY-MEM-004,MY-QRY-004..011,MY-IDX-001..005,MY-LOCK-007,MY-CONN-004,MY-CONN-008') AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @dbt_uptime_s > 0
  AND @dbt_uptime_s < COALESCE(@recent_restart_seconds, 86400);
