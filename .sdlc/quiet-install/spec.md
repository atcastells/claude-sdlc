# Spec: Quieter install output

- **Derived from**: `intent.md`
- **Status**: approved (2026-10-27, "apruebo", including the blocking rule)
- **Approved by**: product owner (no policy owner needed: no personal or
  sensitive business data; see Policy applied)

## Requirements

Each one traces to a line of the intent.

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | `install.sh` does not print the suite case by case; it starts the suite in the background and prints one line saying so and where the result goes. | "you see a lot of tests running"; "They run in the background" | A default install prints no `PASS`/`FAIL` case lines; it ends with ≤ 6 lines after the version line; the installer exits without waiting for the suite. |
| R2 | The background run writes a machine-readable result: version, start and end time, status (`running`, `green`, `red`), pass and fail counts, and each failed case with its name, kind and detail. | "if there are errors they are left somewhere" | After a run with one planted failing case, the result file has `status: red`, `fail: 1` and that case's name, kind and detail. |
| R3 | At session start, if the result for the installed version is `red`, Claude gets a short notice with the failed cases and how to fix or re-check; nothing is said when it is `green` or `running`. | "so that it [Claude] takes them into account to suggest corrections to the user" | SessionStart with a red result → context with the failed names and the commands; green / running / older version → silent. |
| R4 | The notice separates failures that **block the workflow** from those that can wait, and asks Claude to raise blocking ones to the user at once and the rest when relevant. | "if that blocks the workflow from working" | A failed `hook` case or one about `settings.json` / installed `CLAUDE.md` is listed as blocking; a failed template `file_contains` case is listed as "can wait". |
| R5 | `--verbose` (and `WORKFLOW_INSTALL_VERBOSE=1`) keeps today's behavior: suite in the foreground, case by case, install fails when red. | Open question "whether a verbose option is still wanted"; the repo's own `CLAUDE.md` relies on "clean test install; ends with the suite green" | `HOME=$(mktemp -d) ./install.sh --no-profile --verbose` prints the suite and exits 1 with a planted failure. |

## Design

**`evals/run.sh`.** New optional `EVALS_RESULT_JSON=<file>`: on finish it
writes the result of R2 there (via a temp file and `mv`, so readers never
see half a file), built with jq. Output on stdout does not change.

**`evals/install-verify.sh`** (new, installed with `evals/`): writes
`{status: "running", version, started}` to
`~/.claude/workflow/install-verify.json`, runs `run.sh` with
`EVALS_RESULT_JSON` pointing there and its stdout to
`~/.claude/workflow/install-verify.log`, and records its PID in
`install-verify.pid`. If a previous run's PID is still alive, it is stopped
first, so a second install never races the first.

**`install.sh`.** Default: launch `install-verify.sh` detached (`nohup …
&`) and print:

```
Installed 2.6.0. Hooks take effect in the NEXT Claude Code session.
Verifying in the background; Claude will tell you at session start if something fails.
Repos set up with an older version will say so when opened: /repo-setup upgrade.
Plugins are not part of this repo: reinstall yours with /plugin.
```

`--verbose` / `WORKFLOW_INSTALL_VERBOSE=1`: today's foreground run (R5).
`WORKFLOW_INSTALL_NO_VERIFY` keeps working.

**Notice at session start.** `hooks/workflow-version-check.sh` already runs
on SessionStart (startup|clear), reads `~/.claude/workflow/` and never
blocks; it gains one more check instead of a new hook. When
`install-verify.json` has `status: red` and its `version` equals the
installed `VERSION`, it adds:

```
claude-sdlc: install verification of 2.6.0 failed 2 cases.
Blocking (tell the user now, suggest the fix): <name> (<kind>): <detail>
Can wait (mention when relevant): <name> (<kind>): <detail>
Re-check: bash ~/.claude/evals/run.sh   Full log: ~/.claude/workflow/install-verify.log
```

At most 5 cases per group, then "and N more". A result for an older version
or with status `running` is ignored.

**Blocking vs can wait** (answers the intent's open question; the product
owner can change it at approval): a failed case **blocks** when its kind is
`hook`, or when its file is `settings.json` or the installed `CLAUDE.md`:
those are the guards and the rules every session depends on. Every other
failure (templates, skill texts, docs) **can wait**.

**Repo docs.** `CLAUDE.md` of this repo: the clean test install command
gains `--verbose`, so "ends with the suite green" stays true.

**Touched.** `install.sh`, `evals/run.sh`, `evals/install-verify.sh` (new),
`hooks/workflow-version-check.sh`, eval cases and scripts, `CLAUDE.md`,
`CHANGELOG.md`, `VERSION`. Nothing that `/repo-setup` leaves in projects
changes, so no `migrations/<version>.md`.

## Policy applied

- **Personal data**: none. The result file holds case names and details from
  the workflow's own evals.
- **Sensitive business data**: none.
- **Credentials**: none. Eval fixtures already use fake values; the log
  holds the same output the suite prints today.
- **Decisions about people / high risk**: no.

## Out of scope

- Running the suite in the background anywhere other than `install.sh`
  (`evals-on-config-change` keeps its behavior).
- A progress bar or spinner.
- Fixing failures automatically: Claude suggests, the user decides.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| The install no longer fails on a red suite (accepted in the intent's approval). | A broken install is used until the next session start. | The notice at the first session start; `--verbose` for CI and for this repo's checklist. |
| The user opens a session before the run finishes (~20 s installed, measured 2026-10-27; the spec first said ~3 s). | No notice in that session. | Status `running` is silent; the next start or `/clear` shows it. Documented in the install line. |
| A stale result from an earlier install is shown. | False alarm. | Notice only when the result's `version` equals the installed one; each install overwrites the result. |
| Background process outlives a failing terminal on macOS. | Orphan or missing result. | `nohup`; a result stuck at `running` for > 10 min is reported as "verification did not finish, run it again". |
| The blocking rule misclassifies a case. | Urgent failure shown as "can wait". | Rule kept simple and explicit; adjustable at approval. |

---
Next stage: Build reads this file and writes `plan.md`.
