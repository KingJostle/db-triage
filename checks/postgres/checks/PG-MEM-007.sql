-- check: PG-MEM-007
-- title: random_page_cost at the spinning-disk default
-- priority: 150
-- scope: setting
-- cost: 0
-- thresholds: storage_class
-- storage_class comes from .db-triage.yml baseline.storage: hdd|ssd|nvme|cloud|unknown.
SELECT 'PG-MEM-007'::text          AS check_id,
       'setting'::text             AS scope,
       'random_page_cost'::text    AS object,
       format('random_page_cost = %s (the default), seq_page_cost = %s, with baseline.storage = %s. The 4:1 ratio models a spinning disk where a random seek costs four sequential reads. On SSD, NVMe and cloud block storage the real ratio is close to 1, and leaving it at 4 makes the planner prefer sequential scans over index scans on exactly the queries where an index would win. 1.1 for local NVMe and 1.1 to 2.0 for cloud volumes are the common settings. %s',
              s.setting,
              (SELECT setting FROM pg_settings WHERE name = 'seq_page_cost'),
              :'pg_mem_007_storage_class'::text,
              CASE WHEN :'pg_mem_007_storage_class' = 'unknown'
                   THEN 'Storage type was not supplied, so this is a guess: set baseline.storage in .db-triage.yml to confirm or silence it.'
                   ELSE '' END) AS details,
       json_build_object('random_page_cost', s.setting::numeric,
                         'seq_page_cost', (SELECT setting::numeric FROM pg_settings WHERE name = 'seq_page_cost'),
                         'source', s.source, 'storage_class', :'pg_mem_007_storage_class'::text,
                         'effective_cache_size', current_setting('effective_cache_size'))::text AS evidence_json,
       CASE WHEN :'pg_mem_007_storage_class' = 'unknown' THEN 'low' ELSE 'medium' END::text AS confidence
FROM pg_settings s
WHERE s.name = 'random_page_cost'
  AND s.setting::numeric = 4
  AND :'pg_mem_007_storage_class' IN ('ssd', 'nvme', 'cloud', 'unknown');
