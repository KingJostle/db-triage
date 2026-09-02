-- check: PG-CFG-001
-- title: Non-default server settings
-- priority: 200
-- scope: setting
-- cost: 0
-- thresholds: summary_threshold
-- Inventory, not a finding: this is what you read after the problems, to
-- understand why the server behaves the way it does.
SELECT 'PG-CFG-001'::text AS check_id,
       'setting'::text    AS scope,
       s.name::text       AS object,
       format('%s = %s%s (default %s%s), set in %s%s. Context: %s.%s',
              s.name, s.setting, coalesce(' ' || s.unit, ''),
              s.boot_val, coalesce(' ' || s.unit, ''),
              s.source, coalesce(' at ' || s.sourcefile || ':' || s.sourceline::text, ''),
              s.context,
              CASE WHEN s.pending_restart THEN ' A restart is pending for this setting (PG-REL-010).' ELSE '' END) AS details,
       json_build_object('setting', s.name, 'value', s.setting, 'default', s.boot_val,
                         'reset_val', s.reset_val, 'unit', s.unit, 'source', s.source,
                         'sourcefile', s.sourcefile, 'sourceline', s.sourceline,
                         'context', s.context, 'category', s.category,
                         'pending_restart', s.pending_restart, 'vartype', s.vartype)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.source NOT IN ('default', 'override', 'client', 'session')
  AND s.setting IS DISTINCT FROM s.boot_val
  AND s.name NOT IN ('application_name', 'TimeZone', 'log_timezone', 'DateStyle', 'IntervalStyle',
                     'data_directory', 'config_file', 'hba_file', 'ident_file', 'external_pid_file',
                     'port', 'cluster_name', 'listen_addresses', 'unix_socket_directories',
                     'unix_socket_group', 'unix_socket_permissions', 'max_stack_depth',
                     'server_encoding', 'client_encoding', 'search_path', 'default_text_search_config',
                     'transaction_isolation', 'transaction_read_only', 'transaction_deferrable',
                     'lc_collate', 'lc_ctype', 'lc_messages', 'lc_monetary', 'lc_numeric', 'lc_time',
                     'ssl_cert_file', 'ssl_key_file', 'ssl_ca_file', 'ssl_crl_file', 'ssl_dh_params_file',
                     'stats_temp_directory', 'wal_segment_size', 'block_size', 'segment_size',
                     'statement_timeout', 'lock_timeout', 'idle_in_transaction_session_timeout',
                     'default_transaction_read_only', 'client_min_messages', 'jit')
ORDER BY s.category, s.name;
