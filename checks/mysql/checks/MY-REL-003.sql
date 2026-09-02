-- check: MY-REL-003
-- title: Server version within six months of end of life
-- priority: 100 | category: REL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: eol_warning_days=180;eol_as_of=2026-09-02
-- reads: as MY-REL-001
-- The lead time this finding exists to protect: a major-version upgrade on a
-- production database is a rehearsal, an application compatibility pass, a
-- replica-first rollout and a rollback plan. Six months is roughly the minimum
-- for that to happen calmly rather than as an incident, which is why the warning
-- comes here rather than at MY-REL-001 when the date has already passed.
SET @dbt_eol_as_of := IFNULL(@dbt_eol_as_of, '2026-09-02');
SET @dbt_q := "
SELECT
  'MY-REL-003' AS check_id,
  'cluster'    AS scope,
  CONCAT(v.fork, ' ', v.branch) AS object,
  CONCAT(v.fork, ' ', @@GLOBAL.version, ' (branch ', v.branch,
         ') reaches end of life on ', v.eol, ' — in ',
         DATEDIFF(v.eol, CURDATE()), ' days (threshold ',
         COALESCE(@eol_warning_days, 180), ' days). Next supported branch: ',
         v.successor, '. ',
         'A major upgrade on a production database needs a rehearsal, an application compatibility pass, a replica-first rollout and a rollback plan; ',
         DATEDIFF(v.eol, CURDATE()),
         ' days is enough to do that calmly and not much more. ',
         'Release data as of ', @dbt_eol_as_of, '.') AS details,
  JSON_OBJECT(
    'fork', v.fork, 'version', @@GLOBAL.version, 'branch', v.branch,
    'eol_date', v.eol, 'days_until_eol', DATEDIFF(v.eol, CURDATE()),
    'successor', v.successor,
    'threshold_days', COALESCE(@eol_warning_days, 180),
    'release_data_as_of', @dbt_eol_as_of) AS evidence_json,
  IF(DATEDIFF(CURDATE(), @dbt_eol_as_of) > 365, 'low', 'high') AS confidence
FROM (BRANCHES) AS v
WHERE v.eol >= CURDATE()
  AND DATEDIFF(v.eol, CURDATE()) <= COALESCE(@eol_warning_days, 180)";
-- The release table is redefined here rather than inherited from MY-REL-001,
-- so this check still works when the runner is invoked with --only MY-REL-002.
-- The release table. Matched on fork + major.minor.
SET @dbt_branches := "
  SELECT b.* FROM (
              SELECT 'mysql'   AS fork, '5.7'   AS branch, '2023-10-31' AS eol, '8.4 LTS' AS successor
    UNION ALL SELECT 'mysql',   '8.0',   '2026-04-30', '8.4 LTS'
    UNION ALL SELECT 'mysql',   '8.4',   '2032-04-30', '9.x innovation / the next LTS'
    UNION ALL SELECT 'percona', '5.7',   '2023-10-31', '8.4 LTS'
    UNION ALL SELECT 'percona', '8.0',   '2026-04-30', '8.4 LTS'
    UNION ALL SELECT 'percona', '8.4',   '2032-04-30', 'the next LTS'
    UNION ALL SELECT 'mariadb', '10.4',  '2024-06-18', '10.11 LTS'
    UNION ALL SELECT 'mariadb', '10.5',  '2025-06-24', '10.11 LTS'
    UNION ALL SELECT 'mariadb', '10.6',  '2026-07-06', '10.11 LTS or 11.4 LTS'
    UNION ALL SELECT 'mariadb', '10.11', '2028-02-16', '11.4 LTS'
    UNION ALL SELECT 'mariadb', '11.4',  '2029-05-29', '11.8 LTS'
    UNION ALL SELECT 'mariadb', '11.8',  '2030-06-04', 'the next LTS'
  ) AS b
  WHERE b.fork = @dbt_fork
    AND b.branch = CONCAT(@dbt_vmajor, '.', @dbt_vminor)";

SET @dbt_q := REPLACE(@dbt_q, 'BRANCHES', @dbt_branches);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
