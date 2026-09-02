-- check: PG-INFO-001
-- title: Server identity
-- priority: 250
-- scope: cluster
-- cost: 0
SELECT 'PG-INFO-001'::text AS check_id,
       'cluster'::text     AS scope,
       NULL::text          AS object,
       format('%s. Role: %s. Started %s (up %s). cluster_name = %s. data_checksums = %s, wal_level = %s, max_connections = %s, shared_buffers = %s, work_mem = %s, effective_cache_size = %s. Encoding %s, TimeZone %s. Worst-case memory commitment if every connection used work_mem twice: %s. Cluster holds %s across %s database(s).',
              version(),
              CASE WHEN pg_is_in_recovery() THEN 'STANDBY (in recovery)' ELSE 'PRIMARY' END,
              pg_postmaster_start_time(),
              justify_interval(date_trunc('second', now() - pg_postmaster_start_time())),
              coalesce(nullif(current_setting('cluster_name'), ''), '(unset)'),
              current_setting('data_checksums'), current_setting('wal_level'),
              current_setting('max_connections'), current_setting('shared_buffers'),
              current_setting('work_mem'), current_setting('effective_cache_size'),
              current_setting('server_encoding'), current_setting('TimeZone'),
              pg_size_pretty(((SELECT setting::bigint * 8192 FROM pg_settings WHERE name = 'shared_buffers')
                            + (SELECT setting::bigint FROM pg_settings WHERE name = 'max_connections')
                              * (SELECT setting::bigint * 1024 FROM pg_settings WHERE name = 'work_mem') * 2
                            + (SELECT setting::bigint FROM pg_settings WHERE name = 'autovacuum_max_workers')
                              * (SELECT setting::bigint * 1024 FROM pg_settings WHERE name = 'maintenance_work_mem'))::bigint),
              pg_size_pretty((SELECT sum(pg_database_size(oid)) FROM pg_database)),
              (SELECT count(*) FROM pg_database)) AS details,
       json_build_object('version', version(),
                         'server_version_num', current_setting('server_version_num')::int,
                         'in_recovery', pg_is_in_recovery(),
                         'postmaster_start_time', pg_postmaster_start_time(),
                         'uptime_seconds', round(extract(epoch FROM now() - pg_postmaster_start_time()))::bigint,
                         'cluster_name', current_setting('cluster_name'),
                         'data_checksums', current_setting('data_checksums'),
                         'wal_level', current_setting('wal_level'),
                         'max_connections', current_setting('max_connections')::int,
                         'shared_buffers_bytes', (SELECT setting::bigint * 8192 FROM pg_settings WHERE name = 'shared_buffers'),
                         'work_mem_bytes', (SELECT setting::bigint * 1024 FROM pg_settings WHERE name = 'work_mem'),
                         'effective_cache_size_bytes', (SELECT setting::bigint * 8192 FROM pg_settings WHERE name = 'effective_cache_size'),
                         'worst_case_memory_bytes',
                            ((SELECT setting::bigint * 8192 FROM pg_settings WHERE name = 'shared_buffers')
                           + (SELECT setting::bigint FROM pg_settings WHERE name = 'max_connections')
                             * (SELECT setting::bigint * 1024 FROM pg_settings WHERE name = 'work_mem') * 2
                           + (SELECT setting::bigint FROM pg_settings WHERE name = 'autovacuum_max_workers')
                             * (SELECT setting::bigint * 1024 FROM pg_settings WHERE name = 'maintenance_work_mem')),
                         'server_encoding', current_setting('server_encoding'),
                         'timezone', current_setting('TimeZone'),
                         'cluster_bytes', (SELECT sum(pg_database_size(oid)) FROM pg_database),
                         'database_count', (SELECT count(*) FROM pg_database),
                         'current_database', current_database(),
                         'connected_role', current_user,
                         'is_superuser', current_setting('is_superuser'))::text AS evidence_json,
       'high'::text AS confidence;
