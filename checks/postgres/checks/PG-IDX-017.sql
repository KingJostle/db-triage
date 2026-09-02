-- check: PG-IDX-017
-- title: Index build in progress
-- priority: 200
-- scope: index
-- cost: 0
-- min_version: 12
SELECT 'PG-IDX-017'::text AS check_id,
       'index'::text      AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('%s is building an index on %s.%s (pid %s), running for %s. Phase "%s", %s of %s blocks done%s, lockers %s of %s. While this runs it holds a lock on the table, it generates WAL, and a CONCURRENTLY build additionally waits for every transaction older than itself to finish - which is why one long transaction (PG-LOCK-005) can stall it indefinitely. Statement: %s',
              coalesce(nullif(a.application_name, ''), 'A session'),
              n.nspname, c.relname, p.pid,
              justify_interval(date_trunc('second', now() - a.query_start)),
              p.phase,
              to_char(p.blocks_done, 'FM999,999,999,999'), to_char(p.blocks_total, 'FM999,999,999,999'),
              CASE WHEN p.blocks_total > 0
                   THEN ' (' || round(100.0 * p.blocks_done / p.blocks_total, 1)::text || '%)' ELSE '' END,
              p.lockers_done, p.lockers_total,
              left(regexp_replace(coalesce(a.query, ''), '\s+', ' ', 'g'), 200)) AS details,
       json_build_object('pid', p.pid, 'phase', p.phase, 'schema', n.nspname, 'table', c.relname,
                         'blocks_done', p.blocks_done, 'blocks_total', p.blocks_total,
                         'tuples_done', p.tuples_done, 'tuples_total', p.tuples_total,
                         'lockers_done', p.lockers_done, 'lockers_total', p.lockers_total,
                         'current_locker_pid', p.current_locker_pid,
                         'running_seconds', round(extract(epoch FROM now() - a.query_start))::bigint)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_progress_create_index p
JOIN pg_class c     ON c.oid = p.relid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_stat_activity a ON a.pid = p.pid;
