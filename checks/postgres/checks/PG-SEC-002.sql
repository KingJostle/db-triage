-- check: PG-SEC-002
-- title: Cleartext password authentication over the network
-- priority: 5
-- scope: cluster
-- cost: 0
-- min_version: 10
-- requires: superuser
SELECT 'PG-SEC-002'::text AS check_id,
       'cluster'::text    AS scope,
       format('pg_hba.conf:%s', r.line_number)::text AS object,
       format('pg_hba.conf line %s: %s %s %s %s password. The "password" method sends the password across the connection in clear text. On a hostnossl rule, or on a host rule where the client does not negotiate TLS, anyone on the path reads it. ssl = %s. Change the method to scram-sha-256 (password_encryption is currently %s) and require hostssl.',
              r.line_number, r.type, array_to_string(r.database, ','), array_to_string(r.user_name, ','),
              coalesce(r.address || coalesce('/' || r.netmask, ''), 'all addresses'),
              current_setting('ssl'), current_setting('password_encryption')) AS details,
       json_build_object('line_number', r.line_number, 'type', r.type,
                         'database', array_to_string(r.database, ';'),
                         'user_name', array_to_string(r.user_name, ';'),
                         'address', r.address, 'auth_method', r.auth_method,
                         'ssl', current_setting('ssl'),
                         'password_encryption', current_setting('password_encryption'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_hba_file_rules r
WHERE r.error IS NULL
  AND r.auth_method = 'password'
  AND r.type IN ('host', 'hostnossl', 'hostnogssenc')
ORDER BY r.line_number;
