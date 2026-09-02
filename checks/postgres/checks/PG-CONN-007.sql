-- check: PG-CONN-007
-- title: statement_timeout unset globally
-- priority: 150
-- scope: setting
-- cost: 0
SELECT 'PG-CONN-007'::text        AS check_id,
       'setting'::text            AS scope,
       'statement_timeout'::text  AS object,
       format('statement_timeout = 0 (no limit) at server level, and no per-database or per-role override sets one (%s override(s) exist in pg_db_role_setting, none for statement_timeout). Any statement can run until it finishes or the client goes away, holding its snapshot and its locks the whole time - which is how one bad query becomes PG-LOCK-001 and PG-VAC-005. Set it per application role (ALTER ROLE app SET statement_timeout = ...) rather than globally, so that migrations, backups and maintenance sessions are not cut off. idle_in_transaction_session_timeout = %s, lock_timeout = %s.',
              (SELECT count(*) FROM pg_db_role_setting),
              current_setting('idle_in_transaction_session_timeout'),
              current_setting('lock_timeout')) AS details,
       json_build_object('statement_timeout', '0',
                         'db_role_settings_total', (SELECT count(*) FROM pg_db_role_setting),
                         'idle_in_transaction_session_timeout', current_setting('idle_in_transaction_session_timeout'),
                         'lock_timeout', current_setting('lock_timeout'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'statement_timeout' AND s.reset_val = '0'
  AND NOT EXISTS (SELECT 1 FROM pg_db_role_setting r
                  WHERE array_to_string(r.setconfig, ' ') LIKE '%statement_timeout%');
