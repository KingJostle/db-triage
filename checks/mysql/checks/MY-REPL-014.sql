-- check: MY-REPL-014
-- title: binlog_row_image MINIMAL with logical consumers configured
-- priority: 100 | category: REPL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: interview
-- thresholds: (none)
-- reads: @@GLOBAL.binlog_row_image, @dbt_v_binlog_row_metadata
-- Requires the .db-triage.yml baseline to declare CDC consumers (Debezium,
-- Maxwell, Canal, a data-lake sink). Without that declaration the runner does
-- not surface this row, because MINIMAL is a perfectly good setting for a
-- topology whose only consumers are MySQL replicas — it is only wrong when
-- something downstream needs the unchanged columns of an UPDATE.
-- binlog_row_metadata (MySQL 8.0+; NULL on MariaDB) decides whether column names
-- and types travel with the events, which most CDC tools need to avoid
-- reconstructing the schema from a side channel.
SELECT
  'MY-REPL-014' AS check_id,
  'setting'     AS scope,
  'binlog_row_image' AS object,
  CONCAT('binlog_row_image = ', @@GLOBAL.binlog_row_image,
         ': row events carry only the primary key and the changed columns. ',
         'A logical consumer (CDC, a data lake sink, an audit stream) receives UPDATE events without the unchanged columns and without before-images, so it cannot reconstruct a full row. ',
         'binlog_row_metadata = ', IFNULL(@dbt_v_binlog_row_metadata,
            'not available on this fork; MariaDB always ships minimal metadata'),
         '.') AS details,
  JSON_OBJECT(
    'binlog_row_image', @@GLOBAL.binlog_row_image,
    'binlog_row_metadata', IFNULL(@dbt_v_binlog_row_metadata, 'n/a'),
    'binlog_format', @@GLOBAL.binlog_format) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE @@GLOBAL.log_bin = 1
  AND UPPER(@@GLOBAL.binlog_row_image) = 'MINIMAL';
