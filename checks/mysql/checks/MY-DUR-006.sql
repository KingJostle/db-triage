-- check: MY-DUR-006
-- title: InnoDB page checksums disabled
-- priority: 50 | category: DUR | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @dbt_v_innodb_checksum_algorithm (bundle: present in MySQL 5.6+ and
--        MariaDB 10.x, but read through the bundle so a fork that drops it
--        yields NULL and this check stays silent instead of erroring)
-- 'none' means InnoDB writes a constant instead of a checksum and never verifies
-- it. Silent bit rot in the storage stack then reaches the buffer pool as if it
-- were good data. The PostgreSQL analogue is PG-CORR-004 (data checksums off).
SELECT
  'MY-DUR-006' AS check_id,
  'setting'    AS scope,
  'innodb_checksum_algorithm' AS object,
  CONCAT('innodb_checksum_algorithm = ', @dbt_v_innodb_checksum_algorithm,
         ': InnoDB neither writes nor verifies page checksums, so corruption arriving from the storage layer is read into the buffer pool undetected. ',
         'Data size at risk: ', s.gb, ' GB of InnoDB data and indexes.') AS details,
  JSON_OBJECT(
    'innodb_checksum_algorithm', @dbt_v_innodb_checksum_algorithm,
    'innodb_data_gb', s.gb,
    'innodb_doublewrite', CAST(@@GLOBAL.innodb_doublewrite AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT ROUND(IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) / 1073741824, 1) AS gb
  FROM information_schema.TABLES
  WHERE ENGINE = 'InnoDB'
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS s
WHERE LOWER(IFNULL(@dbt_v_innodb_checksum_algorithm, '')) = 'none';
