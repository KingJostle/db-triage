-- check: MY-SEC-009
-- title: LOAD DATA LOCAL enabled
-- priority: 100 | category: SEC | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.local_infile
-- The threat runs the wrong way round from what the name suggests. With
-- local_infile ON, a malicious or compromised SERVER can answer any client query
-- with a request for a local file, and a client library that honours it will
-- upload that file — /etc/passwd, an SSH key, an application config — without
-- the user doing anything. The database is the attacker and the client is the
-- victim, which is why it is a server-side setting worth turning off even though
-- the exposure is client-side.
-- MySQL 8.0 and MariaDB 10.x both default it to OFF; finding it ON means an
-- import job needed it once. Universal variable, no version gate needed.
SELECT
  'MY-SEC-009' AS check_id,
  'setting'    AS scope,
  'local_infile' AS object,
  CONCAT('local_infile = ON. A compromised or hostile server can respond to any client query with a file-transfer request, and client libraries that honour LOAD DATA LOCAL will upload the named local file without user interaction. ',
         'secure_file_priv = ',
         IF(IFNULL(@dbt_v_secure_file_priv, '') = '', '(empty — see MY-SEC-010)',
            IFNULL(@dbt_v_secure_file_priv, 'unknown')),
         '. Both forks ship local_infile OFF, so this was enabled for an import and probably not turned back off.') AS details,
  JSON_OBJECT(
    'local_infile', 'ON',
    'secure_file_priv', IFNULL(@dbt_v_secure_file_priv, 'unknown')) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.local_infile = 1;
