-- check: PG-WRAP-002
-- title: Transaction ID or MultiXact age high
-- priority: 10
-- scope: database
-- cost: 0
-- thresholds: xid_age, xid_age_critical
SELECT 'PG-WRAP-002'::text AS check_id,
       'database'::text    AS scope,
       d.datname::text     AS object,
       format('age(datfrozenxid) = %s, mxid_age(datminmxid) = %s; worst is %s%% of the 2,147,483,648 XID limit (threshold %s, escalates to PG-WRAP-001 at %s). autovacuum_freeze_max_age = %s, so the anti-wraparound vacuum has been due for %s XIDs.',
              to_char(age(d.datfrozenxid), 'FM999,999,999,999'),
              to_char(mxid_age(d.datminmxid), 'FM999,999,999,999'),
              round(100.0 * greatest(age(d.datfrozenxid), mxid_age(d.datminmxid)) / 2147483648.0, 1)::text,
              to_char(:'pg_wrap_002_xid_age'::bigint, 'FM999,999,999,999'),
              to_char(:'pg_wrap_002_xid_age_critical'::bigint, 'FM999,999,999,999'),
              current_setting('autovacuum_freeze_max_age'),
              to_char(greatest(age(d.datfrozenxid), 0) - current_setting('autovacuum_freeze_max_age')::bigint, 'FM999,999,999,999')) AS details,
       json_build_object(
              'xid_age', age(d.datfrozenxid),
              'mxid_age', mxid_age(d.datminmxid),
              'worst_age', greatest(age(d.datfrozenxid), mxid_age(d.datminmxid)),
              'threshold', :'pg_wrap_002_xid_age'::bigint,
              'escalation_threshold', :'pg_wrap_002_xid_age_critical'::bigint,
              'freeze_max_age', current_setting('autovacuum_freeze_max_age')::bigint,
              'database_bytes', pg_database_size(d.oid))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_database d
WHERE greatest(age(d.datfrozenxid), mxid_age(d.datminmxid)) >= :'pg_wrap_002_xid_age'::bigint
  AND greatest(age(d.datfrozenxid), mxid_age(d.datminmxid)) <  :'pg_wrap_002_xid_age_critical'::bigint
ORDER BY greatest(age(d.datfrozenxid), mxid_age(d.datminmxid)) DESC;
