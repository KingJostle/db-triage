-- check: MY-SEC-010
-- title: FILE privilege unrestricted by secure_file_priv
-- priority: 100 | category: SEC | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: @dbt_v_secure_file_priv, normalised account source (FILE holders)
-- Derived: neither half is a finding alone. secure_file_priv empty means SELECT
-- ... INTO OUTFILE and LOAD_FILE() may read and write ANY path the mysqld OS
-- user can reach; that only matters if some account actually holds FILE.
-- Together they mean any of those accounts can read the server's private key,
-- /etc/shadow if mysqld runs as root, or any other database's data files, and
-- can write files into directories the OS user owns.
-- Empty string and NULL mean different things: NULL/absent (MySQL 5.7 default
-- on some builds) also disables the restriction; a path restricts to that
-- directory; the literal string 'NULL' disables the feature entirely, which is
-- the secure setting and is deliberately NOT flagged.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-010' AS check_id,
  'setting'    AS scope,
  'secure_file_priv' AS object,
  CONCAT('secure_file_priv is ',
         IF(IFNULL(@dbt_v_secure_file_priv, '') = '', 'empty', 'unset'),
         ', so file import and export are not restricted to any directory, and ',
         f.n, ' account(s) hold the FILE privilege: ', f.list, '. ',
         'Those accounts can read any file the mysqld OS user can read (including other databases'' data files and the server''s TLS private key) via LOAD_FILE(), and write files anywhere it can write via SELECT ... INTO OUTFILE. ',
         'Setting secure_file_priv to a dedicated directory, or to the literal NULL to disable file access entirely, closes this.') AS details,
  JSON_OBJECT(
    'secure_file_priv', IFNULL(@dbt_v_secure_file_priv, ''),
    'file_privilege_holders', f.n,
    'accounts', f.list,
    'local_infile', CAST(@@GLOBAL.local_infile AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n,
         SUBSTRING(GROUP_CONCAT(CONCAT('''', a.acct_user, '''@''', a.acct_host, '''')
           ORDER BY a.acct_user SEPARATOR ', '), 1, 400) AS list
  FROM (ACCTSRC) AS a
  WHERE a.File_priv = 'Y' AND a.is_role = 0 AND a.acct_user NOT IN ACCTSYS
) AS f
WHERE f.n > 0
  AND IFNULL(@dbt_v_secure_file_priv, '') = ''
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
