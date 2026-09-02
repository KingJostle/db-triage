-- check: PG-CONN-003
-- title: max_connections very high with no evidence of a pooler
-- priority: 50
-- scope: setting
-- cost: 0
-- min_version: 10
-- thresholds: max_conn, pooler_address_fraction, pooler_address_count
WITH a AS (
  SELECT count(*) AS clients,
         count(*) FILTER (WHERE application_name ~* '(pgbouncer|pgpool|pgcat|odyssey|supavisor|rds_?proxy|pgagroal)') AS pooler_named,
         count(DISTINCT client_addr) AS distinct_addrs
  FROM pg_stat_activity WHERE backend_type = 'client backend'
),
top AS (
  SELECT coalesce(sum(n), 0) AS top_n_clients FROM (
    SELECT count(*) AS n FROM pg_stat_activity
    WHERE backend_type = 'client backend' AND client_addr IS NOT NULL
    GROUP BY client_addr ORDER BY count(*) DESC
    LIMIT :'pg_conn_003_pooler_address_count'::int) t
)
SELECT 'PG-CONN-003'::text     AS check_id,
       'setting'::text         AS scope,
       'max_connections'::text AS object,
       format('max_connections = %s (threshold %s) and nothing suggests a connection pooler in front of it: no backend has a pooler application_name, and the busiest %s client addresses account for %s of %s current connections (%s%%, threshold %s%%) across %s distinct addresses. Each PostgreSQL connection is an operating-system process with its own memory (see PG-MEM-003, worst case %s) and its own share of the snapshot and lock-manager overhead every backend pays. A transaction-mode pooler usually lets max_connections come down by an order of magnitude.',
              (SELECT setting FROM pg_settings WHERE name = 'max_connections'),
              :'pg_conn_003_max_conn'::text,
              :'pg_conn_003_pooler_address_count'::text,
              t.top_n_clients, a.clients,
              round(100.0 * t.top_n_clients / nullif(a.clients, 0), 1)::text,
              round(100 * :'pg_conn_003_pooler_address_fraction'::numeric)::text,
              a.distinct_addrs,
              pg_size_pretty(((SELECT setting::bigint * 8192 FROM pg_settings WHERE name = 'shared_buffers')
                              + (SELECT setting::bigint FROM pg_settings WHERE name = 'max_connections')
                                * (SELECT setting::bigint * 1024 FROM pg_settings WHERE name = 'work_mem') * 2)::bigint)) AS details,
       json_build_object('max_connections', (SELECT setting::int FROM pg_settings WHERE name = 'max_connections'),
                         'threshold_max_connections', :'pg_conn_003_max_conn'::int,
                         'client_backends', a.clients, 'distinct_client_addrs', a.distinct_addrs,
                         'pooler_named_backends', a.pooler_named,
                         'top_address_clients', t.top_n_clients,
                         'top_address_fraction', round(t.top_n_clients::numeric / nullif(a.clients, 0), 4),
                         'threshold_fraction', :'pg_conn_003_pooler_address_fraction'::numeric)::text AS evidence_json,
       'medium'::text AS confidence
FROM a CROSS JOIN top t
WHERE (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') >= :'pg_conn_003_max_conn'::int
  AND a.pooler_named = 0
  AND coalesce(t.top_n_clients::numeric / nullif(a.clients, 0), 0) < :'pg_conn_003_pooler_address_fraction'::numeric;
