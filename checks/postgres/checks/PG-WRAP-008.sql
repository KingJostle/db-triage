-- check: PG-WRAP-008
-- title: vacuum_failsafe_age raised above the default
-- priority: 100
-- scope: setting
-- cost: 0
-- min_version: 14
-- thresholds: failsafe_age
SELECT 'PG-WRAP-008'::text AS check_id,
       'setting'::text     AS scope,
       s.name::text        AS object,
       format('%s = %s (default %s, threshold %s), set in %s. The failsafe is what makes a vacuum abandon cost delays and index cleanup so it can finish before wraparound; raising it delays that last automatic defence by %s XIDs.',
              s.name, to_char(s.setting::bigint, 'FM999,999,999,999'),
              to_char(s.boot_val::bigint, 'FM999,999,999,999'),
              to_char(:'pg_wrap_008_failsafe_age'::bigint, 'FM999,999,999,999'),
              s.source,
              to_char(s.setting::bigint - s.boot_val::bigint, 'FM999,999,999,999')) AS details,
       json_build_object('setting', s.name, 'value', s.setting::bigint, 'default', s.boot_val::bigint,
                         'source', s.source, 'threshold', :'pg_wrap_008_failsafe_age'::bigint)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name IN ('vacuum_failsafe_age', 'vacuum_multixact_failsafe_age')
  AND s.setting::bigint > :'pg_wrap_008_failsafe_age'::bigint;
