-- check: PG-LOCK-009
-- title: lock_timeout unset
-- priority: 150
-- scope: setting
-- cost: 0
SELECT 'PG-LOCK-009'::text     AS check_id,
       'setting'::text         AS scope,
       'lock_timeout'::text    AS object,
       format('lock_timeout = 0 at server level. A statement that needs a lock waits for it forever - and while an ALTER TABLE waits for its ACCESS EXCLUSIVE lock, every subsequent statement against the same table queues behind the waiting ALTER, including plain SELECTs. That is how a routine migration behind one long transaction (PG-LOCK-005) becomes a total outage on a hot table. Setting lock_timeout to a few seconds in migration sessions makes the migration fail instead of the application. statement_timeout = %s, deadlock_timeout = %s, log_lock_waits = %s.',
              current_setting('statement_timeout'),
              current_setting('deadlock_timeout'),
              current_setting('log_lock_waits')) AS details,
       json_build_object('lock_timeout', '0',
                         'statement_timeout', current_setting('statement_timeout'),
                         'deadlock_timeout', current_setting('deadlock_timeout'),
                         'log_lock_waits', current_setting('log_lock_waits'),
                         'db_role_overrides', (SELECT count(*) FROM pg_db_role_setting r
                                               WHERE array_to_string(r.setconfig, ' ') LIKE '%lock_timeout%'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'lock_timeout' AND s.reset_val = '0';
