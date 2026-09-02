-- check: MY-MEM-002
-- title: Buffer pool far smaller than the InnoDB working set
-- priority: 50 | category: MEM | scope: setting | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: pool_to_data_ratio=0.25;pool_to_ram_ratio=0.50
-- reads: @@GLOBAL.innodb_buffer_pool_size, information_schema.TABLES, @dbt_ram_bytes
-- CAVEAT that belongs in the finding, not a footnote: on MySQL 8.0
-- information_schema.TABLES sizes are served from a cache refreshed at most
-- every information_schema_stats_expiry seconds (default 86400), so the data
-- size can be up to a day stale. db-triage never runs ANALYZE TABLE to refresh
-- it. MariaDB reads the sizes live from the storage engine, so there the figure
-- is current. The details name which behaviour applies.
-- Only fires when the pool is ALSO not simply capped by host memory: if RAM is
-- known and the pool already holds half of it, the constraint is the host, and
-- MY-MEM-003/007 are the relevant findings instead.
SELECT
  'MY-MEM-002' AS check_id,
  'setting'    AS scope,
  'innodb_buffer_pool_size' AS object,
  CONCAT('Buffer pool is ', ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 2),
         ' GB against ', ROUND(s.bytes / 1073741824, 2), ' GB of InnoDB data and indexes (',
         ROUND(100.0 * @@GLOBAL.innodb_buffer_pool_size / s.bytes, 1), '%, threshold ',
         ROUND(100 * COALESCE(@pool_to_data_ratio, 0.25), 0), '%). ',
         'Buffer pool read miss rate since restart: ',
         IF(CAST(IFNULL(@dbt_s_innodb_buffer_pool_read_requests, 0) AS DECIMAL(30, 0)) > 0,
            CONCAT(ROUND(100.0 * CAST(IFNULL(@dbt_s_innodb_buffer_pool_reads, 0) AS DECIMAL(30, 0))
                       / CAST(@dbt_s_innodb_buffer_pool_read_requests AS DECIMAL(30, 0)), 2), '%'),
            'not measurable'),
         '. Host RAM: ', IF(@dbt_ram_bytes IS NULL, 'not supplied (set baseline.ram_gb)',
                            CONCAT(ROUND(@dbt_ram_bytes / 1073741824, 1), ' GB')),
         '. Sizes are ', IF(@dbt_is_mariadb,
            'read live from the storage engine',
            CONCAT('served from the information_schema cache and may be up to ',
                   ROUND(CAST(IFNULL(@dbt_v_information_schema_stats_expiry, 86400) AS DECIMAL(20,0)) / 3600, 1),
                   ' h stale (information_schema_stats_expiry)')),
         '.') AS details,
  JSON_OBJECT(
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'innodb_data_bytes', s.bytes,
    'pool_to_data_ratio', ROUND(@@GLOBAL.innodb_buffer_pool_size / s.bytes, 4),
    'threshold_ratio', COALESCE(@pool_to_data_ratio, 0.25),
    'ram_bytes', IFNULL(@dbt_ram_bytes, 'unknown'),
    'buffer_pool_reads', CAST(IFNULL(@dbt_s_innodb_buffer_pool_reads, 0) AS UNSIGNED),
    'buffer_pool_read_requests', CAST(IFNULL(@dbt_s_innodb_buffer_pool_read_requests, 0) AS UNSIGNED),
    'sizes_cached', IF(@dbt_is_mariadb, 0, 1)) AS evidence_json,
  IF(@dbt_ram_bytes IS NULL, 'medium', 'high') AS confidence
FROM (
  SELECT IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes
  FROM information_schema.TABLES
  WHERE ENGINE = 'InnoDB'
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS s
WHERE s.bytes > 0
  AND @@GLOBAL.innodb_buffer_pool_size < s.bytes * COALESCE(@pool_to_data_ratio, 0.25)
  AND (@dbt_ram_bytes IS NULL
       OR @@GLOBAL.innodb_buffer_pool_size < @dbt_ram_bytes * COALESCE(@pool_to_ram_ratio, 0.50));
