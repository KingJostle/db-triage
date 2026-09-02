-- check: PG-IDX-007
-- title: Estimated B-tree bloat over 30 percent (100 MB or more wasted)
-- priority: 150
-- scope: index
-- cost: 1
-- thresholds: bloat_pct, wasted_bytes, bloat_pct_high, wasted_bytes_high, top_n
-- estimator: lib/bloat_btree.sql (re-derived from documented page layout; no third-party code)
WITH const AS (
  SELECT current_setting('block_size')::numeric AS bs,
         8::numeric AS index_tuple_hdr, 8::numeric AS ma,
         24::numeric AS page_hdr, 16::numeric AS btree_special, 4::numeric AS item_id
),
idx AS (
  SELECT i.indexrelid, i.indrelid, ic.relname AS index_name, tn.nspname, tc.relname AS table_name,
         ic.reltuples::numeric AS reltuples, ic.relpages::numeric AS relpages,
         pg_relation_size(i.indexrelid) AS index_bytes,
         i.indnatts, i.indnkeyatts, i.indkey,
         (i.indexprs IS NOT NULL OR i.indpred IS NOT NULL) AS is_special,
         coalesce(substring(array_to_string(ic.reloptions, ' ') FROM 'fillfactor=([0-9]+)')::numeric, 90) AS fillfactor
  FROM pg_index i
  JOIN pg_class ic ON ic.oid = i.indexrelid
  JOIN pg_class tc ON tc.oid = i.indrelid
  JOIN pg_namespace tn ON tn.oid = tc.relnamespace
  JOIN pg_am am ON am.oid = ic.relam AND am.amname = 'btree'
  WHERE tn.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    AND i.indisvalid
),
keywidth AS (
  SELECT x.indexrelid,
         sum((1 - s.null_frac)::numeric * s.avg_width)    AS keywidth,
         count(*) FILTER (WHERE s.null_frac > 0) AS nullable_cols,
         count(*)                                AS ncols
  FROM (SELECT idx.indexrelid, idx.nspname, idx.table_name, a.attname
        FROM idx
        JOIN LATERAL unnest(idx.indkey[0:idx.indnkeyatts - 1]) WITH ORDINALITY AS k(attnum, ord) ON true
        JOIN pg_attribute a ON a.attrelid = idx.indrelid AND a.attnum = k.attnum
        WHERE NOT idx.is_special) x
  JOIN pg_stats s ON s.schemaname = x.nspname AND s.tablename = x.table_name AND s.attname = x.attname
  GROUP BY 1
),
est AS (
  SELECT idx.*, const.bs,
         ceil((const.index_tuple_hdr + CASE WHEN kw.nullable_cols > 0 THEN ceil(kw.ncols / 8.0) ELSE 0 END) / const.ma) * const.ma
           + ceil(coalesce(kw.keywidth, 0) / const.ma) * const.ma AS entry_bytes,
         greatest(1, floor(((const.bs - const.page_hdr - const.btree_special) * idx.fillfactor / 100.0)
                  / (ceil((const.index_tuple_hdr + CASE WHEN kw.nullable_cols > 0 THEN ceil(kw.ncols / 8.0) ELSE 0 END) / const.ma) * const.ma
                     + ceil(coalesce(kw.keywidth, 0) / const.ma) * const.ma + const.item_id))) AS entries_per_page,
         (idx.is_special OR kw.keywidth IS NULL OR idx.reltuples < 0 OR idx.relpages <= 1) AS is_na
  FROM idx LEFT JOIN keywidth kw ON kw.indexrelid = idx.indexrelid CROSS JOIN const
),
scored AS (
  SELECT nspname, table_name, index_name, reltuples, relpages, index_bytes, fillfactor,
         entry_bytes, entries_per_page,
         greatest(relpages - ceil(reltuples / entries_per_page), 0) AS bloat_pages,
         (greatest(relpages - ceil(reltuples / entries_per_page), 0) * bs)::bigint AS bloat_bytes,
         round(100.0 * greatest(relpages - ceil(reltuples / entries_per_page), 0) / nullif(relpages, 0), 1) AS bloat_pct
  FROM est WHERE NOT is_na
)
SELECT 'PG-IDX-007'::text AS check_id,
       'index'::text     AS scope,
       format('%I.%I.%I', current_database(), s.nspname, s.index_name)::text AS object,
       format('Estimated %s%% bloat (threshold %s%%) on index %s of table %s: %s of %s is not occupied by live entries, against %s estimated entries at %s bytes each and fillfactor %s. Estimated from pg_stats and pg_class only. REINDEX INDEX CONCURRENTLY rebuilds it without blocking writes on PostgreSQL 12 and newer.',
              s.bloat_pct::text, :'pg_idx_007_bloat_pct'::text, s.index_name, s.table_name,
              pg_size_pretty(s.bloat_bytes), pg_size_pretty(s.index_bytes),
              to_char(s.reltuples::bigint, 'FM999,999,999,999'), s.entry_bytes::text, s.fillfactor::text) AS details,
       json_build_object('bloat_pct', s.bloat_pct, 'bloat_bytes', s.bloat_bytes,
                         'index_bytes', s.index_bytes, 'relpages', s.relpages::bigint,
                         'reltuples', s.reltuples::bigint, 'estimated_entry_bytes', s.entry_bytes,
                         'fillfactor', s.fillfactor, 'table', s.table_name,
                         'threshold_pct', :'pg_idx_007_bloat_pct'::numeric,
                         'threshold_wasted_bytes', :'pg_idx_007_wasted_bytes'::bigint,
                         'estimator', 'lib/bloat_btree.sql')::text AS evidence_json,
       'medium'::text AS confidence
FROM scored s
WHERE s.bloat_pct   >= :'pg_idx_007_bloat_pct'::numeric
  AND s.bloat_bytes >= :'pg_idx_007_wasted_bytes'::bigint
  AND NOT (s.bloat_pct >= :'pg_idx_007_bloat_pct_high'::numeric
           AND s.bloat_bytes >= :'pg_idx_007_wasted_bytes_high'::bigint)
ORDER BY s.bloat_bytes DESC
LIMIT :'pg_idx_007_top_n'::int;
