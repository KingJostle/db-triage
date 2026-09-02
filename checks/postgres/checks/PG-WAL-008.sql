-- check: PG-WAL-008
-- title: WAL compression off with a high full-page-image ratio
-- priority: 150
-- scope: setting
-- cost: 0
-- min_version: 14
-- run_on: primary
-- thresholds: fpi_ratio
SELECT 'PG-WAL-008'::text        AS check_id,
       'setting'::text           AS scope,
       'wal_compression'::text   AS object,
       format('%s of the %s WAL records written since %s carried a full-page image (%s%%, threshold %s%%) while wal_compression = off. A full-page image is written on the first change to a page after each checkpoint, so a high ratio means either frequent checkpoints (PG-WAL-001) or scattered writes across a large working set. Total WAL since reset: %s. PostgreSQL 15 and newer offer lz4 and zstd, which cut WAL volume on this pattern for a small amount of CPU.',
              to_char(w.wal_fpi, 'FM999,999,999,999'),
              to_char(w.wal_records, 'FM999,999,999,999'),
              coalesce(w.stats_reset::text, 'the last statistics reset'),
              round(100.0 * w.wal_fpi / nullif(w.wal_records, 0), 1)::text,
              round(100 * :'pg_wal_008_fpi_ratio'::numeric)::text,
              pg_size_pretty(w.wal_bytes::bigint)) AS details,
       json_build_object('wal_fpi', w.wal_fpi, 'wal_records', w.wal_records,
                         'fpi_ratio', round(w.wal_fpi::numeric / nullif(w.wal_records, 0), 4),
                         'threshold_ratio', :'pg_wal_008_fpi_ratio'::numeric,
                         'wal_bytes', w.wal_bytes::bigint, 'stats_reset', w.stats_reset,
                         'wal_compression', current_setting('wal_compression'),
                         'full_page_writes', current_setting('full_page_writes'))::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_stat_wal w
WHERE NOT pg_is_in_recovery()
  AND current_setting('wal_compression') = 'off'
  AND w.wal_records > 0
  AND w.wal_fpi::numeric / nullif(w.wal_records, 0) >= :'pg_wal_008_fpi_ratio'::numeric;
