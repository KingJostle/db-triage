-- check: PG-REL-009
-- title: No evidence of a monitoring agent
-- priority: 100
-- scope: cluster
-- cost: 0
-- min_version: 10
SELECT 'PG-REL-009'::text AS check_id,
       'cluster'::text    AS scope,
       NULL::text         AS object,
       format('Nothing visible from inside the server suggests a monitoring agent is collecting from it: no role name and no application_name among the %s current connection(s) matches a known agent, and no monitoring extension is installed. Extensions present: %s. Roles that can log in: %s. This is weak evidence - an agent that polls every minute is simply not connected at the moment this ran, and an agent may collect from a replica instead - so confidence is low. It matters because every rate in this report is a since-reset average: without a time series there is no way to tell a problem that started this morning from one that has been there for a year.',
              (SELECT count(*) FROM pg_stat_activity WHERE backend_type = 'client backend'),
              coalesce((SELECT string_agg(extname, ', ' ORDER BY extname) FROM pg_extension), 'none'),
              (SELECT count(*) FROM pg_roles WHERE rolcanlogin)) AS details,
       json_build_object('client_backends', (SELECT count(*) FROM pg_stat_activity WHERE backend_type = 'client backend'),
                         'extensions', (SELECT string_agg(extname, ';' ORDER BY extname) FROM pg_extension),
                         'login_roles', (SELECT count(*) FROM pg_roles WHERE rolcanlogin),
                         'detection', 'application_name, role name and extension name matching against a list of known agents')::text AS evidence_json,
       'low'::text AS confidence
WHERE NOT EXISTS (
  SELECT 1 FROM pg_stat_activity a
  WHERE coalesce(a.application_name, '') || ' ' || coalesce(a.usename, '')
        ~* '(datadog|newrelic|new_relic|pgwatch|postgres_exporter|prometheus|pganalyze|zabbix|nagios|check_postgres|grafana|percona|pmm|sentry|dynatrace|telegraf|netdata|instana|appdynamics)')
  AND NOT EXISTS (
  SELECT 1 FROM pg_roles r
  WHERE r.rolname NOT LIKE 'pg\_%'
    AND r.rolname ~* '(datadog|newrelic|new_relic|pgwatch|postgres_exporter|prometheus|pganalyze|zabbix|nagios|check_postgres|grafana|percona|pmm|telegraf|netdata|monitor)')
  AND NOT EXISTS (
  SELECT 1 FROM pg_extension e WHERE e.extname IN ('pg_stat_monitor', 'pgwatch', 'pg_qualstats', 'powa', 'pg_stat_kcache'));
