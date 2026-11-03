# Plan: Quieter install output

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-10-27, "apruebo lo de quiet install")
- **Nothing is implemented until this file is approved.**

## Done means

- A default `HOME=$(mktemp -d) ./install.sh --no-profile` prints no case
  lines, ends with the four lines of the spec, and leaves
  `~/.claude/workflow/install-verify.json` at `green` within seconds.
- With a planted failing case, the result is `red` with the case's name,
  kind and detail, and SessionStart gives the notice with it in the right
  group (blocking / can wait); green, running and older-version results
  are silent.
- `--verbose` behaves as today, including exit 1 on red.
- `bash evals/run.sh` → `FAIL: 0` (with the org profile too); new cases seen
  red first; `check-public.sh` exit 0; `bash -n` clean.
- `verifier` green, or amber with its items resolved.
- Released in the same 2.6.0 as `rules-command` (both on `main`, unreleased).

## Stop and ask if

- `nohup … &` from `install.sh` does not survive the installer exiting on
  macOS, or leaves the terminal waiting.
- An existing case or `workflow-version-check` notice must change wording.
- An implementer touches a file outside its `Files`.

## Tasks

`Est` from `calibrate.sh` (2026-10-27): implementer median actual (repo,
n=23) 2.0m/180k; main (repo) 3.1m/2.5M; verifier (all) 6.3m/2.2M.

| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|--------------------|---------|---------|-----|--------|
| Q1 | `run.sh`: `EVALS_RESULT_JSON=<file>` writes `{version, started, finished, status, pass, fail, failed:[{name, kind, file, detail}]}` atomically (temp + `mv`); stdout unchanged | `evals/run.sh`, `evals/scripts/run-result-json-test.sh`, `evals/cases/110a-run-result-json.json` | Scenarios with a fixture case dir: all pass → `green`, `fail: 0`; one planted failure → `red` with its name, kind, file and detail; unset variable → no file written, stdout identical | R2 | implementer | — | 2m/180k | done (W1; diff read; review fix: version from `workflow/VERSION` in an installed root, scenario red first) |
| Q2 | `evals/install-verify.sh`: writes `running`, stops a live previous run (PID file), runs `run.sh` with `EVALS_RESULT_JSON`, log to `install-verify.log` | `evals/install-verify.sh`, `evals/scripts/install-verify-test.sh`, `evals/cases/110b-install-verify.json` | With a stub `run.sh` in a temp root: status goes `running` → final; a second start kills the first (stub that sleeps); log written | R1, R2 | implementer | — | 2m/180k | done (W1; diff read; a crashed suite is recorded as kind `suite`, so it lands in "can wait") |
| Q3 | `workflow-version-check.sh`: notice from `install-verify.json` when `red` and `version` = installed; blocking = kind `hook` or file ending in `settings.json` / `.claude/CLAUDE.md`; ≤ 5 per group + "and N more"; `running` > 10 min → "did not finish, run it again" | `hooks/workflow-version-check.sh`, `evals/scripts/install-verify-notice-test.sh`, `evals/cases/110c-install-verify-notice.json` | Scenarios: red mixed → both groups; green / running / other version → no notice; stuck running → re-run notice; 7 blocking → 5 + "and 2 more"; existing 35–37, 88 cases still green | R3, R4 | implementer | — | 2m/180k | done (W1; diff read; stuck-running also requires the installed version; GNU `date -d` path not exercised) |
| Q4 | `install.sh`: default launches `install-verify.sh` with `nohup … &` and prints the spec's four lines; `--verbose` / `WORKFLOW_INSTALL_VERBOSE=1` = today's foreground run; `CLAUDE.md` clean-install command gains `--verbose`; existing install test uses `--verbose` if it relied on the suite output | `install.sh`, `CLAUDE.md`, `evals/scripts/install-test.sh`, `evals/scripts/quiet-install-test.sh`, `evals/cases/110d-quiet-install.json` | Temp HOME: default output has no `PASS`/`FAIL` lines and ≤ 6 lines after the version line; result file reaches `green`; `--verbose` prints the suite; `--verbose` with a planted failing case exits 1 | R1, R5 | implementer | Q1, Q2 | 2m/180k | done (W2; diff read; review fix: 110d 96 s → 1.2 s via a scratch repo copy with one case; "~3 s" removed from the install line) |
| Q5 | Fold into the 2.6.0 `CHANGELOG.md` entry | `CHANGELOG.md` | case 40; suites; check-public | all | main | Q1–Q4, rules-command T5 | 3m/2.5M | done (cause: none; same verification run as rules-command T5; also corrected the repo CLAUDE.md suite time from ~3 s to ~30 s, measured: 23 s at HEAD, 32 s now) |
| Q7 | Verifier fixes (Q6 amber): `--verbose` runs the suite with `EVALS_RESULT_JSON` pointing at `install-verify.json` (fresh result); `WORKFLOW_INSTALL_NO_VERIFY` removes the stale result; `run.sh` writes `file` with `$HOME` shown as `~` | `install.sh`, `evals/run.sh`, `evals/scripts/quiet-install-test.sh`, `evals/scripts/run-result-json-test.sh` | Red first: red default install, then `--verbose` clean → result `green`; then red, then NO_VERIFY → no result file; result `file` starts with `~/` when under HOME | R2, R3 | implementer | Q6 | 2m/180k | done (diff read; scenarios red first; 110d 4.7 s) |
| Q8 | Re-verify after Q7 | — | `verifier` | all | verifier | Q7 | 3m/800k | done (green; 1 nit: `install-verify.log` survives a NO_VERIFY install, harmless) |
| Q6 | Verification | — | `verifier`: the change + adjacent flows (`evals-on-config-change` still runs the suite in the foreground; a version-ahead notice and a red-install notice together in one SessionStart) | all | verifier | Q5 | 6m/2.2M | done (amber: a stale red result survives `--verbose` / NO_VERIFY reinstalls → Q7; nits: detail lacks the missing text, `file` has the home path) |

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| W0 | main writes `.sdlc/quiet-install/context.md` | 2m | — |
| W1 | Q1, Q2, Q3 | 2m | diffs, fold `Learned:`, suite (~3m) |
| W2 | Q4 | 2m | same (~3m) |
| W3 | Q5 | 3m | — |
| W4 | Q6 | 6m | consolidate (~3m) |

- **Estimated wall-clock**: ~24m
- **Sequential sum**: ~17m
- **Estimated tokens**: ~7.9M

## Order and dependencies

Q1–Q3 only share the JSON shape fixed in `spec.md` and `context.md`, so
they run together. Q4 wires Q1 and Q2 into `install.sh`. The changelog waits
for the `rules-command` release task so both land in one 2.6.0 entry.

## Test strategy

TDD: each scenario red before the code. If a test fails, fix the code, not
the test.

- **Unit**: `run.sh` result file; `install-verify.sh` with a stub suite;
  the notice from fixture result files.
- **Integration**: `quiet-install-test.sh` runs the real `install.sh` into a
  temp HOME, default and `--verbose`.
- **Manual verification**: `verifier` checks a real-looking session start
  after a planted red install.

## Verification commands

```
bash -n install.sh evals/run.sh evals/install-verify.sh hooks/*.sh evals/scripts/*.sh
bash evals/run.sh
WORKFLOW_PROFILE=profiles/<org> bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile --verbose
```

## Implementation risks

- `run.sh` is used by every suite run and by `evals-on-config-change`: the
  result file must be opt-in and stdout byte-identical without it.
- Background process in tests: tests wait on the result file with a bounded
  loop (≤ 20 s), never a bare `sleep`.
- Killing a previous run must only kill a PID that is still an
  `install-verify.sh`/`run.sh` process, never a reused PID.

## Estimate vs actual

Filled at Build close from `.sdlc/quiet-install/actuals.jsonl`.

| # | Runs on | Est | Actual | Deviation | Cause |
|---|---------|-----|--------|-----------|-------|
| Q1–Q8 | — | — | not recorded | — | the plan used `Q<n>` task ids; the `task-actuals` hook only recognises `T<n>`, so no `actuals.jsonl` was written. Use `T<n>` in plans. |

## Outside this plan

Everything in the spec's "Out of scope".

---
Next stage: Build implements, Test verifies, Deploy opens the PR.
