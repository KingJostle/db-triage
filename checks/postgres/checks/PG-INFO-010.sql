-- check: PG-INFO-010
-- title: pg_hba summary
-- priority: 250
-- scope: cluster
-- cost: 0
-- min_version: 10
-- requires: superuser
-- Skipped without the privilege to read pg_hba_file_rules; PG-SEC-012 then says so.
SELECT 'PG-INFO-010'::text AS check_id,
       'cluster'::text     AS scope,
       format('%s/%s', r.type, r.auth_method)::text AS object,
       format('%s rule(s) of type %s using method %s. Lines: %s. Addresses: %s. Databases: %s. Roles: %s.%s',
              count(*), r.type, r.auth_method,
              string_agg(r.line_number::text, ', ' ORDER BY r.line_number),
              coalesce(string_agg(DISTINCT coalesce(r.address || coalesce('/' || r.netmask, ''), 'n/a'), ', '), 'n/a'),
              string_agg(DISTINCT array_to_string(r.database, '+'), ', '),
              string_agg(DISTINCT array_to_string(r.user_name, '+'), ', '),
              CASE WHEN count(*) FILTER (WHERE r.error IS NOT NULL) > 0
                   THEN format(' %s of these rules failed to parse: %s',
                               count(*) FILTER (WHERE r.error IS NOT NULL),
                               string_agg(r.error, '; ') FILTER (WHERE r.error IS NOT NULL))
                   ELSE '' END) AS details,
       json_build_object('type', r.type, 'auth_method', r.auth_method, 'rule_count', count(*),
                         'line_numbers', string_agg(r.line_number::text, ';' ORDER BY r.line_number),
                         'addresses', string_agg(DISTINCT coalesce(r.address, ''), ';'),
                         'databases', string_agg(DISTINCT array_to_string(r.database, '+'), ';'),
                         'roles', string_agg(DISTINCT array_to_string(r.user_name, '+'), ';'),
                         'errors', count(*) FILTER (WHERE r.error IS NOT NULL),
                         'listen_addresses', current_setting('listen_addresses'),
                         'ssl', current_setting('ssl'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_hba_file_rules r
GROUP BY r.type, r.auth_method
ORDER BY min(r.line_number);
