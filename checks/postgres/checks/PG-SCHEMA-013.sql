-- check: PG-SCHEMA-013
-- title: Large objects present (vacuumlo candidate)
-- priority: 100
-- scope: database
-- cost: 1
-- thresholds: min_bytes
SELECT 'PG-SCHEMA-013'::text  AS check_id,
       'database'::text       AS scope,
       format('%I.pg_largeobject', current_database())::text AS object,
       format('pg_largeobject holds %s across %s large object(s) in database %s (threshold %s). A large object is not owned by the row that references its OID: deleting that row leaves the object behind forever, and nothing in the server ever notices. The standard sweep is the vacuumlo utility, which finds OIDs no column references and unlinks them - that is a write, so it is yours to schedule. pg_largeobject is also a normal table for vacuum purposes, so it bloats and freezes like one; its relfrozenxid age is %s.',
              pg_size_pretty(pg_total_relation_size('pg_largeobject'::regclass)),
              to_char((SELECT count(*) FROM pg_largeobject_metadata), 'FM999,999,999,999'),
              current_database(),
              pg_size_pretty(:'pg_schema_013_min_bytes'::bigint),
              to_char((SELECT age(relfrozenxid) FROM pg_class WHERE oid = 'pg_largeobject'::regclass), 'FM999,999,999,999')) AS details,
       json_build_object('database', current_database(),
                         'largeobject_bytes', pg_total_relation_size('pg_largeobject'::regclass),
                         'largeobject_count', (SELECT count(*) FROM pg_largeobject_metadata),
                         'threshold_bytes', :'pg_schema_013_min_bytes'::bigint,
                         'relfrozenxid_age', (SELECT age(relfrozenxid) FROM pg_class WHERE oid = 'pg_largeobject'::regclass))::text AS evidence_json,
       'high'::text AS confidence
WHERE pg_total_relation_size('pg_largeobject'::regclass) >= :'pg_schema_013_min_bytes'::bigint;
