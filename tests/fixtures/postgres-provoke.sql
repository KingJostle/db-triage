-- ===========================================================================
--  DESTRUCTIVE. THROWAWAY CONTAINERS ONLY. DO NOT RUN THIS ANYWHERE REAL.
-- ===========================================================================
--
--  This is the ONLY file in db-triage that writes. Everything else in this
--  repository is read-only by contract (see reference/methodology.md and the
--  safety contract in SKILL.md). This file exists to deliberately create the
--  conditions db-triage detects, so the checks can be exercised against a real
--  server instead of against a mock.
--
--  It CREATES SCHEMAS, TABLES, INDEXES, SEQUENCES, FUNCTIONS AND A REPLICATION
--  SLOT; it GRANTS TO PUBLIC; it leaves an INVALID INDEX behind on purpose; and
--  it leaves tables bloated and unvacuumed on purpose.
--
--  Run it only against a database you are willing to drop:
--
--      createdb triage_test
--      psql -d triage_test -f tests/fixtures/postgres-provoke.sql
--
--  Refuse to run against anything that looks like production.
-- ===========================================================================

\set ON_ERROR_STOP on

DO $guard$
BEGIN
  IF current_database() !~ '(test|fixture|scratch|triage|sandbox|tmp)' THEN
    RAISE EXCEPTION
      'db-triage fixture refused: database "%" does not look like a throwaway database. Rename it or use createdb triage_test.',
      current_database();
  END IF;
  IF NOT pg_is_in_recovery() AND current_setting('server_version_num')::int < 100000 THEN
    RAISE EXCEPTION 'db-triage fixtures require PostgreSQL 10 or newer.';
  END IF;
END
$guard$;

CREATE SCHEMA IF NOT EXISTS triage_fixture;
SET search_path = triage_fixture, public;

-- ---------------------------------------------------------------- PG-SEC-013
-- PUBLIC CREATE on schema public. PostgreSQL 15 revoked this by default; the
-- fixture puts it back so the check has something to find on 15+.
GRANT CREATE ON SCHEMA public TO PUBLIC;

-- ---------------------------------------------------------------- bloat base
-- A table with enough rows that relpages is meaningful, then most rows deleted
-- and never vacuumed. Provokes PG-VAC-003 (dead tuples) and, with lowered
-- thresholds, PG-VAC-006/007 and PG-IDX-006/007.
DROP TABLE IF EXISTS bloated CASCADE;
CREATE TABLE bloated (
  id      bigint PRIMARY KEY,
  payload text   NOT NULL,
  tag     text,
  amount  numeric(12,2)
);
INSERT INTO bloated (id, payload, tag, amount)
SELECT g, repeat('x', 180), 'tag-' || (g % 7), (g % 10000)::numeric / 100
FROM generate_series(1, 400000) g;
CREATE INDEX bloated_tag_idx ON bloated (tag);
ANALYZE bloated;
DELETE FROM bloated WHERE id % 10 <> 0;        -- 90% dead, deliberately not vacuumed

-- --------------------------------------------------------- PG-IDX-002/003/004
-- An index nothing reads, and two indexes identical in every catalog column.
DROP TABLE IF EXISTS orders CASCADE;
CREATE TABLE orders (
  id         bigserial PRIMARY KEY,
  customer_id bigint NOT NULL,
  status     text    NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  total      numeric(12,2)
);
INSERT INTO orders (customer_id, status, total)
SELECT (g % 5000), (ARRAY['new','paid','shipped','refunded'])[1 + g % 4], (g % 500)::numeric
FROM generate_series(1, 120000) g;

CREATE INDEX orders_never_read_idx    ON orders (created_at);   -- PG-IDX-002/003
CREATE INDEX orders_customer_id_idx   ON orders (customer_id);  -- PG-IDX-004 pair A
CREATE INDEX orders_customer_id_copy  ON orders (customer_id);  -- PG-IDX-004 pair B
CREATE INDEX orders_cust_status_idx   ON orders (customer_id, status); -- PG-IDX-005 superset
ANALYZE orders;

-- ---------------------------------------------------------------- PG-IDX-001
-- A failed CREATE UNIQUE INDEX CONCURRENTLY leaves an index with
-- indisvalid = false behind. Provoked by unique-violating data.
DROP TABLE IF EXISTS dupes CASCADE;
CREATE TABLE dupes (id int, k int);
INSERT INTO dupes SELECT g, g % 50 FROM generate_series(1, 500) g;
-- CREATE INDEX CONCURRENTLY cannot run inside a transaction block, so this
-- must be a top-level statement and the expected failure must not stop the
-- script. The unique violation is the point: it leaves indisvalid = false.
DROP INDEX IF EXISTS dupes_k_uniq;
\set ON_ERROR_STOP off
CREATE UNIQUE INDEX CONCURRENTLY dupes_k_uniq ON dupes (k);
\set ON_ERROR_STOP on
\echo 'fixture: the ERROR above is expected; it leaves invalid index dupes_k_uniq behind for PG-IDX-001'

-- ---------------------------------------------------------------- PG-IDX-008
-- Foreign key with no index on the referencing columns.
DROP TABLE IF EXISTS order_lines CASCADE;
CREATE TABLE order_lines (
  id       bigserial PRIMARY KEY,
  order_id bigint NOT NULL REFERENCES orders (id),
  sku      text   NOT NULL,
  qty      int    NOT NULL
);
INSERT INTO order_lines (order_id, sku, qty)
SELECT 1 + (g % 120000), 'SKU-' || (g % 900), 1 + (g % 5)
FROM generate_series(1, 200000) g;
ANALYZE order_lines;

-- ------------------------------------------------------------- PG-SCHEMA-003
-- An ordinary table with neither a primary key nor a unique index.
DROP TABLE IF EXISTS events_no_pk CASCADE;
CREATE TABLE events_no_pk (
  occurred_at timestamptz NOT NULL DEFAULT now(),
  kind        text        NOT NULL,
  body        jsonb
);
INSERT INTO events_no_pk (kind, body)
SELECT 'kind-' || (g % 12), jsonb_build_object('n', g)
FROM generate_series(1, 40000) g;
ANALYZE events_no_pk;

-- --------------------------------------------------------- PG-SCHEMA-001/002
-- A sequence deliberately advanced close to the limit of its int4 owner column.
DROP TABLE IF EXISTS nearly_full CASCADE;
CREATE TABLE nearly_full (id serial PRIMARY KEY, note text);
INSERT INTO nearly_full (note) VALUES ('first');
SELECT setval(pg_get_serial_sequence('nearly_full', 'id'), 2100000000);

-- ---------------------------------------------------------------- PG-VAC-009
-- A relation with autovacuum switched off by storage parameter.
DROP TABLE IF EXISTS no_autovacuum CASCADE;
CREATE TABLE no_autovacuum (id int PRIMARY KEY, v text) WITH (autovacuum_enabled = false);
INSERT INTO no_autovacuum SELECT g, repeat('y', 40) FROM generate_series(1, 20000) g;
DELETE FROM no_autovacuum WHERE id % 3 = 0;

-- ---------------------------------------------------------------- PG-DUR-005
DROP TABLE IF EXISTS scratch_unlogged CASCADE;
CREATE UNLOGGED TABLE scratch_unlogged (id int, v text);
INSERT INTO scratch_unlogged SELECT g, 'u' FROM generate_series(1, 1000) g;

-- ------------------------------------------------------------- PG-SCHEMA-011
DROP MATERIALIZED VIEW IF EXISTS unpopulated_mv;
CREATE MATERIALIZED VIEW unpopulated_mv AS SELECT id, status FROM orders WITH NO DATA;

-- ------------------------------------------------------------- PG-SCHEMA-008
ALTER TABLE order_lines ADD CONSTRAINT order_lines_qty_positive CHECK (qty > 0) NOT VALID;

-- ---------------------------------------------------------------- PG-SEC-014
CREATE OR REPLACE FUNCTION triage_fixture.unsafe_definer(p int)
RETURNS int LANGUAGE sql SECURITY DEFINER AS $fn$ SELECT p * 2 $fn$;

-- ------------------------------------------------------------- PG-SEC-015/016
GRANT SELECT, INSERT, UPDATE, DELETE ON triage_fixture.events_no_pk TO PUBLIC;

-- ------------------------------------------------------------- PG-SCHEMA-009
CREATE OR REPLACE FUNCTION triage_fixture.noop_trigger()
RETURNS trigger LANGUAGE plpgsql AS $tg$ BEGIN RETURN NEW; END $tg$;
DROP TRIGGER IF EXISTS orders_noop ON orders;
CREATE TRIGGER orders_noop BEFORE INSERT ON orders
  FOR EACH ROW EXECUTE FUNCTION triage_fixture.noop_trigger();

-- ------------------------------------------------------------- PG-REPL-003/4
-- An inactive physical replication slot with nothing consuming it. Harmless in
-- a throwaway container; a WAL-retention outage on a real primary. Drop it with
--   SELECT pg_drop_replication_slot('triage_fixture_dead_slot');
DO $slot$
BEGIN
  IF NOT pg_is_in_recovery()
     AND NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'triage_fixture_dead_slot') THEN
    PERFORM pg_create_physical_replication_slot('triage_fixture_dead_slot');
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'fixture: could not create replication slot (%), PG-REPL-003/004 will not fire', SQLERRM;
END
$slot$;

ANALYZE;

\echo ''
\echo 'Fixture applied. Findings you should now be able to provoke:'
\echo '  PG-IDX-001  invalid index         triage_fixture.dupes_k_uniq'
\echo '  PG-IDX-004  duplicate indexes     orders_customer_id_idx / _copy'
\echo '  PG-IDX-005  overlapping indexes   orders_customer_id_idx inside orders_cust_status_idx'
\echo '  PG-IDX-002/003 unused index       orders_never_read_idx  (needs -v ..._min_bytes=1)'
\echo '  PG-IDX-008  unindexed FK          order_lines.order_id   (needs -v ..._min_bytes=1)'
\echo '  PG-VAC-003  dead tuples           bloated                (needs lowered thresholds)'
\echo '  PG-VAC-006/007 estimated bloat    bloated                (needs lowered thresholds)'
\echo '  PG-VAC-009  autovacuum disabled   no_autovacuum'
\echo '  PG-SCHEMA-001 sequence exhausted  nearly_full_id_seq'
\echo '  PG-SCHEMA-003 no primary key      events_no_pk'
\echo '  PG-SCHEMA-008 NOT VALID constraint order_lines_qty_positive'
\echo '  PG-SCHEMA-009 trigger on hot table orders                (needs -v ..._min_writes=1)'
\echo '  PG-SCHEMA-011 unpopulated matview unpopulated_mv'
\echo '  PG-SEC-013  PUBLIC CREATE on public'
\echo '  PG-SEC-014  SECURITY DEFINER without search_path'
\echo '  PG-SEC-015/016 PUBLIC grants      events_no_pk'
\echo '  PG-DUR-005  unlogged table        scratch_unlogged'
\echo '  PG-REPL-003/004 inactive slot     triage_fixture_dead_slot'
\echo ''
\echo 'For PG-LOCK-003 (idle in transaction), open a second psql and run:'
\echo '    BEGIN; SELECT 1;   -- then leave it sitting'
\echo ''
