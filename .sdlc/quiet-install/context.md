# Context: quiet-install

Shared by every task of this plan. Read it before anything else. The main
session is the only writer. Committed: no personal data, credentials or
sensitive business data.

## Decisions that shape the code

- Result file shape (Q1 writes it, Q2 and Q3 read it), built with jq:
  `{"version": "<VERSION of the root, or null>", "started": "<ISO 8601 UTC>",
  "finished": "<ISO 8601 UTC or null>", "status": "running|green|red",
  "pass": N, "fail": N, "failed": [{"name", "kind", "file", "detail"}]}`.
  `file` = the case's `file` field expanded, or `""`; `detail` = the text
  run.sh prints in `FAIL (...)`.
- `run.sh` writes it only when `EVALS_RESULT_JSON` is set; temp file in the
  same dir + `mv`. Without the variable, stdout must be byte-identical.
- Paths under `${WORKFLOW_HOME:-$HOME/.claude/workflow}`:
  `install-verify.json`, `install-verify.log`, `install-verify.pid`.
- `install-verify.sh` takes the installed root (`~/.claude`) as `$1`, runs
  `$1/evals/run.sh`; kills a previous PID only if `ps -p <pid> -o command=`
  contains `install-verify.sh` or `evals/run.sh`.
- Notice (Q3) is added by `hooks/workflow-version-check.sh`, lines start with
  `claude-sdlc:`; blocking = kind `hook`, or `file` ending in
  `settings.json` or `.claude/CLAUDE.md`. `running` older than 10 min →
  "install verification did not finish; run: bash ~/.claude/evals/run.sh".
- `install.sh` default: `nohup bash "$dst/evals/install-verify.sh" "$dst"
  >/dev/null 2>&1 &`; `--verbose` or `WORKFLOW_INSTALL_VERBOSE=1` = today's
  foreground block, unchanged. `WORKFLOW_INSTALL_NO_VERIFY` unchanged.

## Conventions

- bash 3.2 + jq on macOS; no `sort -V`, no suffix-less `sed -i`, no
  `mapfile`; `date -u +%Y-%m-%dT%H:%M:%SZ` for timestamps.
- Script tests build everything in `mktemp -d` (temp HOME / WORKFLOW_HOME),
  never the real `~/.claude`; print `all passed`; bounded waits (≤ 20 s
  loop), no bare `sleep` to wait for a background process.
- A case runs the test script: see `evals/cases/107a-project-profile-scenarios.json`;
  hook cases run without `CLAUDE_PROJECT_DIR`.
- `bash evals/run.sh '110*'` runs only this plan's cases.

## Key paths

- `evals/run.sh`, `evals/install-verify.sh` (new), `hooks/workflow-version-check.sh`,
  `install.sh`, `evals/scripts/`, `evals/cases/110*.json`.

## Do not

- Edit files outside your task's `Files`; touch the real `~/.claude`; run git
  writes or `install.sh` against the real HOME.
- Another plan (`rules-command`) is being built in the same tree
  (`skills/rules/`, `evals/*/rules*`, `109*`): ignore its in-flight red cases.

## Learned

- An installed root (`~/.claude`) has its version in `workflow/VERSION`, not
  `VERSION`: code reading a root's version checks both.
- A fixture root without `install.sh` makes `run.sh` run in installed mode;
  inner runs unset the caller's `EVALS_ROOT` and `WORKFLOW_PROFILE` (`env -u`).
- Hook tests set `WORKFLOW_HOME`/`WORKFLOW_SOURCE` and a payload `cwd` in an
  empty temp dir, so no project notices appear.

