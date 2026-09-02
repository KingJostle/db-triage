-- check: PG-REPL-012
-- title: Logical subscription disabled or erroring
-- priority: 10
-- scope: cluster
-- cost: 0
-- min_version: 10
\set ON_ERROR_STOP off
SELECT (current_setting('server_version_num')::int >= 150000) AS pg_repl_012_has_sub_stats \gset
\if :pg_repl_012_has_sub_stats
SELECT 'PG-REPL-012'::text AS check_id,
       'cluster'::text     AS scope,
       s.subname::text     AS object,
       format('Logical subscription %s: enabled = %s, %s apply worker(s) running, %s apply error(s) and %s table-sync error(s) since %s. Publications: %s. While a subscription is stopped or erroring, the subscriber diverges from the publisher and the publisher''s replication slot keeps retaining WAL for it (see PG-REPL-002/003).',
              s.subname, s.subenabled,
              (SELECT count(*) FROM pg_stat_subscription ss WHERE ss.subid = s.oid AND ss.pid IS NOT NULL),
              st.apply_error_count, st.sync_error_count,
              coalesce(st.stats_reset::text, 'the subscription was created'),
              coalesce(array_to_string(s.subpublications, ', '), 'none')) AS details,
       json_build_object('subname', s.subname, 'subenabled', s.subenabled,
                         'workers', (SELECT count(*) FROM pg_stat_subscription ss WHERE ss.subid = s.oid AND ss.pid IS NOT NULL),
                         'apply_error_count', st.apply_error_count,
                         'sync_error_count', st.sync_error_count,
                         'stats_reset', st.stats_reset,
                         'publications', array_to_string(s.subpublications, ';'),
                         'subslotname', s.subslotname)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_subscription s
LEFT JOIN pg_stat_subscription_stats st ON st.subid = s.oid
WHERE s.subdbid = (SELECT oid FROM pg_database WHERE datname = current_database())
  AND (NOT s.subenabled
       OR coalesce(st.apply_error_count, 0) > 0
       OR coalesce(st.sync_error_count, 0) > 0
       OR NOT EXISTS (SELECT 1 FROM pg_stat_subscription ss WHERE ss.subid = s.oid AND ss.pid IS NOT NULL));
\else
SELECT 'PG-REPL-012'::text AS check_id,
       'cluster'::text     AS scope,
       s.subname::text     AS object,
       format('Logical subscription %s: enabled = %s, %s apply worker(s) running. Publications: %s. This server predates pg_stat_subscription_stats (PostgreSQL 15), so apply and table-sync error counts are not available; check the server log for "logical replication apply worker" errors. While a subscription is stopped, the subscriber diverges from the publisher and the publisher''s slot keeps retaining WAL.',
              s.subname, s.subenabled,
              (SELECT count(*) FROM pg_stat_subscription ss WHERE ss.subid = s.oid AND ss.pid IS NOT NULL),
              coalesce(array_to_string(s.subpublications, ', '), 'none')) AS details,
       json_build_object('subname', s.subname, 'subenabled', s.subenabled,
                         'workers', (SELECT count(*) FROM pg_stat_subscription ss WHERE ss.subid = s.oid AND ss.pid IS NOT NULL),
                         'publications', array_to_string(s.subpublications, ';'),
                         'error_counts_available', false)::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_subscription s
WHERE s.subdbid = (SELECT oid FROM pg_database WHERE datname = current_database())
  AND (NOT s.subenabled
       OR NOT EXISTS (SELECT 1 FROM pg_stat_subscription ss WHERE ss.subid = s.oid AND ss.pid IS NOT NULL));
\endif
