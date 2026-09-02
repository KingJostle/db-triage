-- check: PG-IDX-005
-- title: Overlapping indexes (leading-column prefix)
-- priority: 100
-- scope: index
-- cost: 1
WITH idx AS (
  SELECT i.indexrelid, i.indrelid, n.nspname, tc.relname AS table_name, ic.relname AS index_name,
         ic.relam, i.indnkeyatts, i.indisunique,
         (string_to_array(i.indkey::text, ' '))[1:i.indnkeyatts]   AS keys,
         (string_to_array(i.indclass::text, ' '))[1:i.indnkeyatts] AS classes,
         (string_to_array(i.indoption::text, ' '))[1:i.indnkeyatts] AS options,
         coalesce(pg_get_expr(i.indpred, i.indrelid), '')          AS pred,
         pg_relation_size(i.indexrelid)                            AS index_bytes,
         s.idx_scan
  FROM pg_index i
  JOIN pg_class ic    ON ic.oid = i.indexrelid
  JOIN pg_class tc    ON tc.oid = i.indrelid
  JOIN pg_namespace n ON n.oid = ic.relnamespace
  LEFT JOIN pg_stat_user_indexes s ON s.indexrelid = i.indexrelid
  WHERE i.indisvalid AND i.indexprs IS NULL
    AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
)
SELECT 'PG-IDX-005'::text AS check_id,
       'index'::text      AS scope,
       format('%I.%I.%I', current_database(), a.nspname, a.index_name)::text AS object,
       format('Index %s on %s.%s is a strict leading-column prefix of %s: %s against %s. Anything the shorter index can answer, the longer one can answer too, so the shorter one is usually redundant write cost (%s, %s scans recorded; the wider index has %s and %s scans). It is P100 rather than P50 because prefixes are sometimes deliberate: a narrower index is cheaper to maintain and fits more entries per page, and INCLUDE columns or a different sort direction can make the wider one unusable for a given query. Check the plans before dropping.',
              a.index_name, a.nspname, a.table_name, b.index_name,
              pg_get_indexdef(a.indexrelid), pg_get_indexdef(b.indexrelid),
              pg_size_pretty(a.index_bytes), coalesce(a.idx_scan::text, 'unknown'),
              pg_size_pretty(b.index_bytes), coalesce(b.idx_scan::text, 'unknown')) AS details,
       json_build_object('schema', a.nspname, 'table', a.table_name,
                         'narrow_index', a.index_name, 'wide_index', b.index_name,
                         'narrow_bytes', a.index_bytes, 'wide_bytes', b.index_bytes,
                         'narrow_idx_scan', a.idx_scan, 'wide_idx_scan', b.idx_scan,
                         'narrow_def', pg_get_indexdef(a.indexrelid),
                         'wide_def', pg_get_indexdef(b.indexrelid))::text AS evidence_json,
       'medium'::text AS confidence
FROM idx a
JOIN idx b
  ON b.indrelid = a.indrelid
 AND b.indexrelid <> a.indexrelid
 AND b.relam = a.relam
 AND b.pred = a.pred
 AND b.indnkeyatts > a.indnkeyatts
 AND b.keys[1:a.indnkeyatts]    = a.keys
 AND b.classes[1:a.indnkeyatts] = a.classes
 AND b.options[1:a.indnkeyatts] = a.options
WHERE NOT a.indisunique
ORDER BY a.index_bytes DESC;
