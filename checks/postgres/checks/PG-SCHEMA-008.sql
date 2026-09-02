-- check: PG-SCHEMA-008
-- title: Foreign keys or check constraints NOT VALID
-- priority: 200
-- scope: relation
-- cost: 1
SELECT 'PG-SCHEMA-008'::text AS check_id,
       'relation'::text      AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('%s constraint %s on %s.%s is NOT VALID: %s. New and modified rows are checked, rows that were already there when it was added never were, so the constraint documents an intention rather than a guarantee - and the planner will not use a NOT VALID check constraint for constraint exclusion. Table size %s. VALIDATE CONSTRAINT scans the table under a SHARE UPDATE EXCLUSIVE lock, which does not block reads or writes, so this is usually a finished migration nobody came back to.',
              CASE con.contype WHEN 'f' THEN 'Foreign-key' WHEN 'c' THEN 'Check' ELSE con.contype::text END,
              con.conname, n.nspname, c.relname,
              pg_get_constraintdef(con.oid),
              pg_size_pretty(pg_total_relation_size(c.oid))) AS details,
       json_build_object('schema', n.nspname, 'table', c.relname,
                         'constraint', con.conname, 'contype', con.contype::text,
                         'definition', pg_get_constraintdef(con.oid),
                         'total_bytes', pg_total_relation_size(c.oid))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_constraint con
JOIN pg_class c     ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT con.convalidated
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY pg_total_relation_size(c.oid) DESC;
