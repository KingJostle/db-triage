# Extending db-triage

## Adding a check to an existing engine

1. **Open an issue first.** Agree the priority, category, title, condition and — most
   importantly — *the false-positive story* before any SQL is written. A check that fires
   on a healthy server costs more than a check that does not exist.
2. **Take the next number in the category.** `docs/Checks_by_Priority.md` carries the
   current high ID for every `(engine, category)` pair. Never reuse a retired number and
   never renumber: suppression lists in the wild key on these.
3. **Add the registry row** to `checks/registry.csv` with every column filled. `condition`
   is the sentence a human reads in the generated table; `thresholds` lists every number in
   it as `key=default`.
4. **Write `checks/<engine>/checks/<ID>.sql`.** It must:
   - begin with `-- check: <ID>` and carry the title, priority, scope and cost as comments;
   - return exactly `check_id, scope, object, details, evidence_json, confidence`;
   - use `:'<lower_check_id>_<threshold_key>'` for every threshold in the registry row;
   - contain nothing outside the read-only allow-list (the build lints for this);
   - degrade rather than error on old versions — use a `\if` guard on
     `server_version_num`, or probe `pg_attribute` for a column that moved;
   - build `details` from the values actually found.
5. **Write the reference section** in `reference/checks-<engine>.md` with an explicit
   `<a id="<lower-id>"></a>` anchor, following the six-part template. The build fails
   without the anchor.
6. **Add a fixture** to `tests/fixtures/` that makes it fire, and record it in the fixture's
   summary block.
7. **Run `bin/build.py --check`, then `bin/build.py`,** and re-run the check against a live
   server on the oldest and newest supported versions.

## Retiring a check

Set `status=retired` and fill `superseded_by`. Keep the row. Delete the SQL file — the build
requires that a non-active row has no file. Add a CHANGELOG entry.

## Changing a threshold

Change the default in the registry's `thresholds` column, bump `threshold_changed` to the
version being released, and add a CHANGELOG entry saying what changed and why. A threshold
change is a minor version bump; changing a check's *meaning* is not a threshold change — it
retires the ID and issues a new one.

## Adding an engine

The finding model, priority bands, category taxonomy, CLI, suppression file and report
renderer are engine-neutral by design. Adding SQL Server, Oracle or CockroachDB is:

1. **Pick a two-letter engine code** and register it in the registry's `engine` enum and in
   `bin/db-triage`'s client map (`sqlcmd`, `sqlplus`, `cockroach sql`).
2. **Create `checks/<engine>/`** with `00_preflight.sql`, `01_session.sql` and `checks/`.
   The session file is the important one: it is where the read-only contract is enforced in
   that engine's own terms.
3. **Reuse the category codes.** Add a new code only for a mechanism with no cousin — the
   way `WRAP` (PostgreSQL wraparound) and `UNDO` (InnoDB purge) are siblings rather than one
   shared category. Do not invent a category because a name sounds better.
4. **Write `reference/checks-<engine>.md`** with anchors.
5. **Add fixtures** that provoke the checks, and a note in `tests/README.md` saying which
   version you verified against.
6. **Add the embedded fast pass** for the engine to `SKILL.md` between its markers.

The one thing that does *not* transfer is the catalog knowledge, which is the whole job.
Resist translating a check from another engine unless the mechanism is genuinely the same:
"unused index" means something different where index usage is not counted per instance, and
"backup age" means something different where the server has a backup history table.

## What a new check has to earn

Before adding one, answer these in the issue:

| Question | Why it matters |
|---|---|
| What breaks, and how fast? | Determines the priority band. If the answer is "eventually, maybe", it is P100 or lower. |
| What is the false positive? | Every check has one. If you cannot name it, you do not understand the check yet. |
| What does `details` say that a static sentence could not? | If nothing, the check is a documentation page, not a check. |
| Which counter does it read, and when was that counter last reset? | Determines the confidence level. |
| Is it true on a replica? On a managed platform? On the oldest supported version? | Determines `run_on`, `platform_skip` and `min_version`. |
| What is the next action, in one imperative sentence? | If there isn't one, the finding belongs in the P200+ inventory bands, not in the punch list. |
