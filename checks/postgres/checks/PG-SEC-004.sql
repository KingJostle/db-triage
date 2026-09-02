-- check: PG-SEC-004
-- title: SSL disabled while accepting non-local connections
-- priority: 50
-- scope: setting
-- cost: 0
SELECT 'PG-SEC-004'::text AS check_id,
       'setting'::text    AS scope,
       'ssl'::text        AS object,
       format('ssl = off while listen_addresses = %s, so the server accepts TCP connections but cannot offer TLS on any of them. Every password exchange (password_encryption = %s), every query and every result crosses the network in clear text. %s client backend(s) are connected from %s distinct non-local address(es) right now. Enabling ssl needs a certificate and key readable by the server account and a reload.',
              current_setting('listen_addresses'), current_setting('password_encryption'),
              (SELECT count(*) FROM pg_stat_activity WHERE backend_type = 'client backend' AND client_addr IS NOT NULL),
              (SELECT count(DISTINCT client_addr) FROM pg_stat_activity WHERE client_addr IS NOT NULL)) AS details,
       json_build_object('ssl', 'off', 'listen_addresses', current_setting('listen_addresses'),
                         'password_encryption', current_setting('password_encryption'),
                         'remote_backends', (SELECT count(*) FROM pg_stat_activity
                                             WHERE backend_type = 'client backend' AND client_addr IS NOT NULL),
                         'distinct_client_addrs', (SELECT count(DISTINCT client_addr) FROM pg_stat_activity
                                                   WHERE client_addr IS NOT NULL))::text AS evidence_json,
       'high'::text AS confidence
WHERE current_setting('ssl') = 'off'
  AND current_setting('listen_addresses') NOT IN ('', 'localhost', '127.0.0.1', '::1', '127.0.0.1,::1');
