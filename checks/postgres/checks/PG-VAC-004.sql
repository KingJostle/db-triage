-- check: PG-VAC-004
-- title: Large tables never analyzed or with stale statistics
-- priority: 50
-- scope: relation
-- cost: 1
-- thresholds: never_analyzed_rows, stale_fraction, stale_min_rows, top_n
SELECT 'PG-VAC-004'::text AS check_id,
       'relation'::text   AS scope,
       format('%I.%I.%I', current_database(), t.schemaname, t.relname)::text AS object,
       CASE WHEN t.last_analyze IS NULL AND t.last_autoanalyze IS NULL
            THEN format('Never analyzed. %s live rows, %s modified since the last analyze, relation size %s. The planner has only the default estimates for this table, so row-count guesses can be wrong by orders of magnitude.',
                        to_char(t.n_live_tup, 'FM999,999,999,999'),
                        to_char(t.n_mod_since_analyze, 'FM999,999,999,999'),
                        pg_size_pretty(pg_relation_size(t.relid)))
            ELSE format('%s rows modified since the last analyze against %s live rows (%s%%, threshold %s%%). Last analyze %s, last autoanalyze %s. Relation size %s.',
                        to_char(t.n_mod_since_analyze, 'FM999,999,999,999'),
                        to_char(t.n_live_tup, 'FM999,999,999,999'),
                        round(100.0 * t.n_mod_since_analyze / nullif(t.n_live_tup, 0), 1)::text,
                        round(100 * :'pg_vac_004_stale_fraction'::numeric)::text,
                        coalesce(t.last_analyze::text, 'never'),
                        coalesce(t.last_autoanalyze::text, 'never'),
                        pg_size_pretty(pg_relation_size(t.relid)))
       END AS details,
       json_build_object('n_live_tup', t.n_live_tup, 'n_mod_since_analyze', t.n_mod_since_analyze,
                         'last_analyze', t.last_analyze, 'last_autoanalyze', t.last_autoanalyze,
                         'relation_bytes', pg_relation_size(t.relid),
                         'never_analyzed', (t.last_analyze IS NULL AND t.last_autoanalyze IS NULL),
                         'stale_fraction_threshold', :'pg_vac_004_stale_fraction'::numeric)::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_stat_user_tables t
WHERE (t.last_analyze IS NULL AND t.last_autoanalyze IS NULL
       AND t.n_live_tup >= :'pg_vac_004_never_analyzed_rows'::bigint)
   OR (t.n_mod_since_analyze > :'pg_vac_004_stale_fraction'::numeric * greatest(t.n_live_tup, 0)
       AND t.n_live_tup >= :'pg_vac_004_stale_min_rows'::bigint)
ORDER BY t.n_live_tup DESC
LIMIT :'pg_vac_004_top_n'::int;
