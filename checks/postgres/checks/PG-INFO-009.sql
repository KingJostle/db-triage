-- check: PG-INFO-009
-- title: Roles summary
-- priority: 250
-- scope: role
-- cost: 0
SELECT 'PG-INFO-009'::text AS check_id,
       'role'::text        AS scope,
       NULL::text          AS object,
       format('%s roles in total: %s can log in, %s are superusers, %s have REPLICATION, %s have CREATEROLE, %s have CREATEDB, %s have BYPASSRLS. %s are PostgreSQL predefined roles (pg_*) and %s are platform-owned. %s login role(s) have a password set, %s have an expiry date. Group roles (no login): %s.',
              c.total, c.login, c.super, c.replication, c.createrole, c.createdb, c.bypassrls,
              c.predefined, c.platform, c.with_password, c.with_expiry, c.total - c.login) AS details,
       json_build_object('total_roles', c.total, 'login_roles', c.login, 'superusers', c.super,
                         'replication_roles', c.replication, 'createrole_roles', c.createrole,
                         'createdb_roles', c.createdb, 'bypassrls_roles', c.bypassrls,
                         'predefined_roles', c.predefined, 'platform_roles', c.platform,
                         'login_roles_with_password', c.with_password,
                         'login_roles_with_expiry', c.with_expiry,
                         'group_roles', c.total - c.login)::text AS evidence_json,
       'high'::text AS confidence
FROM (
  SELECT count(*)                                                        AS total,
         count(*) FILTER (WHERE rolcanlogin)                             AS login,
         count(*) FILTER (WHERE rolsuper)                                AS super,
         count(*) FILTER (WHERE rolreplication)                          AS replication,
         count(*) FILTER (WHERE rolcreaterole)                           AS createrole,
         count(*) FILTER (WHERE rolcreatedb)                             AS createdb,
         count(*) FILTER (WHERE rolbypassrls)                            AS bypassrls,
         count(*) FILTER (WHERE rolname LIKE 'pg\_%')                    AS predefined,
         count(*) FILTER (WHERE rolname IN ('rdsadmin', 'cloudsqladmin', 'cloudsqlsuperuser',
                                            'azure_superuser', 'azure_pg_admin', 'supabase_admin',
                                            'neon_superuser', 'tsdbadmin', 'crunchy_superuser')) AS platform,
         count(*) FILTER (WHERE rolcanlogin AND rolpassword IS NOT NULL) AS with_password,
         count(*) FILTER (WHERE rolcanlogin AND rolvaliduntil IS NOT NULL) AS with_expiry
  FROM pg_roles
) c;
