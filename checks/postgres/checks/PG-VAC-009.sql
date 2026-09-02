-- check: PG-VAC-009
-- title: Tables with autovacuum disabled via a storage parameter
-- priority: 100
-- scope: relation
-- cost: 1
SELECT 'PG-VAC-009'::text AS check_id,
       'relation'::text   AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('reloptions contain %s. Size %s, %s dead tuples against %s live. Last vacuum %s, last autovacuum %s. Nothing will reclaim dead tuples on this relation except a manual VACUUM or the emergency anti-wraparound path; relfrozenxid age is currently %s.',
              array_to_string(ARRAY(SELECT o FROM unnest(c.reloptions) o WHERE o LIKE 'autovacuum%'), ', '),
              pg_size_pretty(pg_total_relation_size(c.oid)),
              to_char(coalesce(t.n_dead_tup, 0), 'FM999,999,999,999'),
              to_char(coalesce(t.n_live_tup, 0), 'FM999,999,999,999'),
              coalesce(t.last_vacuum::text, 'never'), coalesce(t.last_autovacuum::text, 'never'),
              to_char(age(c.relfrozenxid), 'FM999,999,999,999')) AS details,
       json_build_object('reloptions', array_to_string(c.reloptions, ';'),
                         'total_bytes', pg_total_relation_size(c.oid),
                         'n_dead_tup', t.n_dead_tup, 'n_live_tup', t.n_live_tup,
                         'last_vacuum', t.last_vacuum, 'last_autovacuum', t.last_autovacuum,
                         'relfrozenxid_age', age(c.relfrozenxid))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_stat_user_tables t ON t.relid = c.oid
WHERE c.relkind IN ('r', 'm', 'p')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  AND array_to_string(c.reloptions, ' ') ~ 'autovacuum_enabled\s*=\s*(false|off|0)'
ORDER BY pg_total_relation_size(c.oid) DESC;
