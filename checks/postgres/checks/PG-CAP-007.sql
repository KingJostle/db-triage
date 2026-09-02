-- check: PG-CAP-007
-- title: Log directory large
-- priority: 150
-- scope: cluster
-- cost: 1
-- min_version: 10
-- thresholds: min_bytes
\set ON_ERROR_STOP off
-- pg_ls_logdir() raises if log_directory does not exist, which is the normal state
-- when logging_collector is off (logs go to stderr / the OS journal). Gate on it.
SELECT (current_setting('logging_collector') = 'on') AS pg_cap_007_has_logdir \gset
\if :pg_cap_007_has_logdir
WITH l AS (SELECT sum(size)::bigint AS bytes, count(*) AS files,
                  min(modification) AS oldest, max(modification) AS newest FROM pg_ls_logdir())
SELECT 'PG-CAP-007'::text AS check_id,
       'cluster'::text    AS scope,
       'log_directory'::text AS object,
       format('The log directory holds %s across %s files (threshold %s), spanning %s to %s. On most installations the logs share a volume with the data directory, so this is disk the database cannot use (PG-CAP-001/002). Rotation and retention settings: log_rotation_age = %s, log_rotation_size = %s, log_truncate_on_rotation = %s, log_filename = %s. Volume drivers: log_min_duration_statement = %s, log_statement = %s, log_connections = %s.',
              pg_size_pretty(l.bytes), l.files, pg_size_pretty(:'pg_cap_007_min_bytes'::bigint),
              coalesce(l.oldest::text, 'unknown'), coalesce(l.newest::text, 'unknown'),
              current_setting('log_rotation_age'), current_setting('log_rotation_size'),
              current_setting('log_truncate_on_rotation'), current_setting('log_filename'),
              current_setting('log_min_duration_statement'), current_setting('log_statement'),
              current_setting('log_connections')) AS details,
       json_build_object('log_bytes', l.bytes, 'log_files', l.files,
                         'oldest', l.oldest, 'newest', l.newest,
                         'threshold_bytes', :'pg_cap_007_min_bytes'::bigint,
                         'log_rotation_age', current_setting('log_rotation_age'),
                         'log_rotation_size', current_setting('log_rotation_size'),
                         'log_truncate_on_rotation', current_setting('log_truncate_on_rotation'),
                         'log_min_duration_statement', current_setting('log_min_duration_statement'),
                         'log_statement', current_setting('log_statement'))::text AS evidence_json,
       'high'::text AS confidence
FROM l
WHERE l.bytes >= :'pg_cap_007_min_bytes'::bigint;
\endif
