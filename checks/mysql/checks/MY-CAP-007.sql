-- check: MY-CAP-007
-- title: General query log enabled
-- priority: 50 | category: CAP | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.general_log, @@GLOBAL.log_output, @dbt_s_questions
-- The general log records EVERY statement, including every SELECT, with no
-- threshold and no sampling. Three consequences worth stating with numbers:
-- it costs roughly ten to twenty percent of throughput; at the current statement
-- rate it produces an estimable volume per day; and when log_output=TABLE it
-- writes into mysql.general_log, which is a CSV-engine table that grows inside
-- the data directory and cannot be rotated by logrotate.
-- It is almost never intentional in production — it is normally switched on to
-- debug something and never switched off. It is dynamic on both forks, so
-- turning it off needs no restart.
-- Note it is also NOT an audit log: it records statements but not their results
-- or their success, and any account can be granted enough to read it. MY-SEC-015
-- covers actual audit facilities.
SELECT
  'MY-CAP-007' AS check_id,
  'setting'    AS scope,
  'general_log' AS object,
  CONCAT('general_log = ON with log_output = ', @@GLOBAL.log_output,
         '. Every statement is being recorded, with no threshold and no sampling. ',
         'At the observed rate of ',
         ROUND(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)) / GREATEST(@dbt_uptime_s, 1), 0),
         ' statements/s that is roughly ',
         FORMAT(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)) / GREATEST(@dbt_uptime_s, 1) * 86400, 0),
         ' log entries per day, and it costs on the order of 10-20% of throughput. ',
         IF(@@GLOBAL.log_output LIKE '%TABLE%',
            'Because log_output includes TABLE, it is written into mysql.general_log — a CSV-engine table inside the data directory that logrotate cannot touch. ',
            CONCAT('It is written to ', @@GLOBAL.general_log_file, '. ')),
         'This is normally switched on to debug something and never switched off; it is dynamic, so switching it off needs no restart. ',
         'It is not an audit log either: it records statements but not their outcome (see MY-SEC-015).') AS details,
  JSON_OBJECT(
    'general_log', 'ON',
    'log_output', @@GLOBAL.log_output,
    'general_log_file', @@GLOBAL.general_log_file,
    'questions_per_second', ROUND(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)) / GREATEST(@dbt_uptime_s, 1), 2),
    'estimated_entries_per_day', ROUND(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)) / GREATEST(@dbt_uptime_s, 1) * 86400)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.general_log = 1;
