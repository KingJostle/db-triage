-- check: MY-INFO-003
-- title: Plugins and components
-- priority: 250 | category: INFO | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.PLUGINS, mysql.component (MySQL 8.0+)
-- Always emitted, grouped by plugin type so the row stays readable. What is
-- loaded determines what several findings mean: an audit plugin answers
-- MY-SEC-015, a password-validation plugin answers MY-SEC-011, the thread pool
-- answers MY-CONN-006, semi-sync answers MY-REPL-009, and a non-default
-- authentication plugin changes how MY-SEC-001 and MY-SEC-006 should be read.
-- mysql.component is MySQL 8.0's separate registry for components (the successor
-- to plugins); MariaDB has no such table, so the component list is omitted there.
SELECT
  'MY-INFO-003' AS check_id,
  'cluster'     AS scope,
  p.PLUGIN_TYPE AS object,
  CONCAT(p.n, ' active ', p.PLUGIN_TYPE, ' plugin(s): ', p.list,
         IF(p.inactive > 0, CONCAT('. Also ', p.inactive, ' present but not active: ', p.inactive_list), ''),
         '.') AS details,
  JSON_OBJECT(
    'plugin_type', p.PLUGIN_TYPE,
    'active_count', p.n,
    'active_plugins', p.list,
    'inactive_count', p.inactive,
    'inactive_plugins', IFNULL(p.inactive_list, '')) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT PLUGIN_TYPE,
         SUM(PLUGIN_STATUS = 'ACTIVE') AS n,
         SUM(PLUGIN_STATUS <> 'ACTIVE') AS inactive,
         SUBSTRING(GROUP_CONCAT(IF(PLUGIN_STATUS = 'ACTIVE',
           CONCAT(PLUGIN_NAME, IF(IFNULL(PLUGIN_LIBRARY, '') <> '', '*', '')), NULL)
           ORDER BY PLUGIN_NAME SEPARATOR ', '), 1, 600) AS list,
         SUBSTRING(GROUP_CONCAT(IF(PLUGIN_STATUS <> 'ACTIVE', PLUGIN_NAME, NULL)
           ORDER BY PLUGIN_NAME SEPARATOR ', '), 1, 300) AS inactive_list
  FROM information_schema.PLUGINS
  GROUP BY PLUGIN_TYPE
) AS p
ORDER BY p.PLUGIN_TYPE;
