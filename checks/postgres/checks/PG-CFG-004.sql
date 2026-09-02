-- check: PG-CFG-004
-- title: Settings applied via ALTER SYSTEM
-- priority: 200
-- scope: setting
-- cost: 0
-- min_version: 9.4
SELECT 'PG-CFG-004'::text AS check_id,
       'setting'::text    AS scope,
       s.name::text       AS object,
       format('%s = %s%s was applied with ALTER SYSTEM (it lives in postgresql.auto.conf at line %s), not in postgresql.conf. postgresql.auto.conf is read last, so this value wins over anything configuration management writes into postgresql.conf - and configuration management will not see it, will not diff it, and will not restore it when the host is rebuilt. Default %s%s.%s',
              s.name, s.setting, coalesce(' ' || s.unit, ''), s.sourceline,
              s.boot_val, coalesce(' ' || s.unit, ''),
              CASE WHEN s.pending_restart THEN ' A restart is pending for this setting.' ELSE '' END) AS details,
       json_build_object('setting', s.name, 'value', s.setting, 'default', s.boot_val,
                         'unit', s.unit, 'sourcefile', s.sourcefile, 'sourceline', s.sourceline,
                         'context', s.context, 'pending_restart', s.pending_restart)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.sourcefile LIKE '%postgresql.auto.conf'
ORDER BY s.name;
