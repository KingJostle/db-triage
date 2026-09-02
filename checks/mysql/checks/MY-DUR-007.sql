-- check: MY-DUR-007
-- title: Non-transactional storage engines in use
-- priority: 50 | category: DUR | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: max_rows=20
-- reads: information_schema.TABLES
-- MyISAM and Aria(transactional=0) have no crash recovery for data, take
-- table-level locks for every write, and cannot participate in a transaction —
-- so a statement that fails halfway leaves the table half-updated and the binary
-- log records it as if it succeeded. MEMORY/CSV/ARCHIVE/BLACKHOLE are called out
-- separately because their non-durability is usually the point.
-- Emission shape (b) per DESIGN §2.1: one summary row per engine with a top-N
-- list, so a 4,000-table legacy schema does not produce 4,000 findings.
-- MariaDB note: mysql.* system tables are Aria and are excluded, as is the
-- MariaDB-specific `sys` schema copy.
SELECT
  'MY-DUR-007' AS check_id,
  'relation'   AS scope,
  t.ENGINE     AS object,
  CONCAT(t.n, ' user table(s) use the ', t.ENGINE, ' engine, totalling ',
         ROUND(t.bytes / 1048576, 1), ' MB across ', t.schema_ct, ' schema(s). ',
         CASE t.ENGINE
           WHEN 'MyISAM' THEN 'MyISAM has no crash recovery, no transactions and a table-level write lock; a crash leaves tables needing REPAIR TABLE and a failed multi-row statement is left half-applied yet fully binlogged.'
           WHEN 'Aria'   THEN 'Aria is crash-safe for its own metadata but non-transactional for row data unless TRANSACTIONAL=1; it still takes table-level write locks.'
           WHEN 'MEMORY' THEN 'MEMORY tables are emptied on restart and their contents are not replicated consistently.'
           WHEN 'ARCHIVE' THEN 'ARCHIVE supports no UPDATE/DELETE and no transactions.'
           WHEN 'CSV'    THEN 'CSV supports no indexes, no NULLs and no transactions.'
           WHEN 'BLACKHOLE' THEN 'BLACKHOLE discards every row written to it; verify this is a deliberate binlog relay.'
           ELSE 'This engine is not transactional and not crash-safe.'
         END,
         ' Largest: ', t.top_tables, '.') AS details,
  JSON_OBJECT(
    'engine', t.ENGINE,
    'table_count', t.n,
    'schema_count', t.schema_ct,
    'total_bytes', t.bytes,
    'largest_tables', t.top_tables) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    ENGINE,
    COUNT(*)                                   AS n,
    COUNT(DISTINCT TABLE_SCHEMA)               AS schema_ct,
    IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes,
    SUBSTRING(GROUP_CONCAT(
      CONCAT(TABLE_SCHEMA, '.', TABLE_NAME, ' (',
             ROUND((DATA_LENGTH + INDEX_LENGTH) / 1048576, 1), ' MB)')
      ORDER BY DATA_LENGTH + INDEX_LENGTH DESC SEPARATOR ', '), 1, 400) AS top_tables
  FROM information_schema.TABLES
  WHERE TABLE_TYPE = 'BASE TABLE'
    AND ENGINE IS NOT NULL
    AND ENGINE NOT IN ('InnoDB', 'RocksDB', 'TokuDB', 'MyRocks', 'SEQUENCE')
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  GROUP BY ENGINE
) AS t;
