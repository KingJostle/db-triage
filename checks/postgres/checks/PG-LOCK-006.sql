-- check: PG-LOCK-006
-- title: Orphaned prepared transactions
-- priority: 5
-- scope: cluster
-- cost: 0
-- thresholds: prepared_seconds
SELECT 'PG-LOCK-006'::text AS check_id,
       'cluster'::text     AS scope,
       p.gid::text         AS object,
       format('Prepared transaction "%s" in database %s, owned by %s, has been prepared since %s (%s, threshold %s). Its xmin is %s XIDs old. A prepared transaction holds its locks and its xmin horizon until it is committed or rolled back: it survives server restarts, it does not appear in pg_stat_activity, and nothing will ever time it out. If no external transaction manager is going to resolve it, the fix is ROLLBACK PREPARED %s (or COMMIT PREPARED, if that is genuinely the intent) - which is a write, so it is yours to run, not db-triage''s. max_prepared_transactions = %s.',
              p.gid, p.database, p.owner, p.prepared,
              justify_interval(date_trunc('second', now() - p.prepared)),
              (:'pg_lock_006_prepared_seconds'::int || ' seconds')::interval,
              to_char(age(p.transaction), 'FM999,999,999,999'),
              quote_literal(p.gid),
              current_setting('max_prepared_transactions')) AS details,
       json_build_object('gid', p.gid, 'database', p.database, 'owner', p.owner,
                         'prepared', p.prepared,
                         'open_seconds', round(extract(epoch FROM now() - p.prepared))::bigint,
                         'threshold_seconds', :'pg_lock_006_prepared_seconds'::int,
                         'xid_age', age(p.transaction),
                         'max_prepared_transactions', current_setting('max_prepared_transactions')::int)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_prepared_xacts p
WHERE now() - p.prepared >= (:'pg_lock_006_prepared_seconds'::int || ' seconds')::interval
ORDER BY p.prepared;
