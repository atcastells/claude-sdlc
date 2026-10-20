# Context: project-profiles

Shared by every task of this plan. Read it before anything else. The main
session is the only writer. Committed: no personal data, credentials or
sensitive business data.

## Decisions that shape the code

- A repo declares its profile in `.claude/workflow.json`:
  `"profile": ".claude/profile"`. Valid only if relative, without `..`, and
  the resolved dir (`cd … && pwd -P`) stays under `cwd` (also `pwd -P`).
- Shared helper in `hooks/lib/profile.sh` (T1 writes it, T2 uses it):
  `project_profile_dir <cwd>` prints the resolved dir, or nothing.
- SessionStart output format: like `hooks/workflow-version-check.sh` —
  `{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:…}}`;
  notices start with `claude-sdlc:`. Header for the profile:
  `claude-sdlc: project profile (<dir>): adds to the organization profile, for this repo only.`
- The repo `profile.env` is parsed by the existing `load_profile <file>`
  (whitelisted `WF_*` keys, never sourced), loaded after the global one.

## Conventions

- bash 3.2 + jq on macOS; no `sort -V`, no suffix-less `sed -i`; decimals in jq.
- Hooks are testable from the payload alone (no `CLAUDE_PROJECT_DIR`).
- Script tests copy fixtures into `mktemp -d`, build symlinks at runtime,
  print `all passed`; the case runs the script (see `evals/cases/102a-*.json`).
- `evals/run.sh` takes a glob: `bash evals/run.sh '107*'`.
- Use Write/Edit for files, not heredocs in Bash.

## Key paths

- Hooks `hooks/`, libs `hooks/lib/`, cases `evals/cases/`, fixtures
  `evals/fixtures/`, settings `settings.template.json`.
- rune-world is at `/Users/acastells/rune-world` (read-only for every task
  except T6, which the main session does).

## Do not

- Edit files outside your task's `Files`; touch `~/.claude`; run git writes
  or `install.sh`.
- Run a hook by hand without `CLAUDE_SDLC_ACTUALS` and `TMPDIR` set to temp
  paths (hooks are live in this session and write real logs).
- Quote credential-shaped strings in reports; generate them at runtime.

## Learned

- W1: `project_profile_file <cwd> <name>` (in `hooks/lib/profile.sh`) prints
  a profile file only if it is regular, not a symlink, and physically inside
  the profile dir. Use it for `profile.env`, then `load_profile "<path>"`.
- W1: `project_profile_dir` returns 1 (nothing declared) or 2 (declared but
  invalid). Hooks other than `project-profile.sh` stay silent on 2.
- W1: python and heredocs in Bash get denied; write files with Write/Edit.
- W1: a script-type case that needs repo-only fixtures sets `repo_only: true`.
- Review: repo-controlled input is hostile. Cap sizes before reading (a big
  `profile.env` made a 5 s guard time out), never echo repo values into
  context, cap bytes as well as lines (a file with no newline is one line).
- Review: profile cases must not run code: no `script`, no `env`, `hook`
  only as a bare name under `{root}/hooks`.
