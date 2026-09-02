-- check: PG-BAK-004
-- title: archive_command is a no-op (WAL archived to nowhere)
-- priority: 1
-- scope: setting
-- cost: 0
-- run_on: primary
SELECT 'PG-BAK-004'::text     AS check_id,
       'setting'::text        AS scope,
       'archive_command'::text AS object,
       format('archive_mode = %s but archive_command is %s, which succeeds without storing anything. pg_stat_archiver reports %s segments "archived" and %s failures, so the counters look healthy while no WAL is being kept. Point-in-time recovery is impossible and nothing in the server will say so.',
              current_setting('archive_mode'),
              quote_literal(s.setting),
              to_char((SELECT archived_count FROM pg_stat_archiver), 'FM999,999,999,999'),
              to_char((SELECT failed_count FROM pg_stat_archiver), 'FM999,999,999,999')) AS details,
       json_build_object('archive_command', s.setting, 'archive_mode', current_setting('archive_mode'),
                         'source', s.source,
                         'archived_count', (SELECT archived_count FROM pg_stat_archiver),
                         'failed_count', (SELECT failed_count FROM pg_stat_archiver))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'archive_command'
  AND current_setting('archive_mode') <> 'off'
  AND NOT pg_is_in_recovery()
  AND (s.setting ~ '^\s*(/bin/|/usr/bin/)?(true|:)\s*$'
    OR s.setting ~ '^\s*exit\s+0\s*$'
    OR s.setting ~ '^\s*cd\s+\.\s*$'
    OR s.setting ~ '^\s*#'
    OR s.setting ~ '>\s*/dev/null\s*$');
