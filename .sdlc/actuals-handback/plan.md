# Plan: Read subagent reports from the handback and calibrate across repos

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-10-20)
- **Nothing is implemented until this file is approved.**

## Done means

- `bash evals/run.sh` → `FAIL: 0`, every new case seen red first.
- `WORKFLOW_PROFILE=<org profile> bash evals/run.sh` → `FAIL: 0`.
- `bash scripts/check-public.sh` → exit 0; `bash -n` clean.
- `HOME=$(mktemp -d) ./install.sh --no-profile` → suite green; the temp
  `settings.json` has the `SubagentHandback` PreToolUse entry.
- `verifier` green, or amber with its items resolved.
- Version 2.4.0. The real install is run by the developer; T8 runs after it,
  in a new session.

## Stop and ask if

- Exit 2 on `PreToolUse:SubagentHandback` does not refuse the handback in
  the live test (T8): the spec's fallback needs a decision.
- An existing case must change for a reason other than R6 (103b output
  format) or R8 (cause of `main` rows).
- `install.sh` needs a change.
- An implementer touches a file outside its `Files`.
- `SKILL.md` cannot take R13 within 160 lines without dropping a rule.
- A `Learned:` line carries personal or sensitive business data.

## Tasks

`Est` from the 2.4.0 starting table (R7), before it is installed: implementer
S 2m/200k, M 2m/300k; main 5m/6M; verifier 8m/700k. Delegated tasks run on
the installed `implementer` agent (Sonnet 5.5, medium).

| # | Task | Files | Test that proves it | Req | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|-----|---------|---------|-----|--------|
| T1 | `report.sh` helper | `hooks/lib/report.sh`, `evals/scripts/report-lib-test.sh`, `evals/fixtures/report/`, `evals/cases/105a-report-lib-scenarios.json` | 105a: handback → its message; no handback → last message; missing transcript → last message; handback transcript > 1 MB | R1 | implementer | — | 2m/200k | done (W1; diff read) |
| T4 | `calibrate.sh`: machine log, repo/all medians, new table | `skills/sdlc/calibrate.sh`, `evals/fixtures/calibrate/`, `evals/cases/103a..103e` | 103b updated to the new format (R6); 103c repo 2 + all 6 → `use: all`; 103d repo 5 → `use: repo`; 103e table shows `implementer` `2m/200k` and `(low confidence)` | R6, R7 | implementer | — | 2m/300k | done (W1; main added 103f: no machine log → use repo) |
| T5 | Plan template + settings | `skills/sdlc/templates/plan.md`, `settings.template.json`, `evals/cases/100e-plan-template-main-cause.json`, `evals/cases/84g-pretooluse-subagent-handback.json` | 100e `done (cause:`; 84g `"matcher": "SubagentHandback"` | R8, R9 | implementer | — | 2m/200k | done (W1; diff read) |
| T2 | `subagent-report-check`: PreToolUse on handback, once per agent; SubagentStop skips handback agents | `hooks/subagent-report-check.sh`, `evals/scripts/report-check-test.sh`, `evals/cases/82l-report-check-handback-scenarios.json` | Scenarios in a temp `TMPDIR`: bad handback → 2; good → 0; second bad same `agent_id` → 0; foreign agent → 0; SubagentStop with handback transcript + empty message → 0; 82a–82k green | R2, R3 | implementer | T1 | 2m/300k | done (W2; diff read) |
| T3 | `task-actuals`: cause from the helper, machine log, explicit `main` cause | `hooks/task-actuals.sh`, `evals/scripts/task-actuals-test.sh`, `evals/fixtures/actuals/`, `evals/fixtures/actuals-main/` | New scenarios: handback cause; one line in each log; repeat stop still one; start lines only in the repo log; `done (cause: x)` → `x`; `done (10 tests; ok)` → `""`. Scenario i's fixture moves to `done (cause: spec was ambiguous)` | R4, R5, R8 | implementer | T1 | 2m/300k | done (W2; diff read) |
| T9 | `context.md` template + implementer reads it and reports `Learned:` | `skills/sdlc/templates/context.md`, `agents/implementer.md`, `evals/cases/106a..106d` | 106a template has `## Learned`; 106b template data rule; 106c agent reads `context.md`; 106d report format has `Learned:`; 101a–101e green | R11, R12 | implementer | — | 2m/200k | done (W1; diff read) |
| T10 | `sdlc` Stage 3: write `context.md` before W1, fold `Learned:` after each wave | `skills/sdlc/SKILL.md`, `evals/cases/106e..106f` | 106e `context.md`; 106f `Learned:`; 79 (≤ 160 lines) and 104a–104e green | R13 | main | T9 | 5m/6M | done (cause: SKILL.md at its 160-line budget, one extra compaction pass) |
| T11 | `calibrate.sh`: median actual per runner (R14) | `skills/sdlc/calibrate.sh`, `evals/cases/103b`, `evals/cases/103g-calibrate-median-actual.json` | 103g: history fixture → median actual line; 103a–103f green (103b's line may extend) | R14 | implementer | T4 | 2m/200k | done (W2; diff read) |
| T6 | Release 2.4.0 + project migration | `VERSION`, `CHANGELOG.md`, `skills/repo-setup/templates/sdlc-README.md`, `migrations/2.4.0.md`, `evals/cases/41d-migration-2-4-0-installed.json` | case 40; 41d; full suite, profile suite, check-public, clean install | R10 | main | T1–T5, T9, T10 | 5m/6M | done (cause: none) |
| T7 | Verification | — | `verifier`: the change + adjacent flows (`plan-resume` on the plan template; `task-actuals` PostToolUse branch on a real-size transcript) | all | verifier | T6 | 8m/700k | done (amber, no IMPORTANT; 2 nits fixed: scenario u, CHANGELOG `use:` wording; live items are T8) |
| T15 | Review fixes in `task-actuals` (findings 1–3): redact credentials in `cause` with the shared patterns; `mkdir` lock + unique tmp + rewrite only when the `agent_id` is present; machine-log append filtered per line; plan path must be under `cwd` | `hooks/task-actuals.sh`, `hooks/lib/leak-patterns.sh` (new; `credentials.sh` is covered by the `Read(**/credentials*)` deny rule), `hooks/credential-guard.sh`, `evals/scripts/task-actuals-test.sh`, `evals/fixtures/actuals/` | New scenarios seen red: cause with a credential → `[redacted]`; 12 concurrent stops → 13/12 lines, no stderr; one edit closing T2 and starting T3 → T2 in the machine log; plan.md outside `cwd` → nothing. 01–05, 24 (credential-guard) green | Review | implementer | — | 2m/300k | done (diff read; credential patterns identical; main added scenario z: stale lock) |
| T16 | Review fix in `subagent-report-check`: `agent_id` must match `^[A-Za-z0-9_-]+$` to be used as a marker name, else never block | `hooks/subagent-report-check.sh`, `evals/scripts/report-check-test.sh` | New scenario seen red: `agent_id` `../x` → exit 0, no marker outside `$TMPDIR` | Review | implementer | — | 2m/200k | done (diff read) |
| T17 | Review fixes in docs (findings 4–6, nits): English-only `.sdlc` texts, neutral repo names; spec amendments (plan-resume scope, R6 exception); CHANGELOG median; T8 status; SKILL/template wording on the median actual | `.sdlc/parallel-plans/*`, `.sdlc/actuals-handback/*`, `CHANGELOG.md`, `skills/sdlc/SKILL.md`, `skills/sdlc/templates/plan.md` | `grep` finds no Spanish quotes or other repo slugs; 79, 100*, 104* green | Review | main | — | 5m/2M | done (cause: none) |
| T18 | Re-verify after the fixes | — | `verifier` on T15–T17 + suites + clean install | all | verifier | T15–T17 | 8m/700k | done (green; 2 nits noted in review.md) |
| T8 | Live checks after the developer installs | — | New session: an implementer whose first handback lacks `Deviation cause:` is refused once and then passes; its line in both logs carries the cause; record whether a `SubagentStop` block after a handback has effect | R2, R4, R5 | main | T7 + install | 5m/6M | done (cause: none; first handback refused live, second passed, cause reached both logs, one marker; the test lines were then removed from both logs at the developer's request; this row's own closing line was not written: its id collided with the test implementer's T8) |

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| W0 | main writes `.sdlc/actuals-handback/context.md` by hand (the template comes in T9) | 2m | — |
| W1 | T1, T4, T5, T9 | 2m | `git diff --stat` vs Files, read diffs, fold `Learned:`, suite (~3m) |
| W2 | T2, T3 (implementers) ‖ T10 (main) | 5m | same (~3m) |
| W3 | T6 | 5m | — |
| W4 | T7 | 8m | consolidate (~3m) |
| — | T8 after the developer's install | 5m | — |

- **Estimated wall-clock** (W0–W4): 2 + 2 + 3 + 5 + 3 + 5 + 8 + 3 =
  **31 min**; T8 separate.
- **Sequential sum**: 32 min + 9 min of checks = 41 min. The tasks are
  small, so the main session's checks weigh more than the parallelism.
- **Estimated tokens**: ~1.5M implementers + 12M main (T6, T10) + 0.7M
  verifier ≈ 14M; T8 another ~6M main. The `main` rate (6M per task) rests
  on one sample.
- **Shared-context signal**: implementer `ktok` here vs. the 15 earlier
  runs (median ~240k).

## Order and dependencies

T2 and T3 source the T1 helper. T4, T5 and T9 only depend on the spec. T10
writes the skill text that names T9's template and line. T6 releases what
W1–W2 built. T8 needs the hooks installed, which only the
developer does.

## Test strategy

TDD: every case is written and seen failing first. Fix the code, not the
test; the only case edits are 103b (R6 output format) and scenario i's
fixture (R8), both required by the spec.

- **Unit**: script scenarios in `mktemp -d` workspaces (`TMPDIR` and
  `CLAUDE_SDLC_ACTUALS` pointed there), synthetic transcripts only.
- **Integration**: clean test install.
- **Live**: T8.

## Verification commands

```
bash -n hooks/*.sh hooks/lib/*.sh install.sh evals/run.sh scripts/*.sh skills/sdlc/calibrate.sh evals/scripts/*.sh
bash evals/run.sh
WORKFLOW_PROFILE=<org profile> bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile
```

## Implementation risks

- 2.3.0 is installed and live in this session: `task-actuals` records this
  plan's implementer runs into `.sdlc/actuals-handback/actuals.jsonl` (with
  empty causes until 2.4.0 is installed). That is the first live data for
  T8's comparison.
- Status updates go through Edit so the installed hook times `main` tasks.
- Tests must never write to the real `~/.claude/actuals.jsonl`: every
  scenario sets `CLAUDE_SDLC_ACTUALS`.

## Estimate vs actual

Measured live by the installed 2.3.0 hook (so implementer causes are empty:
the bug this change fixes). Estimates from the new 2.4.0 table.

| # | Runs on | Est | Actual | Deviation (min / tok) |
|---|---------|-----|--------|-----------------------|
| T1 | implementer | 2m/200k | 2.2m/154k | +10 % / −23 % |
| T4 | implementer | 2m/300k | 1.6m/167k | −20 % / −44 % |
| T5 | implementer | 2m/200k | 1.6m/95k | −20 % / −53 % |
| T9 | implementer | 2m/200k | 2.6m/98k | +30 % / −51 % |
| T2 | implementer | 2m/300k | 1.7m/134k | −15 % / −55 % |
| T3 | implementer | 2m/300k | 2.5m/457k | +25 % / +52 % (disk full, one rerun) |
| T11 | implementer | 2m/200k | 1.0m/205k | −50 % / +3 % |
| T10 | main | 5m/6M | 1.0m/1.7M | −80 % / −72 % |
| T6 | main | 5m/6M | 1.4m/771k | −72 % / −87 % |

- **Implementer minutes**: 7/7 within ±50 % (0/15 with the old table).
  Tokens: 3/7 within; three misses sit just past −50 % and one at +52 %
  (T3, disk full); the new table is slightly high on tokens.
- **Shared context**: implementer median 154k tokens against ~240k in the
  15 runs before `context.md` (−35 %), on similar task sizes.
- **Main**: the 5m/6M row (one earlier sample of a long task) is far too
  high for short main tasks; the median actual in `calibrate.sh` corrects
  it from here.
- Wall-clock: 09:23 (W0) → ~09:50 (T6 done), against 31 min estimated.

## Outside this plan

Log rotation, money conversion, separate accounting of permission waits.

---
Next stage: Build implements, Test verifies, Deploy opens the PR.
