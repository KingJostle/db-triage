-- check: PG-CONN-006
-- title: Sessions ending abnormally
-- priority: 100
-- scope: database
-- cost: 0
-- min_version: 14
-- thresholds: abnormal_fraction, min_sessions
SELECT 'PG-CONN-006'::text AS check_id,
       'database'::text    AS scope,
       d.datname::text     AS object,
       format('%s of %s sessions in database %s ended abnormally (%s%%, threshold %s%%) since %s: %s fatal errors, %s killed by an administrator, %s abandoned by the client without a clean disconnect. Abandoned sessions usually mean a network device or a container runtime cutting idle connections; fatal ones mean the server refused or terminated them. Each one is an error the application had to handle, or did not.',
              to_char(d.sessions_fatal + d.sessions_killed + d.sessions_abandoned, 'FM999,999,999,999'),
              to_char(d.sessions, 'FM999,999,999,999'), d.datname,
              round(100.0 * (d.sessions_fatal + d.sessions_killed + d.sessions_abandoned) / nullif(d.sessions, 0), 2)::text,
              round(100 * :'pg_conn_006_abnormal_fraction'::numeric, 2)::text,
              coalesce(d.stats_reset::text, 'the last statistics reset'),
              d.sessions_fatal, d.sessions_killed, d.sessions_abandoned) AS details,
       json_build_object('datname', d.datname, 'sessions', d.sessions,
                         'sessions_fatal', d.sessions_fatal, 'sessions_killed', d.sessions_killed,
                         'sessions_abandoned', d.sessions_abandoned,
                         'abnormal_fraction', round((d.sessions_fatal + d.sessions_killed + d.sessions_abandoned)::numeric
                                                    / nullif(d.sessions, 0), 4),
                         'threshold_fraction', :'pg_conn_006_abnormal_fraction'::numeric,
                         'stats_reset', d.stats_reset)::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_stat_database d
WHERE d.datname IS NOT NULL
  AND d.sessions >= :'pg_conn_006_min_sessions'::bigint
  AND (d.sessions_fatal + d.sessions_killed + d.sessions_abandoned)::numeric / nullif(d.sessions, 0)
      >= :'pg_conn_006_abnormal_fraction'::numeric
ORDER BY (d.sessions_fatal + d.sessions_killed + d.sessions_abandoned) DESC;
