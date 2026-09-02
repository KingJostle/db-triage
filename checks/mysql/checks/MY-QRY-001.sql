-- check: MY-QRY-001
-- title: performance_schema disabled
-- priority: 100 | category: QRY | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.performance_schema
-- A META-shaped finding that lives in QRY because it is about workload
-- visibility: with performance_schema OFF there are no statement digests, no
-- index usage counters and no replication applier tables, so MY-QRY-002 and
-- 004..011, MY-IDX-001..005, MY-REPL-001..004/010/013 and MY-CONN-005 cannot run
-- at all. The runner records every one of them in XX-META-001 with reason
-- `privilege`, and this row explains why.
-- Default divergence: MySQL 5.6+ ships performance_schema ON. MariaDB ships it
-- OFF by default to this day (10.11 included) — so on MariaDB this is usually an
-- unreviewed default rather than a decision, and the details say so.
-- It cannot be turned on without a restart on either fork.
-- The cost of turning it on is real but modest with the default instrumentation:
-- a few hundred MB of memory and single-digit percent overhead. The cost of
-- leaving it off is that roughly a quarter of this catalog is blind.
SELECT
  'MY-QRY-001' AS check_id,
  'setting'    AS scope,
  'performance_schema' AS object,
  CONCAT('performance_schema = OFF. ',
         IF(@dbt_is_mariadb,
            'MariaDB ships it OFF by default, so this is probably an unreviewed default rather than a decision.',
            'MySQL ships it ON by default, so it was disabled deliberately.'),
         ' Without it there are no statement digests, no per-index usage counters and no replication applier tables, so these checks cannot run: ',
         'MY-QRY-002, MY-QRY-004 to MY-QRY-011, MY-IDX-001 to MY-IDX-005, MY-REPL-001 to MY-REPL-004, MY-REPL-010, MY-REPL-013, MY-CONN-005. ',
         'That is a large fraction of the workload and index sections of this report. ',
         'Enabling it needs a server restart on both forks; with the default instrumentation it costs a few hundred MB of memory and low single-digit percent overhead. ',
         'sys schema present: ', IF(IFNULL(@dbt_sys_view_count, 0) > 0, 'yes (but its views return nothing without performance_schema)', 'no'), '.') AS details,
  JSON_OBJECT(
    'performance_schema', 'OFF',
    'fork', @dbt_fork,
    'sys_views', IFNULL(@dbt_sys_view_count, 0),
    'checks_disabled', 'MY-QRY-002,MY-QRY-004..011,MY-IDX-001..005,MY-REPL-001..004,MY-REPL-010,MY-REPL-013,MY-CONN-005') AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.performance_schema = 0;
