-- check: PG-QRY-017
-- title: Wait-event snapshot
-- priority: 240
-- scope: cluster
-- cost: 0
-- min_version: 10
SELECT 'PG-QRY-017'::text AS check_id,
       'cluster'::text    AS scope,
       coalesce(a.wait_event_type, 'CPU')::text AS object,
       format('%s session(s) in wait class %s at snapshot time %s: %s. %s',
              count(*), coalesce(a.wait_event_type, 'none (running on CPU)'),
              to_char(now(), 'YYYY-MM-DD HH24:MI:SS TZ'),
              string_agg(DISTINCT coalesce(a.wait_event, 'running'), ', '),
              CASE coalesce(a.wait_event_type, 'CPU')
                WHEN 'Lock'      THEN 'Waiting for a heavyweight lock held by another transaction: see PG-LOCK-001/002.'
                WHEN 'LWLock'    THEN 'Waiting on an internal shared-memory lock, usually buffer mapping or WAL insertion under high concurrency.'
                WHEN 'IO'        THEN 'Waiting on storage.'
                WHEN 'BufferPin' THEN 'Waiting for exclusive access to a buffer another session is reading.'
                WHEN 'Client'    THEN 'Waiting for the client to send or receive; this is application or network time, not server time.'
                WHEN 'IPC'       THEN 'Waiting for another server process, typically a parallel worker or the WAL writer.'
                WHEN 'Timeout'   THEN 'Sleeping deliberately.'
                WHEN 'Extension' THEN 'Waiting inside an extension.'
                ELSE 'One sample only: a single snapshot can miss a storm and can catch a coincidence. Deep mode samples three times.' END) AS details,
       json_build_object('wait_event_type', a.wait_event_type,
                         'sessions', count(*),
                         'wait_events', string_agg(DISTINCT coalesce(a.wait_event, 'running'), ';'),
                         'databases', string_agg(DISTINCT coalesce(a.datname, '-'), ';'),
                         'sampled_at', now())::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_stat_activity a
WHERE a.state = 'active' AND a.backend_type = 'client backend' AND a.pid <> pg_backend_pid()
GROUP BY a.wait_event_type
ORDER BY count(*) DESC;
