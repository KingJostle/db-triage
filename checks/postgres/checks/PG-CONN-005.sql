-- check: PG-CONN-005
-- title: High connection churn
-- priority: 100
-- scope: cluster
-- cost: 0
-- min_version: 14
-- thresholds: sessions_per_second
WITH w AS (
  SELECT sum(sessions)::numeric AS sessions,
         greatest(extract(epoch FROM now() - coalesce(min(stats_reset), pg_postmaster_start_time())), 60) AS secs,
         min(stats_reset) AS stats_reset
  FROM pg_stat_database WHERE datname IS NOT NULL
)
SELECT 'PG-CONN-005'::text AS check_id,
       'cluster'::text     AS scope,
       NULL::text          AS object,
       format('%s sessions were established in %s: %s per second (threshold %s per second), counted from pg_stat_database since %s. PostgreSQL forks a process and builds fresh catalog caches for every connection, so at this rate a measurable share of the server''s CPU is spent on connection setup rather than on queries, and each connection pays that cost in its own latency. A transaction-mode or session-mode pooler removes it. Currently %s client backends are connected.',
              to_char(w.sessions, 'FM999,999,999,999'),
              justify_interval(date_trunc('second', make_interval(secs => w.secs))),
              round(w.sessions / w.secs, 1)::text,
              :'pg_conn_005_sessions_per_second'::text,
              coalesce(w.stats_reset::text, 'the last statistics reset'),
              (SELECT count(*) FROM pg_stat_activity WHERE backend_type = 'client backend')) AS details,
       json_build_object('sessions', w.sessions::bigint, 'window_seconds', round(w.secs)::bigint,
                         'sessions_per_second', round(w.sessions / w.secs, 3),
                         'threshold_per_second', :'pg_conn_005_sessions_per_second'::numeric,
                         'stats_reset', w.stats_reset,
                         'current_client_backends', (SELECT count(*) FROM pg_stat_activity WHERE backend_type = 'client backend'))::text AS evidence_json,
       'medium'::text AS confidence
FROM w
WHERE w.sessions / w.secs >= :'pg_conn_005_sessions_per_second'::numeric;
