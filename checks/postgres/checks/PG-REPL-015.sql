-- check: PG-REPL-015
-- title: WAL senders or replication slots at capacity
-- priority: 50
-- scope: cluster
-- cost: 0
-- min_version: 9.4
-- run_on: primary
WITH c AS (
  SELECT (SELECT count(*) FROM pg_stat_replication)   AS senders,
         (SELECT setting::int FROM pg_settings WHERE name = 'max_wal_senders')       AS max_senders,
         (SELECT count(*) FROM pg_replication_slots)  AS slots,
         (SELECT setting::int FROM pg_settings WHERE name = 'max_replication_slots') AS max_slots
)
SELECT 'PG-REPL-015'::text AS check_id,
       'cluster'::text     AS scope,
       k.object::text      AS object,
       format('%s of %s %s are in use. The next standby, pg_basebackup, pg_receivewal or logical subscriber to connect is refused; raising the limit requires a restart. Current WAL senders: %s. Current slots: %s.',
              k.used, k.limit_val, k.object,
              coalesce((SELECT string_agg(format('%s (%s)', coalesce(nullif(application_name, ''), 'unnamed'), state), '; ')
                        FROM pg_stat_replication), 'none'),
              coalesce((SELECT string_agg(format('%s (active=%s)', slot_name, active), '; ')
                        FROM pg_replication_slots), 'none')) AS details,
       json_build_object('resource', k.object, 'used', k.used, 'limit', k.limit_val,
                         'senders', c.senders, 'max_wal_senders', c.max_senders,
                         'slots', c.slots, 'max_replication_slots', c.max_slots)::text AS evidence_json,
       'high'::text AS confidence
FROM c
CROSS JOIN LATERAL (VALUES ('WAL senders (max_wal_senders)', c.senders, c.max_senders),
                           ('replication slots (max_replication_slots)', c.slots, c.max_slots))
           AS k(object, used, limit_val)
WHERE NOT pg_is_in_recovery() AND k.limit_val > 0 AND k.used >= k.limit_val;
