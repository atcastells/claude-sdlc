# Context: company-profile

Shared by every task of this plan. Read it, then `spec.md`, before anything
else. The main session is the only writer. Everything public: no
organization names, no personal data, no credentials.

## Decisions that shape the code

- `company.json` in a workflow profile dir: `{"url": "<git clone URL>",
  "rules": "<path relative to the company repo>"}`. Both strings required;
  read with jq. No `company.json` → install byte-identical to today.
- Company repo dir resolution in `install.sh`, in this order:
  `--company-repo <dir>` → content of `$wf/company-repo` → ask (tty: `read`
  with a prompt that shows `git clone <url> <dir>` for who does not have it;
  no tty: exit 1, message naming `--company-repo <dir>` and `git clone
  <url>`). Nothing searches the disk (no `find` over `$HOME`).
- All of that, plus validation, happens **before** `mkdir -p "$dst" "$wf"`
  (install.sh ~line 57): a rejected company repo writes nothing.
- Validation of `rules`: not empty, not absolute, no `..` component, no
  newline; `"$dir/$rules"` is a regular file and not a symlink; its
  `pwd -P` parent is inside the repo's `pwd -P`; size ≤ 16384 bytes (`wc -c`)
  checked before reading. Message on failure starts `company rules:`.
- Composition: core `global/CLAUDE.md`, blank line, rules with a leading
  YAML frontmatter removed (only when line 1 is exactly `---`: drop through
  the next line that is exactly `---`, plus one following blank line if
  any), blank line, profile `CLAUDE.md` (if present).
- After a successful install: `$wf/company-repo` holds the resolved
  absolute dir; with `--no-profile` or a profile without `company.json` it
  is removed.
- Option parsing: `--company-repo` needs a value (exit 2 otherwise, like
  `--profile`). Help text (`sed -n '2,7p'`) mentions it.
- Skill name `workflow-install`, dir `skills/workflow-install/`, a single
  `SKILL.md` (no scripts). It reads `url` and `rules` from
  `$(cat ~/.claude/workflow/profile)/company.json`.
- Notice (`hooks/workflow-version-check.sh`): profile dir from
  `$home/profile`; if it has `company.json` and (`$home/company-repo` is
  missing, or `<dir>/<rules>` is not a file) → message starting
  `claude-sdlc:` that suggests `/workflow-install`. Otherwise silent.

## Conventions

- bash 3.2 + jq on macOS; no `sort -V`, no suffix-less `sed -i`, no
  `mapfile`.
- Install tests: temp HOME, `WORKFLOW_INSTALL_NO_VERIFY=1`, `</dev/null`
  for the no-tty path; see `evals/scripts/install-test.sh` (fixture
  `evals/fixtures/profile-acme`). Print `all passed`.
- Hook tests: see `evals/scripts/install-verify-notice-test.sh` (temp
  `WORKFLOW_HOME`, payload `cwd` in an empty temp dir).
- Skill shape and frontmatter: see `skills/rules/SKILL.md`.
- A case that runs a script: `evals/cases/110a-run-result-json.json`;
  `file_lacks`: grep `"kind":"file_lacks"` in `evals/cases/`.
- Run only your cases: `bash evals/run.sh '112*'`. Baseline 2026-11-03:
  full suite PASS 211, FAIL 0.

## Do not

- Edit files outside your task's `Files`; touch the real `~/.claude`; run
  git writes or `install.sh` against the real HOME.
- Report ids: `TASK: company-profile/T<n>`.

## Learned
- An active `company.json` in `profiles/example/` makes the example
  uninstallable (it needs a real repo): the example ships
  `company.json.example`.
- `production-gate` (installed, older) blocks a `grep` whose pattern holds
  "prod": known false positive.
