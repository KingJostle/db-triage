-- check: PG-REPL-001
-- title: Synchronous replication configured but no synchronous standby connected
-- priority: 1
-- scope: cluster
-- cost: 0
-- min_version: 9.6
-- run_on: primary
SELECT 'PG-REPL-001'::text AS check_id,
       'cluster'::text     AS scope,
       'synchronous_standby_names'::text AS object,
       format('synchronous_standby_names = %s and synchronous_commit = %s, but no connected standby is in sync_state sync or quorum. Every COMMIT that needs a synchronous confirmation is waiting and will keep waiting until a matching standby connects. Connected standbys: %s. Sessions currently in state active: %s.',
              quote_literal(current_setting('synchronous_standby_names')),
              current_setting('synchronous_commit'),
              coalesce((SELECT string_agg(format('%s (%s, %s)', coalesce(nullif(application_name, ''), 'unnamed'),
                                                 coalesce(host(client_addr), 'local'), sync_state), '; ')
                        FROM pg_stat_replication), 'none'),
              (SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND backend_type = 'client backend')) AS details,
       json_build_object('synchronous_standby_names', current_setting('synchronous_standby_names'),
                         'synchronous_commit', current_setting('synchronous_commit'),
                         'connected_standbys', (SELECT count(*) FROM pg_stat_replication),
                         'sync_standbys', (SELECT count(*) FROM pg_stat_replication WHERE sync_state IN ('sync', 'quorum')),
                         'active_sessions', (SELECT count(*) FROM pg_stat_activity
                                             WHERE state = 'active' AND backend_type = 'client backend'))::text AS evidence_json,
       'high'::text AS confidence
WHERE NOT pg_is_in_recovery()
  AND coalesce(nullif(trim(current_setting('synchronous_standby_names')), ''), '') <> ''
  AND current_setting('synchronous_commit') NOT IN ('off', 'local')
  AND NOT EXISTS (SELECT 1 FROM pg_stat_replication WHERE sync_state IN ('sync', 'quorum'));
