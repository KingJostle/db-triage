-- check: MY-MEM-006
-- title: Oversized per-session buffers
-- priority: 100 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: session_buffer_bytes=8388608
-- reads: @@GLOBAL.sort_buffer_size, join_buffer_size, read_buffer_size, read_rnd_buffer_size
-- All four are universal and all four are allocated PER SESSION, and for
-- sort_buffer_size and join_buffer_size potentially more than once per query.
-- At 8 MB and 500 connections that is 4 GB of commitment that does not appear
-- in the buffer pool figure. Worse, a large sort_buffer_size is actively slower:
-- MySQL allocates and touches the whole buffer for sorts that need a fraction of
-- it, so raising it globally to fix one query penalises every other query.
-- The right fix is nearly always to set it per session for the one statement
-- that needs it, which is why this is P100 and not a tuning suggestion.
SELECT
  'MY-MEM-006' AS check_id,
  'setting'    AS scope,
  b.name       AS object,
  CONCAT(b.name, ' = ', ROUND(b.val / 1048576, 1), ' MB globally (threshold ',
         ROUND(COALESCE(@session_buffer_bytes, 8388608) / 1048576, 0),
         ' MB). This is allocated per session', 
         IF(b.name IN ('sort_buffer_size', 'join_buffer_size'),
            ' and can be allocated more than once per query', ''),
         ', so at max_connections = ', @@GLOBAL.max_connections,
         ' the worst case is ', ROUND(b.val * @@GLOBAL.max_connections / 1073741824, 1),
         ' GB for this buffer alone',
         IF(b.name = 'sort_buffer_size',
            '. A large sort_buffer_size also slows small sorts, because the whole buffer is allocated and touched regardless of how much of it the sort needs.',
            '.'),
         ' Set it per session for the statement that needs it instead.') AS details,
  JSON_OBJECT(
    'variable', b.name,
    'value_bytes', b.val,
    'threshold_bytes', COALESCE(@session_buffer_bytes, 8388608),
    'max_connections', @@GLOBAL.max_connections,
    'worst_case_bytes', b.val * @@GLOBAL.max_connections) AS evidence_json,
  'high' AS confidence
FROM (
            SELECT 'sort_buffer_size'     AS name, @@GLOBAL.sort_buffer_size     AS val
  UNION ALL SELECT 'join_buffer_size',          @@GLOBAL.join_buffer_size
  UNION ALL SELECT 'read_buffer_size',          @@GLOBAL.read_buffer_size
  UNION ALL SELECT 'read_rnd_buffer_size',      @@GLOBAL.read_rnd_buffer_size
) AS b
WHERE b.val >= COALESCE(@session_buffer_bytes, 8388608);
