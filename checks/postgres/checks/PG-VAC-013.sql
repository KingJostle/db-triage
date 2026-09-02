-- check: PG-VAC-013
-- title: Insert-only tables never vacuumed (PostgreSQL 12 and older)
-- priority: 100
-- scope: relation
-- cost: 1
-- max_version: 12
-- thresholds: min_inserts
SELECT 'PG-VAC-013'::text AS check_id,
       'relation'::text   AS scope,
       format('%I.%I.%I', current_database(), t.schemaname, t.relname)::text AS object,
       format('%s inserts (threshold %s), no updates and no deletes, never vacuumed, size %s. On PostgreSQL %s autovacuum does not consider inserts at all (autovacuum_vacuum_insert_threshold arrived in 13), so this relation has no visibility map: index-only scans always visit the heap, and the pages will only ever be frozen by the emergency anti-wraparound vacuum. relfrozenxid age is %s.',
              to_char(t.n_tup_ins, 'FM999,999,999,999'),
              to_char(:'pg_vac_013_min_inserts'::bigint, 'FM999,999,999,999'),
              pg_size_pretty(pg_total_relation_size(t.relid)),
              current_setting('server_version'),
              to_char(age(c.relfrozenxid), 'FM999,999,999,999')) AS details,
       json_build_object('n_tup_ins', t.n_tup_ins, 'n_tup_upd', t.n_tup_upd, 'n_tup_del', t.n_tup_del,
                         'threshold_inserts', :'pg_vac_013_min_inserts'::bigint,
                         'total_bytes', pg_total_relation_size(t.relid),
                         'relfrozenxid_age', age(c.relfrozenxid))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_user_tables t
JOIN pg_class c ON c.oid = t.relid
WHERE t.n_tup_ins >= :'pg_vac_013_min_inserts'::bigint
  AND t.n_tup_upd = 0 AND t.n_tup_del = 0
  AND t.last_vacuum IS NULL AND t.last_autovacuum IS NULL
ORDER BY t.n_tup_ins DESC;
