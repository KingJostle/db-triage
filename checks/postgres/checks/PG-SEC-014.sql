-- check: PG-SEC-014
-- title: SECURITY DEFINER functions without a fixed search_path
-- priority: 100
-- scope: relation
-- cost: 1
SELECT 'PG-SEC-014'::text AS check_id,
       'relation'::text   AS scope,
       format('%I.%I.%I', current_database(), n.nspname, p.proname)::text AS object,
       format('Function %s.%s(%s) is SECURITY DEFINER, owned by %s, written in %s, with no search_path pinned in its configuration. It runs with the owner''s privileges but resolves unqualified names using the caller''s search_path, so a caller who can create objects in any schema on that path (see PG-SEC-013) can substitute their own function, operator or table and have the owner execute it. Fix: ALTER FUNCTION %s.%s(%s) SET search_path = pg_catalog, <the schemas it needs>. EXECUTE is granted to: %s.',
              n.nspname, p.proname, pg_get_function_identity_arguments(p.oid),
              pg_get_userbyid(p.proowner), l.lanname,
              quote_ident(n.nspname), quote_ident(p.proname), pg_get_function_identity_arguments(p.oid),
              coalesce((SELECT string_agg(CASE WHEN a.grantee = 0 THEN 'PUBLIC'
                                               ELSE pg_get_userbyid(a.grantee) END, ', ')
                        FROM aclexplode(p.proacl) a WHERE a.privilege_type = 'EXECUTE'),
                       'PUBLIC (default grant)')) AS details,
       json_build_object('schema', n.nspname, 'function', p.proname,
                         'arguments', pg_get_function_identity_arguments(p.oid),
                         'owner', pg_get_userbyid(p.proowner), 'language', l.lanname,
                         'proconfig', array_to_string(p.proconfig, ';'),
                         'execute_granted_to_public',
                            (p.proacl IS NULL
                             OR EXISTS (SELECT 1 FROM aclexplode(p.proacl) a
                                        WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE')))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
JOIN pg_language  l ON l.oid = p.prolang
WHERE p.prosecdef
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND coalesce(array_to_string(p.proconfig, ' '), '') !~ 'search_path='
  AND NOT EXISTS (SELECT 1 FROM pg_depend d
                  WHERE d.objid = p.oid AND d.classid = 'pg_proc'::regclass AND d.deptype = 'e')
ORDER BY n.nspname, p.proname;
