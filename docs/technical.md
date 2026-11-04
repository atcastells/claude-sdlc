# Claudio — technical details

An agentic SDLC workflow for [Claude Code](https://code.claude.com):
global rules, skills, hooks, a `verifier` agent and an eval suite,
installed into `~/.claude`.

## Install by hand

Requires `git` and `jq`.

```bash
git clone https://github.com/atcastells/claudio ~/claudio && cd ~/claudio && ./install.sh --no-profile
```

With an organization profile: `./install.sh --profile <dir>` (add
`--company-repo <dir>` if the profile reads its rules from a company
repository). With no option, `install.sh` reuses the previous profile.
The steps an agent follows are in [install.md](install.md).

## What you get

- **Every change leaves a trail.** `intent.md` → `spec.md` → `plan.md` →
  diff + tests → PR → `incident.md`, committed in the repo. Nothing is built
  before you approve the plan.
- **A faster mode when you are exploring.** `/vibe` switches the session
  from Spec to Vibe: small steps, no approval stops, a mermaid map of the
  project kept up to date, and the status line says which mode you are in.
- **Plan hints in the status line** (terminal): the task in progress
  against its estimate (`T3 4m/6m`, yellow over, red over twice), what is
  left of the plan (`5/12 · ~22m left`), and `compact between tasks` at 70%
  context with a task open (90% always). Read from `.sdlc/*/plan.md` and
  `actuals.jsonl`.
- **Guards that do not depend on the model.** Hooks block credentials in
  code, weakened tests and actions on production.
- **Git stays yours.** Claude prepares; you commit, push and release.
- **Work verified before you see it.** A `verifier` runs the build, the tests
  and two nearby flows; three `reviewer`s check bugs, security and fit with
  the spec.
- **Lower cost.** Haiku looks things up, Sonnet verifies and reviews, the
  main model edits.
- **Rules that stay true.** An eval suite tests the configuration itself and
  runs whenever it changes.
- **Your organization's rules on top.** Language, data protection, secrets
  manager and compliance contact go in a profile:
  [`profiles/example`](../profiles/example/README.md). A profile's
  `company.json` may also name a `spinner_verbs` file in the company
  repository (a JSON array of 1–200 phrases, 1–80 characters each); the
  installer sets them as `spinnerVerbs` in `replace` mode.

## Formerly claude-sdlc

Claudio was called `claude-sdlc` up to 2.7.0. Existing installs keep
working from their old folder; see `CHANGELOG.md` for 3.0.0.
