-- check: PG-WAL-003
-- title: checkpoint_completion_target below 0.9
-- priority: 150
-- scope: setting
-- cost: 0
-- thresholds: target
SELECT 'PG-WAL-003'::text                 AS check_id,
       'setting'::text                    AS scope,
       'checkpoint_completion_target'::text AS object,
       format('checkpoint_completion_target = %s (threshold %s, default on this version %s), set in %s. The checkpointer spreads its writes over that fraction of the checkpoint interval; at %s it compresses the same dirty pages into the first %s%% of %s, which shows up as a periodic latency spike. 0.9 spreads them and is the default from PostgreSQL 14 onward.',
              s.setting, :'pg_wal_003_target'::text, s.boot_val, s.source,
              s.setting, round(100 * s.setting::numeric)::text,
              current_setting('checkpoint_timeout')) AS details,
       json_build_object('checkpoint_completion_target', s.setting::numeric,
                         'default', s.boot_val::numeric, 'threshold', :'pg_wal_003_target'::numeric,
                         'source', s.source,
                         'checkpoint_timeout', current_setting('checkpoint_timeout'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'checkpoint_completion_target'
  AND s.setting::numeric < :'pg_wal_003_target'::numeric;
