-- db-triage: catalog-only table bloat estimator (heap).
--
-- PROVENANCE. Re-derived from PostgreSQL's documented on-disk layout
-- (https://www.postgresql.org/docs/current/storage-page-layout.html): a page is
-- PageHeaderData (24 bytes) plus one ItemIdData line pointer (4 bytes) per
-- tuple, and each tuple is HeapTupleHeaderData (23 bytes) plus an optional null
-- bitmap, MAXALIGNed (8 bytes), followed by MAXALIGNed user data. No third-party
-- estimator source was copied.
--
-- WHAT IT MEASURES. Expected page count if every live row were packed at the
-- relation's fillfactor, against the actual relpages. The difference is
-- "estimated bloat": space held by dead tuples not yet reclaimed, plus free
-- space inside pages.
--
-- WHERE IT IS WRONG, AND BY HOW MUCH.
--   * TOAST. Out-of-line values are not counted; a TOAST-heavy table looks
--     smaller than it is and its bloat is understated. TOAST relations are
--     estimated separately, not attributed to the parent.
--   * Stale pg_stats. avg_width and null_frac come from the last ANALYZE. A
--     table that PG-VAC-004 flags as never analyzed produces is_na = true here.
--   * reltuples. -1 (PostgreSQL 14+) means never vacuumed or analyzed; 0 on a
--     large relation means the same thing on older versions. Both are is_na.
--   * Alignment. Per-column alignment padding between columns is not modelled,
--     only the header and the total-width MAXALIGN. Wide tables with many
--     small, differently aligned columns are underestimated by a few percent.
--   * Freshly vacuumed relations legitimately keep free space for reuse. A
--     30% figure on a busy table is normal, not damage.
--
-- Because of all of that, findings built on this carry confidence: medium and
-- the word "estimated", and the reference doc tells the reader to confirm with
-- pgstattuple_approx() before scheduling any rewrite.

WITH const AS (
  SELECT current_setting('block_size')::numeric AS bs,
         23::numeric AS tuple_hdr, 8::numeric AS ma,
         24::numeric AS page_hdr,  4::numeric AS item_id
),
colstats AS (
  SELECT s.schemaname, s.tablename,
         sum((1 - s.null_frac)::numeric * s.avg_width)    AS datawidth,
         count(*) FILTER (WHERE s.null_frac > 0) AS nullable_cols,
         count(*)                                AS ncols
  FROM pg_stats s
  WHERE s.schemaname NOT IN ('pg_catalog', 'information_schema')
  GROUP BY 1, 2
),
tbl AS (
  SELECT c.oid, n.nspname, c.relname, c.reltuples::numeric AS reltuples,
         c.relpages::numeric AS relpages, pg_relation_size(c.oid) AS rel_bytes,
         coalesce(substring(array_to_string(c.reloptions, ' ') FROM 'fillfactor=([0-9]+)')::numeric, 100) AS fillfactor
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relkind IN ('r', 'm')
    AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
),
est AS (
  SELECT t.oid, t.nspname, t.relname, t.reltuples, t.relpages, t.rel_bytes, t.fillfactor,
         const.bs,
         ceil((const.tuple_hdr + CASE WHEN k.nullable_cols > 0 THEN ceil(k.ncols / 8.0) ELSE 0 END) / const.ma) * const.ma
           + ceil(coalesce(k.datawidth, 0) / const.ma) * const.ma AS tuple_bytes,
         greatest(1, floor(((const.bs - const.page_hdr) * t.fillfactor / 100.0)
                  / (ceil((const.tuple_hdr + CASE WHEN k.nullable_cols > 0 THEN ceil(k.ncols / 8.0) ELSE 0 END) / const.ma) * const.ma
                     + ceil(coalesce(k.datawidth, 0) / const.ma) * const.ma + const.item_id))) AS rows_per_page,
         (k.datawidth IS NULL OR t.reltuples < 0 OR t.relpages <= 0) AS is_na
  FROM tbl t
  LEFT JOIN colstats k ON k.schemaname = t.nspname AND k.tablename = t.relname
  CROSS JOIN const
)
SELECT nspname, relname, is_na, reltuples::bigint AS reltuples, relpages::bigint AS relpages,
       rel_bytes, fillfactor, tuple_bytes, rows_per_page,
       ceil(reltuples / rows_per_page)                                       AS expected_pages,
       greatest(relpages - ceil(reltuples / rows_per_page), 0)               AS bloat_pages,
       (greatest(relpages - ceil(reltuples / rows_per_page), 0) * bs)::bigint AS bloat_bytes,
       round(100.0 * greatest(relpages - ceil(reltuples / rows_per_page), 0) / nullif(relpages, 0), 1) AS bloat_pct
FROM est
WHERE NOT is_na
ORDER BY greatest(relpages - ceil(reltuples / rows_per_page), 0) * bs DESC;
