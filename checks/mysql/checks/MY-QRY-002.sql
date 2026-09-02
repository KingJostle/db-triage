-- check: MY-QRY-002
-- title: Statement digest instrumentation incomplete
-- priority: 150 | category: QRY | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: (none)
-- reads: performance_schema.setup_consumers (statements_digest),
--        @dbt_s_performance_schema_digest_lost, @dbt_v_performance_schema_digests_size
-- Two independent ways the digest table lies, both reported here because both
-- silently degrade MY-QRY-004..011 without any error:
--   1. the statements_digest consumer is disabled, so nothing is aggregated at
--      all and the top-N lists are simply empty;
--   2. the consumer is on but performance_schema_digests_size (default 5000 on
--      MySQL 8.0, 200 on MariaDB) is too small, so digests beyond the limit are
--      collapsed into a single NULL-digest row and
--      Performance_schema_digest_lost counts them. Any "% of total time" figure
--      computed from the table is then understated by an unknown amount.
-- Verified on MariaDB 10.11: setup_consumers has the statements_digest row and
-- the same NAME/ENABLED columns as MySQL.
SET @dbt_q := "
SELECT
  'MY-QRY-002' AS check_id,
  'setting'    AS scope,
  'statements_digest' AS object,
  CONCAT(CONCAT_WS('; ',
    IF(c.digest_enabled = 0,
       'the statements_digest consumer in performance_schema.setup_consumers is disabled, so no statement is aggregated and every top-N list in this report is empty', NULL),
    IF(d.lost > 0,
       CONCAT('Performance_schema_digest_lost = ', FORMAT(d.lost, 0),
              ' — that many distinct statements exceeded performance_schema_digests_size (',
              IFNULL(@dbt_v_performance_schema_digests_size, 'unknown'),
              ') and were collapsed into a single unnamed row, so any percentage-of-total computed from the digest table understates the true total by an unknown amount'), NULL),
    IF(c.history_long_enabled = 0,
       'events_statements_history_long is disabled, so individual slow statement executions cannot be inspected after the fact (the digest aggregate is still available)', NULL)),
    '. Affects MY-QRY-004 to MY-QRY-011 and MY-QRY-014.') AS details,
  JSON_OBJECT(
    'statements_digest_enabled', c.digest_enabled,
    'events_statements_history_long_enabled', c.history_long_enabled,
    'digest_lost', d.lost,
    'performance_schema_digests_size', IFNULL(@dbt_v_performance_schema_digests_size, 'unknown')) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT MAX(NAME = 'statements_digest' AND ENABLED = 'YES') AS digest_enabled,
         MAX(NAME = 'events_statements_history_long' AND ENABLED = 'YES') AS history_long_enabled
    FROM performance_schema.setup_consumers
) AS c,
(
  SELECT CAST(IFNULL(@dbt_s_performance_schema_digest_lost, 0) AS DECIMAL(30, 0)) AS lost
) AS d
WHERE c.digest_enabled = 0 OR d.lost > 0 OR c.history_long_enabled = 0";
SET @dbt_q := IF(IFNULL(@dbt_ps_on, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
