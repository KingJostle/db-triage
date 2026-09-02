-- check: PG-WRAP-007
-- title: autovacuum_freeze_max_age raised to 1 billion or more
-- priority: 20
-- scope: setting
-- cost: 0
-- thresholds: freeze_max_age
SELECT 'PG-WRAP-007'::text AS check_id,
       'setting'::text     AS scope,
       s.name::text        AS object,
       format('%s = %s (default %s, threshold %s), set in %s. The forced anti-wraparound vacuum now starts %s XIDs later, which leaves %s XIDs of headroom before the 2,147,483,648 limit instead of the %s the default gives. On a large table the emergency freeze can take longer than that headroom allows.',
              s.name, to_char(s.setting::bigint, 'FM999,999,999,999'),
              to_char(s.boot_val::bigint, 'FM999,999,999,999'),
              to_char(:'pg_wrap_007_freeze_max_age'::bigint, 'FM999,999,999,999'),
              s.source,
              to_char(s.setting::bigint - s.boot_val::bigint, 'FM999,999,999,999'),
              to_char(2147483648::bigint - s.setting::bigint, 'FM999,999,999,999'),
              to_char(2147483648::bigint - s.boot_val::bigint, 'FM999,999,999,999')) AS details,
       json_build_object(
              'setting', s.name, 'value', s.setting::bigint, 'default', s.boot_val::bigint,
              'source', s.source, 'threshold', :'pg_wrap_007_freeze_max_age'::bigint,
              'headroom_xids', 2147483648::bigint - s.setting::bigint)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name IN ('autovacuum_freeze_max_age', 'autovacuum_multixact_freeze_max_age')
  AND s.setting::bigint >= :'pg_wrap_007_freeze_max_age'::bigint;
