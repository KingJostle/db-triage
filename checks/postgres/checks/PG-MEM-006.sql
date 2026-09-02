-- check: PG-MEM-006
-- title: effective_cache_size at the default
-- priority: 100
-- scope: setting
-- cost: 0
SELECT 'PG-MEM-006'::text            AS check_id,
       'setting'::text               AS scope,
       'effective_cache_size'::text  AS object,
       format('effective_cache_size is at the default %s with source %s. This setting allocates no memory: it tells the planner how much of the data it can expect to find cached, in shared_buffers plus the operating-system page cache. Left at 4 GB on a host with more memory than that, the planner over-estimates the cost of repeated index lookups and drifts towards sequential scans and hash joins. The usual starting point is 50 to 75 percent of RAM. shared_buffers = %s, cluster size %s.',
              pg_size_pretty(s.setting::bigint * 8192), s.source,
              current_setting('shared_buffers'),
              pg_size_pretty((SELECT sum(pg_database_size(oid)) FROM pg_database))) AS details,
       json_build_object('effective_cache_size_bytes', s.setting::bigint * 8192,
                         'source', s.source, 'boot_val_bytes', s.boot_val::bigint * 8192,
                         'shared_buffers', current_setting('shared_buffers'),
                         'cluster_bytes', (SELECT sum(pg_database_size(oid)) FROM pg_database),
                         'random_page_cost', (SELECT setting FROM pg_settings WHERE name = 'random_page_cost'))::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_settings s
WHERE s.name = 'effective_cache_size' AND s.source = 'default';
