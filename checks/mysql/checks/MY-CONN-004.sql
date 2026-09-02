-- check: MY-CONN-004
-- title: Aborted connections high
-- priority: 100 | category: CONN | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: aborted_ratio=0.01;min_connections=10000
-- reads: @dbt_s_aborted_connects, @dbt_s_aborted_clients, @dbt_s_connections
-- Two different failures with one threshold, distinguished in the text:
-- Aborted_connects counts handshakes that never completed (bad credentials, a
-- host blocked by max_connect_errors, connect_timeout, TLS negotiation failure);
-- Aborted_clients counts established connections the client dropped without a
-- clean COM_QUIT (application crash, pool eviction, wait_timeout, an oversized
-- packet). The first is a security or configuration signal, the second is an
-- application-lifecycle signal, and confusing them wastes an afternoon.
SELECT
  'MY-CONN-004' AS check_id,
  'cluster'     AS scope,
  IF(a.connects_ratio >= a.thr, 'Aborted_connects', 'Aborted_clients') AS object,
  CONCAT('Since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago, of ',
         FORMAT(a.total, 0), ' connections: Aborted_connects = ', FORMAT(a.connects, 0),
         ' (', ROUND(100 * a.connects_ratio, 2),
         '%, handshakes that never completed — bad credentials, a host blocked by max_connect_errors, connect_timeout or a TLS failure); ',
         'Aborted_clients = ', FORMAT(a.clients, 0), ' (', ROUND(100 * a.clients_ratio, 2),
         '%, established connections dropped without a clean close — application crashes, pool evictions, wait_timeout = ',
         @@GLOBAL.wait_timeout, ' s, or max_allowed_packet = ',
         ROUND(@@GLOBAL.max_allowed_packet / 1048576, 0), ' MB exceeded). Threshold ',
         ROUND(100 * a.thr, 1), '%.') AS details,
  JSON_OBJECT(
    'aborted_connects', a.connects,
    'aborted_clients', a.clients,
    'connections', a.total,
    'aborted_connects_ratio', ROUND(a.connects_ratio, 5),
    'aborted_clients_ratio', ROUND(a.clients_ratio, 5),
    'threshold_ratio', a.thr,
    'wait_timeout', @@GLOBAL.wait_timeout,
    'max_allowed_packet', @@GLOBAL.max_allowed_packet) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT
    CAST(IFNULL(@dbt_s_aborted_connects, 0) AS DECIMAL(30, 0)) AS connects,
    CAST(IFNULL(@dbt_s_aborted_clients, 0) AS DECIMAL(30, 0))  AS clients,
    GREATEST(CAST(IFNULL(@dbt_s_connections, 0) AS DECIMAL(30, 0)), 1) AS total,
    CAST(IFNULL(@dbt_s_aborted_connects, 0) AS DECIMAL(30, 0))
      / GREATEST(CAST(IFNULL(@dbt_s_connections, 0) AS DECIMAL(30, 0)), 1) AS connects_ratio,
    CAST(IFNULL(@dbt_s_aborted_clients, 0) AS DECIMAL(30, 0))
      / GREATEST(CAST(IFNULL(@dbt_s_connections, 0) AS DECIMAL(30, 0)), 1) AS clients_ratio,
    COALESCE(@aborted_ratio, 0.01) AS thr
) AS a
WHERE a.total >= COALESCE(@min_connections, 10000)
  AND (a.connects_ratio >= a.thr OR a.clients_ratio >= a.thr);
