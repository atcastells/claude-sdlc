# Plan: Interactive command to manage rules by scope

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-10-27, "apruebo, lo hacemos en main")
- **Nothing is implemented until this file is approved.**

## Done means

- `/rules` is installed as a skill; add, modify and delete work for both
  scopes through `skills/rules/rules.sh`, with every scenario of R1–R7
  covered by `evals/scripts/rules-test.sh` and each new case seen red first.
- In a temp git repo, after add/modify/delete with scope "this repo",
  `git status --porcelain` is identical to before (R4).
- `bash evals/run.sh` → `FAIL: 0`; with the organization profile too.
- `bash scripts/check-public.sh` → exit 0; `bash -n` clean on the new
  script; `HOME=$(mktemp -d) ./install.sh --no-profile` → suite green and
  `~/.claude/skills/rules/` present.
- `verifier` green, or amber with its items resolved.
- Version 2.6.0. Commit, PR and real install are the developer's.

## Stop and ask if

- Claude Code does not load `.claude/rules/personal/*.md` (nested) or
  `~/.claude/rules/personal/*.md` in a live session: the storage design
  relies on recursive discovery (docs, "Organize rules").
- A YAML check needs a dependency beyond bash + jq.
- An existing case must change, or `install.sh` needs a change.
- An implementer touches a file outside its `Files`.

## Tasks

`Est` from `calibrate.sh` (2026-10-27): implementer median actual (repo,
n=23) 2.0m/180k; main median actual (repo, n=7) 3.1m/2.5M; verifier median
actual (all, n=10) 6.3m/2.2M.

| # | Task | Files | Test that proves it | Requirement (spec) | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|--------------------|---------|---------|-----|--------|
| T1 | `rules.sh write`: owned dirs (`~/.claude/rules/personal/`, `<repo>/.claude/rules/personal/`), kebab-case topic, `--path` globs quoted as YAML strings and checked against `git ls-files` (zero matches → refuse), frontmatter re-read after writing, repo scope adds `.claude/rules/personal/` to `$(git rev-parse --git-common-dir)/info/exclude` once, refuses when anything under that dir is tracked, refuses text that the installed `credential-guard.sh` blocks (synthetic Write payload) | `skills/rules/rules.sh`, `evals/scripts/rules-test.sh`, `evals/cases/109a-rules-script-scenarios.json` | Scenarios in a temp HOME + temp repo: global write lands in `~/.claude/rules/personal/`; repo write lands in the repo and `git status --porcelain` is unchanged; glob `**/*.sql` written with `paths:`; zero-match glob refused; glob with braces/quotes round-trips; tracked `personal/` refused; credential-shaped text refused; exclude line not duplicated on second write | R2, R3, R4, R6 | implementer | — | 2m/180k | done (W1; diff read; 109a red before the script, green after) |
| T4 | Eval: `install.sh` leaves `~/.claude/rules/` alone | `evals/scripts/install-keeps-rules-test.sh`, `evals/cases/109c-install-keeps-rules.json` | Temp HOME with `~/.claude/rules/personal/x.md` → `install.sh --no-profile` (with `WORKFLOW_INSTALL_NO_VERIFY=1`) → file unchanged, not in `backups/` | R7 | implementer | — | 2m/180k | done (W1; diff read; red shown on a scratch copy with `rules` in the manifest) |
| T3 | `skills/rules/SKILL.md`: flow action → scope → whole repo / some files → globs (from `rules.sh globs`) → text → preview → confirm; modify/delete from `rules.sh list`; delete confirms; one-time notices (rule is not a lock; no customer data; > 40 always-loaded lines); never edits rule files by hand; trigger-style description; Gotchas section | `skills/rules/SKILL.md`, `evals/cases/109d-rules-skill-*.json` | `file_contains` cases: asks the action first, uses `AskUserQuestion`, calls `rules.sh`, has the "not a lock" notice, has `## Gotchas`; seen red before the file exists | R1, R5, R7 | main | — | 3m/2.5M | done (cause: none; 109d1–d5 red before the file, green after; 78 lines) |
| T2 | `rules.sh list` (JSON: scope, topic, file, paths, first 3 lines; only `personal/`), `delete` (owned dirs only, refuses a path outside them), `globs` (top directories and extensions from `git ls-files`, each with its match count) | `skills/rules/rules.sh`, `evals/scripts/rules-test.sh` | New scenarios: list shows two rules with scope and paths and ignores a non-personal `rules/x.md`; delete removes only the named topic; delete of `../x` refused; globs output only patterns with ≥ 1 match | R3, R5, R7 | implementer | T1 | 2m/180k | done (W2; diff read; 109* 7/7 green) |
| T5 | Release 2.6.0 | `VERSION`, `CHANGELOG.md` | case 40 (semver); suites, check-public, clean install | all | main | T1–T4 | 3m/2.5M | done (cause: waited for quiet-install Q4 so the clean install ran once for both; suite 205/0, with org profile 216/0, check-public exit 0, clean `--verbose` install 189/0) |
| T8 | Verifier fixes (T6 red): `write` builds the file in a temp file in the same dir, verifies it, then `mv` (a refused modify keeps the old rule); text whose first line is `---` without `--path` refused up front with a clear message | `skills/rules/rules.sh`, `evals/scripts/rules-test.sh` | New scenarios red first: refused modify leaves the old rule byte-identical; leading `---` refused with its own message, no file created | R6 | implementer | T6 | 2m/180k | done (diff read; temp file + verify + `mv`; leading `---` refused up front; scenarios red first) |
| T9 | Verifier fixes in the skill: text passed with a quoted heredoc (`<<'RULE'`), full script path in every command, full text of a rule read from `list`'s `file` (read-only) for modify/delete, wording of the "never by hand" line | `skills/rules/SKILL.md`, `evals/cases/109d6-rules-skill-heredoc.json` | 109d6 (`<<'RULE'`) red first; 109d1–d5 green | R1, R5 | main | T6 | 3m/2.5M | done (cause: none; 109d6 red first, 109d* 6/6 green; 92 lines) |
| T6 | Verification | — | `verifier`: the change + adjacent flows (`install.sh` upgrade over 2.5.0 keeps settings; `credential-guard` still blocks a Write with a fake credential) | all | verifier | T5 | 6m/2.2M | done (red: 2 important — a refused modify deleted the rule; rule text in double quotes in the skill — fixed in T8, T9; 4 nits) |
| T10 | Re-verify after T8/T9 | — | `verifier` | all | verifier | T8, T9 | 3m/800k | done (green; 2 nits: no trap for a killed write leaves a dot file; preview may start with `---`) |
| T7 | Live check after the developer installs | — | New session: `/rules` adds a repo rule for `**/*.sh` in a scratch repo; reading a `.sh` file loads it, `git status` clean; delete removes it | R1–R4 | main | T6 + install | 3m/2.5M | pending |

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| W0 | main writes `.sdlc/rules-command/context.md` | 2m | — |
| W1 | T1, T4 (implementers) ‖ T3 (main) | 3m | diffs, fold `Learned:`, suite (~3m) |
| W2 | T2 | 2m | same (~3m) |
| W3 | T5 | 3m | — |
| W4 | T6 | 6m | consolidate (~3m) |
| — | T7 after the developer's install | 3m | — |

- **Estimated wall-clock**: ~30m to T6 (waves + main checks)
- **Sequential sum**: ~21m
- **Estimated tokens**: ~12.6M (main tasks dominate)

## Order and dependencies

T1 fixes the script's interface and its test harness; T2 extends the same
file, so it waits. T3 only depends on the interface already written in
`spec.md`, so it runs alongside. T4 is independent. Release after all code,
verification after release, live check after the developer installs.

## Test strategy

TDD: each scenario red before the code. If a test fails, fix the code, not
the test.

- **Unit**: `rules-test.sh` drives `rules.sh` in a temp HOME and a temp git
  repo (never the real `~/.claude`), asserting files, frontmatter,
  `info/exclude` and `git status`.
- **Integration**: 109c runs the real `install.sh` into a temp HOME.
- **Manual verification**: `verifier` reads the skill flow against R1–R7;
  T7 checks that Claude Code actually loads a nested path-scoped rule.

## Verification commands

```
bash -n skills/rules/rules.sh evals/scripts/rules-test.sh evals/scripts/install-keeps-rules-test.sh
bash evals/run.sh
WORKFLOW_PROFILE=profiles/<org> bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile
```

## Implementation risks

- YAML check without a YAML parser: the script writes a fixed shape (a
  `paths:` list of double-quoted strings with `"` and `\` escaped) and the
  check re-parses that shape; anything else is refused rather than guessed.
- `git rev-parse --git-common-dir` returns a relative path in the main
  checkout; resolve it against the repo root.
- macOS bash 3.2 and BSD tools: no `sed -i` without suffix, no `sort -V`,
  no `mapfile`.
- `credential-guard.sh` is read from the installed `~/.claude/hooks/`; in
  repo mode tests use the repo copy.

## Estimate vs actual

Filled at Build close from `.sdlc/rules-command/actuals.jsonl`.

| # | Runs on | Est | Actual | Deviation | Cause |
|---|---------|-----|--------|-----------|-------|
| T1 | implementer | 2m/180k | 9.3m/202k | +365 % / +12 % | flagged; no cause reported by the implementer (test harness bug with a relative path, per its report) |
| T2 | implementer | 2m/180k | 1.5m/93k | −25 % / −48 % | — |
| T3 | main | 3m/2.5M | 0.8m/793k | −73 % / −68 % | flagged; none |
| T4 | implementer | 2m/180k | 3.7m/174k | +85 % / −3 % | flagged; two Bash calls denied and redone |
| T5 | main | 3m/2.5M | 18.3m/3.0M | +510 % / +21 % | flagged; waited for quiet-install Q4 so one clean install covered both |
| T6 | verifier | 6m/2.2M | not recorded | — | the verifier report had no `TASK:` line the hook could read |
| T8 | implementer | 2m/180k | 1.2m/61k | −40 % / −66 % | — |
| T9 | main | 3m/2.5M | 1.9m/882k | −37 % / −65 % | — |
| T10 | verifier | 3m/800k | 2.4m/463k | −20 % / −42 % | — |

## Outside this plan

Everything in the spec's "Out of scope". The `quiet-install` slug is a
separate chain.

---
Next stage: Build implements, Test verifies, Deploy opens the PR.
