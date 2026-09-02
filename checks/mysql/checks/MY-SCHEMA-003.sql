-- check: MY-SCHEMA-003
-- title: sql_require_primary_key off while primary-key-less tables exist
-- priority: 150 | category: SCHEMA | scope: setting | cost: 1 | pass: fast
-- engine: mysql | min_version: 8.0.13 | requires: (none)
-- thresholds: (none)
-- reads: @dbt_v_sql_require_primary_key, information_schema.TABLES/STATISTICS
-- Availability: introduced in MySQL 8.0.13. MariaDB has no such variable at all
-- (verified absent on 10.11), so the bundle returns NULL there and this check
-- emits nothing rather than recommending something that cannot be done.
-- Derived: only fires when MY-SCHEMA-001 or MY-SCHEMA-002 already found
-- primary-key-less tables. Turning the variable on does not fix the existing
-- ones — it prevents the next one, which is why it is P150 hygiene rather than
-- part of the fix for the P20 finding.
-- Note it also blocks CREATE TABLE without a PK for every account including
-- migrations and ORMs, so it is a change that needs coordinating.
SELECT
  'MY-SCHEMA-003' AS check_id,
  'setting'       AS scope,
  'sql_require_primary_key' AS object,
  CONCAT('sql_require_primary_key = ', @dbt_v_sql_require_primary_key,
         ' while ', n.n, ' InnoDB table(s) already have no primary key (MY-SCHEMA-001/002). ',
         'Turning it ON does not fix those tables; it stops the next one being created. ',
         'It applies to every session including migrations and ORM-generated DDL, so coordinate it with whoever ships schema changes.') AS details,
  JSON_OBJECT(
    'sql_require_primary_key', @dbt_v_sql_require_primary_key,
    'tables_without_pk', n.n) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n
  FROM information_schema.TABLES AS t
  LEFT JOIN information_schema.STATISTICS AS s
    ON s.TABLE_SCHEMA = t.TABLE_SCHEMA AND s.TABLE_NAME = t.TABLE_NAME AND s.INDEX_NAME = 'PRIMARY'
  WHERE t.TABLE_TYPE = 'BASE TABLE'
    AND t.ENGINE = 'InnoDB'
    AND t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
    AND s.INDEX_NAME IS NULL
) AS n
WHERE @dbt_v_sql_require_primary_key IS NOT NULL
  AND UPPER(@dbt_v_sql_require_primary_key) IN ('OFF', '0')
  AND n.n > 0;
