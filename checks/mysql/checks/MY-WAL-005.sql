-- check: MY-WAL-005
-- title: innodb_io_capacity at its rotational-disk default on solid-state storage
-- priority: 150 | category: WAL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: interview
-- thresholds: io_capacity_default=200;io_capacity_max_default=2000
-- reads: @@GLOBAL.innodb_io_capacity, @@GLOBAL.innodb_io_capacity_max, @dbt_storage
-- Requires .db-triage.yml baseline.storage to say ssd, nvme or cloud. Without
-- that the runner does not surface this row, because 200 IOPS is the right
-- answer on a spinning disk and there is no way to tell from inside the server
-- what the storage actually is. This is the MySQL sibling of PostgreSQL's
-- random_page_cost=4 finding, and it carries the same caveat.
-- The number bounds background flushing, so leaving it at 200 on an NVMe device
-- means InnoDB deliberately uses a fraction of the device and lets checkpoint
-- age climb (MY-WAL-004) under load it could easily absorb.
SELECT
  'MY-WAL-005' AS check_id,
  'setting'    AS scope,
  'innodb_io_capacity' AS object,
  CONCAT('innodb_io_capacity = ', @@GLOBAL.innodb_io_capacity,
         ' and innodb_io_capacity_max = ', @@GLOBAL.innodb_io_capacity_max,
         ' — the defaults, which assume a rotational disk — while the declared storage is ',
         IFNULL(@dbt_storage, 'unknown'),
         '. Background flushing is capped well below what the device can do, so checkpoint age climbs under write bursts instead of draining.') AS details,
  JSON_OBJECT(
    'innodb_io_capacity', @@GLOBAL.innodb_io_capacity,
    'innodb_io_capacity_max', @@GLOBAL.innodb_io_capacity_max,
    'declared_storage', IFNULL(@dbt_storage, 'unknown'),
    'innodb_flush_neighbors', @@GLOBAL.innodb_flush_neighbors) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE LOWER(IFNULL(@dbt_storage, '')) IN ('ssd', 'nvme', 'cloud')
  AND @@GLOBAL.innodb_io_capacity <= COALESCE(@io_capacity_default, 200)
  AND @@GLOBAL.innodb_io_capacity_max <= COALESCE(@io_capacity_max_default, 2000);
