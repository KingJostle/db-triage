-- check: PG-REL-013
-- title: Logging collector off with a stderr-only destination
-- priority: 150
-- scope: setting
-- cost: 0
SELECT 'PG-REL-013'::text            AS check_id,
       'setting'::text               AS scope,
       'logging_collector'::text     AS object,
       format('logging_collector = off with log_destination = %s. The server writes its log to the standard error it was started with and does nothing else: where that goes depends entirely on how the server was launched. Under systemd it reaches the journal; under a container runtime it reaches the container log; started by hand from a shell that has since closed, it goes nowhere and is unrecoverable. Confidence is low because db-triage cannot see the process supervisor from inside SQL - confirm where stderr points before treating this as a defect. Consequences if it is going nowhere: PG-CORR-005, PG-REL-011 and PG-REL-014 have nothing to read, and neither will you. log_min_duration_statement = %s, log_checkpoints = %s.',
              current_setting('log_destination'),
              current_setting('log_min_duration_statement'),
              current_setting('log_checkpoints')) AS details,
       json_build_object('logging_collector', 'off',
                         'log_destination', current_setting('log_destination'),
                         'log_directory', current_setting('log_directory'),
                         'log_min_duration_statement', current_setting('log_min_duration_statement'))::text AS evidence_json,
       'low'::text AS confidence
WHERE current_setting('logging_collector') = 'off'
  AND current_setting('log_destination') = 'stderr';
