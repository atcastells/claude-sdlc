# Spec: Parallel, model-routed plans with time estimates and measured deviation

- **Derived from**: `intent.md`
- **Status**: approved (2026-10-20, "approved")
- **Approved by**: product owner (no policy owner needed: no personal or
  sensitive business data; see "Policy applied")

## Requirements

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | `plan.md` template: the task table gains `Runs on` (main, or agent + model + effort), `Depends`, `Est` (minutes + tokens) columns; `Status` stays the last column | "every task declares who runs it, what it depends on, an estimate" | Template has the columns; `plan-resume` cases 83a–83d stay green |
| R2 | `plan.md` template: a `Schedule` section groups tasks into waves; tasks in one wave touch disjoint files. It states the estimated wall-clock (sum over waves of the longest task) next to the sequential sum, and the total estimated tokens | "which tasks run in parallel and the estimated wall-clock of the whole plan" | Template section; eval |
| R3 | `plan.md` template: an `Estimate vs actual` section, filled at Build close from the actuals log, with every task over the threshold and its cause | "actual minutes and tokens and the deviation"; "recorded for self-improvement" | Template section; eval |
| R4 | New `implementer` agent: `model: sonnet`, `effort: medium`, tools `Read, Glob, Grep, Bash, Edit, Write`, `maxTurns: 40`. One plan task per invocation; edits only the files the task lists; red test first; no git writes. Report headed `TASK: <slug>/T<n>` with `RESULT: done\|blocked`, the test command and its result, files touched, and `Deviation cause:` | "a Sonnet 5.5 subagent implements well-specified plan tasks that have a test proving them"; "the agent explains" | `agents/implementer.md`; evals on frontmatter and report format |
| R5 | Every delegated plan task carries the tag `[sdlc:<slug>/T<n> est=<min>m/<ktok>k]` on the first line of the subagent prompt. The `sdlc` skill says so | Needed by R6 to tie a measurement to a task | Text in skill; eval |
| R6 | `task-actuals` hook on `SubagentStop` (any agent): reads `agent_transcript_path`; if its first `user` message carries the R5 tag, appends one JSON line to `<cwd>/.sdlc/<slug>/actuals.jsonl`: task, agent, model, est, actual minutes (first → last timestamp), actual tokens (sum of `usage` deduplicated by `message.id`), output tokens, deviation %, `flag` when \|deviation\| > 50 %, and the report's `Deviation cause:` line. No tag → nothing. Never blocks | "the actual time comes from a hook, not from the agent's word"; "recorded for self-improvement" | Hook evals with a fixture transcript: tagged → line appended with the right numbers; duplicated ids counted once; untagged → no file; missing transcript → exit 0 |
| R7 | `task-actuals` on `PostToolUse` for `Edit\|Write` of `.sdlc/*/plan.md`: for task rows whose `Runs on` is `main`, a status that turns `in progress` records a start; one that turns `done` records the end and appends the same JSON line, with tokens summed from the main `transcript_path` between both timestamps | "every plan task is estimated and measured, whoever runs it" | Hook evals with fixtures: start recorded; done appends a line; delegated rows ignored; a row already measured is not duplicated |
| R8 | `subagent-report-check` also checks `implementer`: requires `TASK:` and `RESULT: done\|blocked` lines and a `Deviation cause:` line | "subagents must be able to report the deviation" | Hook evals: ok → 0; no `TASK:` → 2; no cause → 2 |
| R9 | `skills/sdlc/calibrate.sh <repo>`: reads every `.sdlc/*/actuals.jsonl` and prints, per `Runs on`, the count, the median ratio actual/estimate for minutes and tokens, and the flagged tasks. Prints the starting table when there is no history | "kept where the next plan reads them, so later estimates move closer" | Script evals with fixtures: no history → starting table; with history → medians |
| R10 | `sdlc` Stage 3: before writing `plan.md`, run `calibrate.sh` and scale the starting estimates by its medians; route each task down the ladder (Haiku reads, Sonnet implements well-specified tasks with a proving test, Sonnet verifies and reviews, the main session integrates, decides and edits across tasks); launch each wave's subagents in one message; after a wave, check `git diff --stat` against the files the plan lists; at Build close, fill `Estimate vs actual` | All of "How we will know it is solved" | Text; evals; `sdlc` within its line budget (case 79) |
| R11 | `sdlc` ladder updated: the 2.1.0 rule "small models never edit" becomes "Haiku never edits; Sonnet edits only through `implementer`, one task with a proving test" | Originator's answer "Sonnet implements"; replaces decision of 2.1.0 | Case 85b updated in the same change; text |
| R12 | Hooks registered in `settings.template.json`: `SubagentStop` without matcher for `task-actuals`; `PostToolUse` `Edit\|Write` for `task-actuals`; `SubagentStop` `implementer` for `subagent-report-check` | R6, R7, R8 | Registration evals |
| R13 | `sdlc-README.md` template lists `actuals.jsonl`; version 2.3.0 with `CHANGELOG.md` and `migrations/2.3.0.md` | Release rules in `CLAUDE.md` | Case 40; migration eval; suite, check-public and clean install green |

## Design

### Starting estimates (R9, printed by `calibrate.sh` with no history)

Our own values, not sourced: no claude.dev page gives durations by task
type. The closest data point: a feature took 4 / 11 / 67 min at medium /
high / max effort (claude.dev, "Spending your effort"). The first plans
correct them through R9.

| Runs on | S | M | L |
|---|---|---|---|
| `scout` (Haiku 5.5, medium) | 2 m / 60k | 4 m / 90k | split it: stay under 100K prompt |
| `implementer` (Sonnet 5.5, medium) | 5 m / 400k | 12 m / 1.2M | 25 m / 3M |
| `verifier` / `reviewer` (Sonnet 5.5, high) | 6 m / 500k | 10 m / 1M | 15 m / 2M |
| main (Opus 5.5, medium) | 5 m / 500k | 15 m / 2M | 30 m / 4M |

Size: S = one file and its test; M = 2–4 files; L = more, or unknown code.
Tokens = input + cache writes + cache reads + output, the figure the
transcript gives; most of it is cache reads.

### Routing (R10, R11)

| Work | Runs on | Why |
|---|---|---|
| Lookups, logs, test output | `scout` (Haiku 5.5) | Fastest, from $0.10 / $0.50 per Mtok (platform.claude.com) |
| Task with a clear spec, listed files and a test that proves it | `implementer` (Sonnet 5.5) | "a clear spec and a way to check the result" (claude.dev, Sonnet 5.5); half Opus's price |
| Verification, review | `verifier`, `reviewer` (Sonnet 5.5) | Unchanged |
| Cross-task integration, design decisions, unclear or risky code | main (Opus 5.5) | "Keep judgment calls on the main model" (claude.dev, what a task costs) |

Haiku stays read-only: a small model that misreads "sends the main model
after the wrong file" (same source).

### Parallelism

- One wave = tasks with no pending dependency and disjoint `Files`. The
  main session launches the wave's subagents in a single message; they run
  in the background (default) in the same working tree.
- No `isolation: worktree`: bringing a worktree back needs `merge` or
  `cherry-pick`, reserved for the developer. Disjoint files replace
  isolation; after the wave the main session compares `git diff --stat`
  with the files the plan lists and stops if they differ.
- Concurrency stays far below the default limit of 20
  (code.claude.com, sub-agents).

### Measurement (R6, R7)

- One script, `hooks/task-actuals.sh`, branches on `hook_event_name`.
- Transcript shape checked on a real subagent transcript (2026-10-20): every
  line has `timestamp`; the prompt is the first `type: "user"` line with
  string content; `assistant` lines carry `message.usage` and repeat it once
  per content block with the same `message.id`, hence the deduplication.
- **Amended in Build (2026-10-20), `plan-resume`**: the new `Estimate vs
  actual` table also has `T<n>` rows, which `plan-resume` listed as open
  tasks after a compaction. When a plan has a `## Tasks` heading, only that
  section is read; plans without it keep the old behavior. Case 83e,
  `hooks/plan-resume.sh`, fixture `evals/fixtures/plan-actuals/`. Found by
  the main session while filling this plan's own table; recorded here after
  the conformance review flagged it as untraced.
- **Amended in Build (2026-10-20)**: `output_tokens` in the transcript is
  the stream-start value (`stop_reason: null`, a handful of tokens), so
  `out_ktok` is dropped from the log. `ktok` stays: input, cache writes and
  cache reads are complete at stream start and dominate the total. Checked
  on this plan's W1 transcripts: minutes match the `duration_ms` Claude Code
  reports for each subagent.
- Main-session start marks are lines of their own in the same
  `actuals.jsonl` (`{"task":"T2","event":"start","ts":...}`); the closing
  line is computed from the latest start of that task. One file, committed
  with the plan, no `.gitignore` change. `calibrate.sh` ignores start lines.
- The hook never blocks and never fails the session: any missing field,
  file or bad JSON → exit 0 silently.
- Payload-only testability: fixture transcripts under `evals/fixtures/`
  with the shape above; no `CLAUDE_PROJECT_DIR`.

### Log line (`actuals.jsonl`)

```json
{"task":"T3","runs_on":"implementer","model":"claude-sonnet-5-5",
 "est_min":5,"est_ktok":400,"min":7.5,"ktok":520,"out_ktok":9,
 "dev_min_pct":50,"dev_tok_pct":30,"flag":false,
 "cause":"two flaky test runs","date":"2026-10-20"}
```

No author, session or user field.

## Policy applied

- **Personal data**: none. The log has no author field; git authorship of
  the commit that adds it is the only link to a person, as with any file.
- **Sensitive business data**: none. Token counts and minutes, no prices,
  no content of prompts or reports beyond the one-line cause.
- **Credentials**: none.
- **Decisions about people / high risk**: no, provided the log is not used
  to assess individual developers. The `sdlc` skill says it calibrates
  estimates, not people. If anyone wants to use it for that, it becomes a
  case for the compliance contact.

## Out of scope

- Converting tokens to money (originator chose minutes + tokens).
- `isolation: worktree` and any agent-run merge.
- Haiku editing.
- Agent teams, dynamic workflows and cloud sessions for Build.
- Blocking or re-planning on a deviation: it is recorded, not enforced.
- A PreToolUse guard that stops an `implementer` from editing files outside
  its task (the post-wave `git diff --stat` check replaces it for now).

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Transcript format changes in a Claude Code update | Actuals stop being recorded | Hook exits 0 silently; eval fixture documents the expected shape; `verifier` checks it against a fresh real transcript |
| Transcript not fully flushed when `SubagentStop` fires | Last turn missing from minutes/tokens | Verified on a real run in Test; if it happens, read on the next `PostToolUse` |
| Two implementers edit the same file | Lost or mixed edits | Disjoint `Files` per wave; `git diff --stat` check after each wave |
| Main-session minutes include time waiting for the human | Main estimates look worse than they are | Documented in the skill; `cause` notes it |
| Sonnet implements something wrong | Rework on the main model | Only tasks with a proving test; `verifier` after Build; main session reviews every diff |
| Starting table is a guess | First deviations are large | Expected; calibration fixes it; flagged rows say why |
| `sdlc` exceeds its line budget | Case 79 red | Move the starting table and routing detail to `templates/plan.md` and `calibrate.sh` |
| `test-guard` / `credential-guard` not firing inside subagents | A weakened test slips through | Verify in Test that PreToolUse hooks fire for `implementer` edits |

---
Next stage: Build reads this file and writes `plan.md`.
