-- check: MY-SCHEMA-007
-- title: Integrity checks disabled globally
-- priority: 50 | category: SCHEMA | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.foreign_key_checks, @@GLOBAL.unique_checks
-- Both are SESSION variables with a GLOBAL default, and both are legitimately
-- set to OFF for the duration of a bulk import — that is what mysqldump output
-- does, in the session, and it is fine.
-- Setting them OFF GLOBALLY is different: every future session inherits it, so
-- foreign keys stop being enforced and unique indexes stop being checked on
-- insert for the whole server. InnoDB does not re-validate afterwards, so rows
-- that violate a constraint are simply in the table, and the first time anyone
-- notices is when a JOIN returns orphans or a unique index reports duplicates
-- during a rebuild.
-- @@GLOBAL is read explicitly, never @@SESSION, so an import running right now
-- in another session cannot produce a false positive.
SELECT
  'MY-SCHEMA-007' AS check_id,
  'setting'       AS scope,
  IF(@@GLOBAL.foreign_key_checks = 0, 'foreign_key_checks', 'unique_checks') AS object,
  CONCAT('Globally: foreign_key_checks = ', IF(@@GLOBAL.foreign_key_checks = 1, 'ON', 'OFF'),
         ', unique_checks = ', IF(@@GLOBAL.unique_checks = 1, 'ON', 'OFF'),
         '. Every new session inherits this, so ',
         CONCAT_WS(' and ',
           IF(@@GLOBAL.foreign_key_checks = 0, 'foreign key constraints are not enforced on insert, update or delete', NULL),
           IF(@@GLOBAL.unique_checks = 0, 'unique secondary indexes are not checked on insert', NULL)),
         '. InnoDB never revalidates afterwards, so violating rows stay in the table and only surface as orphaned JOIN results or as duplicate-key errors during a later index rebuild. ',
         'There are ', fk.n, ' foreign key constraint(s) defined on this server, which is what is currently not being enforced. ',
         'Setting these OFF per-session for a bulk import is normal; setting them OFF globally is not.') AS details,
  JSON_OBJECT(
    'foreign_key_checks', CAST(@@GLOBAL.foreign_key_checks AS CHAR),
    'unique_checks', CAST(@@GLOBAL.unique_checks AS CHAR),
    'foreign_key_constraints', fk.n) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n FROM information_schema.TABLE_CONSTRAINTS
  WHERE CONSTRAINT_TYPE = 'FOREIGN KEY'
    AND CONSTRAINT_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS fk
WHERE @@GLOBAL.foreign_key_checks = 0 OR @@GLOBAL.unique_checks = 0;
