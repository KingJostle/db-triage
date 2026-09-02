-- check: MY-QRY-003
-- title: Slow query log off, or its threshold at the default
-- priority: 100 | category: QRY | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: long_query_seconds=10;recommended_long_query_seconds=1
-- reads: @@GLOBAL.slow_query_log, @@GLOBAL.long_query_time,
--        @dbt_v_log_slow_extra (MySQL 8.0.14+) / @dbt_v_log_slow_verbosity (MariaDB)
-- Complements rather than duplicates performance_schema: the digest table gives
-- aggregates but no individual execution, no parameter values and no timestamp.
-- The slow log gives the actual statement text of the actual slow execution,
-- which is what pt-query-digest consumes and what you need to reproduce a
-- problem that happened at 03:00.
-- The default long_query_time of 10 s is the real finding on most servers: a
-- statement has to take ten seconds to be recorded, so the 200 ms statement
-- executed forty thousand times an hour — which is where the load actually is —
-- never appears. 0.5 to 1 s is the usual working setting.
-- Fork divergence in the extra-detail variable: MySQL 8.0.14+ has log_slow_extra
-- (adds rows examined, tmp tables, etc. to each entry); MariaDB has
-- log_slow_verbosity with a different value syntax. Both read from the bundle.
SELECT
  'MY-QRY-003' AS check_id,
  'setting'    AS scope,
  IF(@@GLOBAL.slow_query_log = 0, 'slow_query_log', 'long_query_time') AS object,
  CONCAT(IF(@@GLOBAL.slow_query_log = 0,
            'slow_query_log = OFF, so no slow statement is recorded anywhere with its actual text, parameters or timestamp. ',
            CONCAT('slow_query_log = ON but long_query_time = ', @@GLOBAL.long_query_time,
                   ' s, the shipped default. A statement must take ten seconds to be recorded, so the 200 ms statement running forty thousand times an hour — where the load usually is — never appears. ')),
         'performance_schema digests give aggregates but never an individual execution, its parameter values or when it ran; the slow log is what pt-query-digest reads and what lets you reproduce a 03:00 incident. ',
         'Recommended threshold: ', COALESCE(@recommended_long_query_seconds, 1), ' s or lower. ',
         'Extra detail per entry: ',
         IFNULL(COALESCE(@dbt_v_log_slow_extra, @dbt_v_log_slow_verbosity),
                'not available on this version'),
         '. log_output = ', @@GLOBAL.log_output,
         '; log_queries_not_using_indexes = ', CAST(@@GLOBAL.log_queries_not_using_indexes AS CHAR),
         ' (leave that OFF on a busy server — it logs every small unindexed lookup and can fill a disk).') AS details,
  JSON_OBJECT(
    'slow_query_log', CAST(@@GLOBAL.slow_query_log AS CHAR),
    'long_query_time', @@GLOBAL.long_query_time,
    'log_output', @@GLOBAL.log_output,
    'log_queries_not_using_indexes', CAST(@@GLOBAL.log_queries_not_using_indexes AS CHAR),
    'log_slow_extra', IFNULL(@dbt_v_log_slow_extra, 'n/a'),
    'log_slow_verbosity', IFNULL(@dbt_v_log_slow_verbosity, 'n/a'),
    'threshold_seconds', COALESCE(@long_query_seconds, 10)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.slow_query_log = 0
   OR @@GLOBAL.long_query_time >= COALESCE(@long_query_seconds, 10);
