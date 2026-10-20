# Intent: Secondary profile per repository

- **Originator**: maintainer
- **Date**: 2026-10-20
- **Status**: approved by product owner (2026-10-20, "approved, inside
  rune-world": the secondary profile lives in the repo that uses it)
- **Slug**: project-profiles

## The problem, in the originator's words

> "Create a secondary profile for the rune-world repo, which is a side
> project, focused on game development and with language closer to that
> world."

Answers to the scoping questions (2026-10-20):

- Mechanism: **secondary, per repo**. The organization profile stays
  global; a repo declares its own profile, which is added on top in that
  repo only and says which organization rules have nothing to act on there.
- Content of the game profile: **glossary and tone of the world**, **game
  quality criteria**, **its own policy**, **profile evals**.

## Who it affects

The maintainer, in a personal game project (Rust core + Godot client, lore
as the source of truth, playtested on a handheld PC) that uses the workflow
since 2.3.0. Any other repo that needs rules of its own beyond the
organization profile.

## What happens if we do nothing

- One profile per machine: `install.sh --profile` appends it to the global
  `~/.claude/CLAUDE.md`, so the organization's rules (customer personal
  data, amounts in euros, the company secrets manager, the company
  compliance contact) load in the game repo, where they have nothing to act
  on and only add noise every turn.
- Game-specific rules can only go in the repo's own `CLAUDE.md`, which is
  already 196 lines: with the global file it is over the 200-line budget
  that `/repo-setup` checks.
- Hooks that read `profile.env` (credential-guard, production-gate) name the
  organization's secrets manager and policy in a repo that has neither.

## How we will know it is solved

- In the game repo, a session starts with the game profile in context and
  the organization profile marked as not applicable where it has nothing to
  act on; in every other repo nothing changes.
- The game profile carries: a glossary and tone for the world, game quality
  criteria, its own data and asset policy, and evals that run with the
  suite.
- The repo's own `CLAUDE.md` does not grow.
- Evals cover the mechanism; suite green, with and without the
  organization profile.

## Open questions

- Where a secondary profile lives: in `claude-sdlc/profiles/<name>/`
  (private, installed with `install.sh`) or inside the repo that uses it.
- Whether hooks should read the repo profile's `profile.env` instead of the
  global one (secrets manager and policy names in block messages).
- The organization's own instructions (set by its administrator for the
  account) apply to every session regardless of any profile; a profile can
  only state that they have nothing to act on in this repo. Whether using
  the organization account for a personal project needs a check with the
  organization's compliance contact is outside this change.

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.
