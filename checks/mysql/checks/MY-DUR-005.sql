-- check: MY-DUR-005
-- title: Server running in innodb_force_recovery mode
-- priority: 1 | category: DUR | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.innodb_force_recovery
-- Universal, read-only variable. 1-3 disable parts of recovery; from 4 upward
-- InnoDB is explicitly allowed to corrupt data structures to stay up, and from
-- 4 (MySQL 8.0 / MariaDB 10.x) the server refuses writes. Anything above 0 is a
-- rescue mode nobody should still be in.
SELECT
  'MY-DUR-005' AS check_id,
  'setting'    AS scope,
  'innodb_force_recovery' AS object,
  CONCAT('innodb_force_recovery = ', @@GLOBAL.innodb_force_recovery,
         CASE
           WHEN @@GLOBAL.innodb_force_recovery >= 4
             THEN ': InnoDB is permitted to damage data structures to keep the server up, and writes are refused. This is a data-rescue mode, not a running configuration.'
           ELSE ': parts of InnoDB crash recovery, the purge thread and/or the insert buffer merge are disabled. Undo is not being purged and background repair is not happening.'
         END,
         ' Uptime is ', ROUND(@dbt_uptime_s / 3600, 1),
         ' h, so this is not a transient boot state.') AS details,
  JSON_OBJECT(
    'innodb_force_recovery', @@GLOBAL.innodb_force_recovery,
    'uptime_seconds', @dbt_uptime_s,
    'read_only', CAST(@@GLOBAL.read_only AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.innodb_force_recovery > 0;
