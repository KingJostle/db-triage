-- check: PG-WRAP-005
-- title: Autovacuum disabled
-- priority: 5
-- scope: setting
-- cost: 0
SELECT 'PG-WRAP-005'::text AS check_id,
       'setting'::text     AS scope,
       'autovacuum'::text  AS object,
       format('autovacuum = off (set in %s%s). Dead tuples are never reclaimed and planner statistics are never refreshed. The emergency anti-wraparound vacuum still runs, which is the only reason this is not P1; the highest XID age in this cluster is currently %s.',
              s.source,
              coalesce(', ' || s.sourcefile || ':' || s.sourceline::text, ''),
              to_char((SELECT max(age(datfrozenxid)) FROM pg_database), 'FM999,999,999,999')) AS details,
       json_build_object(
              'autovacuum', s.setting,
              'source', s.source,
              'sourcefile', s.sourcefile,
              'max_datfrozenxid_age', (SELECT max(age(datfrozenxid)) FROM pg_database),
              'track_counts', current_setting('track_counts'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'autovacuum' AND s.setting = 'off';
