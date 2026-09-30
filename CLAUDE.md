# claude-sdlc

Source of truth for an agentic SDLC workflow for Claude Code: global rules,
skills, hooks, the `verifier` agent and an eval suite. Installed into
`~/.claude` with `install.sh`. The global rules live in `global/CLAUDE.md`;
this file only describes the repo.

## Commands

```bash
bash evals/run.sh                                   # core suite; ~3 s; "PASS: N FAIL: 0 (repo: ...)"
WORKFLOW_PROFILE=profiles/<name> bash evals/run.sh  # core + that profile's cases
bash scripts/check-public.sh                        # before publishing: exit 0, 0 denylisted terms
HOME=$(mktemp -d) ./install.sh --no-profile         # clean test install; ends with the suite green
./install.sh --profile profiles/<name>              # real install into ~/.claude: ask first
bash -n hooks/*.sh hooks/lib/*.sh install.sh evals/run.sh scripts/*.sh
```

## Structure

- `global/CLAUDE.md` → `~/.claude/CLAUDE.md`, with the profile's `CLAUDE.md`
  appended. Budgets: core ≤ 75 lines, installed ≤ 110 (cases 65, 65b).
- `hooks/` (deterministic, exit 2 = block); `hooks/lib/semver.sh` and
  `hooks/lib/profile.sh` are shared.
- `skills/{sdlc,intent,repo-setup}`, `agents/verifier.md`.
- `evals/cases/*.json`, `evals/fixtures/`, `evals/scripts/`. `run.sh` tests the
  root above it: the repo here, `~/.claude` once installed. `file_repo` = path
  in the repo when it differs from the installed one; `repo_only` = skipped
  when installed.
- `profiles/example/` is public; every other `profiles/*` is git-ignored.
- `VERSION`, `CHANGELOG.md`, `migrations/<version>.md`.
- `.sdlc/<slug>/`: changes to this repo go through the chain too.

## Releasing a version

1. Bump `VERSION` (semver; criteria in `CHANGELOG.md`).
2. Add a `CHANGELOG.md` entry.
3. If anything `/repo-setup` leaves in projects changes (templates, project
   `settings.json`, `REVIEW.md`, `workflow.json`), write
   `migrations/<version>.md` (format in `migrations/README.md`). Without it,
   already configured repos never hear about the change.
4. `bash evals/run.sh` green (with your profile too), `scripts/check-public.sh`
   green, then `./install.sh`.

## Conventions

- Everything public in English. Organization-specific text only in a profile.
- Scripts in bash + jq, compatible with macOS bash and `sort`. No `sort -V`
  and no suffix-less `sed -i` in installed scripts. Decimals are formatted in
  jq: `printf %f` follows the locale.
- `hook` cases run without `CLAUDE_PROJECT_DIR` (`run.sh` unsets it): hooks
  must be testable from their payload alone.
- Every new rule gets its eval, seen red first.
- Fixtures and evals use credentials with a valid format and a fake value
  (`squ_aaa...`). `credential-guard` blocks writing them with Write/Edit;
  generate them at runtime or with jq.

## Git

Reserved for the developer (see `global/CLAUDE.md`). Base branch: `main`.
Run `scripts/install-git-hooks.sh` once per clone.

## What Claude gets wrong

- An outdated installed `production-gate` fires on commands that contain
  "prod" or the hook's name next to "push"/"release" in prose. To write docs,
  use Write/Edit instead of heredocs in Bash.
