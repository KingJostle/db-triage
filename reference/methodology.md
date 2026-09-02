# Methodology

## Lineage and credit

db-triage is **structurally modelled on Brent Ozar's SQL Server First Responder Kit**, in
particular `sp_Blitz`. What was borrowed is the shape of the idea, and it is worth naming
precisely:

1. **A single integer priority** shared across every category, so one ranked list
   interleaves a security finding, a vacuum finding and a backup finding correctly.
2. **A reserved P1 band** for "the reasons you get fired", protected by never using it for
   anything less.
3. **A documented ceiling** (`≤ 50`) that an unattended scheduled job filters on, so the
   tool is useful lights-out without being noisy.
4. **Stable check IDs, never reused and never renumbered**, because suppression lists and
   trend tracking key on them.
5. **`Details` built dynamically from the values actually found.** sp_Blitz's rule, kept
   verbatim: if two different servers produce identical details text for a check that
   measures something, the check is wrong.
6. **A reserved high band for descriptive rows** — environment, configuration, workload —
   so the health check doubles as an inventory of the estate.
7. **Suppression that lives outside the tool**, in the user's own file, so it survives
   upgrades and re-runs.
8. **Cost-aware execution with explicit safety rails**: the expensive checks are opt-in,
   and there is a named rail before running them across a large estate.
9. **First responder, not surgeon.** It never fixes anything.

**No code was copied.** The First Responder Kit is T-SQL against SQL Server DMVs; none of
that is portable to PostgreSQL or MySQL, and none of it was translated. Every check in this
repository was derived from how PostgreSQL and MySQL actually fail, written against their
own catalogs, and tested against a live server.

**db-triage is not affiliated with, endorsed by, or supported by Brent Ozar Unlimited.**
If you run SQL Server, use the First Responder Kit itself:
<https://www.brentozar.com/first-aid/>.

## Tenets

**First responder, not surgeon.** db-triage establishes the patient's condition and orders
the problems. Every "next action" is text for a human to run. It has no code path that
mutates anything, and the session it opens is configured so that a bug could not.

**Read-only is enforced by the session, not by convention.** `default_transaction_read_only
= on`, `statement_timeout`, `lock_timeout`, `idle_in_transaction_session_timeout` and an
identifiable `application_name` are set before any check runs, and the forbidden-statement
list is lint-checked by `bin/build.py --check` across the whole repository.

**Uncertainty is a first-class field.** Every finding carries `confidence`, and the report
has a mandatory Caveats section built from it. The biggest way this class of tool fails is
not by missing something — it is by sounding sure about something it estimated.

**Thresholds are opinions, and they say so.** Every number is in the registry, every number
is overridable per target, and the reference section for each check names the assumption
behind the number rather than presenting it as physics.

**A title must be true of everything it reports, and a threshold must survive its own
window.** A check whose title claims a magnitude has to enforce that magnitude; when the
same underlying condition has two urgencies, they get two IDs and two bands, so suppressing
the mild one can never hide the severe one. And a threshold read off a cumulative counter
(`n_tup_upd`, `seq_scan`, `calls`, `sessions`) measures the age of the statistics as much as
the workload: a lifetime count of 1,000 is a busy hour or four idle months, and the check
cannot tell which. Where the number is meant to say "this is happening often", it is
divided by the statistics window and expressed as a rate. **Known limitation:**
`PG-IDX-010`, `PG-IDX-012`, `PG-SCHEMA-009`, `PG-VAC-012` and `PG-QRY-016` still gate on
lifetime counters (1,000,000 writes or calls, 100 sequential scans). Each is one to three
orders of magnitude above the figure that made `PG-IDX-008` misfire, and each is paired with
a size or ratio gate, so none of them is a live false-positive source — but on a cluster
whose counters have run for years they will drift toward being one, and they are the next
candidates for the same rate treatment.

**Absence of evidence is not evidence of absence.** "No monitoring agent is connected right
now" is not "there is no monitoring". Checks of that shape are `confidence: low`, are
phrased as *no evidence of*, and can be answered once in the config so they stop firing.

**The tool must be able to say what it could not see.** Every check that did not run is
listed with a reason. A report that silently omits the backup checks because the role
lacked a privilege is worse than no report, because the reader will believe backups are
fine.

## How to present findings to a client

Three deliverable sizes, matching the effort available:

| Time | Deliverable | How |
|---|---|---|
| 10 minutes | The ranked list | `--format summary`. Sections 0–2 only: the verdict, the meta rows, the rollup. |
| 1–2 hours | Written assessment | `--format markdown`. Work section 1 into the client's own language, add what you know about their environment that the tool cannot see, and keep the effort/risk column — it is what turns a list into a plan. |
| Full engagement | Walkthrough | The full report plus the deep pass, plus a second run a week later with `--compare` so the trend is visible. |

Rules that make the difference between a report that gets acted on and one that gets
filed:

1. **Roll up before you detail.** "14 databases have this problem" lands; fourteen separate
   rows do not.
2. **Lead with the mechanism, not the metric.** "Commits are hanging right now" before
   "`sync_state` has no `sync` row".
3. **Do not try to fix everything.** Take the top band. A list of sixty items is a list
   nobody starts.
4. **Give every P≤10 item a validation step and a failure mode.** The reader needs to know
   how they will know it worked, and what to do if it does not.
5. **Say what you could not check.** Appendix A is not padding; it is the difference
   between an assessment and a guess.

## The workflow this encodes

1. **Triage first, always.** Run the fast pass before chasing any symptom. The thing the
   user reported is frequently not the thing that will take the database down.
2. **Read the META band before believing anything else.** A statistics reset three hours
   ago invalidates every rate in the report.
3. **Work the ranked list top-down**, and re-run the individual check to prove each fix.
4. **Then go deeper with the right tool**: `EXPLAIN (ANALYZE, BUFFERS)` for a statement
   `PG-QRY-008` named, `pgstattuple_approx` before acting on an estimated-bloat finding,
   `pg_amcheck` when `PG-CORR-006` fires, a real restore test for anything in `BAK`.
5. **Record the answers.** Interview answers, expected superusers, RAM and storage class go
   in `.db-triage.yml` so the second run is quieter and more accurate than the first.
