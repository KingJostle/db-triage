-- check: PG-CORR-001
-- title: Data checksum failures reported
-- priority: 1
-- scope: database
-- cost: 0
-- min_version: 12
SELECT 'PG-CORR-001'::text AS check_id,
       'database'::text    AS scope,
       coalesce(d.datname, 'shared objects')::text AS object,
       format('pg_stat_database reports %s checksum failures for %s; the most recent was at %s (%s ago). The server read a page whose checksum did not match its contents. Counters are since the statistics reset at %s. This is a report from the storage layer, not an inference.',
              to_char(d.checksum_failures, 'FM999,999,999,999'),
              coalesce('database ' || d.datname, 'shared catalogs'),
              d.checksum_last_failure,
              justify_interval(date_trunc('second', now() - d.checksum_last_failure)),
              coalesce(d.stats_reset::text, 'unknown')) AS details,
       json_build_object('checksum_failures', d.checksum_failures,
                         'checksum_last_failure', d.checksum_last_failure,
                         'datname', d.datname, 'stats_reset', d.stats_reset,
                         'data_checksums', current_setting('data_checksums'),
                         'ignore_checksum_failure', current_setting('ignore_checksum_failure'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_database d
WHERE d.checksum_failures > 0
ORDER BY d.checksum_failures DESC;
