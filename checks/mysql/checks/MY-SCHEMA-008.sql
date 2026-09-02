-- check: MY-SCHEMA-008
-- title: Leftover online-schema-change artefacts
-- priority: 100 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.TABLES, information_schema.TRIGGERS
-- pt-online-schema-change and gh-ost both work by building a shadow copy of the
-- table and swapping it in. If the tool is killed — a lost SSH session is the
-- usual cause — the shadow table and, for pt-osc, THREE TRIGGERS on the original
-- table are left behind.
-- The triggers are the expensive part and the reason this is not just clutter:
-- every INSERT, UPDATE and DELETE on the production table continues to be
-- mirrored into an abandoned copy forever, roughly doubling write cost and
-- silently growing the shadow table until the disk notices.
-- Naming conventions matched: pt-osc uses _<table>_new and _<table>_old plus
-- pt_osc_%_{ins,upd,del} triggers; gh-ost uses _<table>_gho, _<table>_ghc and
-- _<table>_del. MySQL's own failed ALTER leaves #sql-* tables, also matched.
SELECT
  'MY-SCHEMA-008' AS check_id,
  'relation'      AS scope,
  CONCAT(x.sch, '.', x.nm) AS object,
  CONCAT('`', x.sch, '`.`', x.nm, '` is a ', x.kind,
         ' left behind by an interrupted online schema change (', x.tool, '), size ',
         ROUND(x.bytes / 1048576, 1), ' MB, created ', IFNULL(CAST(x.created AS CHAR), 'unknown'), '. ',
         IF(x.trigger_count > 0,
            CONCAT('There are also ', x.trigger_count,
                   ' pt-osc trigger(s) still attached to the original table: ', x.trigger_names,
                   '. Every write to the production table is still being mirrored into this abandoned copy, roughly doubling write cost and growing it without bound.'),
            'No matching triggers remain, so this is dead weight rather than an active cost — but confirm before dropping it that no schema change is in flight.')) AS details,
  JSON_OBJECT(
    'schema', x.sch,
    'table', x.nm,
    'kind', x.kind,
    'tool', x.tool,
    'bytes', x.bytes,
    'created', CAST(x.created AS CHAR),
    'orphan_triggers', x.trigger_count,
    'trigger_names', x.trigger_names) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    t.TABLE_SCHEMA AS sch, t.TABLE_NAME AS nm,
    t.DATA_LENGTH + t.INDEX_LENGTH AS bytes,
    t.CREATE_TIME AS created,
    CASE
      WHEN t.TABLE_NAME LIKE '#sql-%' OR t.TABLE_NAME LIKE '#sql_%' THEN 'temporary ALTER table'
      WHEN t.TABLE_NAME LIKE '\_%\_old' THEN 'pre-swap original'
      ELSE 'shadow copy'
    END AS kind,
    CASE
      WHEN t.TABLE_NAME LIKE '\_%\_gho' OR t.TABLE_NAME LIKE '\_%\_ghc'
        OR t.TABLE_NAME LIKE '\_%\_del' THEN 'gh-ost'
      WHEN t.TABLE_NAME LIKE '#sql%'    THEN 'MySQL ALTER TABLE'
      ELSE 'pt-online-schema-change'
    END AS tool,
    (SELECT COUNT(*) FROM information_schema.TRIGGERS AS g
      WHERE g.TRIGGER_SCHEMA = t.TABLE_SCHEMA AND g.TRIGGER_NAME LIKE 'pt\_osc\_%') AS trigger_count,
    (SELECT SUBSTRING(GROUP_CONCAT(g.TRIGGER_NAME SEPARATOR ', '), 1, 250)
       FROM information_schema.TRIGGERS AS g
      WHERE g.TRIGGER_SCHEMA = t.TABLE_SCHEMA AND g.TRIGGER_NAME LIKE 'pt\_osc\_%') AS trigger_names
  FROM information_schema.TABLES AS t
  WHERE t.TABLE_TYPE = 'BASE TABLE'
    AND t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
    AND (t.TABLE_NAME LIKE '\_%\_new' OR t.TABLE_NAME LIKE '\_%\_old'
      OR t.TABLE_NAME LIKE '\_%\_gho' OR t.TABLE_NAME LIKE '\_%\_ghc'
      OR t.TABLE_NAME LIKE '\_%\_del' OR t.TABLE_NAME LIKE '#sql%')
) AS x;
