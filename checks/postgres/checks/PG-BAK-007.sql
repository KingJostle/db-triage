-- check: PG-BAK-007
-- title: archive_timeout unset on a low-write primary
-- priority: 50
-- scope: setting
-- cost: 0
-- run_on: primary
SELECT 'PG-BAK-007'::text      AS check_id,
       'setting'::text         AS scope,
       'archive_timeout'::text AS object,
       format('archive_mode = %s with archive_timeout = 0 and no pg_receivewal connected. A WAL segment ships only when it fills, so on a low-write server the current segment may sit unarchived for hours and the recovery point objective is undefined. Archiver has shipped %s segments%s. A value of 60 to 300 seconds bounds the exposure at the cost of one partly-filled 16 MB segment per interval.',
              current_setting('archive_mode'),
              to_char((SELECT archived_count FROM pg_stat_archiver), 'FM999,999,999,999'),
              coalesce('; last at ' || (SELECT last_archived_time FROM pg_stat_archiver)::text
                       || ' (' || justify_interval(now() - (SELECT last_archived_time FROM pg_stat_archiver))::text || ' ago)', '')) AS details,
       json_build_object('archive_timeout', 0, 'archive_mode', current_setting('archive_mode'),
                         'archived_count', (SELECT archived_count FROM pg_stat_archiver),
                         'last_archived_time', (SELECT last_archived_time FROM pg_stat_archiver),
                         'walreceiver_clients', (SELECT count(*) FROM pg_stat_replication
                                                 WHERE application_name ILIKE '%receivewal%'
                                                    OR application_name ILIKE '%pg_receivexlog%'))::text AS evidence_json,
       'medium'::text AS confidence
WHERE current_setting('archive_mode') <> 'off'
  AND NOT pg_is_in_recovery()
  AND (SELECT setting::int FROM pg_settings WHERE name = 'archive_timeout') = 0
  AND NOT EXISTS (SELECT 1 FROM pg_stat_replication
                  WHERE application_name ILIKE '%receivewal%' OR application_name ILIKE '%pg_receivexlog%');
