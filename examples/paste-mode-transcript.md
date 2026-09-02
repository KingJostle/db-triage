# Paste mode, end to end

What rung 4 of the access ladder actually looks like: no shell on the database host, no
network route from where Claude is running, no MCP connector. One command goes out, one
file comes back, and the report is the same report a direct run would have produced —
because the pasted output and the live run go through the same evaluation path
(`bin/db-triage --offline`).

---

**User:** Can you do a health check on our production Postgres? I can't give you access to
it, but I can run things against it.

**Claude:** Yes. It is read-only, bounded and identifiable as `db-triage` in
`pg_stat_activity`, so it is safe to run against a primary during business hours — nothing
is changed. Since I have no route to the database, I will hand you one command and read
what it produces.

Save this file, then run the command. It needs `psql` and a connection; a role with
`pg_monitor` gives the most complete result, and a plain login role still gets most of it.

> `db-triage-preflight.sql` — `checks/postgres/00_preflight.sql`, and
> `db-triage-fast.sql` — the embedded fast pass from `SKILL.md` §10, or
> `checks/postgres/fast-cluster.sql` if you have the repository.

```
psql "$YOUR_DSN" -X -q -f db-triage-preflight.sql --csv >  triage.csv 2>&1
psql "$YOUR_DSN" -X -q -f db-triage-fast.sql      --csv >> triage.csv 2>&1
```

Then paste `triage.csv` back to me. Three notes before you run it:

- The preflight line comes first for a reason. It is what tells me the version and whether
  this is a managed platform. Without it I cannot apply the platform adaptations, so on RDS
  or Neon I would report settings your provider owns and you cannot change — `fsync`,
  `archive_mode`, `ssl` — as though they were your problems.

- `2>&1` is deliberate. Some checks need privileges your role may not have; those raise a
  permission error, and I need to see the error next to the check it belongs to so I can
  tell you which checks were blind rather than silently reporting them as clean.
- If you can, run it once more per database with `fast-database.sql` — the index, bloat,
  sequence and schema checks read per-database catalogs and only see the one you connect to.

---

**User:** Here you go.

```
@@RUN-BEGIN fast cluster
@@TARGET triage_test 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1) primary
@@CHECK PG-BAK-001
check_id,scope,object,details,evidence_json,confidence
PG-BAK-001,setting,archive_mode,"archive_mode = off (set in default) on a primary. Without
archived WAL there is no point-in-time recovery: the only recoverable states are whatever
full backups exist, and every transaction since the newest one is unrecoverable. wal_level =
replica, cluster size 168 MB. A pg_dump is a logical export, not PITR.","{""archive_mode"" :
""off"", ""wal_level"" : ""replica""}",medium
@@END PG-BAK-001
@@CHECK PG-BAK-002
check_id,scope,object,details,evidence_json,confidence
@@END PG-BAK-002
...
@@CHECK PG-CORR-004
check_id,scope,object,details,evidence_json,confidence
PG-CORR-004,cluster,data_checksums,"data_checksums = off. Pages carry no checksum, so
storage corruption is detected only when it happens to break a structure PostgreSQL
validates; otherwise a flipped bit returns a wrong answer, and keeps returning it, into
reports and into backups. Cluster holds 168 MB.","{""data_checksums"" : ""off"",
""cluster_bytes"" : 176312320}",high
@@END PG-CORR-004
...
@@SKIP PG-REPL-008 needs PostgreSQL 9.6 or newer; standby only
@@SKIP PG-REPL-011 standby only
@@SKIP PG-REPL-016 standby only
@@RUN-END fast cluster
```

---

**Claude:** Read it. Three things need action, and one of them is that I could not check
your backups.

*(Claude runs `bin/db-triage --offline triage.csv --format markdown`, or evaluates the
markers directly against the priorities and thresholds in `SKILL.md` when the repository is
not installed.)*

> **Verdict:** 3 findings need action today (P≤10); worst priority P1. PostgreSQL 16.13 ·
> self-managed · PRIMARY · fast mode · 18 findings, 3 checks skipped · counters cover 0.9
> days — **every rate below is measured over that window and means very little yet.**
>
> **1. Fix first**
>
> **1. [P1] PG-BAK-001 — No WAL archiving: point-in-time recovery impossible**
> *What:* `archive_mode = off` on a primary. wal_level = replica, cluster size 168 MB.
> *Do:* Decide the strategy before touching the setting — pgBackRest, Barman or WAL-G rather
> than a hand-written `archive_command`, because they also handle retention, verification
> and parallel restore. Then set `archive_mode = on` (needs a restart) and confirm
> `pg_stat_archiver.last_archived_time` advances.
> *Validate:* `SELECT * FROM pg_stat_archiver;` — `last_archived_time` should advance.
> *If it goes wrong:* until this is done, your recovery point is whenever the newest full
> backup was taken, and everything after it is unrecoverable.
>
> **8. Caveats**
> - Counters cover 0.9 days. Anything phrased as a rate, and every "0 scans since reset",
>   is not yet meaningful. Re-run in a week.
> - `PG-REPL-008`, `PG-REPL-011` and `PG-REPL-016` were skipped: they only apply to a
>   standby, and this is the primary.
> - **The backup checks are unverified, not clear.** `PG-BAK-008` needs either the output of
>   your backup tool or an answer from you.

**What I could not see, and what it would take:**

| Missing | Why | What unlocks it |
|---|---|---|
| Per-database index, bloat, sequence and schema findings | `fast-cluster.sql` reads shared catalogs only | run `fast-database.sql` once per database |
| Backup posture (`PG-BAK-008`, `PG-BAK-009`) | no backup tool output, no interview answer | paste `pgbackrest info` / `barman list-backups`, or answer the two questions below |
| Disk usage (`PG-CAP-001`, `PG-CAP-002`) | PostgreSQL has no disk-free function | paste `df -h` for the data directory and `pg_wal` |
| Host resources (`PG-MEM-002`, `PG-MEM-003`, `PG-INFO-002`) | RAM is not visible from SQL | tell me the RAM, or set `baseline.ram_gb` |
| `pg_hba.conf` posture (`PG-SEC-001/002/003/007`) | needs superuser | run the pass once as a superuser, or paste `pg_hba.conf` |
| Log-based checks (`PG-CORR-005`, `PG-REL-011`, `PG-REL-014`) | deep pass; needs log access | out of scope for a fast pass |

**Two questions, asked once:**

1. What takes base backups, and when did one last succeed?
2. When was a restore last tested end to end, and how long did it take?

Record the answers under `interview:` in `.db-triage.yml` and the backup findings stop
firing — and start being true.

---

## Notes on running paste mode well

**Always ask for `2>&1`.** Permission errors are information: they are what turns "no
security findings" into "the security checks could not run". A run that hides them produces
a report that reads as reassurance.

**Say what was not in the paste, every time.** The table above is not optional politeness;
it is the difference between an assessment and a guess. `SKILL.md` requires
`XX-META-001` with reason `no-input` for exactly this.

**One command, not five.** The user is doing you a favour and will run the first thing you
send. Ask for the per-database pass as a follow-up once the first one has told you which
databases matter.

**Never ask for a password, a DSN, or the connection string.** You do not need any of them:
the user runs the command, and `$YOUR_DSN` stays on their machine.

**The statistics window is the first thing to read.** In this transcript it was 0.9 days,
which makes every rate and every "0 scans since reset" close to meaningless. Saying so is
more useful than any of the findings that depended on it.
