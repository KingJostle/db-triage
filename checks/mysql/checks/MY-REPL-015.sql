-- check: MY-REPL-015
-- title: Replication filters configured
-- priority: 50 | category: REPL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: performance_schema.replication_applier_filters /
--        replication_applier_global_filters (MySQL 8.0.1+);
--        @dbt_v_replicate_* bundle variables (MariaDB, and MySQL where the
--        performance_schema tables are unavailable)
-- NOT in the design's §5.2 table; added because filters are one of the few
-- MySQL replication settings that silently make a replica a non-backup and a
-- non-failover-target, and requirement lists them explicitly.
-- Why it matters: a filtered replica is missing data by design, so it can never
-- be promoted and a restore from it is incomplete. Worse, replicate_ignore_db
-- and replicate_do_db act on the *default database of the statement*, not on the
-- tables it touches, so a cross-schema statement issued with the wrong USE is
-- filtered or not filtered contrary to intent — that is a documented behaviour,
-- not a bug, and it is why the *_wild_*_table forms are the safer spelling.
-- Reported at P50 rather than higher because a filter is usually deliberate;
-- what is almost never deliberate is the failover plan that forgot about it.
SET @dbt_q_ps := "
SELECT
  'MY-REPL-015' AS check_id,
  'cluster'     AS scope,
  'replication-filters' AS object,
  CONCAT(f.n, ' replication filter(s) are active: ', f.list,
         '. A filtered replica is missing rows by design: it cannot be promoted to source and a backup taken from it is incomplete. ',
         'Note that the *_DB filters test the statement''s default database, not the tables it touches.') AS details,
  JSON_OBJECT('filter_count', f.n, 'filters', f.list, 'source', 'performance_schema.replication_applier_filters') AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n,
         SUBSTRING(GROUP_CONCAT(CONCAT(FILTER_NAME, ' = ', FILTER_RULE) SEPARATOR '; '), 1, 600) AS list
    FROM performance_schema.replication_applier_global_filters
) AS f
WHERE f.n > 0";

SET @dbt_q_var := "
SELECT
  'MY-REPL-015' AS check_id,
  'cluster'     AS scope,
  'replication-filters' AS object,
  CONCAT(f.n, ' replication filter variable(s) are set: ', f.list,
         '. A filtered replica is missing rows by design: it cannot be promoted to source and a backup taken from it is incomplete. ',
         'Note that replicate_do_db / replicate_ignore_db test the statement''s default database, not the tables it touches, so the *_wild_*_table forms are the predictable spelling.') AS details,
  JSON_OBJECT('filter_count', f.n, 'filters', f.list, 'source', 'global variables') AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    (IFNULL(@dbt_v_replicate_do_db, '') <> '')
  + (IFNULL(@dbt_v_replicate_ignore_db, '') <> '')
  + (IFNULL(@dbt_v_replicate_do_table, '') <> '')
  + (IFNULL(@dbt_v_replicate_ignore_table, '') <> '')
  + (IFNULL(@dbt_v_replicate_wild_do_table, '') <> '')
  + (IFNULL(@dbt_v_replicate_wild_ignore_table, '') <> '')
  + (IFNULL(@dbt_v_replicate_rewrite_db, '') <> '') AS n,
    SUBSTRING(CONCAT_WS('; ',
      IF(IFNULL(@dbt_v_replicate_do_db, '') <> '',            CONCAT('replicate_do_db = ', @dbt_v_replicate_do_db), NULL),
      IF(IFNULL(@dbt_v_replicate_ignore_db, '') <> '',        CONCAT('replicate_ignore_db = ', @dbt_v_replicate_ignore_db), NULL),
      IF(IFNULL(@dbt_v_replicate_do_table, '') <> '',         CONCAT('replicate_do_table = ', @dbt_v_replicate_do_table), NULL),
      IF(IFNULL(@dbt_v_replicate_ignore_table, '') <> '',     CONCAT('replicate_ignore_table = ', @dbt_v_replicate_ignore_table), NULL),
      IF(IFNULL(@dbt_v_replicate_wild_do_table, '') <> '',    CONCAT('replicate_wild_do_table = ', @dbt_v_replicate_wild_do_table), NULL),
      IF(IFNULL(@dbt_v_replicate_wild_ignore_table, '') <> '',CONCAT('replicate_wild_ignore_table = ', @dbt_v_replicate_wild_ignore_table), NULL),
      IF(IFNULL(@dbt_v_replicate_rewrite_db, '') <> '',       CONCAT('replicate_rewrite_db = ', @dbt_v_replicate_rewrite_db), NULL)
    ), 1, 600) AS list
) AS f
WHERE f.n > 0";

SET @dbt_q := IF(IFNULL(@dbt_has_applier_filters, 0) = 1 AND IFNULL(@dbt_is_mariadb, 0) = 0,
                 @dbt_q_ps, @dbt_q_var);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
