-- check: MY-CONN-010
-- title: DNS lookups performed on every connection
-- priority: 150 | category: CONN | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.skip_name_resolve, mysql.user host patterns
-- With skip_name_resolve OFF, every incoming connection triggers a reverse DNS
-- lookup and then a forward lookup to confirm it. Three consequences, all real:
-- connection latency depends on a DNS server, a DNS outage looks like a database
-- outage, and failed lookups count toward max_connect_errors and can get a host
-- permanently blocked (MY-CONN-005).
-- It is also a security surface: host-based grants written against names rather
-- than addresses are only as trustworthy as reverse DNS. Turning it on requires
-- that every grant use an IP or a wildcard, which is why this is P150 with the
-- count of name-based grants included rather than a bare recommendation.
SELECT
  'MY-CONN-010' AS check_id,
  'setting'     AS scope,
  'skip_name_resolve' AS object,
  CONCAT('skip_name_resolve = OFF, so every connection performs a reverse and forward DNS lookup before authentication. ',
         'Connection latency then depends on the resolver, a DNS outage presents as a database outage, and failed lookups count toward max_connect_errors = ',
         @@GLOBAL.max_connect_errors, ' (MY-CONN-005). ',
         'Host-based grants that name a hostname are only as trustworthy as reverse DNS. ',
         'Aborted_connects since restart: ',
         CAST(IFNULL(@dbt_s_aborted_connects, 0) AS UNSIGNED),
         '. Before enabling it, confirm no account grant relies on a hostname (MY-SEC-004 lists host patterns).') AS details,
  JSON_OBJECT(
    'skip_name_resolve', 'OFF',
    'max_connect_errors', @@GLOBAL.max_connect_errors,
    'aborted_connects', CAST(IFNULL(@dbt_s_aborted_connects, 0) AS UNSIGNED)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.skip_name_resolve = 0;
