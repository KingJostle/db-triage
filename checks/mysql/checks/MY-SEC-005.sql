-- check: MY-SEC-005
-- title: TLS not enforced, or largely unused
-- priority: 100 | category: SEC | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: tls_usage_ratio=0.50
-- reads: @dbt_v_require_secure_transport, @dbt_v_have_ssl, @dbt_v_tls_version,
--        @dbt_s_ssl_accepts, @dbt_s_connections
-- Version divergence handled through the bundle: have_ssl was deprecated in
-- MySQL 8.0.26 and REMOVED in 8.4 (replaced by the performance_schema
-- tls_channel_status table); require_secure_transport arrived in MySQL 5.7.8 and
-- MariaDB 10.5. A NULL from the bundle means "this fork/version does not have
-- the variable", not "off".
-- Two separate statements, reported together because the fix differs:
--   * require_secure_transport OFF means an unencrypted connection is ACCEPTED,
--     even if most clients happen to use TLS;
--   * a low Ssl_accepts / Connections ratio means clients are in fact connecting
--     in the clear right now.
-- Per-account REQUIRE SSL clauses are not visible here, so a server that
-- enforces TLS through grants rather than globally will still fire — hence
-- medium confidence and the wording.
SELECT
  'MY-SEC-005' AS check_id,
  'setting'    AS scope,
  'require_secure_transport' AS object,
  CONCAT('require_secure_transport = ', IFNULL(@dbt_v_require_secure_transport,
            'not available on this version'),
         ', have_ssl/TLS availability = ', IFNULL(@dbt_v_have_ssl,
            'not reported (removed in MySQL 8.4; see performance_schema.tls_channel_status)'),
         ', tls_version = ', IFNULL(@dbt_v_tls_version, 'unknown'), '. ',
         IF(t.conns > 0,
            CONCAT(FORMAT(t.ssl_conns, 0), ' of ', FORMAT(t.conns, 0), ' connections since restart used TLS (',
                   ROUND(100.0 * t.ssl_conns / t.conns, 1), '%, threshold ',
                   ROUND(100 * COALESCE(@tls_usage_ratio, 0.50), 0), '%). '),
            ''),
         'Unencrypted connections are accepted, so credentials and result sets cross the network in the clear unless every client opts in. ',
         'Per-account REQUIRE SSL clauses are not visible from here, so confirm before treating this as unprotected.') AS details,
  JSON_OBJECT(
    'require_secure_transport', IFNULL(@dbt_v_require_secure_transport, 'n/a'),
    'have_ssl', IFNULL(@dbt_v_have_ssl, 'n/a'),
    'tls_version', IFNULL(@dbt_v_tls_version, 'n/a'),
    'ssl_accepts', t.ssl_conns,
    'connections', t.conns,
    'tls_ratio', IF(t.conns > 0, ROUND(t.ssl_conns / t.conns, 4), NULL),
    'threshold_ratio', COALESCE(@tls_usage_ratio, 0.50)) AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_ssl_accepts, 0) AS DECIMAL(30, 0)) AS ssl_conns,
         CAST(IFNULL(@dbt_s_connections, 0) AS DECIMAL(30, 0))  AS conns
) AS t
WHERE UPPER(IFNULL(@dbt_v_require_secure_transport, 'OFF')) IN ('OFF', '0')
  AND (t.conns = 0 OR t.ssl_conns / t.conns < COALESCE(@tls_usage_ratio, 0.50));
