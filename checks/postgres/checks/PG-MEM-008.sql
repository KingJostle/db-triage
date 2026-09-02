-- check: PG-MEM-008
-- title: Huge pages not in effect with a large buffer cache
-- priority: 100
-- scope: setting
-- cost: 0
-- thresholds: shared_buffers_bytes
\set ON_ERROR_STOP off
SELECT (current_setting('server_version_num')::int >= 170000) AS pg_mem_008_has_status \gset
WITH hp AS (
\if :pg_mem_008_has_status
  SELECT current_setting('huge_pages') AS requested, current_setting('huge_pages_status') AS status
\else
  SELECT current_setting('huge_pages') AS requested, 'unknown (huge_pages_status is PostgreSQL 17+)'::text AS status
\endif
)
SELECT 'PG-MEM-008'::text     AS check_id,
       'setting'::text        AS scope,
       'huge_pages'::text     AS object,
       format('shared_buffers = %s (threshold %s) with huge_pages = %s and huge_pages_status = %s. Mapping a buffer cache this size with 4 kB pages costs roughly %s of page tables per backend and puts constant pressure on the TLB; with 2 MB huge pages the same mapping is %s. max_connections = %s. Enabling huge pages needs vm.nr_hugepages set on the host and a server restart, and huge_pages = on (rather than try) makes the server refuse to start if they are unavailable, which is the safer signal.',
              current_setting('shared_buffers'),
              pg_size_pretty(:'pg_mem_008_shared_buffers_bytes'::bigint),
              hp.requested, hp.status,
              pg_size_pretty(((SELECT setting::bigint FROM pg_settings WHERE name = 'shared_buffers') * 8192 / 4096 * 8)::bigint),
              pg_size_pretty(((SELECT setting::bigint FROM pg_settings WHERE name = 'shared_buffers') * 8192 / 2097152 * 8)::bigint),
              (SELECT setting FROM pg_settings WHERE name = 'max_connections')) AS details,
       json_build_object('shared_buffers_bytes', (SELECT setting::bigint * 8192 FROM pg_settings WHERE name = 'shared_buffers'),
                         'threshold_bytes', :'pg_mem_008_shared_buffers_bytes'::bigint,
                         'huge_pages', hp.requested, 'huge_pages_status', hp.status,
                         'max_connections', (SELECT setting::int FROM pg_settings WHERE name = 'max_connections'))::text AS evidence_json,
       'medium'::text AS confidence
FROM hp
WHERE (SELECT setting::bigint * 8192 FROM pg_settings WHERE name = 'shared_buffers') >= :'pg_mem_008_shared_buffers_bytes'::bigint
  AND (hp.requested = 'off' OR hp.status = 'off');
