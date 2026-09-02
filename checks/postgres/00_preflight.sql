-- db-triage PostgreSQL preflight.
--
-- Emits five labelled result sets. Every one is catalog-only and cost 0 except
-- the last two probes, which are cheap directory listings. The two probes are
-- expected to fail on managed platforms and on non-superuser roles; run this
-- file with ON_ERROR_STOP off so a failure records a capability rather than
-- aborting the run.
--
-- Consumers: bin/db-triage, and Claude reading the output by hand.

\echo '@@PREFLIGHT core'
SELECT 'postgresql'                                              AS engine,
       current_setting('server_version_num')::int                AS version_num,
       version()                                                 AS version_string,
       current_setting('server_version')                         AS version_short,
       pg_is_in_recovery()                                       AS in_recovery,
       current_user                                              AS connected_role,
       current_setting('is_superuser') = 'on'                    AS is_superuser,
       pg_has_role(current_user, 'pg_monitor', 'USAGE')           AS has_pg_monitor,
       pg_has_role(current_user, 'pg_read_all_stats', 'USAGE')    AS has_read_all_stats,
       pg_has_role(current_user, 'pg_read_all_settings', 'USAGE') AS has_read_all_settings,
       current_database()                                        AS current_database,
       pg_postmaster_start_time()                                AS postmaster_start_time,
       extract(epoch FROM now() - pg_postmaster_start_time())::bigint AS uptime_seconds,
       current_setting('data_checksums')                         AS data_checksums,
       current_setting('wal_level')                              AS wal_level,
       current_setting('cluster_name')                           AS cluster_name,
       current_setting('shared_preload_libraries') LIKE '%pg_stat_statements%' AS pgss_preloaded,
       EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements') AS pgss_installed,
       (SELECT extversion FROM pg_extension WHERE extname = 'pg_stat_statements') AS pgss_version,
       (SELECT min(s) FROM (SELECT min(stats_reset) FROM pg_stat_database
                            UNION ALL SELECT stats_reset FROM pg_stat_bgwriter) t(s)) AS earliest_stats_reset,
       CASE
         WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'aurora_version')            THEN 'aurora'
         WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rdsadmin')
           OR EXISTS (SELECT 1 FROM pg_settings WHERE name LIKE 'rds.%')                 THEN 'rds'
         WHEN EXISTS (SELECT 1 FROM pg_settings WHERE name LIKE 'alloydb.%')             THEN 'alloydb'
         WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN ('cloudsqladmin','cloudsqlsuperuser'))
                                                                                          THEN 'cloudsql'
         WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'azure_pg_admin')
           OR EXISTS (SELECT 1 FROM pg_settings WHERE name LIKE 'azure.%')               THEN 'azure'
         WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')           THEN 'supabase'
         WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'neon_superuser')           THEN 'neon'
         WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tsdbadmin')                THEN 'timescale'
         WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crunchy_superuser')        THEN 'crunchy'
         WHEN EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'heroku_ext')           THEN 'heroku'
         ELSE 'self-managed'
       END                                                       AS platform;

\echo '@@PREFLIGHT databases'
SELECT d.datname                            AS datname,
       pg_database_size(d.oid)              AS size_bytes,
       d.datallowconn                       AS allow_conn,
       d.datistemplate                      AS is_template,
       t.spcname                            AS tablespace,
       shobj_description(d.oid, 'pg_database') IS NOT NULL AS has_comment
FROM pg_database d
JOIN pg_tablespace t ON t.oid = d.dattablespace
ORDER BY pg_database_size(d.oid) DESC;

\echo '@@PREFLIGHT roles'
SELECT count(*) FILTER (WHERE rolcanlogin)                       AS login_roles,
       count(*) FILTER (WHERE rolsuper)                          AS superusers,
       count(*) FILTER (WHERE rolreplication)                    AS replication_roles,
       count(*)                                                  AS total_roles
FROM pg_roles;

-- Capability probe. Expected to fail without superuser; the runner records
-- hba_readable = false and PG-SEC-012 fires so the report says the
-- authentication checks were blind.
\echo '@@PREFLIGHT hba_probe'
SELECT count(*) AS hba_rule_count FROM pg_hba_file_rules;

-- Capability probe. pg_monitor is enough on 11+; managed platforms often deny it.
\echo '@@PREFLIGHT waldir_probe'
SELECT count(*) AS wal_segment_count FROM pg_ls_waldir();

\echo '@@PREFLIGHT end'
