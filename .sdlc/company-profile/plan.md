# Plan: Read a workflow-agnostic company profile

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-11-03, "apruebo"; T6 needs its own OK; T5 waits for the 2.6.0 commit)
- **Nothing is implemented until this file is approved.**

## Done means

- `HOME=$(mktemp -d) ./install.sh --profile evals/fixtures/profile-company --company-repo evals/fixtures/company-acme --verbose`
  ends green with the composed `CLAUDE.md` of R2.
- With the real adapter migrated (T6), a reinstall produces an installed
  `CLAUDE.md` with the same rules as today (diff limited to blank lines and
  the order core → company → workflow additions); profile cases green.
- `bash evals/run.sh` → `FAIL: 0` (with the org profile too); new cases seen
  red first; `check-public.sh` exit 0; `bash -n` clean.
- `verifier` green, or amber with its items resolved.
- Version: folded into the unreleased 2.6.0 (decision 2026-11-03: "Todo como 2.6.0"; the three shared files could not be split cleanly).

## Stop and ask if

- The composed real `CLAUDE.md` passes 110 lines (case 65b).
- Removing frontmatter needs more than "leading block between two `---`
  lines".
- An implementer touches a file outside its `Files`.

## Tasks

`Est`: implementer median for this repo (quiet-install plan, n=23): 2m/180k;
main 3m/2.5M; verifier 6m/2.2M.

| # | Task | Files | Test that proves it | Req | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|-----|---------|---------|-----|--------|
| T2 | `install.sh`: `company.json` (`url`, `rules`), `--company-repo`, validation, composition, saved dir; tty prompt / tty-less error with the clone command; fixture company repo; example `company.json` | `install.sh`, `evals/fixtures/company-acme/`, `profiles/example/company.json`, `evals/scripts/company-install-test.sh`, `evals/cases/112b-company-install.json`, `evals/cases/112c-company-repo-agnostic.json` | R2, R3, R4 scenarios on temp HOMEs; no `company.json` → byte-identical to today; 112c `file_lacks` on the fixture | R1–R4, R8 | implementer | — | 2m/180k | done (W1; diff read; verifier fixes: unclosed frontmatter kept whole, `--company-repo` without `company.json` → exit 2, tty re-asks when the saved dir is gone; example ships `company.json.example` so it installs without a real repo) |
| T3 | `workflow-install` skill: where is it / clone it, fixed suggestions, check only the chosen path, show one command | `skills/workflow-install/SKILL.md`, `evals/cases/112d-workflow-install-skill.json` | R6 `file_contains` red then green | R6 | implementer | — | 2m/180k | done (W1; diff read; cases split 112d1–112d5; verifier fix: option "show me the clone command" and "never runs" rule) |
| T4 | Session-start notice for a missing company repo | `hooks/workflow-version-check.sh`, `evals/scripts/company-notice-test.sh`, `evals/cases/112e-company-notice.json` | R7 scenarios | R7 | implementer | — | 2m/180k | done (W1; diff read; verifier NIT fixed: no stderr when no profile is installed) |
| T5 | 2.6.0 entry (no version bump), `CHANGELOG.md`, repo `CLAUDE.md` structure line, `profiles/example/README.md` | those files | case 40; suites; check-public | all | main | T2–T4 | 3m/2.5M | done (folded into 2.6.0; CHANGELOG, repo CLAUDE.md structure line, example README) |
| T6 | **Outside the repo, needs your OK**: migrate the local org adapter: add `company.json` with the docs repo clone URL and the rules path inside it; cut the company rules from its `CLAUDE.md`, keep the workflow-specific lines; back up first | `<adapter>/company.json`, `<adapter>/CLAUDE.md` | temp-HOME install with the real adapter + docs repo: rules equal to today's installed ones; profile cases green | R1, R2 | main | T2 | 3m | done (OK 2026-11-03; backup in `~/.claude/workflow/backups/profile-<org>-<date>/`; option 1 for the 110-line budget: rules intro removed in the docs repo, adapter block 3 lines → 108; 8 content cases point to the docs repo file in repo mode) |
| T7 | Verification | — | `verifier`: the change + adjacent flows (install without `company.json` unchanged; `--no-profile`; reinstall reusing saved profile and company repo) | all | verifier | T5, T6 | 6m/2.2M | done (amber → fixed: 2 IMPORTANT, 3 NITs; open NIT: a `'` inside url/dir would break the shown command; T5/T6 not covered) |

## Schedule

| Wave | Tasks | Longest | Then (main) |
|------|-------|---------|-------------|
| W1 | T2, T3, T4 (parallel) | 2m | diffs, suite |
| W2 | T5, then T6 | 3m | — |
| W3 | T7 | 6m | consolidate |

- **Estimated wall-clock**: ~17m
- **Estimated tokens**: ~6.8M

## Test strategy

TDD: each scenario red before the code; if a test fails, fix the code, not
the test. Temp `HOME`/`WORKFLOW_HOME` only; never the real `~/.claude`.
Task ids are `T<n>` (`subagent-report-check` requires it).
