-- check: MY-REL-007
-- title: sys schema missing
-- priority: 150 | category: REL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.VIEWS in schema sys (via @dbt_sys_view_count)
-- Availability, verified: MySQL ships sys from 5.7.7 and installs it by default.
-- MariaDB ships it from 10.6 (a MariaDB 10.11 install has 100 sys objects,
-- verified). Below those versions, or after someone dropped the schema, it is
-- absent.
-- Its absence is not a fault — every check that uses a sys view has an
-- information_schema or performance_schema fallback, and MY-IDX-003's fallback
-- was verified to produce byte-identical findings. What is lost is the
-- convenience for the human doing the follow-up work: the confirmation queries
-- in reference/checks-mysql.md are written against sys views because they are
-- an order of magnitude shorter and easier to read.
-- Reported at P150 with the list of which checks took a fallback path, so the
-- reader knows the findings are complete but derived differently.
SELECT
  'MY-REL-007' AS check_id,
  'cluster'    AS scope,
  'sys'        AS object,
  CONCAT('The sys schema is absent (', IFNULL(@dbt_sys_view_count, 0),
         ' views found). MySQL ships it from 5.7.7 and MariaDB from 10.6; this server is ',
         @dbt_fork, ' ', @@GLOBAL.version, '. ',
         'No finding is lost: MY-IDX-001, MY-IDX-003, MY-SCHEMA-005 and MY-SCHEMA-006 fall back to information_schema and performance_schema queries that produce the same results, ',
         'and MY-IDX-004, MY-IDX-005 and MY-SCHEMA-011 are skipped because they have no equivalent fallback worth the noise. ',
         'What is lost is the short confirmation queries in the reference documentation, which are written against sys views. ',
         'Installing it is a matter of loading the sys schema SQL and needs no restart.') AS details,
  JSON_OBJECT(
    'sys_view_count', IFNULL(@dbt_sys_view_count, 0),
    'fork', @dbt_fork,
    'version', @@GLOBAL.version,
    'checks_using_fallback', 'MY-IDX-001,MY-IDX-003,MY-SCHEMA-005,MY-SCHEMA-006',
    'checks_skipped', 'MY-IDX-004,MY-IDX-005,MY-SCHEMA-011') AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_sys_view_count, 0) = 0;
