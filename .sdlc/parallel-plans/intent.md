# Intent: Parallel, model-routed plans with time estimates and measured deviation

- **Originator**: maintainer
- **Date**: 2026-10-20
- **Status**: approved by product owner (2026-10-20, "ok, approved, go on with the spec")
- **Slug**: parallel-plans

## The problem, in the originator's words

> "I want to improve the plans we make: bring parallel tasks into play, give
> a lot of weight to Sonnet and Haiku, and be able to measure the estimated
> time of each task. Check claude.dev for this. We must be able to give
> estimates; subagents must be able to report the deviation from the given
> estimate. The plan must be optimized for time and cost."

Answers to the scoping questions (2026-10-20):

- Who edits: **a Sonnet 5.5 subagent implements** well-specified plan tasks
  that have a test proving them, in its own worktree; the main session
  integrates and checks.
- Estimate unit: **minutes + tokens** (no conversion to money).
- Actual time: **a hook measures, the agent explains** the cause of the
  deviation.
- Scope: **every plan task** is estimated and measured, whoever runs it.
- A deviation is **recorded for self-improvement**: it does not stop the
  task; it feeds the calibration of future estimates (2026-10-20, "se anota
  para automejora").

## Who it affects

Every developer with the workflow installed, at every Stage 3 (Build).
Today `plan.md` is a sequential task list with no estimate, no model per
task and no actual time.

## What happens if we do nothing

- Plan tasks run one after another on the main model (Opus 5.5, $4 / $20 per
  Mtok) even when they are independent and well specified. Sonnet 5.5 costs
  half ($2 / $10) and is recommended for "fast feature iteration" and tasks
  with "a clear spec and a way to check the result" (claude.dev, "Building
  with Claude Sonnet 5.5"). Haiku 5.5 is listed "From $0.10 / $0.50" with
  the fastest latency (platform.claude.com, models overview).
- Nobody can say up front how long a plan will take, and nobody learns from
  the gap: there is no estimate to compare with, so estimates never improve.
- Wall-clock time is lost waiting on subagents that could run in parallel
  (up to 20 concurrent by default; code.claude.com, sub-agents).

## How we will know it is solved

- Every task in `plan.md` declares: who runs it (main session or which
  agent and model), what it depends on, an estimate in minutes and tokens,
  and, once closed, the actual minutes and tokens and the deviation.
- The plan shows which tasks run in parallel and the estimated wall-clock
  of the whole plan (critical path), not just the sum.
- A Sonnet subagent can take an implementation task in its own worktree and
  hand back a report with its estimate, the measured actual, the deviation
  and its cause.
- The actual time comes from a hook, not from the agent's word.
- Recorded deviations are kept where the next plan reads them, so later
  estimates move closer to the actuals.
- Evals cover each new rule; suite green.

## Facts found (sources)

- `PostToolUse` on the `Agent` tool, foreground run: `tool_response` carries
  `totalDurationMs`, `totalToolUseCount`, `resolvedModel`; `totalTokens` and
  `usage` cover **only the last API request**, not the whole run. Background
  runs (`async_launched`) carry no usage at all (code.claude.com, hooks).
- `SubagentStop` carries `agent_transcript_path` and no duration or token
  fields; the transcript is the source for background subagents (same page).
- Subagents start in the background by default; `isolation: worktree` gives
  each one its own copy of the repo (code.claude.com, sub-agents).
- Effort drives time: the same task took 4 / 11 / 67 min at medium / high /
  max in the author's tests (claude.dev, "Spending your effort").
- "Move down to Sonnet or Haiku for lookups, not for writing code" (claude.dev,
  "What a task costs on Opus 5.5"). The originator's answer narrows this for
  Sonnet: well-specified tasks with a proving test. Haiku stays read-only.

## Open questions

- How the main session's own tasks are timed and their tokens counted: no
  hook fires per plan task; `/usage` covers the whole session.
- Where the first estimates come from before there is history: a fixed table
  by task size and model, or past plans' actuals.
- The threshold above which a deviation is flagged (e.g. +50 %).
- How parallel worktree branches are merged back without git writes by the
  agent (git is reserved for the developer).

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.
