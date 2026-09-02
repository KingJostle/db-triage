-- check: PG-INFO-012
-- title: Statistics window
-- priority: 250
-- scope: cluster
-- cost: 0
-- Printed near the top of the report: every rate in it depends on this window.
WITH resets AS (
  SELECT 'pg_stat_database'  AS view_name, min(stats_reset) AS reset_at FROM pg_stat_database
  UNION ALL
  SELECT 'pg_stat_bgwriter', stats_reset FROM pg_stat_bgwriter
  UNION ALL
  SELECT 'pg_stat_archiver', stats_reset FROM pg_stat_archiver
),
agg AS (
  SELECT min(reset_at) AS earliest, max(reset_at) AS latest,
         string_agg(format('%s=%s', view_name, coalesce(reset_at::text, 'never')), ', ' ORDER BY view_name) AS detail
  FROM resets
)
SELECT 'PG-INFO-012'::text AS check_id,
       'cluster'::text     AS scope,
       NULL::text          AS object,
       format('Counters cover %s days: the earliest statistics reset is %s and the server has been up for %s. Per view: %s. Every rate in this report - checkpoints per hour, deadlocks per day, temp bytes per day, "0 index scans since reset" - is measured over this window and means nothing outside it. A window shorter than 24 hours makes every counter-based finding low confidence; a window of years hides recent change inside a long average.',
              round(extract(epoch FROM now() - coalesce(a.earliest, pg_postmaster_start_time())) / 86400.0, 1)::text,
              coalesce(a.earliest::text, 'unknown (no view reports one)'),
              justify_interval(date_trunc('second', now() - pg_postmaster_start_time())),
              a.detail) AS details,
       json_build_object('earliest_stats_reset', a.earliest,
                         'latest_stats_reset', a.latest,
                         'window_days', round(extract(epoch FROM now() - coalesce(a.earliest, pg_postmaster_start_time())) / 86400.0, 3),
                         'uptime_seconds', round(extract(epoch FROM now() - pg_postmaster_start_time()))::bigint,
                         'postmaster_start_time', pg_postmaster_start_time(),
                         'per_view', a.detail)::text AS evidence_json,
       'high'::text AS confidence
FROM agg a;
