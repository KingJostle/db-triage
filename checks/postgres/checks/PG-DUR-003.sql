-- check: PG-DUR-003
-- title: synchronous_commit off cluster-wide
-- priority: 10
-- scope: setting
-- cost: 0
SELECT 'PG-DUR-003'::text            AS check_id,
       'setting'::text               AS scope,
       'synchronous_commit'::text    AS object,
       format('synchronous_commit = off at server level (set in %s%s). COMMIT returns before the WAL record is flushed, so a crash of the server process or the host loses every transaction committed in roughly the last %s ms (three times wal_writer_delay). No transaction is torn and the cluster stays consistent; the loss is bounded and silent. %s per-database or per-role override(s) exist (see PG-CFG-002). This is often deliberate on a queue or cache database and always worth stating explicitly.',
              s.source, coalesce(', ' || s.sourcefile || ':' || s.sourceline::text, ''),
              3 * (SELECT setting::int FROM pg_settings WHERE name = 'wal_writer_delay'),
              (SELECT count(*) FROM pg_db_role_setting r
               WHERE array_to_string(r.setconfig, ' ') LIKE '%synchronous_commit%')) AS details,
       json_build_object('synchronous_commit', s.setting, 'source', s.source,
                         'wal_writer_delay_ms', (SELECT setting::int FROM pg_settings WHERE name = 'wal_writer_delay'),
                         'bounded_loss_ms', 3 * (SELECT setting::int FROM pg_settings WHERE name = 'wal_writer_delay'),
                         'db_role_overrides', (SELECT count(*) FROM pg_db_role_setting r
                                               WHERE array_to_string(r.setconfig, ' ') LIKE '%synchronous_commit%'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'synchronous_commit' AND s.setting = 'off';
