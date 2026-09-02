-- check: MY-REL-001
-- title: Server version is past end of life
-- priority: 20 | category: REL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: eol_as_of=2026-09-02
-- reads: @@GLOBAL.version, @dbt_fork, and the embedded release table below
-- SOURCE OF THE DATES. The design puts EOL dates in reference/versions.yml with
-- an `as_of` stamp. That file is generated elsewhere in the repo, so this check
-- embeds the same table as a UNION ALL of literals and stamps it with
-- @dbt_eol_as_of. The runner SHOULD overwrite @dbt_eol_as_of and the branch rows
-- from versions.yml when it has them; when it does not, XX-META-004 fires if the
-- embedded stamp is more than a year old and every REL finding drops to low
-- confidence, exactly as the design specifies.
-- Working values as of 2026-09-02, from dev.mysql.com and mariadb.org:
--   MySQL   5.7  EOL 2023-10-31   8.0 EOL 2026-04-30   8.4 LTS EOL 2032-04-30
--           9.x  innovation releases: supported only until the next one ships
--   MariaDB 10.4 EOL 2024-06-18   10.5 EOL 2025-06-24  10.6 EOL 2026-07-06
--           10.11 EOL 2028-02-16  11.4 EOL 2029-05-29  11.8 EOL 2030-06-04
-- Note that MySQL 8.0 reached EOL in April 2026, so most fleets trip this.
-- Past EOL means no security patches at all: a CVE published tomorrow has no fix
-- for this server, and the only remedy is the major upgrade that was already due.
SET @dbt_eol_as_of := IFNULL(@dbt_eol_as_of, '2026-09-02');
SET @dbt_q := "
SELECT
  'MY-REL-001' AS check_id,
  'cluster'    AS scope,
  CONCAT(v.fork, ' ', v.branch) AS object,
  CONCAT(v.fork, ' ', @@GLOBAL.version, ' is on the ', v.branch,
         ' branch, which reached end of life on ', v.eol, ' — ',
         DATEDIFF(CURDATE(), v.eol), ' days ago. ',
         'There are no further security patches for this branch: a vulnerability published tomorrow will have no fix for this server. ',
         'Next supported branch: ', v.successor, '. ',
         'Release data as of ', @dbt_eol_as_of,
         '; if that is more than a year old, treat this finding as low confidence and check the vendor page.') AS details,
  JSON_OBJECT(
    'fork', v.fork,
    'version', @@GLOBAL.version,
    'branch', v.branch,
    'eol_date', v.eol,
    'days_past_eol', DATEDIFF(CURDATE(), v.eol),
    'successor', v.successor,
    'release_data_as_of', @dbt_eol_as_of) AS evidence_json,
  IF(DATEDIFF(CURDATE(), @dbt_eol_as_of) > 365, 'low', 'high') AS confidence
FROM (BRANCHES) AS v
WHERE v.eol < CURDATE()";

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
