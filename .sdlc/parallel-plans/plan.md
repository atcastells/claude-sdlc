# Plan: Parallel, model-routed plans with time estimates and measured deviation

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-10-20)
- **Nothing is implemented until this file is approved.**

## Done means

- `bash evals/run.sh` → `FAIL: 0`, every new case seen red first.
- `WORKFLOW_PROFILE=profiles/<org> bash evals/run.sh` → `FAIL: 0`.
- `bash scripts/check-public.sh` → exit 0.
- `HOME=$(mktemp -d) ./install.sh --no-profile` → suite green; the temp
  `settings.json` registers `task-actuals` (SubagentStop, PostToolUse) and
  `subagent-report-check` for `implementer`; `~/.claude/agents/implementer.md`
  and `skills/sdlc/calibrate.sh` are installed.
- `bash -n` clean on the new scripts.
- `task-actuals.sh` run by hand on this plan's real subagent transcripts
  writes correct lines (minutes match the transcript's timestamps; tokens
  deduplicated).
- `verifier` verdict green or amber with its items resolved.
- The real `./install.sh` into `~/.claude` is run by the developer, not by
  the agent.

## Stop and ask if

- `skills/sdlc/SKILL.md` cannot stay within 160 lines (case 79) without
  dropping an existing rule.
- `install.sh` needs a change (the plan assumes it already copies the new
  files and `calibrate.sh` is run with `bash`, so no `chmod`).
- An implementer touched a file outside its task's `Files`
  (`git diff --stat` after each wave).
- A real subagent transcript is not complete when `SubagentStop` fires.
- `test-guard` or `credential-guard` do not fire on a subagent's edits.
- An existing eval turns red for a reason unrelated to this change.

## Tasks

`Runs on`: `implementer` = Sonnet 5.5, effort medium. The agent is not
installed in this session yet, so it is launched as `general-purpose` with
`model: sonnet`, `effort: medium` and the rules of spec R4 in the prompt,
first line tagged `[sdlc:parallel-plans/T<n> est=<min>m/<ktok>k]`.
`Est`: minutes / tokens, from the spec's starting table (no history yet).

| # | Task | Files | Test that proves it | Req | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|-----|---------|---------|-----|--------|
| T1 | Plan template: `Runs on`, `Depends`, `Est` columns (Status last), `Schedule` and `Estimate vs actual` sections | `skills/sdlc/templates/plan.md`, `evals/cases/100a..100c` | 100a columns header, 100b `## Schedule`, 100c `## Estimate vs actual`; 70–72 and 83a–83d green | R1–R3 | implementer | — | 5m/400k | done (W1; diff read) |
| T2 | `implementer` agent | `agents/implementer.md`, `evals/cases/101a..101e` | 101a `model: sonnet`, 101b `effort: medium`, 101c tools include `Edit, Write`, 101d `maxTurns: 40`, 101e report has `TASK:`, `RESULT:`, `Deviation cause:` | R4 | implementer | — | 5m/400k | done (W1; diff read) |
| T3 | `subagent-report-check` handles `implementer` | `hooks/subagent-report-check.sh`, `evals/cases/82h..82j` | 82h valid → 0; 82i no `TASK:` → 2; 82j no `Deviation cause:` → 2; 82a–82g green | R8 | implementer | — | 5m/400k | done (W1; diff read) |
| T4 | `task-actuals.sh`, SubagentStop branch | `hooks/task-actuals.sh`, `evals/fixtures/actuals/`, `evals/scripts/task-actuals-test.sh`, `evals/cases/102a` | Script scenarios in a temp dir: tagged transcript → one line with minutes from timestamps and tokens deduplicated by `message.id`; flag at >50 %; untagged → no file; missing transcript → exit 0 | R6 | implementer | — | 12m/1.2M | done (W1; diff read; out_ktok dropped in T5, see spec) |
| T5 | `task-actuals.sh`, PostToolUse branch on `plan.md` edits | `hooks/task-actuals.sh`, `evals/fixtures/actuals-main/`, `evals/scripts/task-actuals-test.sh` | Added scenarios: `in progress` → start line; `done` → closing line with tokens from the main transcript window; delegated row ignored; no duplicate on a second edit | R7 | implementer | T4 | 12m/1.2M | done (W2; diff read; main fixed ARG_MAX bug + scenario o) |
| T6 | `calibrate.sh` | `skills/sdlc/calibrate.sh`, `evals/fixtures/calibrate/`, `evals/cases/103a..103b` | 103a no history → starting table; 103b history → median ratio per `Runs on` and flagged tasks | R9 | implementer | — | 12m/1.2M | done (W1; diff read) |
| T7 | Register hooks | `settings.template.json`, `evals/cases/84d..84f` | 84d `task-actuals` on SubagentStop, 84e on PostToolUse, 84f `"matcher": "implementer"` | R12 | implementer | — | 5m/400k | done (W1; diff read) |
| T8 | `sdlc` Stage 3 and the ladder | `skills/sdlc/SKILL.md`, `evals/cases/85b`, `evals/cases/104a..104e` | 85b updated to the new rule; 104a tag format, 104b `calibrate.sh`, 104c one message per wave, 104d `git diff --stat`, 104e "estimates, not people"; 79 (≤160 lines) and 77–87 green | R5, R10, R11 | main | T1, T2, T6 | 15m/2M | done (moved into W1: names were fixed by the spec; ≤160 lines) |
| T9 | Release 2.3.0 | `skills/repo-setup/templates/sdlc-README.md`, `migrations/2.3.0.md`, `VERSION`, `CHANGELOG.md`, `evals/cases/41c` | 40 green; 41c migration installed; full suite, profile suite, check-public, clean install | R13 | main | T1–T8 | 5m/500k | done (suite 160/160, profile 171/171, check-public 0) |
| T10 | Verification | — | `verifier`: the change + two adjacent flows (`plan-resume` on the new table; `install.sh` settings merge) | all | verifier | T9 | 10m/1M | done (verifier amber: 1 IMPORTANT fixed + scenario p; 2 nits fixed with 82k, 100d; rest noted) |
| T11 | Real-run checks | — | `task-actuals.sh` by hand on W1/W2 transcripts; transcript complete at stop; guards fire on a subagent's edit | R6, Risks | main | T9 | 5m/500k | done (hook on real transcripts ok; guards fire in a subagent; transcript complete at stop) |

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| W1 | T1, T2, T3, T4, T6, T7 — six implementers, disjoint files | 12m | wave check: `git diff --stat` vs `Files`, read each diff, suite (~3m) |
| W2 | T5 (implementer) ‖ T8 (main; in the run, moved into W1) | 15m | wave check (~3m) |
| W3 | T9 | 5m | — |
| W4 | T10 (verifier) ‖ T11 (main) | 10m | consolidate (~3m) |

- **Estimated wall-clock**: 12 + 3 + 15 + 3 + 5 + 10 + 3 = **51 min**.
- **Sequential sum** of the same tasks: 91 min + 9 min of checks = 100 min.
- **Estimated tokens**: ~9.2M (implementers 5.2M, main 3M, verifier 1M),
  most of it cache reads. 7 of 11 tasks run on Sonnet.
- The main session is idle during W1 except for launching and checking;
  T8 goes to W2 because it needs the names fixed in T1, T2 and T6.

## Order and dependencies

W1 tasks depend only on the spec (formats are fixed there). T5 edits the
same file as T4, so it waits. T8 writes the skill text that names the
template sections, the agent and the script. T9 releases. T10/T11 verify.
Each task: write its eval cases, see them red, implement, see them green.

## Test strategy

TDD: every case in the table is written and seen failing before the code.
If a test fails: fix the code, not the test.

- **Unit**: `hook` and `file_contains` cases; `task-actuals` and
  `calibrate` through scripts that copy fixtures into `mktemp -d` (the hook
  writes files, so it never runs on the repo tree).
- **Integration**: clean test install with a temp `HOME`.
- **Manual verification**: T11 on real transcripts from this plan's own
  subagents; `verifier` on the change and two adjacent flows.

## Verification commands

```
bash -n hooks/*.sh hooks/lib/*.sh install.sh evals/run.sh scripts/*.sh skills/sdlc/calibrate.sh evals/scripts/*.sh
bash evals/run.sh
WORKFLOW_PROFILE=profiles/<org> bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile
```

## Implementation risks

- `evals-on-config-change` runs the suite on every edit under `hooks/`,
  `skills/`, `agents/`, `evals/`: with six implementers in W1 it fires often
  and shows red cases written first. Expected during TDD.
- Concurrent writers: the six W1 tasks share no file; eval case numbers are
  reserved per task in the table.
- `production-gate` false positives: write docs with Write/Edit, not
  heredocs.
- 85b changes meaning (rule replaced, R11): same change, not a weakened
  test; `test-guard` may flag it and the reason is in the spec.
- This plan's own actuals cannot be recorded by the hook (not installed);
  T11 runs it by hand and the result fills `Estimate vs actual`.

## Estimate vs actual

Delegated tasks: `hooks/task-actuals.sh` run by hand on each subagent's
real transcript (the hook is not installed yet), with `runs_on` set to
`implementer` (they ran as `general-purpose` + Sonnet 5.5 with the
implementer rules). Log: `actuals.jsonl` next to this file. Minutes match
the `duration_ms` Claude Code reported for each subagent.

| # | Runs on | Est | Actual | Deviation (min / tok) | Cause |
|---|---------|-----|--------|-----------------------|-------|
| T1 | implementer | 5m/400k | 1.5m/235k | −70 % / −41 % | starting table too high |
| T2 | implementer | 5m/400k | 1.5m/188k | −70 % / −53 % | same |
| T3 | implementer | 5m/400k | 1.7m/177k | −66 % / −56 % | same |
| T4 | implementer | 12m/1.2M | 2.5m/322k | −79 % / −73 % | same |
| T5 | implementer | 12m/1.2M | 20.9m/380k | +74 % / −68 % | ~18 min waiting on two Bash calls (probably permission prompts); scope change mid-task |
| T6 | implementer | 12m/1.2M | 1.4m/242k | −88 % / −80 % | starting table too high |
| T7 | implementer | 5m/400k | 1.5m/231k | −70 % / −42 % | same |
| T8, T9, T11 | main | 15m, 5m, 5m | not measured | — | hook not installed; Status was updated with `sed`, which the PostToolUse branch does not see |

- `calibrate.sh .` → `implementer n=7 min x0.30 tok x0.44`: the next plan
  starts an S implementer task at ~1.5 min / ~180k.
- **Wall-clock**: 06:50 → 07:19 for W1–W3 plus the T5 wait and the
  large-transcript fix, against an estimated 51 min (sequential sum 100).
  W1 (six tasks) took 2.5 min of wall-clock against 12 estimated.
- Every task flagged; all but T5 because the starting table is high, which
  is what calibration is for.

## Outside this plan

Money conversion, worktrees, Haiku editing, a PreToolUse guard on
implementer file scope, agent teams.

---
Next stage: Build implements, Test verifies, Deploy opens the PR.
