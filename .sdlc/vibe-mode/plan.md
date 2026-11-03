# Plan: Vibe mode, with Spec as the default

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (maintainer, 2026-11-03, "apruebo")
- **Nothing is implemented until this file is approved.**

## Done means

- `bash evals/run.sh` green, and green with `WORKFLOW_PROFILE=profiles/example`
  (the only profile in this clone); the new cases `113*` were seen red
  before their code existed.
- Cases 65 and 65b (CLAUDE.md budgets) and 90-92 (status line) unchanged
  and green.
- `bash scripts/check-public.sh` exit 0; `HOME=$(mktemp -d) ./install.sh
  --no-profile --verbose` ends with the suite green and installs
  `hooks/mode.sh`, `hooks/lib/mode.sh` and `skills/vibe/`.
- With a test payload, `status-line.sh` prints `Spec` with no marker and
  `Vibe` with one.
- Left for the developer, after a real `./install.sh` (needs your go): a live
  session where `/vibe` changes the status line and `/vibe off` returns it.

## Stop and ask if

- T1 finds that `UserPromptSubmit` does not see `/vibe` as typed, or that
  the status line payload has no `session_id`: the spec's fallback changes
  T3 and T4, so the plan is revised before going on.
- `global/CLAUDE.md` cannot take the bullet within 75 lines without
  rewording another rule.
- An existing case goes red for a reason unrelated to this change (measure
  it on the clean tree first).
- `install.sh` needs more than adding the new files to what it copies.

## Tasks

| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|--------------------|---------|---------|-----|--------|
| T1 | Confirm in the official Claude Code docs (hooks reference, status line): `UserPromptSubmit` payload fields and whether a skill slash command reaches it as typed; `session_id` in the status line payload; whether `/clear` changes `session_id`. Write the findings, with URLs, at the end of this plan. | `.sdlc/vibe-mode/plan.md` | Each of the three answers cites a doc URL, or says "not documented" | R2, R3, R10 (risks) | main | — | 3m/2M | done (cause: none; two doc pages read in full, findings below) |
| T2 | `hooks/lib/mode.sh`: `mode_marker <session_id>` prints `${TMPDIR:-/tmp}/claude-sdlc-mode-<id>` or returns 1 when the id does not match `[A-Za-z0-9_-]+`; `mode_is_vibe <session_id>` returns 0 only when the marker exists. Scenario script and its case, red first. | `hooks/lib/mode.sh`, `evals/scripts/mode-lib-test.sh`, `evals/cases/113a-mode-lib.json` | `113a`: valid id gives the path; `../x`, empty and `a b` return 1; `mode_is_vibe` true only with the marker | R2, R10 | implementer | — | 2m/180k | done |
| T3 | `hooks/mode.sh`: on `UserPromptSubmit`, `/vibe` writes the marker and emits the Vibe context (under 15 lines, never the prompt text); `/vibe off` removes it and emits one line; other prompts emit nothing. On `SessionStart`: `compact` with marker re-emits the context; `startup` and `clear` delete the marker. Always exit 0. | `hooks/mode.sh`, `evals/scripts/mode-hook-test.sh`, `evals/cases/113b-mode-hook.json` | `113b` scenarios: on, off, other prompt, other session not affected, compact keeps, clear and startup reset, invalid id ignored, prompt text not echoed | R2, R3 | implementer | T1, T2 | 3m/300k | done |
| T4 | `status-line.sh`: segment after model and effort, `Spec` dimmed or `Vibe` bold magenta, from `mode_is_vibe` on `.session_id`; sources `hooks/lib/mode.sh` relative to the script. | `status-line.sh`, `evals/cases/113c-statusline-spec.json`, `113d-statusline-vibe.json`, `113e-statusline-no-session.json`, `113f-statusline-bad-session.json` | `113c-f` red first, then green; 90-92 still green | R10 | implementer | T1, T2 | 2m/200k | done |
| T5 | `skills/vibe/SKILL.md` (`/vibe`, `/vibe off`: the loop, when to read and write the map, rules of thumb for test, capture and promotion, what still applies, one line on confidential data) and templates `map.md` (mermaid flowchart, classes `idea`/`wip`/`done`/`dropped`) and `topic.md`. | `skills/vibe/SKILL.md`, `skills/vibe/templates/map.md`, `skills/vibe/templates/topic.md`, `evals/cases/113g-vibe-skill-*.json` | `113g*` (`file_contains`): reads `.sdlc/map.md` at start, updates it each iteration, no `.sdlc/<slug>/` for small changes, promotion seeds `intent.md`, git reserved, verify before claiming, map template has the four classes | R4, R6, R7, R8, R9 | main | — | 6m/3M | done (cause: none; 113g* 13 red, 2 needles split across lines fixed by rewrapping the skill text, 13 green; 86 lines) |
| T6 | `global/CLAUDE.md`: one bullet in the artifact chain section naming Spec as default and Vibe as the only exception to the chain and to the `plan.md` approval. | `global/CLAUDE.md`, `evals/cases/113h-core-vibe-rule.json` | `113h` red first; 65 (≤ 75) and 65b (≤ 110) green | R1, R5 | main | T5 | 3m/2M | done (cause: none; 113h red then green; core at 75 lines, 65 green) |
| T7 | `settings.template.json`: `UserPromptSubmit` entry for `mode.sh`, and `mode.sh` added to the `SessionStart` matcher `startup\|clear\|compact`. Check that `install.sh`'s merge carries the new event. | `settings.template.json`, `evals/cases/113i-settings-mode-hook.json` | `113i` red first; `evals/scripts/install-test.sh` green | R2, R3 | implementer | T3 | 2m/180k | done |
| T8 | 2.7.0: `VERSION`, `CHANGELOG.md` entry, one paragraph in `README.md`. No migration (spec: nothing `/repo-setup` leaves changes). Full suite, example-profile suite, `check-public.sh`, clean install. | `VERSION`, `CHANGELOG.md`, `README.md` | The four commands in "Verification commands" green | R1-R10 | main | T4, T6, T7 | 5m/3M | done (cause: none; suite 240/0, example profile 241/0, check-public exit 0, clean install 222/0, end-to-end Spec→Vibe→compact→Spec on the installed copy) |
| T9 | Verify the change and two adjacent flows: status line cost and effort (90-92) with and without the marker; `plan-resume` and `project-profile` still inject on `compact` next to `mode.sh`. | — | Verifier report with commands and output | R1, R3, R10 | verifier | T8 | 6m/1.8M | done (amber: 5 nits, 3 fixed in main with red scenarios first in mode-hook-test.sh, 113j added; TMPDIR between hook and status line only checkable live) |
| T10 | Review pass: bugs | — | Findings per `REVIEW.md` | all | reviewer | T9 | 4m/650k | done (0 important, 3 nits) |
| T11 | Review pass: security (untrusted `session_id` and prompt text, marker path, TMPDIR) | — | Findings per `REVIEW.md` | R2, R10 | reviewer | T9 | 4m/650k | done (0 important, 4 nits) |
| T12 | Review pass: conformance (bash + jq, macOS bash, no `sed -i`, budgets, English) | — | Findings per `REVIEW.md` | all | reviewer | T9 | 4m/650k | done (0 important, 5 nits) |

Estimates from `calibrate.sh` (2026-11-03): repo medians implementer
2.0m/177k, main 2.5m/2.1M, reviewer 3.6m/656k; verifier from the machine
log, 5.6m/1.8M. T5 and T8 are sized above the median (new skill; four
verification commands).

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| 1 | T1 (main), T2, T5 (main, after T1) | 9m | check `git diff --stat`; stop here if T1 changes the design |
| 2 | T3, T4, T6 (main) | 3m | check `git diff --stat` |
| 3 | T7 | 2m | — |
| 4 | T8 | 5m | — |
| 5 | T9 | 6m | — |
| 6 | T10, T11, T12 | 4m | collect findings |

T1 and T5 both run on main, so in wave 1 they are sequential next to T2.

- **Estimated wall-clock**: 29m
- **Sequential sum**: 44m
- **Estimated tokens**: about 14.6M

## Order and dependencies

T1 first because it can change T3 and T4. T2 is the shared marker logic both
read, so it goes before them. T6 after T5 so the rule names a skill that
exists. T7 needs the hook's final events. T8 closes the version once all
code is in; T9-T12 are the Test and Deploy stages.

## Test strategy

TDD: every `113*` case is written and seen red before its code.
If a test fails: fix the code, not the test.

- **Unit**: `113a` (marker path and id validation), `113c-f` (status line).
- **Integration**: `113b` (hook across events with one `TMPDIR`), `113i`
  plus `install-test.sh` (wiring survives install).
- **Manual verification**: the verifier runs `status-line.sh` with real
  payloads and the `SessionStart compact` hooks together; the live
  `/vibe` session is the developer's, after a real install.

## Verification commands

```
bash -n hooks/*.sh hooks/lib/*.sh install.sh evals/run.sh scripts/*.sh status-line.sh
bash evals/run.sh
WORKFLOW_PROFILE=profiles/example bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile --verbose
```

## Implementation risks

- `status-line.sh` runs on every refresh: the mode check must be one `test
  -e`, no extra `jq` beyond the one that reads `session_id`.
- `TMPDIR` can differ between the hook process and the status line; T1
  checks what the docs say, T9 checks both read the same path.
- Writing the hook from Bash heredocs can trip the outdated installed
  `production-gate`; use Write/Edit.

## Estimate vs actual

Filled at Build close from `.sdlc/vibe-mode/actuals.jsonl`.

| # | Runs on | Est | Actual | Deviation (min / tok) | Cause |
|---|---------|-----|--------|-----------|-------|
| T1 | main | 3m/2000k | 8.4m/751k | 180% / -62% | WebFetch truncated both doc pages; downloaded them with curl and read the sections; the clock also ran while T2 (blocking agent) worked |
| T2 | implementer | 2m/180k | 4.6m/59k | 130% / -67% | none reported; ran concurrently with T1's doc reads |
| T3 | implementer | 3m/300k | 2.5m/84k | -17% / -72% | none |
| T4 | implementer | 2m/200k | 2.2m/90k | 10% / -55% | traversal fixture for 113f |
| T5 | main | 6m/3000k | 2.3m/921k | -62% / -69% | sized above the median; skill written in one pass |
| T6 | main | 3m/2000k | 1.3m/408k | -57% / -80% | none |
| T7 | implementer | 2m/180k | 2.1m/165k | 5% / -8% | none |
| T8 | main | 5m/3000k | 2.2m/867k | -56% / -71% | none |
| T9 | verifier | 6m/1800k | ~13.2m (agent duration; not in actuals.jsonl) | ~120% / ? | wide probing: 22 tool calls, every invalid id against five events |
| T10 | reviewer | 4m/650k | 1.7m/258k | -57% / -60% | none |
| T11 | reviewer | 4m/650k | 0.7m/108k | -83% / -83% | none |
| T12 | reviewer | 4m/650k | 1.9m/159k | -53% / -76% | none |

After T9-T12 (main, not a planned task): fixed 3 verifier nits and 4 review
nits, each behavior change with a red scenario first (`mode-hook-test.sh`,
`113g11`, `113g12`); added `113j`. Skipped, noted in Found: tab after
`/vibe`, a per-user marker dir on Linux shared `/tmp`, stale markers of
abandoned sessions, thin evals for R7-R9 wording.

## Outside this plan

- The real `./install.sh` into `~/.claude`: done 2026-11-03 at the
  developer's go, with the saved profile; background suite green 236/0;
  installed CLAUDE.md at 110 lines (budget 110). Before it: suite with that
  profile 254/0 and no denylist term in the changed files.
- The live check of `/vibe` in a new session (yours).
- Trying Vibe in rune-world, and whether its `roadmap.html` feeds the map.
- A per-repo default mode (out of scope in the spec).

## T1 findings (official docs, 2026-11-03)

1. **`UserPromptSubmit` sees `/vibe` as typed, with `session_id`.** "When
   the prompt is a skill or custom command you typed, such as `/deploy
   staging`, the hook receives that line as you typed it rather than the
   expanded skill content." `session_id` is a common input field. Plain
   stdout or `hookSpecificOutput.additionalContext` is added to context.
   The event also fires on scheduled tasks, background subagent reports and
   cross-session messages, so `mode.sh` matches only a prompt whose first
   line is `/vibe` or `/vibe off`. Default timeout 30 s.
   https://code.claude.com/docs/en/hooks#userpromptsubmit-input
   (`UserPromptExpansion` also exists for typed commands; not needed.)
2. **Status line payload has `session_id`**, "stable for the lifetime of a
   session and unique per session"; the docs' own cache example keys a
   `/tmp` file by it, as this design does. The script runs at session start
   (including resume), on every new assistant message and after `/compact`,
   so the segment changes on the reply to `/vibe`. Whether it inherits the
   same `TMPDIR` as hooks: **not documented**; T9 checks it.
   https://code.claude.com/docs/en/statusline
3. **Does `/clear` change `session_id`?** **Not documented.** `SessionEnd`
   fires with reason `clear` and `SessionStart` with source `clear`, which
   suggests a new session. Either way the design holds: `SessionStart`
   `clear` deletes the marker of the id it receives.
   https://code.claude.com/docs/en/hooks#sessionstart

Adjustment for T3, inside R3 (resume is the same session, not a new one):
on `SessionStart` `resume` with the marker present, re-emit the Vibe context
as on `compact`, so the context agrees with the status line, which also
runs on resume. `fork` gets a new `session_id`, so it starts in Spec.

---
Next stage: Build implements, Test verifies, Deploy opens the PR.
