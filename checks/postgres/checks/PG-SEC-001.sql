-- check: PG-SEC-001
-- title: trust authentication reachable over the network
-- priority: 1
-- scope: cluster
-- cost: 0
-- min_version: 10
-- requires: superuser
SELECT 'PG-SEC-001'::text AS check_id,
       'cluster'::text    AS scope,
       format('pg_hba.conf:%s', r.line_number)::text AS object,
       format('pg_hba.conf line %s: %s %s %s %s trust. Anyone who can open a TCP connection to port %s becomes any role they ask for, with no password and no certificate. Databases matched: %s. Roles matched: %s. listen_addresses = %s, ssl = %s.',
              r.line_number, r.type, array_to_string(r.database, ','), array_to_string(r.user_name, ','),
              coalesce(r.address || coalesce('/' || r.netmask, ''), 'all addresses'),
              current_setting('port'),
              array_to_string(r.database, ','), array_to_string(r.user_name, ','),
              current_setting('listen_addresses'), current_setting('ssl')) AS details,
       json_build_object('line_number', r.line_number, 'type', r.type,
                         'database', array_to_string(r.database, ';'),
                         'user_name', array_to_string(r.user_name, ';'),
                         'address', r.address, 'netmask', r.netmask,
                         'auth_method', r.auth_method,
                         'listen_addresses', current_setting('listen_addresses'),
                         'port', current_setting('port'), 'ssl', current_setting('ssl'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_hba_file_rules r
WHERE r.error IS NULL
  AND r.auth_method = 'trust'
  AND r.type IN ('host', 'hostssl', 'hostnossl', 'hostgssenc', 'hostnogssenc')
  AND coalesce(r.address, '') NOT IN ('127.0.0.1', '::1', 'localhost', 'samehost')
ORDER BY r.line_number;
