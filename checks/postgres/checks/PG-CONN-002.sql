-- check: PG-CONN-002
-- title: Connections at 70 percent or more of max_connections
-- priority: 50
-- scope: cluster
-- cost: 0
-- min_version: 10
-- thresholds: conn_fraction, conn_fraction_high
WITH lim AS (
  SELECT (SELECT setting::int FROM pg_settings WHERE name = 'max_connections')                  AS max_conn,
         (SELECT setting::int FROM pg_settings WHERE name = 'superuser_reserved_connections')   AS su_reserved,
         coalesce((SELECT setting::int FROM pg_settings WHERE name = 'reserved_connections'), 0) AS reserved
),
cur AS (
  SELECT count(*) FILTER (WHERE backend_type = 'client backend')                    AS clients,
         count(*) FILTER (WHERE backend_type = 'client backend' AND state = 'idle') AS idle,
         count(*) FILTER (WHERE backend_type = 'client backend' AND state = 'active') AS active,
         count(*) FILTER (WHERE backend_type = 'client backend' AND state LIKE 'idle in transaction%') AS idle_in_txn
  FROM pg_stat_activity
)
SELECT 'PG-CONN-002'::text AS check_id,
       'cluster'::text  AS scope,
       'max_connections'::text AS object,
       format('%s client backends against a usable ceiling of %s (max_connections %s less %s superuser-reserved and %s reserved): %s%% (threshold %s%%). Of those, %s are active, %s idle and %s idle in transaction. The next connection past the ceiling is refused with "FATAL: sorry, too many clients already", which the application sees as an outage rather than as slowness.',
              c.clients, l.max_conn - l.su_reserved - l.reserved, l.max_conn, l.su_reserved, l.reserved,
              round(100.0 * c.clients / nullif(l.max_conn - l.su_reserved - l.reserved, 0), 1)::text,
              round(100 * :'pg_conn_002_conn_fraction'::numeric)::text,
              c.active, c.idle, c.idle_in_txn) AS details,
       json_build_object('client_backends', c.clients, 'max_connections', l.max_conn,
                         'superuser_reserved_connections', l.su_reserved, 'reserved_connections', l.reserved,
                         'usable_ceiling', l.max_conn - l.su_reserved - l.reserved,
                         'fraction_used', round(c.clients::numeric / nullif(l.max_conn - l.su_reserved - l.reserved, 0), 4),
                         'threshold_fraction', :'pg_conn_002_conn_fraction'::numeric,
                         'active', c.active, 'idle', c.idle, 'idle_in_transaction', c.idle_in_txn)::text AS evidence_json,
       'high'::text AS confidence
FROM cur c CROSS JOIN lim l
WHERE c.clients >= :'pg_conn_002_conn_fraction'::numeric * (l.max_conn - l.su_reserved - l.reserved)
  AND c.clients < :'pg_conn_002_conn_fraction_high'::numeric * (l.max_conn - l.su_reserved - l.reserved);
