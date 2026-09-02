-- check: PG-CORR-003
-- title: ignore_checksum_failure enabled
-- priority: 1
-- scope: setting
-- cost: 0
SELECT 'PG-CORR-003'::text            AS check_id,
       'setting'::text                AS scope,
       'ignore_checksum_failure'::text AS object,
       format('ignore_checksum_failure = on (set in %s%s). A page whose checksum does not match is used anyway after a WARNING, so corrupt data flows into query results, into indexes built from it, and into every backup and replica taken afterwards. data_checksums = %s; checksum failures reported so far: %s.',
              s.source, coalesce(', ' || s.sourcefile || ':' || s.sourceline::text, ''),
              current_setting('data_checksums'),
              coalesce((SELECT sum(checksum_failures)::text FROM pg_stat_database), 'not tracked on this version')) AS details,
       json_build_object('ignore_checksum_failure', s.setting, 'source', s.source,
                         'data_checksums', current_setting('data_checksums'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'ignore_checksum_failure' AND s.setting = 'on';
