-- check: PG-SEC-003
-- title: Listening on all interfaces with world-open HBA rules
-- priority: 50
-- scope: cluster
-- cost: 0
-- min_version: 10
-- requires: superuser
SELECT 'PG-SEC-003'::text AS check_id,
       'cluster'::text    AS scope,
       format('pg_hba.conf:%s', r.line_number)::text AS object,
       format('listen_addresses = %s (the server accepts connections on every interface) and pg_hba.conf line %s allows %s from %s for database %s, user %s, with method %s. The database''s own access control therefore places no network restriction at all; whatever limits reachability is outside PostgreSQL - a security group, a firewall, or a private network. db-triage cannot see that from here, so confirm it. ssl = %s, port %s.',
              current_setting('listen_addresses'), r.line_number, r.type,
              coalesce(r.address || coalesce('/' || r.netmask, ''), 'any address'),
              array_to_string(r.database, ','), array_to_string(r.user_name, ','),
              r.auth_method, current_setting('ssl'), current_setting('port')) AS details,
       json_build_object('listen_addresses', current_setting('listen_addresses'),
                         'line_number', r.line_number, 'type', r.type, 'address', r.address,
                         'netmask', r.netmask, 'auth_method', r.auth_method,
                         'database', array_to_string(r.database, ';'),
                         'user_name', array_to_string(r.user_name, ';'),
                         'ssl', current_setting('ssl'), 'port', current_setting('port'))::text AS evidence_json,
       'low'::text AS confidence
FROM pg_hba_file_rules r
WHERE r.error IS NULL
  AND current_setting('listen_addresses') IN ('*', '0.0.0.0', '::', '0.0.0.0,::')
  AND r.type IN ('host', 'hostssl', 'hostnossl', 'hostgssenc', 'hostnogssenc')
  AND (coalesce(r.address, '') IN ('0.0.0.0', '::', 'all', 'samenet')
       OR (r.address = '0.0.0.0' AND r.netmask = '0.0.0.0'))
  AND 'all' = ANY (r.database)
ORDER BY r.line_number;
