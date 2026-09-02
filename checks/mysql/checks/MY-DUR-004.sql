-- check: MY-DUR-004
-- title: InnoDB doublewrite buffer disabled
-- priority: 1 | category: DUR | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.innodb_doublewrite, @@GLOBAL.innodb_page_size
-- Type divergence: MariaDB and MySQL < 8.0.30 expose this as a boolean (1/0);
-- MySQL 8.0.30+ made it an enum (ON | OFF | DETECT_ONLY | DETECT_AND_RECOVER).
-- Casting to CHAR and comparing against a set covers both. DETECT_ONLY writes
-- only page metadata, so torn pages are detected but not repairable — that is
-- still a loss of the crash-recovery guarantee, so it fires too.
SELECT
  'MY-DUR-004' AS check_id,
  'setting'    AS scope,
  'innodb_doublewrite' AS object,
  CONCAT('innodb_doublewrite = ', d.val,
         IF(d.val = 'DETECT_ONLY',
            ': only page metadata is doublewritten, so a torn page is detected but cannot be recovered.',
            ': torn pages are neither detected nor recoverable.'),
         ' A power loss or kernel panic mid-write leaves a partially written ',
         @@GLOBAL.innodb_page_size,
         '-byte page that InnoDB cannot repair, unless the storage layer guarantees atomic writes of that size (ZFS, some NVMe with atomic-write support, Fusion-io). Confirm the filesystem and device before treating this as intentional.') AS details,
  JSON_OBJECT(
    'innodb_doublewrite', d.val,
    'innodb_page_size', @@GLOBAL.innodb_page_size,
    'innodb_flush_method', IFNULL(@dbt_v_innodb_flush_method, 'unknown')) AS evidence_json,
  'high' AS confidence
FROM (SELECT UPPER(CAST(@@GLOBAL.innodb_doublewrite AS CHAR)) AS val) AS d
WHERE d.val IN ('0', 'OFF', 'DETECT_ONLY');
