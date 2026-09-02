-- check: PG-VAC-002
-- title: Autovacuum workers saturated
-- priority: 50
-- scope: cluster
-- cost: 1
-- min_version: 10
-- thresholds: overdue_tables
WITH workers AS (
  SELECT count(*) AS running FROM pg_stat_activity WHERE backend_type = 'autovacuum worker'
),
overdue AS (
  SELECT count(*) AS n
  FROM pg_stat_user_tables t
  JOIN pg_class c ON c.oid = t.relid
  WHERE t.n_dead_tup > current_setting('autovacuum_vacuum_threshold')::numeric
                     + current_setting('autovacuum_vacuum_scale_factor')::numeric * greatest(t.n_live_tup, 0)
),
maxw AS (SELECT current_setting('autovacuum_max_workers')::int AS m)
SELECT 'PG-VAC-002'::text AS check_id,
       'cluster'::text    AS scope,
       NULL::text         AS object,
       format('All %s autovacuum workers are busy and %s tables in database %s already exceed their vacuum threshold (threshold %s tables). New work queues behind the running workers, so tables fall further behind. autovacuum_naptime = %s, autovacuum_vacuum_cost_delay = %s.',
              maxw.m, overdue.n, current_database(),
              :'pg_vac_002_overdue_tables'::int,
              current_setting('autovacuum_naptime'),
              current_setting('autovacuum_vacuum_cost_delay')) AS details,
       json_build_object('workers_running', workers.running, 'autovacuum_max_workers', maxw.m,
                         'overdue_tables', overdue.n, 'threshold_tables', :'pg_vac_002_overdue_tables'::int,
                         'autovacuum_naptime', current_setting('autovacuum_naptime'),
                         'database', current_database())::text AS evidence_json,
       'medium'::text AS confidence
FROM workers, overdue, maxw
WHERE workers.running >= maxw.m AND maxw.m > 0
  AND overdue.n >= :'pg_vac_002_overdue_tables'::int;
