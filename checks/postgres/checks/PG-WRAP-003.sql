-- check: PG-WRAP-003
-- title: Anti-wraparound vacuum overdue
-- priority: 50
-- scope: database
-- cost: 0
-- thresholds: freeze_multiple, xid_age_ceiling
WITH s AS (
  SELECT current_setting('autovacuum_freeze_max_age')::bigint            AS fma,
         current_setting('autovacuum_multixact_freeze_max_age')::bigint  AS mfma
)
SELECT 'PG-WRAP-003'::text AS check_id,
       'database'::text    AS scope,
       d.datname::text     AS object,
       format('age(datfrozenxid) = %s vs autovacuum_freeze_max_age %s (%sx); mxid_age = %s vs autovacuum_multixact_freeze_max_age %s (%sx). The forced anti-wraparound vacuum should have started at 1.0x, so something is preventing tuples from being frozen: check PG-VAC-005 (old xmin horizon), PG-LOCK-005/006 (long or prepared transactions) and PG-REPL-002/003 (slots).',
              to_char(age(d.datfrozenxid), 'FM999,999,999,999'), to_char(s.fma, 'FM999,999,999,999'),
              round(age(d.datfrozenxid)::numeric / nullif(s.fma, 0), 2)::text,
              to_char(mxid_age(d.datminmxid), 'FM999,999,999,999'), to_char(s.mfma, 'FM999,999,999,999'),
              round(mxid_age(d.datminmxid)::numeric / nullif(s.mfma, 0), 2)::text) AS details,
       json_build_object(
              'xid_age', age(d.datfrozenxid),
              'mxid_age', mxid_age(d.datminmxid),
              'autovacuum_freeze_max_age', s.fma,
              'autovacuum_multixact_freeze_max_age', s.mfma,
              'xid_multiple', round(age(d.datfrozenxid)::numeric / nullif(s.fma, 0), 3),
              'mxid_multiple', round(mxid_age(d.datminmxid)::numeric / nullif(s.mfma, 0), 3),
              'threshold_multiple', :'pg_wrap_003_freeze_multiple'::numeric)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_database d CROSS JOIN s
WHERE greatest(age(d.datfrozenxid), mxid_age(d.datminmxid)) < :'pg_wrap_003_xid_age_ceiling'::bigint
  AND (age(d.datfrozenxid)     > :'pg_wrap_003_freeze_multiple'::numeric * s.fma
    OR mxid_age(d.datminmxid)  > :'pg_wrap_003_freeze_multiple'::numeric * s.mfma)
ORDER BY greatest(age(d.datfrozenxid), mxid_age(d.datminmxid)) DESC;
