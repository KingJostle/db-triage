-- check: PG-WRAP-001
-- title: Transaction ID or MultiXact wraparound imminent
-- priority: 1
-- scope: database
-- cost: 0
-- thresholds: xid_age
SELECT 'PG-WRAP-001'::text AS check_id,
       'database'::text    AS scope,
       d.datname::text     AS object,
       format('age(datfrozenxid) = %s, mxid_age(datminmxid) = %s; worst is %s%% of the 2,147,483,648 XID limit (threshold %s). autovacuum_freeze_max_age = %s. Database size %s. When the oldest unfrozen XID reaches the limit the cluster stops accepting write transactions.',
              to_char(age(d.datfrozenxid), 'FM999,999,999,999'),
              to_char(mxid_age(d.datminmxid), 'FM999,999,999,999'),
              round(100.0 * greatest(age(d.datfrozenxid), mxid_age(d.datminmxid)) / 2147483648.0, 1)::text,
              to_char(:'pg_wrap_001_xid_age'::bigint, 'FM999,999,999,999'),
              current_setting('autovacuum_freeze_max_age'),
              pg_size_pretty(pg_database_size(d.oid))) AS details,
       json_build_object(
              'xid_age', age(d.datfrozenxid),
              'mxid_age', mxid_age(d.datminmxid),
              'worst_age', greatest(age(d.datfrozenxid), mxid_age(d.datminmxid)),
              'threshold', :'pg_wrap_001_xid_age'::bigint,
              'xid_limit', 2147483648::bigint,
              'pct_of_limit', round(100.0 * greatest(age(d.datfrozenxid), mxid_age(d.datminmxid)) / 2147483648.0, 2),
              'freeze_max_age', current_setting('autovacuum_freeze_max_age')::bigint,
              'datallowconn', d.datallowconn,
              'database_bytes', pg_database_size(d.oid))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_database d
WHERE greatest(age(d.datfrozenxid), mxid_age(d.datminmxid)) >= :'pg_wrap_001_xid_age'::bigint
ORDER BY greatest(age(d.datfrozenxid), mxid_age(d.datminmxid)) DESC;
