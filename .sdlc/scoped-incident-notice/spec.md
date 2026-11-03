# Spec: An install-verification notice that interrupts only when it should

- **Derived from**: `intent.md` (decision "a", 2026-11-03)
- **Status**: approved (2026-11-03, "apruebo")
- **Approved by**: product owner (no policy owner needed: see Policy applied)

## Requirements

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | A case can declare the product repo it tests with an optional `"repo"` field (path, `~` allowed). A plain `run.sh` run (no variables) runs it as today. | "Incident evals of a product repo..." | Same output and counts as today for a manual `bash evals/run.sh`. |
| R2 | `EVALS_SKIP_REPO=1` makes `run.sh` skip every case with `repo` (`SKIP (repo case)`, not counted). The background install verification, `install.sh --verbose` and `evals-on-config-change` set it. | "do not run on install or on config changes" | A fixture suite with a failing repo case is `green` with the variable; the three callers pass it (checked by scenario or `file_contains`). |
| R3 | `EVALS_REPO=<dir>` makes `run.sh` run only the cases whose `repo` is `<dir>` or contains it, after resolving symlinks; prefix match needs a trailing `/`. No matching case → `PASS: 0 FAIL: 0`, exit 0. | "they run in the Test stage of that repo" | Scenarios: dir = repo → runs; subdir → runs; `…/app-2` vs repo `…/app` → not run; missing repo → not run. |
| R4 | The `verifier` agent, in the Test stage, runs `EVALS_REPO=<repo root> bash ~/.claude/evals/run.sh` and reports it under Tests; a red result makes the verdict red. | same | `agents/verifier.md` says so; `file_contains` case. |
| R5 | The SessionStart notice is **blocking** only when a failed case tests `credential-guard.sh`, `test-guard.sh` or `production-gate.sh` (case field `hook`, recorded in the result). Its text names the protection that is not active and the action: reinstall from the source repo (`<source>/install.sh`), and tell the workflow maintainer if it persists. | "only interrupts ... when one of the workflow's protections ... is not working, with an action any workflow user can take" | Red result with a failed `credential-guard.sh` case → notice with "not active", the install command and "maintainer". |
| R6 | Any other failure goes in one non-interrupting line: Claude is told not to raise it at session start and to mention it in one line under the closing "Found" heading. | "Every other install-verification failure is mentioned in one line at the end of the run, without interrupting" | Red result with only a `workflow-version-check.sh` or `file_contains` failure → no "Blocking" text; the line says "do not interrupt" and "Found". |
| R7 | The `sdlc` skill, stage 6: an incident eval that runs in a product repo sets `"repo"`. | prevents the problem coming back | `file_contains` case on `skills/sdlc/SKILL.md`. |

## Design

**`evals/run.sh`.** After the `repo_only` check: read `.repo // empty`.
With `EVALS_SKIP_REPO=1` and a repo → `SKIP (repo case)`. With
`EVALS_REPO` set → skip cases without a repo, and cases whose resolved repo
(`expand`, `cd … && pwd -P`) is neither the resolved `EVALS_REPO` nor a
prefix of it followed by `/`. With `EVALS_RESULT_JSON`, each failed entry
also gets `hook` (the case's `.hook`, or `""`).

**Callers.** `evals/install-verify.sh` and the `--verbose` path of
`install.sh` run `run.sh` with `EVALS_SKIP_REPO=1`;
`hooks/evals-on-config-change.sh` too.

**`hooks/workflow-version-check.sh`.** In the jq formatter: blocking =
`.hook` in the three guard hooks. The "Blocking" group's text becomes:
`Protection not active (tell the user now): <hook> — <name>: <detail>.
Action: bash <source>/install.sh; if it persists, tell the workflow
maintainer.` (`<source>` from `workflow/source`, or `./install.sh in the
claude-sdlc repo` when missing). The other group's text becomes:
`Not blocking (do not interrupt; mention in one line under Found at the end
of the run): ...`. The header, the 5 + "and N more" limit, the re-check
line and the stuck-running notice stay.

**`agents/verifier.md`** step 2 and **`skills/sdlc/SKILL.md`** stage 6
gain one sentence each.

## Policy applied

- **Personal data**: none.
- **Sensitive business data**: none. Local repo paths in case files, which
  already hold them in `args`.
- **Credentials**: none.
- **Decisions about people / high risk**: no.

## Out of scope

- Why `i-11` failed at install time (other repo's state): signal for
  `autoimprove`.
- Deduplicating the notice across sessions (it shows while the result is
  red, as today).
- Running incident evals in CI.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| A real regression in a product repo goes unseen if no Test stage runs there | Caught later | The repo's own tests still run; incident evals still run on a manual `run.sh` |
| Session or verifier in a git worktree (other path) | `EVALS_REPO` matches nothing | Accepted; noted in the CHANGELOG |
| A broken non-guard hook (`plan-resume`, `subagent-report-check`) no longer interrupts | Mentioned only in Found | Accepted: those degrade help, not protection |
| Incident cases without `repo` | Still run on install and config change, as today | Plan task S5 adds `repo` to the 19 existing cases |

---
Next stage: Build reads this file and writes `plan.md`.
