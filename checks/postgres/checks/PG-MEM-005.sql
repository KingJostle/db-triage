-- check: PG-MEM-005
-- title: maintenance_work_mem at the default on a large database
-- priority: 100
-- scope: setting
-- cost: 0
-- thresholds: maintenance_work_mem_bytes, total_bytes
SELECT 'PG-MEM-005'::text            AS check_id,
       'setting'::text               AS scope,
       'maintenance_work_mem'::text  AS object,
       format('maintenance_work_mem = %s (threshold %s) while the connectable databases total %s (threshold %s). This is the working memory for CREATE INDEX, REINDEX, ALTER TABLE rewrites and, before PostgreSQL 17, for the dead-tuple array of every vacuum: a vacuum that exceeds it has to make an extra pass over every index. autovacuum_work_mem = %s, autovacuum_max_workers = %s, so the autovacuum ceiling is %s in total.',
              current_setting('maintenance_work_mem'),
              pg_size_pretty(:'pg_mem_005_maintenance_work_mem_bytes'::bigint),
              pg_size_pretty((SELECT sum(pg_database_size(oid)) FROM pg_database WHERE datallowconn)),
              pg_size_pretty(:'pg_mem_005_total_bytes'::bigint),
              current_setting('autovacuum_work_mem'),
              (SELECT setting FROM pg_settings WHERE name = 'autovacuum_max_workers'),
              pg_size_pretty(((SELECT setting::bigint FROM pg_settings WHERE name = 'autovacuum_max_workers')
                              * (CASE WHEN (SELECT setting::bigint FROM pg_settings WHERE name = 'autovacuum_work_mem') < 0
                                      THEN (SELECT setting::bigint FROM pg_settings WHERE name = 'maintenance_work_mem')
                                      ELSE (SELECT setting::bigint FROM pg_settings WHERE name = 'autovacuum_work_mem') END) * 1024)::bigint)) AS details,
       json_build_object('maintenance_work_mem_bytes', (SELECT setting::bigint * 1024 FROM pg_settings WHERE name = 'maintenance_work_mem'),
                         'threshold_bytes', :'pg_mem_005_maintenance_work_mem_bytes'::bigint,
                         'cluster_bytes', (SELECT sum(pg_database_size(oid)) FROM pg_database WHERE datallowconn),
                         'threshold_cluster_bytes', :'pg_mem_005_total_bytes'::bigint,
                         'autovacuum_work_mem', current_setting('autovacuum_work_mem'),
                         'autovacuum_max_workers', (SELECT setting::int FROM pg_settings WHERE name = 'autovacuum_max_workers'))::text AS evidence_json,
       'medium'::text AS confidence
WHERE (SELECT setting::bigint * 1024 FROM pg_settings WHERE name = 'maintenance_work_mem') <= :'pg_mem_005_maintenance_work_mem_bytes'::bigint
  AND (SELECT sum(pg_database_size(oid)) FROM pg_database WHERE datallowconn) >= :'pg_mem_005_total_bytes'::bigint;
