-- check: PG-DUR-002
-- title: full_page_writes disabled
-- priority: 1
-- scope: setting
-- cost: 0
SELECT 'PG-DUR-002'::text          AS check_id,
       'setting'::text             AS scope,
       'full_page_writes'::text    AS object,
       format('full_page_writes = off (set in %s%s). After a checkpoint, the first write to each page is no longer logged in full, so a page torn by a crash mid-write cannot be reconstructed from WAL. This is only safe where the filesystem guarantees atomic %s-byte writes, which ZFS does and ext4, xfs and most cloud block devices do not. Confirm the filesystem before treating this as intentional. fsync = %s, data_checksums = %s, wal_log_hints = %s.',
              s.source, coalesce(', ' || s.sourcefile || ':' || s.sourceline::text, ''),
              current_setting('block_size'),
              current_setting('fsync'), current_setting('data_checksums'),
              current_setting('wal_log_hints')) AS details,
       json_build_object('full_page_writes', s.setting, 'source', s.source,
                         'block_size', current_setting('block_size')::int,
                         'fsync', current_setting('fsync'),
                         'data_checksums', current_setting('data_checksums'),
                         'wal_log_hints', current_setting('wal_log_hints'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'full_page_writes' AND s.setting = 'off';
