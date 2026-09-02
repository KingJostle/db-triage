-- check: MY-REL-009
-- title: Buffer pool warm-up not configured (review)
-- priority: 200 | category: REL | scope: setting | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.innodb_buffer_pool_dump_at_shutdown,
--        @@GLOBAL.innodb_buffer_pool_load_at_startup,
--        @@GLOBAL.innodb_buffer_pool_dump_pct
-- Both variables exist on MySQL 5.6+ and MariaDB 10.0+ and both default to ON,
-- so finding either OFF means someone turned it off.
-- Reported at P200 as a review row, not a defect: it changes only how long a
-- restart takes to return to normal performance, and on a server with a small
-- pool or infrequent restarts that may not matter. On a server with a large
-- pool it matters a great deal — a cold pool means every query is reading from
-- disk, and a planned two-minute restart becomes an hour of degraded service
-- while the pool refills organically.
-- What is saved and restored is the LIST OF PAGE IDENTIFIERS, not the pages, so
-- the dump file is small and shutdown is not meaningfully delayed.
SELECT
  'MY-REL-009' AS check_id,
  'setting'    AS scope,
  IF(@@GLOBAL.innodb_buffer_pool_dump_at_shutdown = 0,
     'innodb_buffer_pool_dump_at_shutdown', 'innodb_buffer_pool_load_at_startup') AS object,
  CONCAT('innodb_buffer_pool_dump_at_shutdown = ',
         CAST(@@GLOBAL.innodb_buffer_pool_dump_at_shutdown AS CHAR),
         ', innodb_buffer_pool_load_at_startup = ',
         CAST(@@GLOBAL.innodb_buffer_pool_load_at_startup AS CHAR),
         ' (both default to ON, so this was changed). Buffer pool is ',
         ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 2), ' GB. ',
         'Without warm-up, a restart leaves the pool empty and every query reads from disk until it refills organically — a planned two-minute restart becomes an extended period of degraded service on a pool this size. ',
         'What is dumped is the list of page identifiers, not the pages themselves, so the file is small and shutdown is not meaningfully delayed. ',
         'Recorded for review rather than as a defect: on a small pool or a server that never restarts, it does not matter.') AS details,
  JSON_OBJECT(
    'innodb_buffer_pool_dump_at_shutdown', CAST(@@GLOBAL.innodb_buffer_pool_dump_at_shutdown AS CHAR),
    'innodb_buffer_pool_load_at_startup', CAST(@@GLOBAL.innodb_buffer_pool_load_at_startup AS CHAR),
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'innodb_buffer_pool_dump_pct', @@GLOBAL.innodb_buffer_pool_dump_pct) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.innodb_buffer_pool_dump_at_shutdown = 0
   OR @@GLOBAL.innodb_buffer_pool_load_at_startup = 0;
