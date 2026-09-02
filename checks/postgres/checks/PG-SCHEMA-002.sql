-- check: PG-SCHEMA-002
-- title: Sequence or integer key at 70 percent or more of its range
-- priority: 50
-- scope: relation
-- cost: 1
-- min_version: 10
-- thresholds: exhaustion_fraction, exhaustion_fraction_high
WITH owned AS (
  SELECT s.schemaname, s.sequencename, s.last_value, s.max_value, s.min_value,
         s.increment_by, s.cycle,
         a.attname AS owner_column, tn.nspname AS owner_schema, tc.relname AS owner_table,
         t.typname AS owner_type,
         CASE t.typname WHEN 'int2' THEN 32767::bigint
                        WHEN 'int4' THEN 2147483647::bigint
                        WHEN 'int8' THEN 9223372036854775807::bigint
                        ELSE NULL END AS type_max
  FROM pg_sequences s
  JOIN pg_class sc      ON sc.relname = s.sequencename
  JOIN pg_namespace sn  ON sn.oid = sc.relnamespace AND sn.nspname = s.schemaname
  LEFT JOIN pg_depend d ON d.objid = sc.oid AND d.classid = 'pg_class'::regclass
                        AND d.refclassid = 'pg_class'::regclass AND d.deptype IN ('a', 'i')
  LEFT JOIN pg_class tc     ON tc.oid = d.refobjid
  LEFT JOIN pg_namespace tn ON tn.oid = tc.relnamespace
  LEFT JOIN pg_attribute a  ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
  LEFT JOIN pg_type t       ON t.oid = a.atttypid
  WHERE sc.relkind = 'S'
),
scored AS (
  SELECT o.*, least(o.max_value, coalesce(o.type_max, o.max_value)) AS effective_max,
         o.last_value::numeric / nullif(least(o.max_value, coalesce(o.type_max, o.max_value)), 0)::numeric AS used_fraction
  FROM owned o WHERE o.last_value IS NOT NULL AND o.increment_by > 0 AND NOT o.cycle
)
SELECT 'PG-SCHEMA-002'::text AS check_id,
       'relation'::text AS scope,
       format('%I.%I.%I', current_database(), s.schemaname, s.sequencename)::text AS object,
       format('Sequence %s.%s is at %s of an effective maximum of %s (%s%%, threshold %s%%). %s When it runs out, every INSERT that calls nextval fails: "nextval: reached maximum value of sequence" or, if the column type is the binding limit, "integer out of range". Widening the column to bigint rewrites the whole table and every index on it, which is why this is worth seeing at 70%% rather than at 99%%.',
              s.schemaname, s.sequencename,
              to_char(s.last_value, 'FM999,999,999,999,999,999'),
              to_char(s.effective_max, 'FM999,999,999,999,999,999'),
              round(100 * s.used_fraction, 1)::text,
              round(100 * :'pg_schema_002_exhaustion_fraction'::numeric)::text,
              CASE WHEN s.owner_table IS NULL
                   THEN 'It is not owned by any column, so the limit is the sequence''s own max_value.'
                   ELSE format('It backs %s.%s.%s of type %s, whose maximum (%s) %s the sequence''s own max_value (%s).',
                               s.owner_schema, s.owner_table, s.owner_column, s.owner_type,
                               to_char(s.type_max, 'FM999,999,999,999,999,999'),
                               CASE WHEN s.type_max < s.max_value THEN 'is lower than' ELSE 'is not lower than' END,
                               to_char(s.max_value, 'FM999,999,999,999,999,999')) END) AS details,
       json_build_object('schema', s.schemaname, 'sequence', s.sequencename,
                         'last_value', s.last_value, 'max_value', s.max_value,
                         'effective_max', s.effective_max,
                         'used_fraction', round(s.used_fraction, 5),
                         'threshold_fraction', :'pg_schema_002_exhaustion_fraction'::numeric,
                         'increment_by', s.increment_by,
                         'owner_schema', s.owner_schema, 'owner_table', s.owner_table,
                         'owner_column', s.owner_column, 'owner_type', s.owner_type)::text AS evidence_json,
       'high'::text AS confidence
FROM scored s
WHERE s.used_fraction >= :'pg_schema_002_exhaustion_fraction'::numeric
  AND s.used_fraction < :'pg_schema_002_exhaustion_fraction_high'::numeric
ORDER BY s.used_fraction DESC;
