# Plan: Secondary profile per repository

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-10-20)
- **Nothing is implemented until this file is approved.**

## Done means

- `bash evals/run.sh` → `FAIL: 0`, every new case seen red first;
  `WORKFLOW_PROFILE=<org profile> bash evals/run.sh` → `FAIL: 0`.
- Installed-mode run with `WORKFLOW_PROFILE=/Users/acastells/rune-world/.claude/profile`
  → the rune-world profile cases pass.
- `bash scripts/check-public.sh` → exit 0; `bash -n` clean;
  `HOME=$(mktemp -d) ./install.sh --no-profile` → suite green, the temp
  `settings.json` registers `project-profile.sh`.
- `verifier` green, or amber with its items resolved.
- Version 2.5.0. Real install and the rune-world commit are the developer's;
  T9 runs after the install, in a new session in rune-world.

## Stop and ask if

- The glossary would need terms not found in rune-world's `docs/` or `lore/`.
- The rune-world profile cannot fit 120 lines with the four sections.
- An existing case must change.
- `install.sh` needs a change.
- An implementer touches a file outside its `Files`.

## Tasks

`Est` from `calibrate.sh` (2026-10-20): implementer median actual (repo,
n=16) ~2m/200k; main median actual (all) ~1.2m/3M; scout starting table
1.5m/650k; verifier (all, n=1) 8m/1.5M.

| # | Task | Files | Test that proves it | Req | Runs on | Depends | Est | Status |
|---|------|-------|---------------------|-----|---------|---------|-----|--------|
| T1 | `project-profile.sh` + path helper `project_profile_dir <cwd>` in `hooks/lib/profile.sh` | `hooks/project-profile.sh`, `hooks/lib/profile.sh`, `evals/scripts/project-profile-test.sh`, `evals/fixtures/project-profile/`, `evals/cases/107a-project-profile-scenarios.json` | Scenarios: declared → header + content as SessionStart context; none → silent; `resume` → silent; absolute / `..` / symlink-escape path → one-line notice, no content; > 150 lines → truncation note | R1, R2 | implementer | — | 2m/200k | done (W1; diff read; symlinked profile file rejected, scenario g) |
| T3 | `run.sh`: `WORKFLOW_PROFILE` in installed mode | `evals/run.sh`, `evals/fixtures/profile-cases/`, `evals/scripts/run-profile-installed-test.sh`, `evals/cases/108a-run-profile-installed-mode.json` | 108a: an installed-mode run with a fixture profile includes its case | R4 | implementer | — | 2m/200k | done (W1; diff read) |
| T4 | Registration + public template + repo-setup line | `settings.template.json`, `skills/repo-setup/templates/project-profile/`, `skills/repo-setup/SKILL.md`, `evals/cases/84h-hook-registered-project-profile.json`, `evals/cases/108b-repo-setup-project-profile.json` | 84h `project-profile.sh` registered; 108b skill mentions `"profile"`; template has the four headings | R5, R6 | implementer | — | 2m/200k | done (W1; diff read) |
| T5 | Glossary sources: game-dev and world terms used in rune-world `docs/` and `lore/`, each with file:line | — (read-only) | Report with ≤ 40 terms, each cited | R7 | scout | — | 1.5m/650k | done (36 cited terms; no handheld performance figures in the sources) |
| T2 | `credential-guard` and `production-gate` load the repo `profile.env` on top | `hooks/credential-guard.sh`, `hooks/production-gate.sh`, `evals/cases/98g..98h` | 98g/98h: a repo profile names its own secrets manager / policy in the block message; 98a–98f green | R3 | implementer | T1 | 2m/200k | done (W2; diff read: names only, detection unchanged) |
| T6 | rune-world profile + declaration | `rune-world/.claude/profile/{CLAUDE.md,profile.env,evals/cases/}`, `rune-world/.claude/workflow.json` | Profile cases green with `WORKFLOW_PROFILE`; ≤ 120 lines; hook output from the rune-world root has the header | R7, R8 | main | T1, T5 | 2m/3M | done (cause: every glossary line checked against its source; 99 lines; rw-a..rw-f green) |
| T7 | Release 2.5.0 | `VERSION`, `CHANGELOG.md` | case 40; suites, check-public, clean install | R9 | main | T1–T6 | 1.2m/3M | done (cause: none) |
| T8 | Verification | — | `verifier`: the change + adjacent flows (`workflow-version-check` on SessionStart alongside the new hook; credential-guard without a repo profile) | all | verifier | T7 | 8m/1.5M | done (green; 2 nits: notice wording for a missing dir, `"."` rejected) |
| T9 | Live check after the developer installs | — | New session in rune-world: the profile header is in context; a session in claude-sdlc has none | R2, R8 | main | T8 + install | 1.2m/3M | done (cause: developer confirmed the header in a new rune-world session; `/repo-setup upgrade` there kept `profile`) |
| T14 | Review fixes 1–3: size caps in `project_profile_file` (profile.env ≤ 4 KB, CLAUDE.md ≤ 16 KB), empty `cwd` = no profile; notice never echoes the value; own notice for a missing dir; 12 KB byte cap + truncation note; quoted prefix strip; header says "repo-authored" | `hooks/lib/profile.sh`, `hooks/project-profile.sh`, `evals/scripts/project-profile-test.sh` | New scenarios seen red: oversized profile.env/CLAUDE.md ignored; notice without the value; missing dir notice; no-newline 200 KB file capped with note; path with `[1]` | Review (approved "arregla todo") | implementer | — | 2m/200k | done (diff read; red evidence = the main session's three reproductions on the old hook, now green: gate 0 s, no echo, 12 KB cap) |
| T15 | Review fix 4 + new case kind: profile cases (from `WORKFLOW_PROFILE`) may not use `script` or `env`, `hook` must be a bare name; kind `file_lacks` (`pattern` ERE, case-insensitive, optional `until` heading); `EVALS_ROOT` not inherited by 108a's inner run | `evals/run.sh`, `evals/scripts/run-profile-installed-test.sh`, `evals/fixtures/profile-cases/`, `evals/cases/108e-run-file-lacks.json` | New scenarios seen red: a profile case with `script` or `env` is skipped with a reason; `file_lacks` passes/fails as expected with and without `until`; 108a green with `EVALS_ROOT` set | Review | implementer | — | 2m/200k | done (diff read) |
| T16 | Review fix 5 + guard coverage: eval for the public template; guards ignore symlinked, oversized or undeclared repo `profile.env` | `evals/cases/108d…108d6-template-profile-*.json`, `evals/scripts/guard-repo-profile-test.sh`, `evals/cases/98i-guard-repo-profile-scenarios.json` | 108d red if a heading is removed; 98i scenarios | Review | implementer | T14 | 2m/200k | done (diff read; mutation-tested since the behavior already worked) |
| T17 | Review fix 6 + docs: rune-world case `rw-g` (`file_lacks` until the "sin objeto" heading); drop the Git bullet from the rune-world profile; spec Policy applied amendment; CHANGELOG | `rune-world/.claude/profile/{CLAUDE.md,evals/cases/rw-g-*.json}`, `.sdlc/project-profiles/spec.md`, `CHANGELOG.md` | rw-g red with a planted term, green without | Review | main | T15 | 1.2m/3M | done (cause: none; rw-g red on a planted copy, green on the real profile) |
| T18 | Re-verify after the review fixes | — | `verifier` | all | verifier | T14–T17 | 3m/800k | done (green; 1 nit: an existing profile dir name appears in the header) |
| T10 | `repo-setup` upgrade keeps other `workflow.json` keys | `skills/repo-setup/SKILL.md`, `evals/cases/108c-repo-setup-upgrade-keeps-keys.json` | 108c seen red first | R10 (amended) | main | — | 1.2m/3M | done (cause: none) |

## Schedule

| Wave | Tasks (in parallel) | Longest | Then (main) |
|------|---------------------|---------|-------------|
| W0 | main writes `.sdlc/project-profiles/context.md` | 2m | — |
| W1 | T1, T3, T4 (implementers) ‖ T5 (scout) | 2m | diffs, fold `Learned:`, suite (~3m) |
| W2 | T2 (implementer) ‖ T6 (main) | 2m | same (~3m) |
| W3 | T7 | 1.2m | — |
| W4 | T8 | 8m | consolidate (~3m) |
| — | T9 after the developer's install | 1.2m | — |

- **Estimated wall-clock** (W0–W4): 2 + 2 + 3 + 2 + 3 + 1.2 + 8 + 3 ≈
  **24 min**; sequential sum ≈ 22 min + 9 min of checks = 31 min.
- **Estimated tokens**: ~0.8M implementers + 0.65M scout + 6M main +
  1.5M verifier ≈ 9M; T9 another ~3M main.

## Order and dependencies

T2 uses T1's path helper. T6 needs T1 (to check the injection) and T5's
cited terms. T7 releases W1–W2. T9 needs the hooks installed.

## Test strategy

TDD: every case written and seen red first. Fix the code, not the test.

- **Unit**: script scenarios in `mktemp -d` (symlinks built at runtime);
  `hook` cases with payloads.
- **Integration**: clean install; installed-mode run with the rune-world
  profile.
- **Live**: T9.

## Verification commands

```
bash -n hooks/*.sh hooks/lib/*.sh install.sh evals/run.sh scripts/*.sh skills/sdlc/calibrate.sh evals/scripts/*.sh
bash evals/run.sh
WORKFLOW_PROFILE=<org profile> bash evals/run.sh
WORKFLOW_PROFILE=/Users/acastells/rune-world/.claude/profile bash ~/.claude/evals/run.sh   (after install)
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile
```

## Implementation risks

- rune-world is another repo: only `rune-world/.claude/profile/` and its
  `workflow.json` are touched; nothing else there.
- Manual hook runs must set `CLAUDE_SDLC_ACTUALS` and `TMPDIR` to temp paths
  (lesson from 2.4.0).
- `SKILL.md` of `sdlc` is not touched (160-line budget).

## Estimate vs actual

Measured live by the installed 2.4.0 hook. Estimates from `calibrate.sh`
median actuals (first plan estimated that way).

| # | Runs on | Est | Actual | Deviation (min / tok) | Cause |
|---|---------|-----|--------|-----------------------|-------|
| T5 | scout | 1.5m/650k | 1.2m/220k | −20 % / −66 % | starting table (no scout history); the 650k row was high |
| T4 | implementer | 2m/200k | 2.9m/156k | +45 % / −22 % | none |
| T3 | implementer | 2m/200k | 7.6m/104k | +280 % / −48 % | none reported; tokens low, so most likely waiting (permission prompts), not work |
| T1 | implementer | 2m/200k | 19.9m/269k | +895 % / +35 % | security finding added mid-task; python/heredoc attempts denied and redone |
| T2 | implementer | 2m/200k | 1.9m/124k | −5 % / −38 % | none |
| T6 | main | 2m/3M | 11.7m/5.5M | +485 % / +84 % | every glossary line checked against its source |
| T7 | main | 1.2m/3M | 3.3m/1.7M | +175 % / −44 % | none |
| T8 | verifier | 8m/1.5M | 3.0m/780k | −63 % / −48 % | one earlier sample only |

- **Tokens** track the median well for implementers (104–269k vs 200k).
  **Minutes** do not: the two misses (T1, T3) are waits and rework, not
  work; the hook cannot tell them apart.
- **Main**: the median (~1.2 min) comes from short status-and-release
  tasks; a content task with verification (T6) is a different size. Size
  matters for `main`, unlike for the implementer.
- Wall-clock: ~11:50 (W0) → ~12:40 (T8), against 24 min estimated; T1's
  20 minutes sit on the critical path.

## Outside this plan

Replacing the organization profile per repo; moving rune-world's existing
`CLAUDE.md` content; the `/repo-setup` budget rule.

---
Next stage: Build implements, Test verifies, Deploy opens the PR.
