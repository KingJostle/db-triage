-- check: MY-REPL-007
-- title: Statement-based binary logging
-- priority: 50 | category: REPL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.binlog_format, @@GLOBAL.log_bin
-- Universal variable. STATEMENT replicates the SQL text, so anything
-- non-deterministic (UUID(), NOW() in some contexts, LIMIT without ORDER BY,
-- UDFs, triggers with side effects, INSERT ... SELECT on a table with an
-- AUTO_INCREMENT and a unique key) produces different rows on the replica, and
-- nothing detects the divergence. Both forks default to ROW on current
-- releases; MariaDB historically defaulted to MIXED.
-- MIXED is not flagged here: it is only unsafe for statements the server itself
-- cannot classify, which is not observable from the catalog. That caveat is in
-- the reference doc rather than being asserted as a finding.
SELECT
  'MY-REPL-007' AS check_id,
  'setting'     AS scope,
  'binlog_format' AS object,
  CONCAT('binlog_format = STATEMENT with binary logging ON. ',
         'Non-deterministic statements replicate as text and produce different rows downstream, and nothing in the topology detects the divergence. ',
         'Connected replicas: ', IFNULL(@dbt_binlog_dump_threads, 0),
         '; binlog_row_image = ', @@GLOBAL.binlog_row_image,
         ' (relevant once you switch to ROW).') AS details,
  JSON_OBJECT(
    'binlog_format', @@GLOBAL.binlog_format,
    'binlog_row_image', @@GLOBAL.binlog_row_image,
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0),
    'log_bin', CAST(@@GLOBAL.log_bin AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.log_bin = 1
  AND UPPER(@@GLOBAL.binlog_format) = 'STATEMENT';
