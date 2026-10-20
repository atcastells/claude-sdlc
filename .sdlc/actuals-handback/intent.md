# Intent: Read subagent reports from the handback and calibrate across repos

- **Originator**: maintainer
- **Date**: 2026-10-20
- **Status**: approved by product owner (2026-10-20, "ok, approved, go on with the spec")
- **Slug**: actuals-handback

## The problem, in the originator's words

> "OK, check that session to see how the estimates are doing in % of hits."

> "Yes, start 2.3.1."

The review of the first real plan measured with 2.3.0 (another repo, slug
9 tasks) found three problems; 2.3.1 fixes them (released as 2.4.0: the
machine-level log is new behavior, MINOR by the CHANGELOG criteria).

## Who it affects

Every developer with 2.3.0 installed who delegates plan tasks to subagents.

## What happens if we do nothing

1. **The deviation cause is lost.** The 8 `implementer` runs wrote their
   `Deviation cause:` line, but delivered the report through the
   `SubagentHandback` tool (its input field `message`), not as final text.
   `task-actuals` reads `last_assistant_message`, so `cause` is empty in all
   8 lines. The "agent explains" half of the 2.3.0 intent does not work.
2. **The report check probably checks nothing.** `subagent-report-check`
   reads the same field. With an empty message it exits 2, yet no subagent
   was sent back: most likely the block has no effect once the report is
   handed back. Not confirmed live.
3. **Estimates do not improve across repos.** `calibrate.sh` reads only the
   current repo's `.sdlc/*/actuals.jsonl`. The second repo planned with the
   raw starting table and hit 0 of 9 tasks within ±50 %: implementers took
   0.12× the estimated minutes and 0.21× the tokens; 7 earlier measurements
   in this repo (0.30× / 0.44×) were not visible to it.
4. **Starting table too high.** 15 implementer measurements across two
   repos: 0.8–2.5 min and 160–410k tokens, with no visible effect of size
   S/M/L. The main session runs fewer minutes but more tokens than
   estimated (one sample: 5.1 min, 6.6M tokens against 30 min, 4M).
5. **Cause of a `main` task parsed badly.** The cause is taken from the
   Status cell and was cut mid-sentence.

## How we will know it is solved

- A handed-back implementer report puts its `Deviation cause:` into
  `actuals.jsonl`, and `subagent-report-check` sees the same report.
- Whether a SubagentStop block after a handback takes effect is known, from
  a live run, and the hook relies only on what works.
- A new repo's first plan starts from the history of the developer's other
  repos, not from the raw table.
- The starting table reflects the 15 measurements.
- Evals cover each change; suite green.

## Added before the plan was approved (2026-10-20)

> "Before approving: can something be done to have some shared context
> between subtasks?" → "1, yes, add it to this change."

6. **Subtasks share no context.** Each implementer starts fresh and
   re-reads spec, plan and code (160–410k tokens per task in the second
   repo), and what one learns (a test suite that needs the database, a
   container pointing at a remote database) never reaches the next.
   Chosen option: a short per-plan `context.md` in git that the main
   session writes before the first wave, every implementer reads first, and
   that grows with the `Learned:` lines of each wave's reports. Not chosen:
   `fork` subagents (run on the main model), agent teams (about seven times
   the tokens of a standard session, claude.dev "What a task costs on Opus
   5.5"), relying on a shared prompt cache between parallel subagents (not
   confirmed by the docs).
   Signal: implementer tokens per task in `actuals.jsonl`, before and after.

## Decisions (2026-10-20)

- Cross-repo history: **a machine-level log in `~/.claude`**, written by
  the hook next to the repo's own `actuals.jsonl`; `calibrate.sh` reads both.
  It never leaves the developer's machine.
- Weight: **the repo's own median from 5 measured tasks of that runner**;
  below that, the cross-repo median. `calibrate.sh` always shows both.
- Starting table: **rebuilt from the measurements** (originator, mid-turn:
  "see if you can improve the starting table based on the numbers we have
  from those subtasks").

## Measurements behind the new starting table

Minutes / tokens per task, both repos (`actuals.jsonl` plus the untagged
subagents measured from their transcripts with the hook's own logic):

| Runs on | n | Measured | Starting table today | Proposed |
|---|---|---|---|---|
| `implementer` S | 5 | 1.5–1.9m / 177–235k | 5m / 400k | 2m / 200k |
| `implementer` M | 8 | 0.8–2.5m / 164–380k (one 20.9m: permission waits) | 12m / 1.2M | 2m / 300k |
| `implementer` L | 2 | 1.5–2.4m / 247–407k | 25m / 3M | 3m / 400k |
| `scout` | 2 | 1.1–1.5m / 576–706k (largest single request 73K) | 2–4m / 60–90k | 1.5m / 650k |
| `verifier` | 1 | 7.6m / 661k | 6–15m / 0.5–2M | 8m / 700k |
| `main` | 1 | 5.1m / 6.6M | 5–30m / 0.5–4M | 5m / 6M |

- Backtest on the 15 implementer tasks (in-sample, so optimistic): within
  ±50 % in 13/15 for minutes and 15/15 for tokens, against 0/15 and 2/15
  with today's table. The two misses are the 20.9m permission wait and a
  0.8m task.
- Size barely moves implementer time; it moves tokens a little.
- The scout column today mixes two things: the 100K price step is **per
  request** (none crossed it), while the table counts **all requests of
  the task** (~15 per scout).
- `verifier`, `scout` and `main` rest on 1–2 samples: marked low
  confidence until calibration has more.

## Open questions

- How the cause of a `main` task should be written so it parses reliably
  (e.g. a `Deviation cause:` note in the Status cell).

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.
