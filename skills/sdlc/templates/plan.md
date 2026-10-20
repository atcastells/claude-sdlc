# Plan: <title>

- **Derived from**: `spec.md`
- **Status**: draft | APPROVED BY ENGINEER
- **Nothing is implemented until this file is approved.**

## Done means

<A verifiable criterion, not an intention. E.g. "every endpoint uses the new
client, the old one is deleted, and `npm test` passes".>

## Stop and ask if

<When to stop during Build instead of deciding alone. E.g. "an existing test
fails for a reason unrelated to this change", "the DB schema must change".>

## Tasks

The *Status* column is updated as each task closes: it is the live list and
the resume point after compaction or a new session.

| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|--------------------|---------|---------|-----|--------|
| T1 | | | | R1 | main | — | 5m/500k | pending |

Keep *Status* the last column: the `plan-resume` hook reads the last cell.
Update it with Edit, not a shell command, and move a `main` task to
`in progress` before `done`: that is when `task-actuals` starts its clock.
Close a `main` task as `done (cause: <why it deviated from Est, or none>)`:
it is the only place `task-actuals` takes a main task's cause from.

- **Runs on**: `main` (Opus, the session); `implementer` (Sonnet 5.5: clear
  spec, listed files, a test that proves it); `scout` (Haiku 5.5: read-only
  lookups); `verifier` / `reviewer` (Sonnet 5.5). Haiku never edits.
- **Est**: `<minutes>m/<ktokens>k` (`12m/1.2M` allowed), from
  `bash ~/.claude/skills/sdlc/calibrate.sh <repo>`: the median actual of the
  runner when there is history, else the starting table.
- Each delegated task's prompt starts with `[sdlc:<slug>/T<n> est=<min>m/<ktok>k]`
  so the `task-actuals` hook can measure it.

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| 1 | T1, T2 | 5m | check `git diff --stat` |

Tasks in one wave have no pending dependency and disjoint Files. Launch a
wave's subagents in one message; after each wave, check `git diff --stat`
against the listed Files.

- **Estimated wall-clock**: sum over waves of the longest task (+ main checks)
- **Sequential sum**: <sum of all Est minutes>
- **Estimated tokens**: <sum of all Est tokens>

## Order and dependencies

<What goes before what, and why.>

## Test strategy

TDD for business logic: a red test before implementing.
If a test fails: fix the code, not the test.

- **Unit**: <what they cover>
- **Integration**: <what they cover>
- **Manual verification**: <what the verifier subagent looks at>

## Verification commands

```
<build>
<test>
<lint>
```

## Implementation risks

<What can go wrong when touching this code. Affected callers.>

## Estimate vs actual

Filled at Build close from `.sdlc/<slug>/actuals.jsonl` (written by the
`task-actuals` hook).

| # | Runs on | Est | Actual | Deviation | Cause |
|---|---------|-----|--------|-----------|-------|

List every task with |deviation| > 50 % and its cause. This calibrates
estimates, not people.

## Outside this plan

<What is left for later, explicitly.>

---
Next stage: Build implements, Test verifies, Deploy opens the PR.
