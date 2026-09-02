-- check: PG-DUR-005
-- title: Unlogged tables present
-- priority: 100
-- scope: relation
-- cost: 1
SELECT 'PG-DUR-005'::text AS check_id,
       'relation'::text   AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('Unlogged %s, %s, %s estimated rows. Its contents are not written to WAL: they are truncated to empty on crash recovery, are not present on any standby, and are not in any base backup or PITR restore. That is the right trade for a scratch or staging relation and a data-loss surprise for anything else.',
              CASE c.relkind WHEN 'r' THEN 'table' WHEN 'p' THEN 'partitioned table'
                             WHEN 'm' THEN 'materialized view' ELSE c.relkind::text END,
              pg_size_pretty(pg_total_relation_size(c.oid)),
              to_char(greatest(c.reltuples, 0)::bigint, 'FM999,999,999,999')) AS details,
       json_build_object('relkind', c.relkind, 'total_bytes', pg_total_relation_size(c.oid),
                         'reltuples', greatest(c.reltuples, 0)::bigint,
                         'schema', n.nspname, 'relname', c.relname)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relpersistence = 'u'
  AND n.nspname NOT LIKE 'pg_temp%'
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY pg_total_relation_size(c.oid) DESC;
