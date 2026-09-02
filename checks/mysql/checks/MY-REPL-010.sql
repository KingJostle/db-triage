-- check: MY-REPL-010
-- title: Group Replication member not ONLINE
-- priority: 5 | category: REPL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql | min_version: 5.7.17 | requires: SELECT ON performance_schema.*
-- thresholds: min_members=3
-- reads: performance_schema.replication_group_members
-- MySQL only. MariaDB has no Group Replication and no such table (verified
-- absent on 10.11) — Galera is its cluster technology and exposes
-- wsrep_* status variables instead, which is a different check not in this
-- catalog. The table-existence gate keeps MariaDB from erroring.
-- A member in RECOVERING, UNREACHABLE or ERROR state is not carrying traffic and
-- is not counted toward quorum; a group that drops below a majority stops
-- accepting writes entirely.
SET @dbt_q := "
SELECT
  'MY-REPL-010' AS check_id,
  'cluster'     AS scope,
  'group-replication' AS object,
  CONCAT('Group Replication group ', IFNULL(g.grp, 'unknown'), ' has ', g.total,
         ' member(s), ', g.online, ' ONLINE. ',
         IF(g.bad > 0, CONCAT('Not ONLINE: ', g.bad_list, '. '), ''),
         IF(g.total < COALESCE(@min_members, 3),
            CONCAT('A group of ', g.total, ' cannot tolerate a single failure and keep a majority; ',
                   COALESCE(@min_members, 3), ' is the minimum for fault tolerance. '), ''),
         'Members not ONLINE neither serve reads nor count toward quorum.') AS details,
  JSON_OBJECT(
    'group_name', g.grp,
    'member_count', g.total,
    'online_count', g.online,
    'not_online', g.bad_list,
    'min_members', COALESCE(@min_members, 3)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT MAX(CHANNEL_NAME) AS grp,
         COUNT(*) AS total,
         SUM(MEMBER_STATE = 'ONLINE') AS online,
         SUM(MEMBER_STATE <> 'ONLINE') AS bad,
         SUBSTRING(GROUP_CONCAT(IF(MEMBER_STATE <> 'ONLINE',
           CONCAT(MEMBER_HOST, ':', MEMBER_PORT, ' = ', MEMBER_STATE), NULL)
           SEPARATOR ', '), 1, 400) AS bad_list
    FROM performance_schema.replication_group_members
) AS g
WHERE g.total > 0
  AND (g.bad > 0 OR g.total < COALESCE(@min_members, 3))";
SET @dbt_q := IF(IFNULL(@dbt_has_group_members, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
