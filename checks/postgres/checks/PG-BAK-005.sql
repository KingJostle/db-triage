-- check: PG-BAK-005
-- title: Archiving enabled but no archive_command or archive_library set
-- priority: 5
-- scope: setting
-- cost: 0
-- run_on: primary
SELECT 'PG-BAK-005'::text     AS check_id,
       'setting'::text        AS scope,
       'archive_command'::text AS object,
       format('archive_mode = %s but neither archive_command nor archive_library is set. Every completed WAL segment is retained in pg_wal waiting for an archiver that will never succeed, and the server log fills with warnings. pg_wal already holds %s segments awaiting archiving.',
              current_setting('archive_mode'),
              coalesce((SELECT count(*)::text FROM pg_ls_archive_statusdir() WHERE name LIKE '%.ready'), 'an unknown number of')) AS details,
       json_build_object('archive_mode', current_setting('archive_mode'),
                         'archive_command', current_setting('archive_command'),
                         'archive_library', coalesce((SELECT setting FROM pg_settings WHERE name = 'archive_library'), ''))::text AS evidence_json,
       'high'::text AS confidence
WHERE current_setting('archive_mode') <> 'off'
  AND NOT pg_is_in_recovery()
  AND coalesce(nullif(trim(current_setting('archive_command')), ''), '') = ''
  AND coalesce(nullif(trim(coalesce((SELECT setting FROM pg_settings WHERE name = 'archive_library'), '')), ''), '') = '';
