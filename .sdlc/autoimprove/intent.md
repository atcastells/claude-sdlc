# Intent: Self-improvement loop for skills, rules and process

- **Originator**: maintainer
- **Date**: 2026-11-02
- **Status**: draft — open questions pending
- **Slug**: autoimprove

## The problem, in the originator's words

> "I want a global autoimprove skill in the style of the one Hermes Agent
> has, that improves the quality, timing and processes of the projects I
> work on. It must respect agentic best practices, and know whether skills
> are local or global."
> (translated from Spanish)

## Reference: what Hermes Agent does (checked 2026-11-02)

Source: hermes-agent.nousresearch.com/docs, pages `features/skills` and
`features/memory`.

- Skills are "procedural memory the agent creates and reuses". The system
  prompt asks it to save a skill after a multi-step workflow worth
  repeating, after finding the working path past errors, or when the user
  corrects its approach. A background review after the session can
  suggest skill changes.
- One tool, `skill_manage`: `create`, `patch` (preferred, targeted),
  full rewrite, `delete`, `write_file`/`remove_file`.
- Storage: `~/.hermes/skills/` is the source of truth; precedence
  `project → local → create_dir → external_dirs`. External dirs "are not a
  write-protection boundary".
- Governance: `skills.write_approval` defaults to `false` (free writes);
  with `true` writes wait in `~/.hermes/pending/skills/` for
  `/skills approve|reject`. Advisory linter (`oversized-body`,
  `references-sprawl`, `incident-log-shape`), content scanner,
  `curator lock <skill>`.
- Memory: `MEMORY.md` (2,200 chars) and `USER.md` (1,375 chars), frozen
  snapshot per session, with explicit "save these / skip these" lists and
  periodic nudges (`memory.nudge_interval`,
  `skills.creation_nudge_interval`; frequency not documented on the page).

Not confirmed in primary sources: the "rewrites its skills every 15
tasks" and "~40 % faster" claims in third-party articles.

## What the workflow has today (verified in the repo, 2026-11-02)

Signals already measured, with nothing that reads them back as
improvements:

- `~/.claude/actuals.jsonl`: 156 task records with estimate vs actual
  (minutes, ktokens, deviation, cause, runner, repo), from `task-actuals`.
  `calibrate.sh` uses them only for estimates.
- `.sdlc/<slug>/context.md` `Learned:` lines folded per plan; plan
  "Estimate vs actual" tables with causes.
- Hook blocks (`credential-guard`, `test-guard`, `production-gate`) and
  verifier/reviewer findings: not aggregated anywhere.
- Incident evals in `~/.claude/evals/` (e.g. `i-11`, which runs jest in
  another repo and failed at session start on 2026-11-02 only because that
  repo was on another branch: passed on re-run, 220/0).

Where skills and rules live, and who owns each:

| Kind | Location | Owner / how it changes |
|---|---|---|
| Workflow-managed global | `~/.claude/skills/{sdlc,intent,repo-setup,rules}`, listed in `~/.claude/workflow/manifest` | source repo `~/claude-sdlc` (`workflow/source`); editing `~/.claude` is lost on the next `install.sh` |
| Personal global | `~/.claude/skills/<x>` not in the manifest | the user, directly |
| Project (shared) | `<repo>/.claude/skills/<x>`, tracked by git | the team, through a PR |
| Plugin | `~/.claude/plugins/...` cache | upstream; read-only here |
| Synced (claude.ai) | `~/.claude/skills/synced/` | claude.ai; not edited locally |
| Personal rules | `~/.claude/rules/personal/`, `<repo>/.claude/rules/personal/` | only through `/rules` (`rules.sh`) |
| Org profile / repo `CLAUDE.md` | profile repo, the repo | by hand / PR, line budgets (cases 65, 65b) |

## Who it affects

The maintainer first (every repo with the workflow installed); later
anyone installing claude-sdlc. How often: not known yet.

## What happens if we do nothing

Measured deviations, repeated corrections and hook blocks keep being
recorded and never turn into a better skill, rule, hook or estimate; the
same mistakes are corrected by hand session after session.

## How we will know it is solved

To be confirmed by the originator. Proposal:

- `/autoimprove` turns the recorded signals into a short list of concrete
  proposals, each with its evidence, its target (and that target's owner
  from the table above) and an eval that proves it.
- No proposal edits a workflow-managed file in `~/.claude`, a shared
  project file outside a branch, a plugin or a synced skill.
- A later run shows whether an applied proposal moved its metric
  (deviation, repeat count).

## Open questions

- Apply mode: propose only, or apply some kinds directly.
- Trigger: on demand only, or also a nudge / scheduled run.
- Which targets are in scope (skills, rules, hooks + evals, CLAUDE.md,
  estimates and process).
- Where it ships: core skill in claude-sdlc (public, English, profile
  agnostic) or a personal global skill.
- Whether transcripts (`~/.claude/projects/*/*.jsonl`) may be read as a
  signal: they can hold customer data and sensitive business data.

## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.
