-- check: MY-SCHEMA-004
-- title: sql_mode is not strict
-- priority: 50 | category: SCHEMA | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @dbt_global_sql_mode (the GLOBAL value captured in 01_session.sql
--        BEFORE this session changed its own sql_mode)
-- IMPORTANT: this check must never read @@sql_mode or @@SESSION.sql_mode.
-- 01_session.sql deliberately sets a fixed SESSION sql_mode so the dynamic SQL
-- elsewhere parses identically on every fork, which would make a session-scoped
-- reading of this check report db-triage's own setting. @dbt_global_sql_mode is
-- the server's real GLOBAL value, snapshotted before that change.
-- Default divergence: MySQL 5.7+ and 8.x ship STRICT_TRANS_TABLES,
-- ERROR_FOR_DIVISION_BY_ZERO, NO_ZERO_DATE and NO_ZERO_IN_DATE on by default.
-- MariaDB 10.2.4+ ships STRICT_TRANS_TABLES and ERROR_FOR_DIVISION_BY_ZERO but
-- NOT NO_ZERO_DATE/NO_ZERO_IN_DATE, so a MariaDB server missing only those two
-- is at its documented default — the finding says which modes are missing and
-- distinguishes truncation (data loss) from zero dates (data that no client
-- library can represent).
-- Without STRICT_*, an INSERT of 300 into a TINYINT stores 127 and returns a
-- warning nobody reads; a 300-character string into VARCHAR(255) is silently cut.
SELECT
  'MY-SCHEMA-004' AS check_id,
  'setting'       AS scope,
  'sql_mode'      AS object,
  CONCAT('Global sql_mode = ''', IF(@dbt_global_sql_mode = '', '(empty)', @dbt_global_sql_mode),
         '''. Missing: ', m.missing, '. ',
         IF(m.no_strict,
            'Without STRICT_TRANS_TABLES an out-of-range or over-length value is silently coerced and stored: 300 into a TINYINT becomes 127, a 300-character string into VARCHAR(255) is truncated, and the statement succeeds with a warning. That is data loss the application never sees. ',
            ''),
         IF(m.no_zero_date,
            'Without NO_ZERO_DATE / NO_ZERO_IN_DATE the value ''0000-00-00'' can be stored, which most client libraries cannot represent and which breaks on any later migration. ',
            ''),
         'Changing sql_mode affects existing applications that rely on the lenient behaviour, so test before applying it globally.') AS details,
  JSON_OBJECT(
    'global_sql_mode', @dbt_global_sql_mode,
    'missing_modes', m.missing,
    'strict_missing', m.no_strict,
    'zero_date_missing', m.no_zero_date,
    'fork', @dbt_fork,
    'server_version', @@GLOBAL.version) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    (@dbt_global_sql_mode NOT LIKE '%STRICT_TRANS_TABLES%'
     AND @dbt_global_sql_mode NOT LIKE '%STRICT_ALL_TABLES%') AS no_strict,
    (@dbt_global_sql_mode NOT LIKE '%NO_ZERO_DATE%'
     OR @dbt_global_sql_mode NOT LIKE '%NO_ZERO_IN_DATE%')    AS no_zero_date,
    CONCAT_WS(', ',
      IF(@dbt_global_sql_mode NOT LIKE '%STRICT_TRANS_TABLES%'
         AND @dbt_global_sql_mode NOT LIKE '%STRICT_ALL_TABLES%', 'STRICT_TRANS_TABLES', NULL),
      IF(@dbt_global_sql_mode NOT LIKE '%ERROR_FOR_DIVISION_BY_ZERO%', 'ERROR_FOR_DIVISION_BY_ZERO', NULL),
      IF(@dbt_global_sql_mode NOT LIKE '%NO_ZERO_DATE%', 'NO_ZERO_DATE', NULL),
      IF(@dbt_global_sql_mode NOT LIKE '%NO_ZERO_IN_DATE%', 'NO_ZERO_IN_DATE', NULL)) AS missing
) AS m
WHERE m.missing <> '';
