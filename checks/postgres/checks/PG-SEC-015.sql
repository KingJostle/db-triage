-- check: PG-SEC-015
-- title: User tables granting write privileges to PUBLIC
-- priority: 50
-- scope: relation
-- cost: 1
SELECT 'PG-SEC-015'::text AS check_id,
       'relation'::text  AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('%s %s.%s grants %s to PUBLIC. Every role that can connect to database %s holds those privileges on it, including roles created later and roles that were only meant to read something else. Size %s, %s estimated rows. Full ACL: %s. Fix with REVOKE %s ON %s.%s FROM PUBLIC, after checking which roles were relying on the PUBLIC grant.',
              CASE c.relkind WHEN 'r' THEN 'Table' WHEN 'p' THEN 'Partitioned table'
                             WHEN 'm' THEN 'Materialized view' WHEN 'v' THEN 'View'
                             WHEN 'f' THEN 'Foreign table' WHEN 'S' THEN 'Sequence' ELSE 'Relation' END,
              n.nspname, c.relname, g.privs, current_database(),
              pg_size_pretty(pg_total_relation_size(c.oid)),
              to_char(greatest(c.reltuples, 0)::bigint, 'FM999,999,999,999'),
              array_to_string(c.relacl, ', '),
              g.privs, quote_ident(n.nspname), quote_ident(c.relname)) AS details,
       json_build_object('schema', n.nspname, 'relname', c.relname, 'relkind', c.relkind,
                         'public_privileges', g.privs,
                         'relacl', array_to_string(c.relacl, ';'),
                         'owner', pg_get_userbyid(c.relowner),
                         'total_bytes', pg_total_relation_size(c.oid),
                         'reltuples', greatest(c.reltuples, 0)::bigint)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL (
  SELECT string_agg(DISTINCT a.privilege_type, ', ' ORDER BY a.privilege_type) AS privs
  FROM aclexplode(c.relacl) a
  WHERE a.grantee = 0 AND a.privilege_type IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
) g
WHERE c.relkind IN ('r', 'p', 'm', 'v', 'f', 'S')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  AND g.privs IS NOT NULL
ORDER BY pg_total_relation_size(c.oid) DESC;
