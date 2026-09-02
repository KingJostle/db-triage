-- db-triage: catalog-only B-tree index bloat estimator.
--
-- PROVENANCE. Re-derived from PostgreSQL's documented B-tree page layout
-- (https://www.postgresql.org/docs/current/btree-implementation.html and
-- storage-page-layout.html): a leaf page is PageHeaderData (24 bytes) plus a
-- 16-byte BTPageOpaqueData special area, holding one ItemIdData (4 bytes) plus
-- one index tuple per entry. An index tuple is IndexTupleData (8 bytes) plus an
-- optional null bitmap, MAXALIGNed (8 bytes), followed by the MAXALIGNed key.
-- Internal pages are not modelled; on a B-tree of ordinary depth they are well
-- under 1% of the index, which is inside this estimator's error bar anyway.
-- No third-party estimator source was copied.
--
-- WHERE IT IS WRONG.
--   * Only simple column B-trees are estimated. Expression indexes have no
--     pg_stats row to take a width from, and are reported is_na.
--   * Partial indexes are is_na: reltuples counts only the matching rows, but
--     the parent's pg_stats describe all of them.
--   * Deduplication (PostgreSQL 13+) packs equal keys into posting lists, so a
--     low-cardinality index is reported as far more bloated than it is. Treat
--     any hit on a low-cardinality index (see PG-IDX-015) as suspect.
--   * The B-tree default fillfactor is 90, and a freshly built index sits at
--     that fill by design: roughly 10% "bloat" is the intended state.
--
-- Findings built on this carry confidence: medium and the word "estimated".

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
)
SELECT nspname, table_name, index_name, is_na, reltuples::bigint AS reltuples,
       relpages::bigint AS relpages, index_bytes, fillfactor, entry_bytes, entries_per_page,
       ceil(reltuples / entries_per_page)                                          AS expected_pages,
       greatest(relpages - ceil(reltuples / entries_per_page), 0)                  AS bloat_pages,
       (greatest(relpages - ceil(reltuples / entries_per_page), 0) * bs)::bigint   AS bloat_bytes,
       round(100.0 * greatest(relpages - ceil(reltuples / entries_per_page), 0) / nullif(relpages, 0), 1) AS bloat_pct
FROM est
WHERE NOT is_na
ORDER BY greatest(relpages - ceil(reltuples / entries_per_page), 0) * bs DESC;
