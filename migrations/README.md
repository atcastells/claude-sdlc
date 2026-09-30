# Project migrations

A workflow version that changes **project files** (what `/repo-setup` creates
in each repo: `CLAUDE.md`, `.claude/settings.json`, `.claude/workflow.json`,
`REVIEW.md`, `.sdlc/README.md`, `.gitignore`) ships a
`migrations/<version>.md`. If it only changes `~/.claude`, `install.sh` is
enough and no migration is needed.

The `workflow-version-check` hook lists the migrations between the project's
version and the installed one. `/repo-setup upgrade` applies them in order,
with a single confirmation, and bumps `workflow_version`.

## Format

```markdown
# <version> — <one-line title>

## Applies if
<condition on the repo; "always" if none>

## Changes
1. `<file>`: <what is added or changed>. **Merge, do not replace.**

## Check
<how to see it was applied: a grep, a check.sh item>
```

A migration is written once and never rewritten. If it is wrong, the next
version fixes it.
