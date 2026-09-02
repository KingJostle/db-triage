-- check: MY-QRY-013
-- title: Sort merge passes high
-- priority: 150 | category: QRY | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: merge_passes_per_second=10
-- reads: @dbt_s_sort_merge_passes, @@GLOBAL.sort_buffer_size
-- A merge pass happens when a sort does not fit in sort_buffer_size and has to
-- be written out and merged from disk. The counter is server-wide and available
-- on both forks without performance_schema.
-- The trap this finding exists to prevent: the obvious response is to raise
-- sort_buffer_size globally, and that is usually wrong twice over. It is
-- allocated per session per sort, so it multiplies by concurrency (MY-MEM-006
-- and MY-MEM-007 quantify that); and MySQL allocates and touches the whole
-- buffer regardless of how much of it the sort needs, so a large global value
-- makes every small sort slower.
-- The right responses, in order: an index that provides the sort order so no
-- sort happens; a smaller result set; and only then a per-session
-- SET sort_buffer_size for the one statement that needs it.
SELECT
  'MY-QRY-013' AS check_id,
  'cluster'    AS scope,
  'sort_buffer_size' AS object,
  CONCAT('Sort_merge_passes = ', FORMAT(s.passes, 0), ' since restart, ',
         ROUND(s.per_sec, 1), '/s over ', ROUND(@dbt_uptime_s / 86400, 1),
         ' days (threshold ', COALESCE(@merge_passes_per_second, 10),
         '/s). Sorts are exceeding sort_buffer_size = ',
         ROUND(@@GLOBAL.sort_buffer_size / 1024, 0),
         ' KB and being written to disk and merged back. ',
         'Do NOT simply raise sort_buffer_size globally: it is allocated per session per sort, so at max_connections = ',
         @@GLOBAL.max_connections, ' the commitment is ',
         ROUND(@@GLOBAL.sort_buffer_size * @@GLOBAL.max_connections / 1073741824, 1),
         ' GB (MY-MEM-006/007), and MySQL touches the whole buffer even for a tiny sort, so a large value makes every small sort slower. ',
         'In order: add an index that supplies the ORDER BY so no sort happens; return fewer rows; only then set it per session for the one statement. MY-QRY-004 and MY-QRY-005 name the candidates.') AS details,
  JSON_OBJECT(
    'sort_merge_passes', s.passes,
    'per_second', ROUND(s.per_sec, 3),
    'threshold_per_second', COALESCE(@merge_passes_per_second, 10),
    'sort_buffer_size', @@GLOBAL.sort_buffer_size,
    'max_connections', @@GLOBAL.max_connections,
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_sort_merge_passes, 0) AS DECIMAL(30, 0)) AS passes,
         CAST(IFNULL(@dbt_s_sort_merge_passes, 0) AS DECIMAL(30, 0)) / GREATEST(@dbt_uptime_s, 1) AS per_sec
) AS s
WHERE s.per_sec >= COALESCE(@merge_passes_per_second, 10);
