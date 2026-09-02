-- check: PG-QRY-011
-- title: High transaction rollback ratio
-- priority: 100
-- scope: database
-- cost: 0
-- thresholds: rollback_ratio, min_transactions
SELECT 'PG-QRY-011'::text AS check_id,
       'database'::text   AS scope,
       d.datname::text    AS object,
       format('%s of %s transactions in database %s ended in ROLLBACK (%s%%, threshold %s%%) since %s. PostgreSQL rolls a transaction back when the application asks it to, and also whenever any statement in it raises an error - after which every subsequent statement fails with "current transaction is aborted" until the block ends. A tenth of all transactions failing is usually one recurring application error, a retry loop around a constraint violation, or a health check that deliberately aborts. Deadlocks in this database: %s (PG-LOCK-008).',
              to_char(d.xact_rollback, 'FM999,999,999,999'),
              to_char(d.xact_commit + d.xact_rollback, 'FM999,999,999,999'), d.datname,
              round(100.0 * d.xact_rollback / nullif(d.xact_commit + d.xact_rollback, 0), 1)::text,
              round(100 * :'pg_qry_011_rollback_ratio'::numeric)::text,
              coalesce(d.stats_reset::text, 'the last statistics reset'),
              d.deadlocks) AS details,
       json_build_object('datname', d.datname, 'xact_commit', d.xact_commit, 'xact_rollback', d.xact_rollback,
                         'rollback_ratio', round(d.xact_rollback::numeric / nullif(d.xact_commit + d.xact_rollback, 0), 4),
                         'threshold_ratio', :'pg_qry_011_rollback_ratio'::numeric,
                         'threshold_min_transactions', :'pg_qry_011_min_transactions'::bigint,
                         'deadlocks', d.deadlocks, 'stats_reset', d.stats_reset)::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_stat_database d
WHERE d.datname IS NOT NULL
  AND d.xact_commit + d.xact_rollback >= :'pg_qry_011_min_transactions'::bigint
  AND d.xact_rollback::numeric / nullif(d.xact_commit + d.xact_rollback, 0) >= :'pg_qry_011_rollback_ratio'::numeric
ORDER BY d.xact_rollback DESC;
