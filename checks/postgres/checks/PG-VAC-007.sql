-- check: PG-VAC-007
-- title: Estimated table bloat over 30 percent (200 MB or more wasted)
-- priority: 100
-- scope: relation
-- cost: 1
-- thresholds: bloat_pct, wasted_bytes, bloat_pct_high, wasted_bytes_high, top_n
-- estimator: lib/bloat_table.sql (re-derived from documented page layout; no third-party code)
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
),
scored AS (
  SELECT nspname, relname, reltuples, relpages, rel_bytes, fillfactor, tuple_bytes, rows_per_page,
         ceil(reltuples / rows_per_page)                            AS expected_pages,
         greatest(relpages - ceil(reltuples / rows_per_page), 0)    AS bloat_pages,
         (greatest(relpages - ceil(reltuples / rows_per_page), 0) * bs)::bigint AS bloat_bytes,
         round(100.0 * greatest(relpages - ceil(reltuples / rows_per_page), 0) / nullif(relpages, 0), 1) AS bloat_pct
  FROM est WHERE NOT is_na
)
SELECT 'PG-VAC-007'::text AS check_id,
       'relation'::text  AS scope,
       format('%I.%I.%I', current_database(), s.nspname, s.relname)::text AS object,
       format('Estimated %s%% bloat (threshold %s%%): %s of %s is space not occupied by live rows, against %s estimated live rows at %s bytes each and fillfactor %s. Estimated from pg_stats and pg_class only; confirm with pgstattuple_approx() before scheduling a rewrite.',
              s.bloat_pct::text, :'pg_vac_007_bloat_pct'::text,
              pg_size_pretty(s.bloat_bytes), pg_size_pretty(s.rel_bytes),
              to_char(s.reltuples::bigint, 'FM999,999,999,999'), s.tuple_bytes::text, s.fillfactor::text) AS details,
       json_build_object('bloat_pct', s.bloat_pct, 'bloat_bytes', s.bloat_bytes,
                         'relation_bytes', s.rel_bytes, 'relpages', s.relpages::bigint,
                         'expected_pages', s.expected_pages::bigint, 'reltuples', s.reltuples::bigint,
                         'estimated_tuple_bytes', s.tuple_bytes, 'fillfactor', s.fillfactor,
                         'threshold_pct', :'pg_vac_007_bloat_pct'::numeric,
                         'threshold_wasted_bytes', :'pg_vac_007_wasted_bytes'::bigint,
                         'estimator', 'lib/bloat_table.sql')::text AS evidence_json,
       'medium'::text AS confidence
FROM scored s
WHERE s.bloat_pct   >= :'pg_vac_007_bloat_pct'::numeric
  AND s.bloat_bytes >= :'pg_vac_007_wasted_bytes'::bigint
  AND NOT (s.bloat_pct >= :'pg_vac_007_bloat_pct_high'::numeric
           AND s.bloat_bytes >= :'pg_vac_007_wasted_bytes_high'::bigint)
ORDER BY s.bloat_bytes DESC
LIMIT :'pg_vac_007_top_n'::int;
