-- check: PG-SEC-020
-- title: Login roles with no password expiry
-- priority: 200
-- scope: role
-- cost: 0
SELECT 'PG-SEC-020'::text AS check_id,
       'role'::text       AS scope,
       NULL::text         AS object,
       format('%s of %s login roles have no rolvaliduntil set: %s. PostgreSQL has no password-age or rotation policy of its own, so an expiry date is the only server-side control over how long a credential stays valid. Most estates rotate secrets outside the database instead, which is why this is an inventory row rather than a finding: it tells a reviewer that nothing here will expire on its own. %s of these are superusers.',
              c.no_expiry, c.total,
              left(c.names, 400),
              c.supers) AS details,
       json_build_object('roles_without_expiry', c.no_expiry, 'login_roles', c.total,
                         'superusers_without_expiry', c.supers,
                         'role_names', c.names)::text AS evidence_json,
       'high'::text AS confidence
FROM (
  SELECT count(*) FILTER (WHERE rolvaliduntil IS NULL)                 AS no_expiry,
         count(*)                                                      AS total,
         count(*) FILTER (WHERE rolvaliduntil IS NULL AND rolsuper)    AS supers,
         string_agg(rolname, ', ' ORDER BY rolname) FILTER (WHERE rolvaliduntil IS NULL) AS names
  FROM pg_roles WHERE rolcanlogin
) c
WHERE c.no_expiry > 0;
