-- db-triage: canonical unit handling for pg_settings.
--
-- WHY THIS EXISTS. pg_settings.setting is a raw number expressed in the
-- setting's own `unit` column, while current_setting() returns a *formatted*
-- string with the unit appended ('2ms', '128MB', '4GB'). Casting
-- current_setting('shared_buffers') to numeric therefore fails at runtime, and
-- comparing pg_settings.setting to a byte threshold silently compares 16384
-- (8 kB blocks) against 134217728 (bytes). Both mistakes are easy to make and
-- neither shows up until the check fires on a real server.
--
-- RULE FOR CHECK AUTHORS. Never cast current_setting() of a unit-bearing
-- setting to a number. Use the conversion below, and guard the sentinel value
-- -1 (which means "unlimited" or "inherit", not "minus one byte") before
-- converting.
--
-- This file is a runnable reference query, not an include: check files inline
-- the CASE expression they need so that each check file remains a single
-- self-contained statement.

SELECT name,
       setting,
       unit,
       boot_val,
       source,
       sourcefile,
       sourceline,
       pending_restart,
       CASE WHEN setting ~ '^-?[0-9]+$' AND setting::numeric >= 0 THEN
         setting::numeric * CASE unit
           WHEN 'B'    THEN 1            WHEN 'kB'  THEN 1024
           WHEN '8kB'  THEN 8192         WHEN '16kB' THEN 16384
           WHEN '32kB' THEN 32768        WHEN '64kB' THEN 65536
           WHEN 'MB'   THEN 1048576      WHEN 'GB'  THEN 1073741824
           WHEN 'TB'   THEN 1099511627776
           ELSE NULL END
       END AS bytes,
       CASE WHEN setting ~ '^-?[0-9]+$' AND setting::numeric >= 0 THEN
         setting::numeric * CASE unit
           WHEN 'us'  THEN 0.001  WHEN 'ms' THEN 1
           WHEN 's'   THEN 1000   WHEN 'min' THEN 60000
           WHEN 'h'   THEN 3600000 WHEN 'd'  THEN 86400000
           ELSE NULL END
       END AS milliseconds
FROM pg_settings
ORDER BY name;
