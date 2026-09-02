-- check: MY-SCHEMA-012
-- title: Legacy character sets and row formats (inventory)
-- priority: 200 | category: SCHEMA | scope: schema | cost: 1 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.TABLES (TABLE_COLLATION, ROW_FORMAT)
-- Inventory at P200: none of this is broken, but all of it constrains what can
-- be done later, and it is the context in which MY-SCHEMA-014 (collation
-- mismatch) is read.
--   latin1        cannot store most of the world's text; a later conversion
--                 rewrites every table and can change index sizes and sort order
--   utf8 / utf8mb3 MySQL's three-byte "utf8" cannot store emoji or many CJK
--                 characters; MySQL 8.0 renamed it utf8mb3 and deprecated it,
--                 MariaDB 10.6+ likewise
--   COMPACT/REDUNDANT  the pre-Barracuda row formats: no large-prefix indexes
--                 (767-byte limit rather than 3072), no per-table compression,
--                 and off-page BLOB storage behaves differently
-- Summary shape: one row per schema, since these are almost always uniform
-- within a schema and per-table rows would be pure noise.
SELECT
  'MY-SCHEMA-012' AS check_id,
  'schema'        AS scope,
  x.sch           AS object,
  CONCAT('Schema `', x.sch, '`: ', x.legacy_charset, ' of ', x.total,
         ' table(s) use a legacy character set (', IFNULL(x.charsets, 'none'), '), and ',
         x.legacy_rowfmt, ' use a pre-Barracuda row format (',
         IFNULL(x.rowfmts, 'none'), '). Total ',
         ROUND(x.bytes / 1073741824, 2), ' GB. ',
         'latin1 cannot represent most non-Western text; utf8/utf8mb3 is three-byte and cannot store emoji or many CJK characters (deprecated in MySQL 8.0 and MariaDB 10.6). ',
         'COMPACT and REDUNDANT limit index prefixes to 767 bytes rather than 3072 and cannot use per-table compression. ',
         'Server defaults: character_set_server = ', @@GLOBAL.character_set_server,
         ', collation_server = ', @@GLOBAL.collation_server, '.') AS details,
  JSON_OBJECT(
    'schema', x.sch,
    'tables', x.total,
    'legacy_charset_tables', x.legacy_charset,
    'legacy_rowformat_tables', x.legacy_rowfmt,
    'charsets', IFNULL(x.charsets, ''),
    'row_formats', IFNULL(x.rowfmts, ''),
    'bytes', x.bytes,
    'character_set_server', @@GLOBAL.character_set_server,
    'collation_server', @@GLOBAL.collation_server) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT TABLE_SCHEMA AS sch,
         COUNT(*) AS total,
         IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes,
         SUM(TABLE_COLLATION LIKE 'latin1%' OR TABLE_COLLATION LIKE 'utf8mb3%'
             OR (TABLE_COLLATION LIKE 'utf8\_%')) AS legacy_charset,
         SUM(ROW_FORMAT IN ('Compact', 'Redundant')) AS legacy_rowfmt,
         SUBSTRING(GROUP_CONCAT(DISTINCT IF(TABLE_COLLATION LIKE 'latin1%'
             OR TABLE_COLLATION LIKE 'utf8mb3%' OR TABLE_COLLATION LIKE 'utf8\_%',
             TABLE_COLLATION, NULL) SEPARATOR ', '), 1, 200) AS charsets,
         SUBSTRING(GROUP_CONCAT(DISTINCT IF(ROW_FORMAT IN ('Compact', 'Redundant'),
             ROW_FORMAT, NULL) SEPARATOR ', '), 1, 100) AS rowfmts
  FROM information_schema.TABLES
  WHERE TABLE_TYPE = 'BASE TABLE'
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  GROUP BY TABLE_SCHEMA
) AS x
WHERE x.legacy_charset > 0 OR x.legacy_rowfmt > 0;
