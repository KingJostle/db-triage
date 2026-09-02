-- check: PG-WRAP-006
-- title: Statistics tracking disabled (autovacuum blind)
-- priority: 5
-- scope: setting
-- cost: 0
SELECT 'PG-WRAP-006'::text  AS check_id,
       'setting'::text      AS scope,
       'track_counts'::text AS object,
       format('track_counts = off (set in %s%s) while autovacuum = %s. Without row-level counters autovacuum cannot see dead tuples or modified rows, so only the anti-wraparound path will ever vacuum, and ANALYZE will never run automatically. Highest XID age in this cluster is %s.',
              s.source,
              coalesce(', ' || s.sourcefile || ':' || s.sourceline::text, ''),
              current_setting('autovacuum'),
              to_char((SELECT max(age(datfrozenxid)) FROM pg_database), 'FM999,999,999,999')) AS details,
       json_build_object(
              'track_counts', s.setting,
              'source', s.source,
              'autovacuum', current_setting('autovacuum'),
              'max_datfrozenxid_age', (SELECT max(age(datfrozenxid)) FROM pg_database))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'track_counts' AND s.setting = 'off';
