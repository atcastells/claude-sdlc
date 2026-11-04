# Plan: Claudio — new name, plain README, plan hints, company phrases

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (maintainer, 2026-11-04, "apruebo")
- **Nothing is implemented until this file is approved.**

## Done means

- `bash evals/run.sh` green, and green with `WORKFLOW_PROFILE=profiles/example`;
  every new or changed case was seen red before its code changed.
- `git grep -n claude-sdlc -- ':!.sdlc' ':!CHANGELOG.md' ':!migrations'`
  returns only the compatibility lines listed in T4's report (R1).
- `bash scripts/check-public.sh` exit 0; `HOME=$(mktemp -d) ./install.sh
  --no-profile --verbose` ends with the suite green, from a copy of the
  repo in a folder named `claudio` and from one named `claude-sdlc` (R3).
- With fixture plans, `status-line.sh` prints the task, plan and context
  segments of R6–R9, and prints today's line with no open plan or a broken
  one (R10); timing under 150 ms with a 30-row plan.
- A test install with an Elektro3-like fixture profile sets 64
  `spinnerVerbs`; with no `spinner_verbs` key the user's phrases stay (R12).
- README above `## Technical details`: ≤ 40 lines, no listed jargon (R4).
- Left for the maintainer: rename the GitHub repo; commit the phrases file
  in the documentation repo; a real `./install.sh` with the Elektro3
  profile (needs your go); one run of the README sentence in a clean `HOME`.

## Stop and ask if

- T1 finds that `spinnerVerbs` has a different schema, or that the status
  line or `spinnerVerbs` is not shown in the desktop app or T3 Code: R12
  or the README wording changes before going on.
- An existing case goes red for a reason unrelated to the rename (measure
  it on the clean tree first).
- The rename reaches a project file `/repo-setup` leaves (then a
  `migrations/3.0.0.md` is needed, which the spec ruled out).
- Plan tables in `.sdlc/` cannot be parsed by header name (a real plan
  without `Est` or `Status` columns).
- Any write outside this repo other than the two in T11.

## Tasks

| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|--------------------|---------|---------|-----|--------|
| T1 | Official docs check: `spinnerVerbs` schema; whether the status line and `spinnerVerbs` show in the terminal, the desktop app and T3 Code; GitHub redirect after a repo rename. Findings appended below. | `plan.md` (findings) | Each finding cites its URL | Risks 1-2, R3 | main | — | 4m/1.3M | done (cause: none; three doc pages, findings below) |
| T2 | Notice prefix `claude-sdlc:` → `Claudio:` in `workflow-version-check.sh`, `plan-resume.sh`, `project-profile.sh`; cases and scripts that assert it changed first (red), then the hooks (green). | those 3 hooks, `evals/cases/39b*`, `88e-g*`, `evals/scripts/{project-profile,install-verify-notice,company-notice}-test.sh` | 39b, 88*, project-profile and notice scripts red then green | R1 | implementer | — | 3m/250k | done (W1; diff read) |
| T3 | Markers and Vibe notices: `claudio-mode-<id>`, `claudio-report-<id>`, `Claudio:` in `mode.sh`; tests first. | `hooks/lib/mode.sh`, `hooks/mode.sh`, `hooks/subagent-report-check.sh`, `evals/scripts/{mode-lib,mode-hook,report-check}-test.sh`, `evals/cases/113f*` and its fixture dir | 113a/b/f and report-check red then green | R1, R2 | implementer | — | 3m/250k | done (W1; diff read; two fixture dirs) |
| T4 | Remaining visible name: `install.sh` output, `skills/repo-setup/check.sh`, skill and agent descriptions, `skills/sdlc/SKILL.md`, `profiles/example/`, repo `CLAUDE.md`; grep `skills/repo-setup/templates` (must be clean). New case: a clone in a folder named `claude-sdlc` is still recognised. Report the leftover `claude-sdlc` lines and why each stays. | listed files, 1 new case | New case red-proof (rename the fixture check), grep of R1 | R1, R3 | implementer | T9, T10 | 3m/250k | done (W3; diff read; only 112c keeps the old name, on purpose) |
| T5 | README rewrite (pitch, paste sentence with the R5 steps, five plain bullets, help, `## Technical details` link) and `docs/technical.md` with what left. Case: no jargon and ≤ 40 lines above the heading; case: the sentence names git/jq check, clone `~/claudio`, profile question, install, plain explanation. | `README.md`, `docs/technical.md`, 2 new cases | Both cases red on today's README, green after | R4, R5 | main | T1 | 5m/1.3M | done (cause: none; 116a-h, 6 red then 8 green; the sentence points to docs/install.md, which holds the R5 steps, so the README stays free of "jq") |
| T6 | `hooks/lib/plan-hint.sh`: pick the open plan (newest `plan.md` with a row not done; regular file ≤ 256 KB), parse by header `Est`/`Status`, print `done/total` and `~Nm left`. Cases with fixture plans built from real `.sdlc/` tables. | new lib, `evals/fixtures/plan-hint/`, cases `114a-d` | Two open plans, all done, malformed `Est`, extra columns: red then green | R7, R8 | implementer | — | 4m/300k | done (W1; diff read) |
| T7 | Task segment in `plan-hint.sh`: `in progress` row → `T3 4m/6m` from its `start` line in `actuals.jsonl`, `~6m` without one; yellow over Est, red over 2×; clock from `PLAN_HINT_NOW`. | `hooks/lib/plan-hint.sh`, cases `114e-g` | Fixed clock 4m, 7m, 13m; non-main task | R6 | implementer | T6 | 3m/200k | done (W2; diff read) |
| T8 | Wire `plan-hint.sh` into `status-line.sh` after the mode; context hint at 70% with an open task, 90% always; robustness: symlink, 300 KB, garbage plan → today's line. Timing check. | `status-line.sh`, cases `114h-m` | New cases red then green; 90-92 and 113c-f unchanged and green | R9, R10 | implementer | T7, T3 | 4m/300k | done (W3; diff read; 76 ms with 32 rows) |
| T9 | `install.sh`: optional `spinner_verbs` in `company.json`, path checks as `rules`, content checks in jq (array, 1–200, 1–80 chars, no control chars); stop before writing on error. | `install.sh`, `evals/fixtures/company-*`, cases `115a-h` | One case per invalid input of R11 + valid: red then green | R11 | implementer | — | 3m/250k | done (W1; diff read; red shown against HEAD install.sh after coding) |
| T10 | `install.sh`: set `.spinnerVerbs = {mode: "replace", verbs}` after today's settings merge, one output line; untouched without the key. | `install.sh`, cases `115i-k` | Replaced + backup holds old; no key → untouched; no other key changes | R12 | implementer | T9 | 3m/200k | done (W2; diff read) |
| T11 | Elektro3 content, outside this repo: write `IA/Perfil Elektro3/Frases de progreso.json` (64 starter kit phrases, "punto y coma") in `~/Repos/elektro3-documentacion`; add `"spinner_verbs"` to `~/Repos/claude-sdlc/profiles/elektro3/company.json`. Test install into a temp `HOME` with that profile. | 2 files outside the repo | `jq '.spinnerVerbs.verbs | length'` = 64 in the temp `HOME` | R13 | main | T10 | 3m/1.3M | done (cause: a shell write outside the repo was denied, redone with Write; temp HOME install: replace, 64 phrases, "punto y coma" present) |
| T12 | 3.0.0: `VERSION`, `CHANGELOG.md` entry ("claude-sdlc is now Claudio", markers, Vibe lost once on upgrade, phrases, hints), no migration. Full suite, example profile suite, `check-public.sh`, clean installs from `claudio/` and `claude-sdlc/` folders. | `VERSION`, `CHANGELOG.md` | Commands of "Done means" | all | main | T2-T11 | 8m/2M | done (cause: install output still said "workflow"; 110d red then green; suite 276/0, example 277/0, elektro3 287/0, check-public 0, clean installs from claudio/ and claude-sdlc/ 239/0; two shell commands denied and rerun without rm) |
| T13 | Verify the change and two adjacent flows: Vibe on/off and the status line mode segment after the marker rename; `install.sh` re-run on an existing `settings.json` keeps the user's other keys. | — | Verifier report | all | verifier | T12 | 5m/1.7M | done: verifier amber; IMPORTANT install.md self-check fixed (--verbose); IMPORTANT new URL left to the maintainer's rename; nits noted |
| T14 | Review pass: bugs | — | Findings per `REVIEW.md` | all | reviewer | T13 | 3m/550k | done (1 important fixed: 08m read as octal, 114n; nits fixed: short rows, no trailing pipe, huge Est, 114o-p) |
| T15 | Review pass: security (company file paths and content, status line reading repo files, untrusted plan text) | — | Findings per `REVIEW.md` | R10, R11 | reviewer | T13 | 3m/550k | done (3 important fixed: multi-value phrases file, C1/bidi controls, quadratic long line; cases 114q, 115l-o) |
| T16 | Review pass: conformance (bash + jq, macOS bash, no `sed -i`, English, budgets) | — | Findings per `REVIEW.md` | all | reviewer | T13 | 3m/550k | done (1 important fixed: install.md reinstall keeps the profile; nits fixed: repo CLAUDE.md, test precedence) |

Estimates from `calibrate.sh` (2026-11-04): repo medians implementer
2.2m/167k, main 2.3m/1.3M, reviewer 3.0m/551k; verifier from the machine
log, 5.3m/1.7M. Sized up: rename tasks (M, several files), T6 and T8 (new
parser, robustness cases), T5 (writing), T12 (four verification commands).

## T1 findings (2026-11-04)

- `spinnerVerbs`: object with `verbs` (array of strings) and `mode`,
  `"append"` or `"replace"`; scope any file; replace with an empty array
  keeps the built-in verbs.
  https://code.claude.com/docs/en/settings-reference#spinnerverbs
- The desktop app reads `spinnerVerbs` with the same fields (desktop
  settings table, so the company phrases also reach desktop users).
  https://code.claude.com/docs/en/desktop
- Custom status line: documented for the terminal interface; the desktop
  and VS Code pages do not mention it, so it is not confirmed outside the
  terminal. T3 Code has no Anthropic docs: not confirmed. Per the spec's
  risk mitigation, the README says the hints show in the terminal.
  https://code.claude.com/docs/en/statusline
- GitHub rename: web traffic and git clone/fetch/push to the old location
  are redirected; do not reuse the old name for a new repo.
  https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| 1 | T2, T3, T6, T9; main: T1 then T5 | 9m (main) | `git diff --stat` against Files; stop if T1 changes R12 |
| 2 | T7, T10 | 3m | `git diff --stat` |
| 3 | T4, T8; main: T11 | 4m | `git diff --stat`; full suite once |
| 4 | T12 (main) | 8m | — |
| 5 | T13 | 5m | — |
| 6 | T14, T15, T16 | 3m | fix findings |

- **Estimated wall-clock**: about 32m plus checks, ~36m.
- **Sequential sum**: 60m.
- **Estimated tokens**: ~12M (main 6M, implementers 2M, verifier 1.7M,
  reviewers 1.7M).

## Order and dependencies

T4 waits for T9 and T10 because all three touch `install.sh`. T8 waits for
T3 because 113f's fixture and the status line's marker read change there.
T11 needs the installer of T10 to test the Elektro3 file. T5 waits for T1
because the README must not promise hints in clients that do not show them.

## Test strategy

TDD: every case red before its code. If a test fails, fix the code.

- **Unit**: `plan-hint.sh` with fixture plans and actuals (114*); install
  validation and apply with fixture company repos (115*).
- **Integration**: status line end to end with fixtures and a fixed clock;
  clean installs from both folder names.
- **Manual verification**: T13 (Vibe on/off after the rename; settings
  re-merge keeps other keys).

## Verification commands

```
bash -n hooks/*.sh hooks/lib/*.sh install.sh evals/run.sh scripts/*.sh status-line.sh
bash evals/run.sh
WORKFLOW_PROFILE=profiles/example bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile --verbose
```

## Implementation risks

- Renaming markers mid-session: an open Vibe session falls back to Spec once.
- `install.sh` is shared by T4, T9, T10: run in separate waves.
- The status line runs on every refresh: any slowness is felt at once (R10).
- The documentation repo is the company's: T11 only writes the file, never
  commits.

## Estimate vs actual

Filled at Build close from `.sdlc/claudio/actuals.jsonl`.

| # | Runs on | Est | Actual | Deviation | Cause |
|---|---------|-----|--------|-----------|-------|
| T1 | main | 4m/1.3M | 7.8m/1.18M | +95% / -9% | three doc pages, one saved to disk and grepped |
| T2 | implementer | 3m/250k | 0.4m/94k | -87% / -62% | mechanical rename, few hits |
| T3 | implementer | 3m/250k | 0.8m/147k | -73% / -41% | mechanical rename; two fixture dirs |
| T4 | implementer | 3m/250k | 0.3m/62k | -90% / -75% | far fewer hits than expected |
| T5 | main | 5m/1.3M | 4.7m/1.19M | -6% / -8% | |
| T6 | implementer | 4m/300k | 0.6m/113k | -85% / -62% | |
| T7 | implementer | 3m/200k | 3.3m/98k | +10% / -51% | |
| T8 | implementer | 4m/300k | 2.9m/154k | -28% / -49% | |
| T9 | implementer | 3m/250k | 0.8m/225k | -73% / -10% | |
| T10 | implementer | 3m/200k | 0.6m/92k | -80% / -54% | |
| T11 | main | 3m/1.3M | not recorded | — | no closing line in `actuals.jsonl` |
| T12 | main | 8m/2M | 4.6m/1.9M | -43% / -5% | |
| T13 | verifier | 5m/1.7M | 9.7m/905k | +94% / -47% | four flows end to end, real repo included |
| T14 | reviewer | 3m/550k | 3.6m/1.30M | +20% / +137% | many demonstrations |
| T15 | reviewer | 3m/550k | 2.8m/942k | -7% / +71% | many demonstrations |
| T16 | reviewer | 3m/550k | 3.6m/814k | +20% / +48% | ran the full suite itself |

Flagged (|deviation| > 50 %): implementers run well under the 3-4m
estimate for mechanical tasks (T2, T3, T4, T6, T9, T10): the repo median
(2.2m) overestimates renames and small libs. T1 and T13 ran about twice
their estimate. Reviewer tokens ran over for all three passes. Not
measured: the fix round after the reviews (main, ~8m).

## Outside this plan

- Renaming the GitHub repository; committing in the documentation repo.
- Other display settings (only if visible in all three clients).
- Translating hints or README.

---
Next stage: Build implements, Test verifies, Deploy opens the PR.
