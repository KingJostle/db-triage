-- check: MY-REPL-016
-- title: GTID set has gaps
-- priority: 20 | category: REPL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql | min_version: 5.6 | requires: (none)
-- thresholds: (none)
-- reads: @dbt_v_gtid_executed, @dbt_v_gtid_purged
-- NOT in the design's §5.2 table; added because requirement lists GTID gaps
-- explicitly and nothing else in the catalog detects them.
-- MySQL's gtid_executed is a set of UUID:interval entries, e.g.
--   3E11FA47-...:1-5:8-12,8C4C4D0F-...:1-900
-- A UUID with MORE THAN ONE interval means transactions in between were never
-- executed here: skipped with sql_slave_skip_counter, injected empty with
-- gtid_next, or lost. Those numbers can never be filled in, so a replica built
-- from this server inherits the hole, and AUTO_POSITION will not re-fetch them.
-- Detection is textual and deliberately conservative: total colons across the
-- whole set versus the number of UUID entries (commas + 1). More colons than
-- UUIDs means at least one UUID carries a second interval. Confidence is medium
-- because it identifies that a gap exists, not which transactions are missing.
-- MariaDB is excluded: its GTID format is domain-server-sequence
-- (0-1-4711) with no interval notation, so a gap is not expressible in the
-- variable and this test would be meaningless there.
SELECT
  'MY-REPL-016' AS check_id,
  'cluster'     AS scope,
  'gtid_executed' AS object,
  CONCAT('gtid_executed contains ', g.colons, ' interval(s) across ', g.uuids,
         ' source UUID(s), so at least ', g.colons - g.uuids,
         ' gap(s) exist in the executed set: some transactions from those sources were never applied here. ',
         'Common causes are sql_slave_skip_counter, an empty transaction injected with gtid_next, or a restore from a backup taken mid-stream. ',
         'gtid_purged = ', SUBSTRING(IFNULL(@dbt_v_gtid_purged, '(empty)'), 1, 200),
         '. Set (truncated): ', SUBSTRING(REPLACE(@dbt_v_gtid_executed, '\n', ''), 1, 300)) AS details,
  JSON_OBJECT(
    'interval_count', g.colons,
    'uuid_count', g.uuids,
    'gap_count', g.colons - g.uuids,
    'gtid_executed', SUBSTRING(REPLACE(@dbt_v_gtid_executed, '\n', ''), 1, 1000),
    'gtid_purged', SUBSTRING(IFNULL(@dbt_v_gtid_purged, ''), 1, 500)) AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT
    LENGTH(x.g) - LENGTH(REPLACE(x.g, ':', ''))     AS colons,
    LENGTH(x.g) - LENGTH(REPLACE(x.g, ',', '')) + 1 AS uuids
  FROM (SELECT REPLACE(IFNULL(@dbt_v_gtid_executed, ''), '\n', '') AS g) AS x
) AS g
WHERE IFNULL(@dbt_v_gtid_executed, '') <> ''
  AND g.colons > g.uuids;
