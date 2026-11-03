# Context: rules-command

Shared by every task of this plan. Read it before anything else. The main
session is the only writer. Committed: no personal data, credentials or
sensitive business data.

## Decisions that shape the code

- Owned dirs only: global `$HOME/.claude/rules/personal/`, repo
  `<repo root>/.claude/rules/personal/`. Nothing else under `rules/` is
  listed, written or deleted.
- File = `<topic>.md`, topic `^[a-z0-9]+(-[a-z0-9]+)*$`, ≤ 48 chars.
- Frontmatter only when there are `--path` globs, fixed shape:
  `---` / `paths:` / `  - "<glob>"` (one per line; `\` and `"` escaped) /
  `---`, then a blank line, then the rule text. No other fields (Claude Code
  reads only `paths`).
- Repo root = `git -C <dir> rev-parse --show-toplevel`; exclude file =
  `<git-common-dir>/info/exclude` (resolve a relative common dir against
  the repo root); line added: `.claude/rules/personal/`, once.
- Credential check: pipe a synthetic payload
  `{"tool_name":"Write","tool_input":{"content":<text>}}` to
  `$(dirname "$0")/../../hooks/credential-guard.sh`; exit 2 → refuse with
  the hook's message. Same relative path in the repo and installed.
- `rules.sh` exits 0 on success, 1 on a refused input (message on stderr,
  starting `rules:`), 2 on usage errors. Rule text comes on stdin.

## Conventions

- bash 3.2 + jq on macOS; no `sort -V`, no suffix-less `sed -i`, no
  `mapfile`; English identifiers and messages; comments only when not obvious.
- Script tests build everything in `mktemp -d` (temp HOME, temp git repo with
  `git init -q` and a committed file), never the real `~/.claude`; they print
  `all passed` and exit non-zero on the first failure, naming the scenario.
- A case runs the test script: see `evals/cases/107a-project-profile-scenarios.json`.
- `bash evals/run.sh '109*'` runs only this plan's cases.
- Fake credentials in tests are generated at runtime (credential-guard blocks
  writing them with Write/Edit): e.g. `printf 'ghp_%s' "$(printf 'a%.0s' $(seq 36))"`.

## Key paths

- `skills/rules/rules.sh`, `skills/rules/SKILL.md` (main writes the skill).
- `evals/scripts/rules-test.sh`, `evals/cases/109*.json`.
- `install.sh` copies `skills agents hooks evals` into `~/.claude`.

## Do not

- Edit files outside your task's `Files`; touch the real `~/.claude`; run git
  writes in this repo or `install.sh` against the real HOME.

## Learned

- Tests resolve the rules.sh path to absolute: the `$PWD` scenario `cd`s.
- `rules.sh` helpers to reuse: `glob_matches <root> <glob>` (brace-expanded,
  `git ls-files ':(glob)…'`), `expand_braces`, `verify_frontmatter`,
  `add_exclude`; `refuse`/`usage` set the exit codes.
- The harness may deny `rm -rf` and long compound Bash commands: use
  `mktemp -d` and `trap` for cleanup inside test scripts.

