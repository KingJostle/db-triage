# Contributing to db-triage

## The rule that matters most

**Open an issue before writing SQL for a new check.** The priority, the category, the title,
the exact condition and — most importantly — *the false-positive story* have to be agreed
first. A check that fires on a healthy server costs more than a check that does not exist,
because it teaches the reader to skim.

Answer these in the issue:

| Question | Why |
|---|---|
| What breaks, and how fast? | Sets the priority band. "Eventually, maybe" is P100 or lower. |
| What is the false positive? | Every check has one. If you cannot name it, the check is not ready. |
| What does `details` say that a static sentence could not? | If nothing, this is a documentation page, not a check. |
| Which counter does it read, and when was it last reset? | Sets the confidence level. |
| Is it true on a replica? On RDS? On the oldest supported version? | Sets `run_on`, `platform_skip`, `min_version`. |
| What is the next action, in one imperative sentence? | If there isn't one, it belongs in the P200+ inventory bands. |

## Adding a check

1. **Take the next number in its category.** `docs/Checks_by_Priority.md` carries the
   current high ID for every `(engine, category)` pair. Never reuse a retired number and
   never renumber — suppression lists in the wild key on these.
2. **Add the registry row** to `checks/registry.csv` (PostgreSQL, engine-agnostic) or
   `checks/registry-mysql.csv`. Every column gets a value. `condition` is the sentence a
   human reads in the generated table; `thresholds` lists every number in it as
   `key=default`.
3. **Write `checks/<engine>/checks/<ID>.sql`.** It must:
   - start with `-- check: <ID>` and carry title, priority, scope and cost as comments;
   - return exactly `check_id, scope, object, details, evidence_json, confidence`;
   - reference each threshold as `:'<lower_check_id>_<key>'` (PostgreSQL — the namespacing
     is required because psql variables are session-global and bare keys collide);
   - contain nothing outside the read-only allow-list;
   - **degrade, never error, on old versions** — a `\if` guard on `server_version_num`, or
     a probe of `pg_attribute` for a column that moved;
   - handle quoted, case-sensitive and non-ASCII object names (use `format('%I')` or
     `quote_ident` when emitting SQL the reader will run);
   - build `details` from the values actually found. If two different servers would produce
     identical text, the check is wrong.
4. **Write the reference section** in `reference/checks-<engine>.md` with an explicit
   `<a id="<lower-id>"></a>` anchor and all six parts. The build fails without the anchor.
   "How to fix" must start with the safest option, and the CLI reads its first paragraph
   directly into the report's **Do** line — so write it as instructions, not as prose about
   instructions.
5. **Add a fixture** in `tests/fixtures/` that makes it fire, and list it in the fixture's
   summary block.
6. **Run the build and the checks:**
   ```
   bin/build.py --check          # must exit 0
   bin/build.py                  # regenerate the derived files
   psql -X -q -f checks/postgres/lib/thresholds.sql \
              -f checks/postgres/01_session.sql \
              -f checks/postgres/checks/<ID>.sql --csv
   ```
   Run that last command against the **oldest and newest** supported major versions. A check
   that errors on PostgreSQL 11 is a check that aborts someone's run.

## The read-only rule

Nothing in this repository may mutate data, schema or server state — including in examples
and in documentation snippets that a reader might paste. The single exception is
`tests/fixtures/`, which carries a loud destructive header and refuses to run against a
database whose name does not look like a throwaway.

`bin/build.py --check` greps every `.sql`, `.md` and `.yml` file outside `tests/fixtures/`
for `INSERT`, `UPDATE`, `DELETE`, `DROP`, `CREATE`, `ALTER`, `GRANT`, `REVOKE`, `VACUUM`,
`ANALYZE`, `REINDEX`, `CHECKPOINT`, `SET GLOBAL`, `LOCK TABLE` and for calls to
`pg_terminate_backend`, `pg_cancel_backend`, `pg_drop_replication_slot`, `pg_stat_reset*`,
`pg_switch_wal`, `pg_promote`, `setval` and friends. If you need to *show* a fix command,
put it inside a `**How to fix.**` paragraph in the reference document (prose lines starting
with `-` or `#` or `>` are exempt) rather than in a fenced SQL block.

## Retiring a check

Set `status=retired`, fill `superseded_by`, delete the SQL file, keep the row and the
reference section. Add a CHANGELOG entry. Never delete the row: the ID must stay reserved.

## Changing a threshold

Change the default in the registry's `thresholds` column, set `threshold_changed` to the
version you are releasing, and add a CHANGELOG entry with the old value, the new value and
the evidence. Thresholds are opinions; changing one needs a reason someone else can read.

## Style

- No emoji, no exclamation marks. The priority integer is the emphasis.
- Lead with the mechanism, not the metric.
- Every number carries a unit, and every rate carries the window it was measured over.
- Use *reported*, *estimated*, *since reset*, *at snapshot time*, *no evidence of*. Never
  "corrupt", "broken" or "unused" without the qualifier that applies.
- Recommendation first, then the alternatives, then the caveats.

## Checklist before opening a pull request

- [ ] `bin/build.py --check` exits 0
- [ ] `bin/build.py` produces no diff beyond the intended one
- [ ] The check ran against the oldest and the newest supported major version
- [ ] The reference section has an anchor and all six parts
- [ ] A fixture provokes it, and `tests/README.md` says what was verified
- [ ] Nothing new writes to the database
- [ ] CHANGELOG updated
