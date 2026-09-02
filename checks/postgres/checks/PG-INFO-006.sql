-- check: PG-INFO-006
-- title: Autovacuum configuration
-- priority: 250
-- scope: setting
-- cost: 0
SELECT 'PG-INFO-006'::text AS check_id,
       'setting'::text     AS scope,
       'autovacuum'::text  AS object,
       format('autovacuum = %s, track_counts = %s, %s workers, naptime %s. Vacuum trigger: threshold %s + scale_factor %s x live rows. Analyze trigger: threshold %s + scale_factor %s x live rows. Insert trigger: %s + %s x rows. Freeze: freeze_max_age %s, multixact_freeze_max_age %s, freeze_min_age %s, table_age %s. Cost limiting: delay %s ms, limit %s (page_hit %s, page_miss %s, page_dirty %s), giving about %s MB/s of dirty pages per worker. Memory: autovacuum_work_mem %s, maintenance_work_mem %s. Logging: log_autovacuum_min_duration %s. %s relation(s) in this database override these with storage parameters (PG-CFG-003).',
              current_setting('autovacuum'), current_setting('track_counts'),
              current_setting('autovacuum_max_workers'), current_setting('autovacuum_naptime'),
              current_setting('autovacuum_vacuum_threshold'), current_setting('autovacuum_vacuum_scale_factor'),
              current_setting('autovacuum_analyze_threshold'), current_setting('autovacuum_analyze_scale_factor'),
              coalesce((SELECT setting FROM pg_settings WHERE name = 'autovacuum_vacuum_insert_threshold'), 'n/a (PostgreSQL 13+)'),
              coalesce((SELECT setting FROM pg_settings WHERE name = 'autovacuum_vacuum_insert_scale_factor'), 'n/a'),
              current_setting('autovacuum_freeze_max_age'), current_setting('autovacuum_multixact_freeze_max_age'),
              current_setting('vacuum_freeze_min_age'), current_setting('vacuum_freeze_table_age'),
              (SELECT setting FROM pg_settings WHERE name = 'autovacuum_vacuum_cost_delay'),
              (SELECT setting FROM pg_settings WHERE name = 'autovacuum_vacuum_cost_limit'),
              current_setting('vacuum_cost_page_hit'), current_setting('vacuum_cost_page_miss'),
              current_setting('vacuum_cost_page_dirty'),
              round(((CASE WHEN (SELECT setting::int FROM pg_settings WHERE name = 'autovacuum_vacuum_cost_limit') < 0
                           THEN (SELECT setting::numeric FROM pg_settings WHERE name = 'vacuum_cost_limit')
                           ELSE (SELECT setting::numeric FROM pg_settings WHERE name = 'autovacuum_vacuum_cost_limit') END)
                     / (SELECT setting::numeric FROM pg_settings WHERE name = 'vacuum_cost_page_dirty'))
                    * (1000.0 / greatest((SELECT setting::numeric FROM pg_settings WHERE name = 'autovacuum_vacuum_cost_delay'), 0.1))
                    * current_setting('block_size')::numeric / 1048576.0, 1)::text,
              current_setting('autovacuum_work_mem'), current_setting('maintenance_work_mem'),
              current_setting('log_autovacuum_min_duration'),
              (SELECT count(*) FROM pg_class WHERE array_to_string(reloptions, ' ') LIKE '%autovacuum%')) AS details,
       json_build_object('autovacuum', current_setting('autovacuum'),
                         'track_counts', current_setting('track_counts'),
                         'autovacuum_max_workers', current_setting('autovacuum_max_workers')::int,
                         'autovacuum_naptime', current_setting('autovacuum_naptime'),
                         'autovacuum_vacuum_threshold', current_setting('autovacuum_vacuum_threshold')::bigint,
                         'autovacuum_vacuum_scale_factor', current_setting('autovacuum_vacuum_scale_factor')::numeric,
                         'autovacuum_analyze_threshold', current_setting('autovacuum_analyze_threshold')::bigint,
                         'autovacuum_analyze_scale_factor', current_setting('autovacuum_analyze_scale_factor')::numeric,
                         'autovacuum_freeze_max_age', current_setting('autovacuum_freeze_max_age')::bigint,
                         'autovacuum_multixact_freeze_max_age', current_setting('autovacuum_multixact_freeze_max_age')::bigint,
                         'autovacuum_vacuum_cost_delay_ms', (SELECT setting::numeric FROM pg_settings WHERE name = 'autovacuum_vacuum_cost_delay'),
                         'autovacuum_vacuum_cost_limit', (SELECT setting::int FROM pg_settings WHERE name = 'autovacuum_vacuum_cost_limit'),
                         'vacuum_cost_limit', (SELECT setting::int FROM pg_settings WHERE name = 'vacuum_cost_limit'),
                         'relations_with_overrides', (SELECT count(*) FROM pg_class WHERE array_to_string(reloptions, ' ') LIKE '%autovacuum%'))::text AS evidence_json,
       'high'::text AS confidence;
