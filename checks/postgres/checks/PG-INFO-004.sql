-- check: PG-INFO-004
-- title: Replication topology
-- priority: 250
-- scope: cluster
-- cost: 0
-- primary_conninfo is emitted with any password removed; db-triage never
-- reports a credential.
SELECT 'PG-INFO-004'::text AS check_id,
       'cluster'::text     AS scope,
       NULL::text          AS object,
       format('This node is a %s. Connected standbys (%s): %s. Replication slots (%s): %s. Upstream: %s. synchronous_standby_names = %s, synchronous_commit = %s. Publications (%s): %s. Subscriptions (%s): %s.',
              CASE WHEN pg_is_in_recovery() THEN 'STANDBY' ELSE 'PRIMARY' END,
              (SELECT count(*) FROM pg_stat_replication),
              coalesce((SELECT string_agg(format('%s at %s [state %s, sync %s, replay lag %s, %s behind]',
                                                 coalesce(nullif(application_name, ''), 'unnamed'),
                                                 coalesce(host(client_addr), 'local'), state, sync_state,
                                                 coalesce(replay_lag::text, 'unknown'),
                                                 coalesce(pg_size_pretty(greatest(pg_wal_lsn_diff(sent_lsn, replay_lsn), 0)::bigint), '?')),
                                          '; ' ORDER BY application_name)
                        FROM pg_stat_replication), 'none'),
              (SELECT count(*) FROM pg_replication_slots),
              coalesce((SELECT string_agg(format('%s [%s%s, active=%s]', slot_name, slot_type,
                                                 coalesce('/' || plugin, ''), active), '; ' ORDER BY slot_name)
                        FROM pg_replication_slots), 'none'),
              coalesce(regexp_replace(nullif(current_setting('primary_conninfo'), ''),
                                      '(password|passfile)\s*=\s*''?[^'' ]+''?', '\1=<redacted>', 'gi'),
                       'none (this node has no upstream configured)'),
              coalesce(nullif(current_setting('synchronous_standby_names'), ''), '(empty)'),
              current_setting('synchronous_commit'),
              (SELECT count(*) FROM pg_publication),
              coalesce((SELECT string_agg(pubname, ', ' ORDER BY pubname) FROM pg_publication), 'none'),
              (SELECT count(*) FROM pg_subscription),
              coalesce((SELECT string_agg(format('%s [enabled=%s]', subname, subenabled), ', ' ORDER BY subname)
                        FROM pg_subscription), 'none')) AS details,
       json_build_object('in_recovery', pg_is_in_recovery(),
                         'standby_count', (SELECT count(*) FROM pg_stat_replication),
                         'slot_count', (SELECT count(*) FROM pg_replication_slots),
                         'inactive_slot_count', (SELECT count(*) FROM pg_replication_slots WHERE NOT active),
                         'publication_count', (SELECT count(*) FROM pg_publication),
                         'subscription_count', (SELECT count(*) FROM pg_subscription),
                         'synchronous_standby_names', current_setting('synchronous_standby_names'),
                         'synchronous_commit', current_setting('synchronous_commit'),
                         'max_wal_senders', current_setting('max_wal_senders')::int,
                         'max_replication_slots', current_setting('max_replication_slots')::int,
                         'wal_level', current_setting('wal_level'),
                         'primary_conninfo_redacted',
                            regexp_replace(current_setting('primary_conninfo'),
                                           '(password|passfile)\s*=\s*''?[^'' ]+''?', '\1=<redacted>', 'gi'))::text AS evidence_json,
       'high'::text AS confidence;
