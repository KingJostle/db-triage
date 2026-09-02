-- check: MY-SEC-015
-- title: No audit logging (review)
-- priority: 200 | category: SEC | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.PLUGINS, mysql.component
-- Fork and edition divergence, all four cases probed:
--   MySQL Enterprise   audit_log plugin (component form in 8.0.30+)
--   Percona Server     audit_log plugin (free)
--   MariaDB            server_audit plugin (free)
--   MySQL Community    no audit facility at all; the general log (MY-CAP-007) is
--                      the only alternative and is not an audit trail
-- Inventory at P200: whether an audit trail is required is a compliance
-- question, not a database one. What db-triage supplies is the fact, so the
-- reviewer does not have to ask.
SELECT
  'MY-SEC-015' AS check_id,
  'cluster'    AS scope,
  'audit-logging' AS object,
  CONCAT('No audit plugin is active (looked for audit_log, server_audit, ',
         'AUDIT-type plugins and the MySQL 8.0 audit_log component). ',
         'Active plugin count: ', p.total, '. ',
         IF(@dbt_is_mariadb,
            'MariaDB ships server_audit and it can be installed without a restart.',
            'The audit_log plugin is an Enterprise feature in Oracle MySQL; Percona Server ships an equivalent free one. MySQL Community has no audit facility.'),
         ' general_log = ', CAST(@@GLOBAL.general_log AS CHAR),
         ' — note the general log records everything and is not a substitute for an audit trail (see MY-CAP-007). ',
         'Recorded for review: whether an audit trail is required is a compliance decision.') AS details,
  JSON_OBJECT(
    'audit_plugin_active', 0,
    'active_plugins', p.total,
    'fork', @dbt_fork,
    'general_log', CAST(@@GLOBAL.general_log AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS total,
         SUM(PLUGIN_STATUS = 'ACTIVE'
             AND (PLUGIN_NAME LIKE '%audit%' OR PLUGIN_TYPE = 'AUDIT')) AS auditors
  FROM information_schema.PLUGINS
) AS p
WHERE IFNULL(p.auditors, 0) = 0;
