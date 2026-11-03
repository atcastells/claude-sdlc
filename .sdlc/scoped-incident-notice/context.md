# Context: scoped-incident-notice

Shared by every task of this plan. Read it, then `spec.md`, before anything
else. The main session is the only writer. No personal data, credentials or
sensitive business data.

## Decisions that shape the code

- Case field `"repo"`: optional string path, `~` allowed; expanded with
  `run.sh`'s existing `expand`. Read right after the `repo_only` check.
- `EVALS_SKIP_REPO=1`: a case with `repo` prints `SKIP (repo case)` and
  `continue`s (not counted in pass/fail).
- `EVALS_REPO=<dir>`: cases without `repo` → `SKIP (not this repo)`; cases
  whose resolved repo (`cd "$r" 2>/dev/null && pwd -P`) is neither the
  resolved `EVALS_REPO` nor a prefix of it followed by `/` → same SKIP; a
  repo that does not exist never matches. Resolve `EVALS_REPO` once, before
  the `cd "$(dirname "$0")"` (relative paths resolve from the caller, like
  `EVALS_ROOT`).
- Plain run (neither variable): byte-identical stdout and counts to today.
- With `EVALS_RESULT_JSON`, each failed entry gains `hook`: the case's
  `.hook` (e.g. `credential-guard.sh`) or `""`. Keys today: `name, kind,
  file, detail`.
- Callers that set `EVALS_SKIP_REPO=1`: `evals/install-verify.sh` (its
  `run.sh` call), `install.sh` (the `--verbose` foreground `run.sh` call,
  line ~180), `hooks/evals-on-config-change.sh` (both `bash "$suite"`
  calls).
- Notice (`hooks/workflow-version-check.sh`, jq formatter): blocking =
  `.hook` in `credential-guard.sh`, `test-guard.sh`, `production-gate.sh`.
  Blocking group text:
  `Protection not active (tell the user now): <hook> — <name>: <detail>`
  joined with `; `, then
  `. Action: bash <source>/install.sh; if it persists, tell the workflow maintainer.`
  `<source>` = content of `$home/source` (the hook already has `$home`);
  missing → `./install.sh in the claude-sdlc repo`.
  Other group text: `Not blocking (do not interrupt; mention in one line under Found at the end of the run): <name> (<kind>): <detail>`.
  Header, 5 + "and N more", `Re-check:` line and stuck-running notice stay.

## Conventions

- bash 3.2 + jq on macOS; no `sort -V`, no suffix-less `sed -i`, no
  `mapfile`.
- Script tests build everything in `mktemp -d` (temp HOME / WORKFLOW_HOME),
  never the real `~/.claude`; print `all passed`; see
  `evals/scripts/run-result-json-test.sh` and
  `evals/scripts/install-verify-notice-test.sh` for the fixture pattern.
- A case runs a test script: see `evals/cases/110a-run-result-json.json`.
- Run only your cases: `bash evals/run.sh '110*'` / `'111*'`. The main
  session runs the whole suite.
- Baseline 2026-11-03: `bash evals/run.sh` → PASS 206, FAIL 0.

## Do not

- Edit files outside your task's `Files`; touch the real `~/.claude`; run
  git writes or `install.sh` against the real HOME.
- Change existing scenario expectations except the two group texts (S3).

## Learned
- Implementer reports must use `TASK: <slug>/T<n>`: `subagent-report-check`
  rejects `S<n>`. Number plan tasks `T<n>`.
- `skills/sdlc/SKILL.md` is at its 160-line budget: any addition needs a cut.
