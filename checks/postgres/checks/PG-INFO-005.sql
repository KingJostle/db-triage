-- check: PG-INFO-005
-- title: Connection summary
-- priority: 250
-- scope: cluster
-- cost: 0
-- min_version: 10
-- thresholds: top_n
SELECT 'PG-INFO-005'::text AS check_id,
       'cluster'::text     AS scope,
       NULL::text          AS object,
       format('%s client backends of a maximum of %s, plus %s background processes. By state: %s. By database: %s. Top %s application names: %s. %s distinct client addresses. Oldest connection opened %s ago.',
              c.clients, current_setting('max_connections'), c.background,
              coalesce(c.by_state, 'none'), coalesce(c.by_db, 'none'),
              :'pg_info_005_top_n'::text, coalesce(c.by_app, 'none'),
              c.distinct_addrs,
              coalesce(justify_interval(date_trunc('second', c.oldest))::text, 'n/a')) AS details,
       json_build_object('client_backends', c.clients, 'background_processes', c.background,
                         'max_connections', current_setting('max_connections')::int,
                         'by_state', c.by_state, 'by_database', c.by_db,
                         'top_applications', c.by_app,
                         'distinct_client_addrs', c.distinct_addrs,
                         'oldest_connection_seconds', round(extract(epoch FROM c.oldest))::bigint,
                         'sampled_at', now())::text AS evidence_json,
       'high'::text AS confidence
FROM (
  SELECT count(*) FILTER (WHERE backend_type = 'client backend')  AS clients,
         count(*) FILTER (WHERE backend_type <> 'client backend') AS background,
         count(DISTINCT client_addr)                              AS distinct_addrs,
         max(now() - backend_start)                               AS oldest,
         (SELECT string_agg(format('%s=%s', coalesce(state, 'unknown'), n), ', ' ORDER BY n DESC)
          FROM (SELECT state, count(*) n FROM pg_stat_activity
                WHERE backend_type = 'client backend' GROUP BY state) x)     AS by_state,
         (SELECT string_agg(format('%s=%s', coalesce(datname, '-'), n), ', ' ORDER BY n DESC)
          FROM (SELECT datname, count(*) n FROM pg_stat_activity
                WHERE backend_type = 'client backend' GROUP BY datname) y)   AS by_db,
         (SELECT string_agg(format('%s=%s', app, n), ', ' ORDER BY n DESC)
          FROM (SELECT coalesce(nullif(application_name, ''), '(none)') AS app, count(*) n
                FROM pg_stat_activity WHERE backend_type = 'client backend'
                GROUP BY 1 ORDER BY count(*) DESC LIMIT 10) z)               AS by_app
  FROM pg_stat_activity
) c;
