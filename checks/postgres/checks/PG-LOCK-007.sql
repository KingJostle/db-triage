-- check: PG-LOCK-007
-- title: idle_in_transaction_session_timeout disabled
-- priority: 100
-- scope: setting
-- cost: 0
-- min_version: 9.6
SELECT 'PG-LOCK-007'::text                        AS check_id,
       'setting'::text                            AS scope,
       'idle_in_transaction_session_timeout'::text AS object,
       format('idle_in_transaction_session_timeout = 0 at server level with no role or database override for it. Nothing stops a client that opened a transaction and then went away - a paused debugger, a crashed worker, a connection a firewall silently dropped - from holding its locks and the cluster''s xmin horizon indefinitely (PG-LOCK-003, PG-VAC-005). %s session(s) are in an idle-in-transaction state right now, the oldest for %s. 5 to 15 minutes for application roles is a common setting; leave interactive and migration roles alone.',
              (SELECT count(*) FROM pg_stat_activity WHERE state LIKE 'idle in transaction%'),
              coalesce((SELECT justify_interval(max(now() - state_change))::text FROM pg_stat_activity
                        WHERE state LIKE 'idle in transaction%'), 'n/a')) AS details,
       json_build_object('idle_in_transaction_session_timeout', '0',
                         'current_idle_in_transaction', (SELECT count(*) FROM pg_stat_activity WHERE state LIKE 'idle in transaction%'),
                         'db_role_overrides', (SELECT count(*) FROM pg_db_role_setting r
                                               WHERE array_to_string(r.setconfig, ' ') LIKE '%idle_in_transaction_session_timeout%'),
                         'statement_timeout', current_setting('statement_timeout'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'idle_in_transaction_session_timeout' AND s.reset_val = '0'
  AND NOT EXISTS (SELECT 1 FROM pg_db_role_setting r
                  WHERE array_to_string(r.setconfig, ' ') LIKE '%idle_in_transaction_session_timeout%');
