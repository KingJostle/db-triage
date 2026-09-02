-- check: PG-SEC-005
-- title: Most client connections not using SSL
-- priority: 100
-- scope: cluster
-- cost: 0
-- min_version: 9.5
-- thresholds: ssl_fraction
WITH c AS (
  SELECT count(*) AS remote,
         count(*) FILTER (WHERE s.ssl) AS encrypted,
         string_agg(DISTINCT coalesce(s.version, 'none'), ', ') AS versions
  FROM pg_stat_activity a
  JOIN pg_stat_ssl s ON s.pid = a.pid
  WHERE a.backend_type = 'client backend' AND a.client_addr IS NOT NULL
)
SELECT 'PG-SEC-005'::text AS check_id,
       'cluster'::text    AS scope,
       NULL::text         AS object,
       format('Only %s of %s non-local client connections are using TLS (%s%%, threshold %s%%) at snapshot time. TLS versions in use: %s. The server has ssl = on, so the capability exists and clients are choosing not to use it - usually because sslmode defaults to prefer and pg_hba.conf accepts a plain host rule. Requiring it means changing the matching host lines to hostssl, which will break any client that has not been configured first.',
              c.encrypted, c.remote,
              round(100.0 * c.encrypted / nullif(c.remote, 0), 1)::text,
              round(100 * :'pg_sec_005_ssl_fraction'::numeric)::text,
              coalesce(c.versions, 'none')) AS details,
       json_build_object('remote_connections', c.remote, 'encrypted_connections', c.encrypted,
                         'encrypted_fraction', round(c.encrypted::numeric / nullif(c.remote, 0), 4),
                         'threshold_fraction', :'pg_sec_005_ssl_fraction'::numeric,
                         'tls_versions', c.versions, 'ssl', current_setting('ssl'),
                         'sampled_at', now())::text AS evidence_json,
       'medium'::text AS confidence
FROM c
WHERE current_setting('ssl') = 'on'
  AND c.remote > 0
  AND c.encrypted::numeric / nullif(c.remote, 0) < :'pg_sec_005_ssl_fraction'::numeric;
