-- check: PG-CORR-002
-- title: zero_damaged_pages enabled
-- priority: 1
-- scope: setting
-- cost: 0
SELECT 'PG-CORR-002'::text        AS check_id,
       'setting'::text            AS scope,
       'zero_damaged_pages'::text AS object,
       format('zero_damaged_pages = on (set in %s%s). A page whose header fails validation is replaced with zeros and the read continues, so every row on that page disappears and the server reports only a WARNING. This is a recovery tool for a supervised salvage operation; leaving it on in normal running converts detectable corruption into silent data loss. data_checksums = %s.',
              s.source, coalesce(', ' || s.sourcefile || ':' || s.sourceline::text, ''),
              current_setting('data_checksums')) AS details,
       json_build_object('zero_damaged_pages', s.setting, 'source', s.source,
                         'sourcefile', s.sourcefile, 'sourceline', s.sourceline,
                         'data_checksums', current_setting('data_checksums'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'zero_damaged_pages' AND s.setting = 'on';
