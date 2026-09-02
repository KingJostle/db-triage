-- check: PG-SEC-021
-- title: Connection logging disabled
-- priority: 200
-- scope: setting
-- cost: 0
SELECT 'PG-SEC-021'::text        AS check_id,
       'setting'::text           AS scope,
       'log_connections'::text   AS object,
       format('log_connections = %s and log_disconnections = %s. Nothing records who connected, from where, as which role, or when they left. After an incident there is no way to answer "which credential was used and from which address" from this server''s own logs. The cost is one log line per connection, which matters only where connection churn is already high (PG-CONN-005). log_line_prefix = %s.',
              current_setting('log_connections'), current_setting('log_disconnections'),
              quote_literal(current_setting('log_line_prefix'))) AS details,
       json_build_object('log_connections', current_setting('log_connections'),
                         'log_disconnections', current_setting('log_disconnections'),
                         'log_line_prefix', current_setting('log_line_prefix'),
                         'logging_collector', current_setting('logging_collector'),
                         'log_destination', current_setting('log_destination'))::text AS evidence_json,
       'high'::text AS confidence
WHERE current_setting('log_connections') IN ('off', 'false', '0')
  AND current_setting('log_disconnections') IN ('off', 'false', '0');
