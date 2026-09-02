-- check: PG-QRY-010
-- title: Plan-hostile patterns in top statements
-- priority: 150
-- scope: query
-- cost: 1
-- thresholds: top_n, offset_rows
-- Regular expressions over normalised statement text. Every hit is a candidate,
-- not a defect: confidence is low by construction and this check never appears
-- in "Fix first".
\set ON_ERROR_STOP off
SELECT (to_regclass('pg_stat_statements') IS NOT NULL) AS pg_qry_010_pgss \gset
\if :pg_qry_010_pgss
SELECT EXISTS (SELECT 1 FROM pg_attribute
               WHERE attrelid = to_regclass('pg_stat_statements')
                 AND attname = 'total_exec_time' AND NOT attisdropped) AS pg_qry_010_v18 \gset
WITH q AS (
\if :pg_qry_010_v18
  SELECT queryid, query, calls, total_exec_time::numeric AS total_ms
  FROM pg_stat_statements WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
  ORDER BY total_exec_time DESC LIMIT :'pg_qry_010_top_n'::int
\else
  SELECT queryid, query, calls, total_time::numeric AS total_ms
  FROM pg_stat_statements WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
  ORDER BY total_time DESC LIMIT :'pg_qry_010_top_n'::int
\endif
),
flagged AS (
  SELECT q.*, p.pattern, p.explanation
  FROM q
  CROSS JOIN LATERAL (VALUES
    ('leading-wildcard LIKE',
     'A LIKE or ILIKE pattern that begins with % cannot use a B-tree index at all; a trigram index (pg_trgm) or full-text search is the usual answer. Note that pg_stat_statements replaces literals with $n, so a pattern supplied as a bound parameter is invisible here: this fires only where the wildcard is written into the SQL or concatenated in it.',
     q.query ~* 'i?like\s+(''%|''\s*\|\||concat\s*\(\s*''%)'),
    ('NOT IN (SELECT ...)',
     'NOT IN over a subquery that can produce NULL returns no rows at all, and the planner cannot turn it into an anti-join. NOT EXISTS is both correct with NULLs and plannable.',
     q.query ~* 'not\s+in\s*\(\s*select'),
    ('ORDER BY random()',
     'ORDER BY random() sorts the entire result set to return a few rows. TABLESAMPLE, or a random key lookup, does the same job without the sort.',
     q.query ~* 'order\s+by\s+random\s*\('),
    ('large OFFSET',
     'A large OFFSET makes the server produce and discard every skipped row on every page. Keyset pagination (WHERE key > last_seen ORDER BY key LIMIT n) reads only what it returns.',
     q.query ~* 'offset\s+\$?[0-9]{5,}'),
    ('function on an indexed column in WHERE',
     'Wrapping a column in lower(), upper() or a cast inside WHERE prevents a plain index on that column from being used; only a matching expression index helps.',
     q.query ~* 'where[^;]*\b(lower|upper)\s*\(\s*[a-z_][a-z0-9_.]*\s*\)\s*(=|like)'),
    ('unfiltered count(*)',
     'count(*) with no WHERE has to visit every row (or every visibility-map page); on a large table that cost is paid on every call.',
     q.query ~* '^\s*select\s+count\s*\(\s*\*\s*\)\s+from\s+[a-z_"][a-z0-9_."]*\s*(;|$)'),
    ('SELECT *',
     'SELECT * ships every column, defeats index-only scans, and breaks silently when the table gains a column.',
     q.query ~* '^\s*select\s+\*\s+from')
  ) AS p(pattern, explanation, matched)
  WHERE p.matched
)
SELECT 'PG-QRY-010'::text AS check_id,
       'query'::text      AS scope,
       ('queryid:' || f.queryid::text)::text AS object,
       format('Pattern "%s" found in a top-%s statement by total time (%s ms over %s calls). %s This is a regular expression over normalised statement text, so it is a candidate to read, not a defect: the pattern may be correct here, and the regex may have misread the statement. Statement: %s',
              f.pattern, :'pg_qry_010_top_n'::text,
              to_char(round(f.total_ms), 'FM999,999,999,999'),
              to_char(f.calls, 'FM999,999,999,999'),
              f.explanation,
              left(regexp_replace(f.query, '\s+', ' ', 'g'), 300)) AS details,
       json_build_object('queryid', f.queryid, 'pattern', f.pattern,
                         'calls', f.calls, 'total_ms', round(f.total_ms, 2),
                         'detection', 'regex over normalised query text',
                         'query', left(regexp_replace(f.query, '\s+', ' ', 'g'), 300))::text AS evidence_json,
       'low'::text AS confidence
FROM flagged f
ORDER BY f.total_ms DESC;
\endif
