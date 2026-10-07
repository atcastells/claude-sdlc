# Plan: Delegate read-only work to Sonnet 5.5 and adopt recent Claude Code features

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-10-07)
- **Nothing is implemented until this file is approved.**

## Done means

- `bash evals/run.sh` → `FAIL: 0`, with every new case seen red first.
- `WORKFLOW_PROFILE=profiles/<org> bash evals/run.sh` → `FAIL: 0`.
- `bash scripts/check-public.sh` → exit 0.
- `HOME=$(mktemp -d) ./install.sh --no-profile` → ends with the suite green,
  and the temp `settings.json` registers both new hooks.
- `bash -n` clean on the new hooks.
- `verifier` verdict green.
- The real `./install.sh` into `~/.claude` is **not** run by the agent; the
  developer runs it.

## Stop and ask if

- `install.sh` needs changes to copy or merge something new.
- `sdlc` cannot stay within 160 lines without dropping an existing rule.
- An existing eval turns red for a reason unrelated to this change.
- `check-public.sh` flags any term.

## Tasks

| # | Task | Files | Test that proves it | Requirement (spec) | Status |
|---|------|-------|---------------------|--------------------|--------|
| T1 | `verifier`: `effort: high`, `maxTurns: 40` | `agents/verifier.md` | new case 75b (`effort: high`), 75c (`maxTurns:`) | R1 | done |
| T2 | `reviewer` agent | `agents/reviewer.md` | cases 81 (`model: sonnet`), 81b (`effort: high`), 81c (no `Edit`/`Write` in tools: `tools: Read, Glob, Grep, Bash`), 81d (`PASS: <pass>` format) | R2 | done |
| T3 | `subagent-report-check.sh` | `hooks/subagent-report-check.sh` | cases 82a verifier report ok → 0; 82b no VERDICT → 2; 82c IMPORTANT without demonstration → 2; 82d reviewer ok → 0; 82e reviewer without PASS → 2; 82f foreign agent → 0; 82g `stop_hook_active` → 0 | R7 | done |
| T4 | `plan-resume.sh` + fixtures | `hooks/plan-resume.sh`, `evals/fixtures/plan-open/`, `evals/fixtures/plan-done/` | cases 83a open tasks listed as SessionStart context; 83b all done → no output; 83c no `.sdlc` → no output | R8 | done |
| T5 | Register hooks | `settings.template.json` | cases 84a/84b registration (file_contains, `file_repo` like case 42) | R9 | done |
| T6 | `sdlc` Stage 5 + session section | `skills/sdlc/SKILL.md` | cases 85a (`reviewer`), 85b (downward rung: `never for edits`), 85c (`subscription`), 85d (`CLAUDE_CODE_SUBAGENT_MODEL`), 85e (workflow only on request), 85f (`/advisor`); existing 77, 78, 79, 80 stay green | R3–R6, R11 | done |
| T7 | Release 2.1.0 | `VERSION`, `CHANGELOG.md` | case 40 green; full suite; check-public; clean test install | R10 | done |
| T8 | Verification | — | `verifier` subagent: change + two adjacent flows (`workflow-version-check` on SessionStart; `install.sh` settings merge) | all | done: verifier amber (its not-covered items run by the main session), 1 nit fixed (83d) |

## Order and dependencies

T1 → T2 (same format) → T3 (needs the report formats fixed in T1/T2) →
T4 → T5 (registers T3, T4) → T6 (references the agent and hooks) → T7 → T8.
Each task: write its eval cases, run them red, implement, run green.

## Test strategy

TDD: every case in the table is written and seen failing before the code.
If a test fails: fix the code, not the test.

- **Unit**: `hook` cases with inline payloads (no `CLAUDE_PROJECT_DIR`).
- **Integration**: clean test install with a temp `HOME`; the suite runs
  against the installed copy.
- **Manual verification**: `verifier` checks the hooks against a real
  payload shape from the hooks reference and that `install.sh` merges the
  new `hooks` keys without dropping existing ones.

## Verification commands

```
bash -n hooks/*.sh hooks/lib/*.sh install.sh evals/run.sh scripts/*.sh
bash evals/run.sh
WORKFLOW_PROFILE=profiles/<org> bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile
```

## Implementation risks

- `evals-on-config-change` fires on every edit under `hooks/`, `skills/`,
  `agents/`, `evals/`: red cases written first will show red on the next edit.
  Expected during TDD.
- `production-gate` false positives on commands that mention its name: use
  Read/Write instead of Bash for those files.
- `install.sh` merges `hooks` wholesale from the template (line 148): the
  new `SubagentStop` key replaces any user-defined one. Same behavior as
  today's keys; noted, not changed.

## Outside this plan

Implementer subagent, saved Stage 5 workflow, plugin distribution, `REVIEW.md`
template changes, Haiku pricing.

---
Next stage: Build implements, Test verifies, Deploy opens the PR.
