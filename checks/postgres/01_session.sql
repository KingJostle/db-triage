-- db-triage session safety block. Source this before every batch of checks.
--
-- This file is the enforcement point for the read-only contract. Nothing in
-- db-triage may mutate data, schema, or server state; these SETs make the
-- session refuse to even if a check were wrong.
--
-- Optional caller-supplied variables (psql -v):
--   db_triage_statement_timeout   default '10s'  ('60s' for the deep pass)
--   db_triage_lock_timeout        default '2s'
--   db_triage_version             default '0.1.0'

\if :{?db_triage_version}
\else
\set db_triage_version '0.1.0'
\endif
\if :{?db_triage_statement_timeout}
\else
\set db_triage_statement_timeout '10s'
\endif
\if :{?db_triage_lock_timeout}
\else
\set db_triage_lock_timeout '2s'
\endif

-- Identifiable: the DBA can see and cancel this run in pg_stat_activity.
\set db_triage_app_name 'db-triage/':db_triage_version
SET application_name = :'db_triage_app_name';

-- Read-only: every statement runs in a read-only transaction.
SET default_transaction_read_only = on;

-- Bounded: no statement runs unbounded, and no catalog read queues behind DDL.
SET statement_timeout = :'db_triage_statement_timeout';
SET lock_timeout = :'db_triage_lock_timeout';
SET idle_in_transaction_session_timeout = '60s';

-- Quiet and cheap: no JIT compilation for catalog queries, no NOTICE spam.
SET client_min_messages = warning;
SET jit = off;

-- Deterministic output for the parser.
SET DateStyle = 'ISO, YMD';
SET bytea_output = 'hex';
