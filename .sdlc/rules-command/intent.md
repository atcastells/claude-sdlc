# Intent: Interactive command to manage rules by scope

- **Originator**: maintainer
- **Date**: 2026-10-27
- **Status**: approved by product owner (2026-10-27, "apruebo")
- **Slug**: rules-command

## The problem, in the originator's words

> "I want there to be a command to add rules interactively, where the user
> chooses whether to add, modify or delete a rule, and the scope of that
> rule."
> (translated from Spanish)

Context from the same conversation: the earlier question was "how can the
user easily add rules and have them applied cleanly depending on the
context".

Answers to the scoping questions (2026-10-27):

- Scopes: **"this repo or global"** (verbatim, translated).
- **"They are personal rules, they are not shared"** (verbatim,
  translated). This corrects an earlier answer that read "global" as the
  organization profile: global means every repo of this user, not the
  organization.
- "This repo" means **the repo the user is working in at that moment**
  (verbatim, translated). Where a personal rule for that repo is stored so
  it is not shared is a design decision for `spec.md`.
- Within "this repo": **the user chooses** whether the rule applies to the
  whole repo or only to some files, with globs suggested from files that
  exist in the repo.

## Who it affects

Developers who install the workflow and want a rule of their own (personal,
for one repo, or for some files of a repo) without editing `CLAUDE.md` by
hand. How many and how often: not known yet.

What the workflow does today, verified in the repo (2026-10-27):

- Rules can be added only by editing files by hand: `global/CLAUDE.md` (core,
  budget ≤ 75 lines), the organization profile's `CLAUDE.md` (appended at
  install, installed budget ≤ 110 lines, cases 65 and 65b), the repo's
  `CLAUDE.md`, or the project profile's `CLAUDE.md` (injected by
  `hooks/project-profile.sh`, at most 150 lines, always loaded).
- Nothing in the repo uses `.claude/rules/` or `~/.claude/rules/`, the
  Claude Code mechanism for rules scoped to files with `paths:` frontmatter
  (source: code.claude.com/docs/en/memory, "Path-specific rules").
- `/repo-setup` audits `CLAUDE.md` but not rule files.

## What happens if we do nothing

- Rules are not added: editing files by hand is enough friction that users
  skip it and repeat the same preferences by hand in every session (chosen
  by the originator, 2026-10-27).

## How we will know it is solved

- A user adds, modifies and deletes a rule only through the command,
  without editing files by hand and without needing to know where the rule
  is stored (chosen by the originator, 2026-10-27).

## Open questions

- Whether a "rule" is only an instruction for Claude (context, not
  enforced) or can also become a blocking hook when it must never be broken.
- Command name and form (a skill invoked with `/<name>`), and whether it
  clashes with a built-in command.
- Whether rules that load always count toward the existing line budgets.
- Not asked for: editing the organization profile or any rule shared with
  the team. Those stay maintained by hand in their own repos.

## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|
| 2026-10-27 | Scopes to choose from | "This repo or global" | maintainer |
| 2026-10-27 | What "global" means | Organization profile | maintainer |
| 2026-10-27 | Who approves organization changes | "They are personal rules, they are not shared" (reverts the row above: global = every repo of this user) | maintainer |
| 2026-10-27 | Whole repo or some files | The user chooses, globs suggested | maintainer |
| 2026-10-27 | Where a repo rule is stored | "This repo" = the repo the user is in; storage left to the spec | maintainer |
| 2026-10-27 | How we know it is solved | Add, modify, delete without touching files | maintainer |
| 2026-10-27 | Cost of doing nothing | Rules are not added | maintainer |

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.
