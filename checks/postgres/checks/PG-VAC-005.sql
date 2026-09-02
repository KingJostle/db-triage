-- check: PG-VAC-005
-- title: Old transaction horizon holding back vacuum
-- priority: 50
-- scope: cluster
-- cost: 0
-- min_version: 9.6
-- thresholds: xmin_age
WITH horizons AS (
  SELECT 'backend'::text AS source_kind,
         format('pid %s (%s / %s, state %s, xact_start %s)', a.pid,
                coalesce(nullif(a.usename, ''), '?'), coalesce(nullif(a.application_name, ''), 'no application_name'),
                coalesce(a.state, '?'), coalesce(a.xact_start::text, 'none')) AS source_name,
         age(a.backend_xmin) AS xmin_age,
         extract(epoch FROM now() - a.xact_start)::bigint AS age_seconds
  FROM pg_stat_activity a WHERE a.backend_xmin IS NOT NULL AND a.pid <> pg_backend_pid()
  UNION ALL
  SELECT 'replication slot', format('slot %s (%s, %s, active=%s)', s.slot_name, s.slot_type,
                                    coalesce(s.plugin, 'physical'), s.active),
         greatest(age(s.xmin), age(s.catalog_xmin)), NULL
  FROM pg_replication_slots s WHERE s.xmin IS NOT NULL OR s.catalog_xmin IS NOT NULL
  UNION ALL
  SELECT 'prepared transaction', format('gid %s (owner %s, prepared %s)', p.gid, p.owner, p.prepared),
         age(p.transaction), extract(epoch FROM now() - p.prepared)::bigint
  FROM pg_prepared_xacts p
  UNION ALL
  SELECT 'standby feedback', format('standby %s from %s (%s)', coalesce(nullif(r.application_name, ''), '?'),
                                    coalesce(host(r.client_addr), 'local'), r.state),
         age(r.backend_xmin), NULL
  FROM pg_stat_replication r WHERE r.backend_xmin IS NOT NULL
)
SELECT 'PG-VAC-005'::text AS check_id,
       'cluster'::text    AS scope,
       NULL::text         AS object,
       format('Oldest xmin horizon is %s XIDs old (threshold %s), held by %s: %s.%s Vacuum cannot remove any row version newer than that horizon anywhere in the cluster, in any database, so dead tuples accumulate and freezing stalls.',
              to_char(h.xmin_age, 'FM999,999,999,999'),
              to_char(:'pg_vac_005_xmin_age'::bigint, 'FM999,999,999,999'),
              h.source_kind, h.source_name,
              CASE WHEN h.age_seconds IS NOT NULL
                   THEN ' It has been open for ' || justify_interval(date_trunc('second', make_interval(secs => h.age_seconds))) || '.'
                   ELSE '' END) AS details,
       json_build_object('source_kind', h.source_kind, 'source', h.source_name,
                         'xmin_age', h.xmin_age, 'threshold', :'pg_vac_005_xmin_age'::bigint,
                         'open_seconds', h.age_seconds,
                         'autovacuum_freeze_max_age', current_setting('autovacuum_freeze_max_age')::bigint)::text AS evidence_json,
       'high'::text AS confidence
FROM horizons h
WHERE h.xmin_age >= :'pg_vac_005_xmin_age'::bigint
ORDER BY h.xmin_age DESC
LIMIT 5;
