-- check: PG-SEC-006
-- title: Non-SCRAM password authentication in use
-- priority: 100
-- scope: cluster
-- cost: 0
-- min_version: 10
-- The pg_authid part needs superuser; without it only the setting is evaluated
-- and the run records the role scan as skipped for privilege.
SELECT 'PG-SEC-006'::text            AS check_id,
       'cluster'::text               AS scope,
       'password_encryption'::text   AS object,
       format('password_encryption = %s, so every password set from now on is stored as an MD5 hash of the password and the role name. MD5 verification sends a value derived only from that hash, so anyone who reads pg_authid can authenticate without knowing the password, and the hash itself is offline-crackable. SCRAM-SHA-256 has been the alternative since PostgreSQL 10 and the default since 14; PostgreSQL 18 warns on md5. Changing the setting does not re-hash existing passwords - each role must set its password again.',
              s.setting) AS details,
       json_build_object('password_encryption', s.setting, 'source', s.source,
                         'server_version_num', current_setting('server_version_num')::int)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'password_encryption' AND s.setting = 'md5';
