-- check: PG-CONN-004
-- title: Most connections idle
-- priority: 100
-- scope: cluster
-- cost: 0
-- min_version: 10
-- thresholds: min_connections, idle_fraction
WITH c AS (
  SELECT count(*) FILTER (WHERE backend_type = 'client backend')                      AS clients,
         count(*) FILTER (WHERE backend_type = 'client backend' AND state = 'idle')   AS idle,
         count(*) FILTER (WHERE backend_type = 'client backend' AND state = 'active') AS active,
         max(now() - backend_start) FILTER (WHERE backend_type = 'client backend')    AS oldest
  FROM pg_stat_activity
)
SELECT 'PG-CONN-004'::text AS check_id,
       'cluster'::text     AS scope,
       NULL::text          AS object,
       format('%s of %s client connections are idle (%s%%, threshold %s%%) at snapshot time; %s are active. Oldest connection opened %s ago. Idle backends still hold their process, their catalog caches and their share of the proc array, and they still have to be examined by every snapshot; on a server with a large max_connections that is a fixed tax for connections nobody is using. Usually an application-side pool sized for peak that never shrinks.',
              c.idle, c.clients,
              round(100.0 * c.idle / nullif(c.clients, 0), 1)::text,
              round(100 * :'pg_conn_004_idle_fraction'::numeric)::text,
              c.active, justify_interval(c.oldest)) AS details,
       json_build_object('client_backends', c.clients, 'idle', c.idle, 'active', c.active,
                         'idle_fraction', round(c.idle::numeric / nullif(c.clients, 0), 4),
                         'threshold_fraction', :'pg_conn_004_idle_fraction'::numeric,
                         'threshold_min_connections', :'pg_conn_004_min_connections'::int,
                         'oldest_connection_seconds', round(extract(epoch FROM c.oldest))::bigint,
                         'max_connections', (SELECT setting::int FROM pg_settings WHERE name = 'max_connections'))::text AS evidence_json,
       'high'::text AS confidence
FROM c
WHERE c.clients >= :'pg_conn_004_min_connections'::int
  AND c.idle::numeric / nullif(c.clients, 0) >= :'pg_conn_004_idle_fraction'::numeric;
