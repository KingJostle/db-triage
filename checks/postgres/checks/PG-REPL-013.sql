-- check: PG-REPL-013
-- title: Published table without a usable replica identity
-- priority: 10
-- scope: relation
-- cost: 1
-- min_version: 10
-- run_on: primary
SELECT 'PG-REPL-013'::text AS check_id,
       'relation'::text    AS scope,
       format('%I.%I.%I', current_database(), pt.schemaname, pt.tablename)::text AS object,
       format('Table %s.%s is published by %s for UPDATE and/or DELETE but its REPLICA IDENTITY is %s. UPDATE and DELETE against it raise "cannot update table ... because it does not have a replica identity and publishes updates" and the statement fails. Set a primary key, or ALTER TABLE %s.%s REPLICA IDENTITY USING INDEX <a unique, non-partial, NOT NULL index>, or as a last resort REPLICA IDENTITY FULL (which ships the whole old row: see PG-SCHEMA-004).',
              pt.schemaname, pt.tablename, p.pubname,
              CASE c.relreplident WHEN 'n' THEN 'NOTHING'
                                  WHEN 'd' THEN 'DEFAULT with no primary key'
                                  WHEN 'i' THEN 'USING INDEX but no valid replica-identity index exists'
                                  ELSE c.relreplident::text END,
              quote_ident(pt.schemaname), quote_ident(pt.tablename)) AS details,
       json_build_object('schema', pt.schemaname, 'table', pt.tablename,
                         'publication', p.pubname, 'relreplident', c.relreplident::text,
                         'pubupdate', p.pubupdate, 'pubdelete', p.pubdelete,
                         'has_primary_key', EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.oid AND i.indisprimary AND i.indisvalid),
                         'total_bytes', pg_total_relation_size(c.oid))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_publication_tables pt
JOIN pg_publication p  ON p.pubname = pt.pubname
JOIN pg_namespace n    ON n.nspname = pt.schemaname
JOIN pg_class c        ON c.relname = pt.tablename AND c.relnamespace = n.oid
WHERE (p.pubupdate OR p.pubdelete)
  AND (c.relreplident = 'n'
    OR (c.relreplident = 'd'
        AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.oid AND i.indisprimary AND i.indisvalid))
    OR (c.relreplident = 'i'
        AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.oid AND i.indisreplident AND i.indisvalid)));
