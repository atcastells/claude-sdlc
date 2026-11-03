# Plan: An install-verification notice that interrupts only when it should

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-11-03, "apruebo"; S5 still needs its own OK)
- **Nothing is implemented until this file is approved.**

## Done means

- With the real 19 incident cases tagged (S5), a red incident case no longer
  produces any SessionStart notice outside the Test stage; a planted broken
  `credential-guard` case does, with the reinstall action.
- `EVALS_REPO=<product repo> bash ~/.claude/evals/run.sh`
  runs exactly the 19 incident cases.
- `bash evals/run.sh` → `FAIL: 0` (with the org profile too); new scenarios
  seen red first; `check-public.sh` exit 0; `bash -n` clean.
- `verifier` green, or amber with its items resolved.
- Released inside the unreleased 2.6.0 (it amends quiet-install).

## Stop and ask if

- An existing 110a/110c/110d scenario has to change its expectation beyond
  the two group texts.
- Path resolution differs in bash 3.2 for a missing repo or a symlinked
  `$HOME`.

## Tasks

`Est`: implementer median for this repo from the quiet-install plan
(2026-10-27, n=23): 2m/180k; main 3m/2.5M; verifier 6m/2.2M.

| # | Task | Files | Test that proves it | Req | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|-----|---------|---------|-----|--------|
| S1 | `run.sh`: `repo` field, `EVALS_SKIP_REPO`, `EVALS_REPO`, `hook` in failed entries | `evals/run.sh`, `evals/scripts/run-repo-cases-test.sh`, `evals/cases/111a-run-repo-cases.json` | Fixture suite: plain run counts the repo case; SKIP → not counted, `green` with a failing repo case; `EVALS_REPO` dir / subdir / `app-2` / missing; result JSON has `hook` | R1–R3 | implementer | — | 2m/180k | done (W1; diff read; a missing `EVALS_REPO` dir exits 1, now with a stderr line) |
| S2 | Callers pass `EVALS_SKIP_REPO=1` | `evals/install-verify.sh`, `install.sh`, `hooks/evals-on-config-change.sh`, `evals/scripts/install-verify-test.sh` | Stub `run.sh` records its env: install-verify passes it; `file_contains` on `install.sh` and the hook | R2 | implementer | — | 2m/180k | done (W1; diff read) |
| S3 | Notice: blocking = guard hooks; new group texts with the action | `hooks/workflow-version-check.sh`, `evals/scripts/install-verify-notice-test.sh` | Scenarios: failed `credential-guard.sh` → "not active" + install command + "maintainer"; only `workflow-version-check.sh` failure → no "Blocking"/"not active", has "Found"; existing scenarios adapted only in group text | R5, R6 | implementer | — | 2m/180k | done (W1; diff read) |
| S4 | `verifier.md` step 2, `sdlc` stage 6, two `file_contains` cases, 2.6.0 `CHANGELOG.md` entry (worktree note) | `agents/verifier.md`, `skills/sdlc/SKILL.md`, `evals/cases/111b-verifier-repo-evals.json`, `evals/cases/111c-sdlc-incident-repo.json`, `CHANGELOG.md` | 111b/111c red then green; case 40; suites | R4, R7 | main | S1–S3 | 3m/2.5M | done (cause: none; SKILL.md hit its 160-line budget, stage 6 intro compacted to 159) |
| S5 | **Outside the repo, needs your OK**: back up and add `"repo": <args[0]>` to the 19 `~/.claude/evals/cases/i-*.json` with jq | `~/.claude/evals/cases/i-*.json` (user-owned, not in the manifest) | `jq -e .repo` on all 19; `EVALS_REPO=… run.sh` → 19 cases | R1 | main | S1 | 2m | done (OK 2026-11-03, "apruebo"; backup in `~/.claude/workflow/backups/incident-cases-2026-11-03/`; content otherwise identical; new run.sh on a temp copy: `EVALS_REPO` repo or `src/` → 19/0, `EVALS_SKIP_REPO=1` → 19 skipped) |
| S6 | Verification | — | `verifier`: the change + adjacent flows (version-ahead notice with a red result; `evals-on-config-change` red path still exits 2 on a real hook failure) | all | verifier | S4, S5 | 6m/2.2M | done (amber → closed by S5; NIT missing-dir message fixed; worktree NIT accepted in spec) |

## Schedule

| Wave | Tasks | Longest | Then (main) |
|------|-------|---------|-------------|
| W1 | S1, S2, S3 (parallel) | 2m | read diffs, suite (~1m) |
| W2 | S4, then S5 | 3m | — |
| W3 | S6 | 6m | consolidate |

- **Estimated wall-clock**: ~14m
- **Estimated tokens**: ~5.6M

## Test strategy

TDD: each scenario red before the code; if a test fails, fix the code, not
the test. Tests in `mktemp -d` with temp `HOME`/`WORKFLOW_HOME`; never the
real `~/.claude` (except S5, with your OK).
