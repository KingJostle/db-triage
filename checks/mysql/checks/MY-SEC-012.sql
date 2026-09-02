-- check: MY-SEC-012
-- title: Legacy test database or test grants present
-- priority: 150 | category: SEC | scope: schema | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.SCHEMATA, information_schema.SCHEMA_PRIVILEGES
-- Historic MySQL packaging created a `test` schema plus rows in mysql.db that
-- grant every privilege on `test` and `test\_%` to ANY user, including the
-- anonymous ones (MY-SEC-003). The combination gives an unauthenticated
-- connection a writable schema on the server — useful for staging an
-- INTO OUTFILE attack or simply for filling the disk.
-- MariaDB's mariadb-install-db still creates it on several packagings (verified
-- present on a stock MariaDB 10.11 install); MySQL 5.7+ does not, and
-- mysql_secure_installation removes it.
-- Read through information_schema.SCHEMA_PRIVILEGES rather than mysql.db so the
-- check works without SELECT on the mysql schema.
SELECT
  'MY-SEC-012' AS check_id,
  'schema'     AS scope,
  'test'       AS object,
  CONCAT('The legacy `test` schema exists',
         IF(g.n > 0,
            CONCAT(' and ', g.n, ' grantee(s) hold schema-level privileges on test / test_%: ', g.list),
            ' (no wildcard grants on it were found in information_schema.SCHEMA_PRIVILEGES)'),
         '. Historic packaging granted all privileges on this schema to every user including anonymous accounts, which gives an unauthenticated connection somewhere writable on the server. ',
         'Tables in it: ', t.n, '. mysql_secure_installation removes both the schema and the grants.') AS details,
  JSON_OBJECT(
    'schema', 'test',
    'table_count', t.n,
    'wildcard_grants', g.n,
    'grantees', g.list) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = 'test'
) AS s,
(
  SELECT COUNT(*) AS n FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'test'
) AS t,
(
  SELECT COUNT(DISTINCT GRANTEE) AS n,
         SUBSTRING(GROUP_CONCAT(DISTINCT GRANTEE SEPARATOR ', '), 1, 300) AS list
    FROM information_schema.SCHEMA_PRIVILEGES
   WHERE TABLE_SCHEMA LIKE 'test%'
) AS g
WHERE s.n > 0;
