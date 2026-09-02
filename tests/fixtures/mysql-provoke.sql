-- ############################################################################
-- ##                                                                        ##
-- ##   D E S T R U C T I V E   —   T H R O W A W A Y   S E R V E R S  O N L Y ##
-- ##                                                                        ##
-- ##   db-triage / tests/fixtures/mysql-provoke.sql                          ##
-- ##                                                                        ##
-- ##   This file DELIBERATELY BREAKS A MySQL/MariaDB SERVER so that the      ##
-- ##   db-triage checks have something to find. It:                          ##
-- ##                                                                        ##
-- ##     * CREATES AND DROPS the schema `dbtriage_fixture`                   ##
-- ##     * CREATES ACCOUNTS WITH NO PASSWORD, reachable from ANY host        ##
-- ##     * GRANTS ALL PRIVILEGES ON *.* to an account open to the world      ##
-- ##     * CREATES an account using the deprecated mysql_native_password     ##
-- ##     * TURNS OFF strict SQL mode, doublewrite-adjacent durability        ##
-- ##       settings, binary log retention and TLS enforcement via SET GLOBAL ##
-- ##     * TURNS ON the general query log                                    ##
-- ##     * LEAVES a transaction open and a metadata lock queued              ##
-- ##                                                                        ##
-- ##   NEVER RUN THIS ON A SERVER YOU CARE ABOUT.                            ##
-- ##   NEVER RUN THIS ON A SERVER REACHABLE FROM A NETWORK YOU DO NOT OWN.   ##
-- ##   It is intended for a disposable container started for one test run    ##
-- ##   and destroyed afterwards (tests/docker-compose.yml).                  ##
-- ##                                                                        ##
-- ##   db-triage ITSELF never runs any of this. Every statement in           ##
-- ##   checks/mysql/ is read-only; this file is the exact opposite, and it   ##
-- ##   lives under tests/ for that reason.                                   ##
-- ##                                                                        ##
-- ############################################################################

-- Refuse to run against anything that looks like a real server: a server with a
-- meaningful amount of data, or one with replicas attached, is not a fixture host.
-- The guard raises an error and stops the script rather than proceeding.
SELECT
  IF((SELECT IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0)
        FROM information_schema.TABLES
       WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys',
                                  'dbtriage_fixture')) > 1073741824,
     (SELECT 'REFUSING TO RUN: this server holds more than 1 GB of user data and is not a throwaway fixture host'
        FROM information_schema.TABLES WHERE 1 = 0 GROUP BY TABLE_NAME HAVING COUNT(*) > 1),
     'guard passed: server holds under 1 GB of user data') AS fixture_guard;

-- ---------------------------------------------------------------------------
-- 1. Schema and tables
-- ---------------------------------------------------------------------------
DROP DATABASE IF EXISTS dbtriage_fixture;
CREATE DATABASE dbtriage_fixture DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE dbtriage_fixture;

-- MY-SCHEMA-001 / MY-SCHEMA-002: InnoDB tables with NO PRIMARY KEY.
-- Under row-based replication every UPDATE or DELETE replayed on a replica scans
-- the whole table once per row, so a single batch job can put a replica hours
-- behind. Two tables so the summary form is exercised as well as the per-object one.
CREATE TABLE no_pk_events (
  event_id   BIGINT       NOT NULL,
  payload    VARCHAR(255) NOT NULL,
  created_at DATETIME     NOT NULL,
  KEY idx_created (created_at)
) ENGINE = InnoDB;

CREATE TABLE no_pk_audit (
  actor   VARCHAR(64) NOT NULL,
  action  VARCHAR(64) NOT NULL,
  at_time DATETIME    NOT NULL
) ENGINE = InnoDB;

INSERT INTO no_pk_events (event_id, payload, created_at)
SELECT seq, CONCAT('payload-', seq), NOW() - INTERVAL seq SECOND
FROM (SELECT 1 AS seq UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8) AS s;
INSERT INTO no_pk_audit VALUES ('alice', 'login', NOW()), ('bob', 'logout', NOW());

-- MY-DUR-007 and MY-LOCK-008: a non-transactional, table-locking engine.
CREATE TABLE legacy_myisam (
  id   INT NOT NULL PRIMARY KEY,
  note VARCHAR(128)
) ENGINE = MyISAM;
INSERT INTO legacy_myisam VALUES (1, 'no crash recovery'), (2, 'table-level write lock');

-- MY-IDX-003: redundant / duplicate indexes. idx_a_b makes idx_a redundant
-- (idx_a is a leftmost prefix of it) and dup_a is an exact duplicate of idx_a.
CREATE TABLE redundant_idx (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  a  INT NOT NULL,
  b  INT NOT NULL,
  c  INT NOT NULL,
  KEY idx_a   (a),
  KEY dup_a   (a),
  KEY idx_a_b (a, b)
) ENGINE = InnoDB;
INSERT INTO redundant_idx (a, b, c) VALUES (1, 1, 1), (2, 2, 2), (3, 3, 3);

-- MY-IDX-007: a single-column index on a column with almost no distinct values.
-- MY-IDX-009: a composite index over six columns.
CREATE TABLE wide_and_narrow_idx (
  id      INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  is_live TINYINT(1) NOT NULL,
  c1 INT NOT NULL, c2 INT NOT NULL, c3 INT NOT NULL,
  c4 INT NOT NULL, c5 INT NOT NULL, c6 INT NOT NULL,
  KEY idx_is_live (is_live),
  KEY idx_six (c1, c2, c3, c4, c5, c6)
) ENGINE = InnoDB;
INSERT INTO wide_and_narrow_idx (is_live, c1, c2, c3, c4, c5, c6)
VALUES (0,1,1,1,1,1,1), (1,2,2,2,2,2,2), (1,3,3,3,3,3,3);

-- MY-SCHEMA-005 / MY-SCHEMA-006: AUTO_INCREMENT close to the column-type maximum.
-- A SMALLINT column tops out at 32,767; starting at 31,000 puts it above 90%.
-- Inserts fail with a duplicate-key error on the maximum value, not with an
-- overflow error, which is why this is so often diagnosed late.
CREATE TABLE autoinc_nearly_full (
  id   SMALLINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  note VARCHAR(32)
) ENGINE = InnoDB AUTO_INCREMENT = 31000;
INSERT INTO autoinc_nearly_full (note) VALUES ('near the ceiling');

-- MY-SCHEMA-008: leftover artefacts from an interrupted online schema change.
-- pt-online-schema-change and gh-ost both leave a shadow table behind if they
-- are killed; pt-osc also leaves triggers that double the cost of every write.
CREATE TABLE _real_table_new (
  id INT NOT NULL PRIMARY KEY,
  v  INT
) ENGINE = InnoDB;
CREATE TABLE _real_table_gho (
  id INT NOT NULL PRIMARY KEY,
  v  INT
) ENGINE = InnoDB;

-- MY-SCHEMA-012 and MY-SCHEMA-014: legacy character sets, legacy row formats and
-- a collation that disagrees with the rest of the schema. A JOIN between a
-- latin1 column and a utf8mb4 column cannot use an index on either side.
CREATE TABLE legacy_charset (
  id   INT NOT NULL PRIMARY KEY,
  name VARCHAR(64)
) ENGINE = InnoDB DEFAULT CHARSET = latin1 ROW_FORMAT = COMPACT;
INSERT INTO legacy_charset VALUES (1, 'latin1 row');

CREATE TABLE mixed_collation (
  id   INT NOT NULL PRIMARY KEY,
  name VARCHAR(64) COLLATE utf8mb4_unicode_ci
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_bin;
INSERT INTO mixed_collation VALUES (1, 'collation that disagrees with the schema default');

-- MY-SCHEMA-011: a trigger on a table, so the trigger inventory has something.
CREATE TABLE triggered_table (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  v  INT
) ENGINE = InnoDB;
CREATE TABLE trigger_log (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  v  INT
) ENGINE = InnoDB;
DELIMITER //
CREATE TRIGGER pt_osc_dbtriage_fixture_triggered_table_ins
AFTER INSERT ON triggered_table
FOR EACH ROW
BEGIN
  INSERT INTO trigger_log (v) VALUES (NEW.v);
END//
DELIMITER ;
INSERT INTO triggered_table (v) VALUES (1), (2), (3);

-- ---------------------------------------------------------------------------
-- 2. Accounts  —  THIS SECTION CREATES INSECURE ACCOUNTS
-- ---------------------------------------------------------------------------
-- MY-SEC-002: a full-privilege account reachable from anywhere.
DROP USER IF EXISTS 'fixture_root'@'%';
CREATE USER 'fixture_root'@'%' IDENTIFIED BY 'fixture-not-a-real-password';
GRANT ALL PRIVILEGES ON *.* TO 'fixture_root'@'%' WITH GRANT OPTION;

-- MY-SEC-001: an account with no password at all.
DROP USER IF EXISTS 'fixture_nopass'@'%';
CREATE USER 'fixture_nopass'@'%';
GRANT SELECT ON dbtriage_fixture.* TO 'fixture_nopass'@'%';

-- MY-SEC-004: an ordinary application account with a wildcard host.
DROP USER IF EXISTS 'fixture_app'@'%';
CREATE USER 'fixture_app'@'%' IDENTIFIED BY 'fixture-not-a-real-password';
GRANT SELECT, INSERT, UPDATE, DELETE ON dbtriage_fixture.* TO 'fixture_app'@'%';

-- MY-SEC-006: the deprecated authentication plugin. The syntax differs between
-- forks and the plugin is not always available, so BOTH spellings are issued and
-- exactly one is expected to succeed. Run the client with --force so the failing
-- one does not abort the fixture.
--   MySQL 5.7/8.0 : IDENTIFIED WITH <plugin> BY '<password>'
--                   (8.4 disables mysql_native_password by default; 9.0 removed it,
--                    so on those versions BOTH statements fail and MY-SEC-006 will
--                    only fire for any pre-existing native-password accounts)
--   MariaDB       : IDENTIFIED WITH <plugin> USING PASSWORD('<password>'), and
--                   plain IDENTIFIED BY already yields mysql_native_password
DROP USER IF EXISTS 'fixture_native'@'%';
CREATE USER 'fixture_native'@'%' IDENTIFIED WITH mysql_native_password
  BY 'fixture-not-a-real-password';
CREATE USER IF NOT EXISTS 'fixture_native'@'%' IDENTIFIED WITH mysql_native_password
  USING PASSWORD('fixture-not-a-real-password');

-- MY-SEC-010: an account holding FILE, which combines with an empty
-- secure_file_priv to allow reading and writing arbitrary paths.
DROP USER IF EXISTS 'fixture_file'@'%';
CREATE USER 'fixture_file'@'%' IDENTIFIED BY 'fixture-not-a-real-password';
GRANT FILE ON *.* TO 'fixture_file'@'%';

-- ---------------------------------------------------------------------------
-- 3. Global settings  —  THIS SECTION DEGRADES THE SERVER
-- ---------------------------------------------------------------------------
-- Each SET GLOBAL below is reverted only by restarting the container. Several
-- are the exact settings db-triage exists to complain about.

-- MY-DUR-001 / MY-DUR-002 / MY-DUR-003: relaxed durability on a source.
SET GLOBAL innodb_flush_log_at_trx_commit = 2;
SET GLOBAL sync_binlog = 0;

-- MY-SCHEMA-004: non-strict SQL mode. Silent truncation and zero dates.
SET GLOBAL sql_mode = 'NO_ENGINE_SUBSTITUTION';

-- MY-SCHEMA-007: integrity checks disabled globally.
SET GLOBAL foreign_key_checks = OFF;
SET GLOBAL unique_checks = OFF;

-- MY-BAK-004: binary logs that never expire.
SET GLOBAL expire_logs_days = 0;

-- MY-CAP-007: the general query log, which records every statement.
SET GLOBAL general_log = ON;

-- MY-QRY-003: slow query logging off.
SET GLOBAL slow_query_log = OFF;
SET GLOBAL long_query_time = 10;

-- MY-CONN-010: DNS lookup on every connection. skip_name_resolve is READ-ONLY on
-- both forks, so it cannot be set here; the compose file must start the server
-- WITHOUT --skip-name-resolve for MY-CONN-010 to fire. Left in place as a note
-- rather than a statement, because a failing SET GLOBAL here would be noise.

-- MY-SEC-009: LOAD DATA LOCAL enabled.
SET GLOBAL local_infile = ON;

-- ---------------------------------------------------------------------------
-- 4. What this fixture deliberately does NOT provoke
-- ---------------------------------------------------------------------------
-- Some conditions cannot be created safely, quickly or at all from SQL. They are
-- listed here so the gap is visible rather than assumed covered:
--
--   MY-DUR-004/005 (doublewrite off, innodb_force_recovery)  read-only variables;
--                   they need a server restart with different command-line flags.
--   MY-UNDO-001/002 (history list length in the millions)    needs sustained
--                   write load against an old read view; minutes of work, not a fixture.
--   MY-REPL-001..004 (replication broken, lagging)           needs a second
--                   server; tests/docker-compose.yml wires that up separately.
--   MY-CORR-001/002 (error-log patterns)                     needs a genuinely
--                   damaged tablespace, which cannot be faked read-only.
--   MY-CAP-001..003 (filesystem headroom)                    OS-level, supplied
--                   by the runner rather than by SQL.
--   MY-MEM-001/010/012, MY-WAL-001 (sizing)                  set at startup in
--                   the compose file, not here.
--
-- The open transaction and metadata-lock pile-up that MY-LOCK-003/004/006 detect
-- need TWO concurrent sessions, so they cannot be provoked from a single script.
-- tests/run_tests.sh opens a sidecar session that runs:
--
--     START TRANSACTION;
--     SELECT * FROM dbtriage_fixture.redundant_idx FOR UPDATE;
--     -- then sleeps, holding row locks and a shared metadata lock
--
-- and, in a third session, an
--
--     ALTER TABLE dbtriage_fixture.redundant_idx ADD COLUMN d INT;
--
-- which queues behind it and blocks every subsequent query on that table.

SELECT 'dbtriage_fixture applied' AS status,
       (SELECT COUNT(*) FROM information_schema.TABLES
         WHERE TABLE_SCHEMA = 'dbtriage_fixture') AS tables_created,
       (SELECT COUNT(*) FROM information_schema.USER_PRIVILEGES
         WHERE GRANTEE LIKE '''fixture%') AS fixture_accounts;
