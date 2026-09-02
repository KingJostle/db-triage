-- check: MY-REL-006
-- title: No evidence of a monitoring agent
-- priority: 100 | category: REL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS, SELECT ON mysql.*
-- thresholds: (none)
-- reads: information_schema.PROCESSLIST (USER, HOST), information_schema.USER_PRIVILEGES
-- CONFIDENCE IS LOW AND THE WORDING IS "NO EVIDENCE OF", NOT "NO MONITORING".
-- This is the design's absence-of-evidence rule applied literally: an agent that
-- polls once a minute is almost never connected at the instant of the snapshot,
-- an agent may connect as a generically named account, and a metrics exporter
-- may scrape through a proxy. All three produce a false positive here.
-- What the check actually establishes is that no account and no connected
-- session carries a recognisable monitoring name, which is worth one question.
-- Recognised names cover the common agents: Percona PMM, Datadog, New Relic,
-- Zabbix, Nagios, Prometheus/mysqld_exporter, Grafana, Dynatrace, SolarWinds,
-- AppDynamics, Netdata, VividCortex/SolarWinds DPM, and Telegraf.
SET @dbt_mon_pat := 'pmm|percona|datadog|dd_|newrelic|new_relic|nrmysql|zabbix|nagios|icinga|prometheus|exporter|grafana|dynatrace|solarwinds|vividcortex|appdynamics|netdata|telegraf|monitor|metrics|observ';
SET @dbt_q := "
SELECT
  'MY-REL-006' AS check_id,
  'cluster'    AS scope,
  'monitoring' AS object,
  CONCAT('No account or connected session has a name matching a known monitoring agent. ',
         'Accounts on this server: ', a.n_accounts, ' (', a.sample, '). ',
         'Sessions at snapshot: ', p.n_sessions, ' from ', p.n_users, ' distinct account(s). ',
         'THIS IS ABSENCE OF EVIDENCE, NOT EVIDENCE OF ABSENCE: an agent polling once a minute is usually not connected at the instant of a snapshot, an agent may use a generic account name, and a metrics exporter may scrape through a proxy. Any of those produces this finding on a well-monitored server. ',
         'What it is worth is one question: what watches this database, and would it have paged someone for the P1 and P5 findings above? ',
         'Record the answer in .db-triage.yml so this stops firing.') AS details,
  JSON_OBJECT(
    'monitoring_accounts_found', 0,
    'account_count', a.n_accounts,
    'session_count', p.n_sessions,
    'distinct_session_users', p.n_users,
    'basis', 'name pattern match on accounts and current sessions',
    'patterns', @dbt_mon_pat) AS evidence_json,
  'low' AS confidence
FROM (
  SELECT COUNT(DISTINCT GRANTEE) AS n_accounts,
         SUBSTRING(GROUP_CONCAT(DISTINCT GRANTEE SEPARATOR ', '), 1, 300) AS sample,
         SUM(GRANTEE REGEXP @dbt_mon_pat) AS monitoring_accounts
    FROM information_schema.USER_PRIVILEGES
) AS a,
(
  SELECT COUNT(*) AS n_sessions,
         COUNT(DISTINCT USER) AS n_users,
         SUM(IFNULL(USER, '') REGEXP @dbt_mon_pat) AS monitoring_sessions
    FROM information_schema.PROCESSLIST
) AS p
WHERE IFNULL(a.monitoring_accounts, 0) = 0
  AND IFNULL(p.monitoring_sessions, 0) = 0";
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
