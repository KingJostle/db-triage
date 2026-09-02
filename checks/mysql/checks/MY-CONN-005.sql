-- check: MY-CONN-005
-- title: Host approaching the connect-error block threshold
-- priority: 100 | category: CONN | scope: host | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: connect_error_ratio=0.50
-- reads: performance_schema.host_cache (SUM_CONNECT_ERRORS), @@GLOBAL.max_connect_errors
-- MySQL-specific failure mode with no PostgreSQL analogue: when a host
-- accumulates max_connect_errors failed handshakes, the server blocks it
-- ENTIRELY — every subsequent connection from that IP is refused with
-- ER_HOST_IS_BLOCKED until someone runs FLUSH HOSTS. The block survives the
-- original problem being fixed, and nothing logs a warning as the count climbs.
-- The design scopes this to MySQL; performance_schema.host_cache is in fact
-- present on MariaDB 10.11 as well (verified), so it is gated on the table
-- rather than on the fork, and the registry row records both engines.
-- Note that skip_name_resolve=OFF makes DNS failures count toward this, which is
-- how a DNS blip turns into a permanently blocked application host (MY-CONN-010).
SET @dbt_q := "
SELECT
  'MY-CONN-005' AS check_id,
  'host'        AS scope,
  h.IP          AS object,
  CONCAT('Host ', h.IP, ' has accumulated ', h.SUM_CONNECT_ERRORS,
         ' connect errors against max_connect_errors = ', @@GLOBAL.max_connect_errors,
         ' (', ROUND(100.0 * h.SUM_CONNECT_ERRORS / @@GLOBAL.max_connect_errors, 0),
         '%, threshold ', ROUND(100 * COALESCE(@connect_error_ratio, 0.50), 0),
         '%). At 100% the server blocks this host entirely with ER_HOST_IS_BLOCKED until FLUSH HOSTS is run; the block outlives whatever caused it. ',
         'Breakdown: ', h.detail, '. skip_name_resolve = ', @@GLOBAL.skip_name_resolve,
         ' (when OFF, DNS failures count here too).') AS details,
  JSON_OBJECT(
    'ip', h.IP,
    'host', h.HOST,
    'sum_connect_errors', h.SUM_CONNECT_ERRORS,
    'max_connect_errors', @@GLOBAL.max_connect_errors,
    'ratio', ROUND(h.SUM_CONNECT_ERRORS / @@GLOBAL.max_connect_errors, 4),
    'threshold_ratio', COALESCE(@connect_error_ratio, 0.50),
    'skip_name_resolve', CAST(@@GLOBAL.skip_name_resolve AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT IP, HOST, SUM_CONNECT_ERRORS,
         CONCAT_WS(', ',
           IF(COUNT_HOST_BLOCKED_ERRORS > 0, CONCAT(COUNT_HOST_BLOCKED_ERRORS, ' host-blocked'), NULL),
           IF(COUNT_AUTHENTICATION_ERRORS > 0, CONCAT(COUNT_AUTHENTICATION_ERRORS, ' auth'), NULL),
           IF(COUNT_HANDSHAKE_ERRORS > 0, CONCAT(COUNT_HANDSHAKE_ERRORS, ' handshake'), NULL),
           IF(COUNT_NAMEINFO_TRANSIENT_ERRORS + COUNT_NAMEINFO_PERMANENT_ERRORS > 0,
              CONCAT(COUNT_NAMEINFO_TRANSIENT_ERRORS + COUNT_NAMEINFO_PERMANENT_ERRORS, ' DNS'), NULL)) AS detail
    FROM performance_schema.host_cache
) AS h
WHERE h.SUM_CONNECT_ERRORS >= @@GLOBAL.max_connect_errors * COALESCE(@connect_error_ratio, 0.50)";
SET @dbt_q := IF(IFNULL(@dbt_has_host_cache, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
