-- check: PG-SEC-007
-- title: trust authentication on the local socket
-- priority: 100
-- scope: cluster
-- cost: 0
-- min_version: 10
-- requires: superuser
SELECT 'PG-SEC-007'::text AS check_id,
       'cluster'::text    AS scope,
       format('pg_hba.conf:%s', r.line_number)::text AS object,
       format('pg_hba.conf line %s: local %s %s trust. Any operating-system account that can reach the Unix socket at %s can connect as any role, including superusers, with no credential. That includes every process in the same container and anything that gets a shell on the host. This is P100 rather than P1 because it needs host access first; "peer" gives the same convenience for the postgres account without giving it to everything else.',
              r.line_number, array_to_string(r.database, ','), array_to_string(r.user_name, ','),
              current_setting('unix_socket_directories')) AS details,
       json_build_object('line_number', r.line_number, 'type', r.type,
                         'database', array_to_string(r.database, ';'),
                         'user_name', array_to_string(r.user_name, ';'),
                         'auth_method', r.auth_method,
                         'unix_socket_directories', current_setting('unix_socket_directories'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_hba_file_rules r
WHERE r.error IS NULL AND r.type = 'local' AND r.auth_method = 'trust'
ORDER BY r.line_number;
