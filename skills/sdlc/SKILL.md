---
name: sdlc
description: Artifact chain for an agentic SDLC. Every stage ends by writing an artifact in git that the next stage reads — intent.md, spec.md, plan.md, the diff with its tests, the PR with its findings, the incident record. Use it when the user says /sdlc, asks to start a new feature, write an intent/spec/plan, prepare a PR, or record an incident. Also when they ask which stage something is in or what comes next.
---

# Agentic SDLC — artifact chain

Six stages. **A stage ends by committing an artifact that the next one reads.**
The commit chain is the audit trail: who asked for what, what the agent
produced, who approved it.

| # | Stage | Writes | Reads | Approves (human) |
|---|-------|--------|-------|------------------|
| 1 | Plan | `intent.md` | the originator's request | Product owner |
| 2 | Design | `spec.md` | `intent.md` | Product owner + policy owner |
| 3 | Build | `plan.md` → diff + tests | `spec.md`, `CLAUDE.md` | Engineer approves `plan.md` |
| 4 | Test | green evals | the diff | Code owner on the PR |
| 5 | Deploy | PR + review findings | `REVIEW.md` | Code owner + release manager |
| 6 | Maintain | `incident.md` → new `intent.md` | monitoring | Service owner |

## Where they live

Repo root, always committed:

```
.sdlc/<slug>/intent.md
.sdlc/<slug>/spec.md
.sdlc/<slug>/plan.md
.sdlc/<slug>/incident.md   (only when it applies)
REVIEW.md                  (root, the repo's review policy)
```

`<slug>` in kebab-case, derived from the intent. E.g. `.sdlc/search-suggestions/`.

## Routing

With an argument (`/sdlc design`), go to that stage. **Without one**, look at
which artifacts exist in `.sdlc/<slug>/` and propose the next stage without
writing anything yet; if several slugs are open, ask which one.

**Never skip a stage.** If the input artifact is missing, say so and offer to
write it. A `plan.md` without a `spec.md` is a plan built on invented
assumptions.

---

## Stage 1 — Plan → `intent.md`

Capture the idea **in the originator's words**. Do not design here, do not
propose a solution. Template: `templates/intent.md`.

To fill it in or complete it, use the `intent` skill: one question at a time,
with options grounded in the code, and each answer written to the file as it
arrives. If the originator does not know something, it is written down as a
gap — an honest gap is worth more than an invented filler.

Close by asking the product owner to approve before moving to Design.

## Stage 2 — Design → `spec.md`

Read `intent.md`. Turn it into requirements and design, with policies
applied. Template: `templates/spec.md`.

Always apply the rules in `~/.claude/CLAUDE.md`, including the organization
profile if one is installed (data protection, business confidentiality,
credentials). If the design touches personal or sensitive business data, flag
it in the policy section and recommend a review by the compliance contact the
profile names.

Every requirement must trace to a line of `intent.md`. Anything that does not
trace is scope someone added — move it to "out of scope" and say so.

## Stage 3 — Build → `plan.md`, then the diff

Read `spec.md` and the repo's `CLAUDE.md`. Write `plan.md`: what "done"
means, when to stop and ask, tasks, files touched, tests that prove them,
risks. Template: `templates/plan.md`.

**Stop and wait for the engineer's approval before implementing.** The
playbook is explicit: no autonomous mode without an approved plan.

Once approved, implement. TDD for business logic: red test first. If a test
fails, **fix the code, not the test** — the `test-guard` hook blocks
weakening tests during a fix.

When each task closes, update its *Status* column in `plan.md` (done, in
progress, blocked + a short note). It is the live task list: it survives
compaction and a new session, which resumes by reading that column.

## Stage 4 — Test → self-verification

Verify your work before anyone sees it: tests, build, or a screenshot. Use
the `verifier` subagent to check the change plus two adjacent flows; it
reports, it does not fix.

Nothing reaches human review with a broken build.

## Stage 5 — Deploy → PR + findings

Read the repo's `REVIEW.md` (if missing, offer to create it from
`templates/REVIEW.md`). Three passes: bugs/logic, security, and conformance
against `spec.md` + `plan.md`. Launch three `reviewer` subagents in parallel,
one per pass (`bugs`, `security`, `conformance`); you consolidate: open every
cited file:line, drop duplicates, keep the 5 nits that matter most. A dynamic
workflow for the review only when the user asks for one: it costs several
times a subagent review.

Classify each finding **Important** or **Nit**, at most 5 nits. Important is
only what would block the merge, with file, line, why it is wrong and how to
demonstrate the failure; what you cannot demonstrate goes to "Unconfirmed".
Human attention moves up a level: not every line, but whether the change does
what the plan intended and whether the risk is acceptable.

Git is reserved for the developer (see `CLAUDE.md`): prepare the PR, draft
the description and the findings, but **you do not commit or push**.
Production requires `RELEASE_APPROVAL`; the `production-gate` hook checks it.

## Stage 6 — Maintain → `incident.md` → new `intent.md`

When production fails, write `incident.md`: what broke, which control
failed, impact, root cause. Template: `templates/incident.md`.

Two mandatory outputs:
1. A new `intent.md` that starts the chain again for the fix.
2. **A permanent eval** in `evals/cases/` of the claude-sdlc repo (or in
   the organization profile if the rule is org-specific); it is installed in
   `~/.claude/evals/`. Every production incident becomes an eval that is
   never removed.

---

## Session, context and cost

Every turn resends the whole conversation; most of it comes from cache, and
what costs is extra turns and output. Sources: the Opus 5.5 and Sonnet 5.5
guides and "what a task costs" (claude.dev, 2026).

- **One stage, one cut.** Closing a stage writes its artifact: that is the
  natural pause for `/compact` or, when switching slug, `/clear`. The next
  session resumes from the artifact and the *Status* column, not from memory.
- **Do not break the cache mid-session**: switching model, toggling fast mode
  or connecting MCP servers rewrites it; do it at the start or after a cut.
  Effort is different: with an API key or subscription, changing it keeps the
  cache on Opus 5.5; on Bedrock, Vertex or a gateway it clears it.
- **Effort and model ladder.** `medium` by default → `high` if it gets stuck →
  `xhigh` for complex problems → `/advisor fable` (Fable advises at decision
  points, the cache stays) → Fable 5.1 as the main model only if Opus 5.5
  still fails twice at `xhigh`. Lower effort with the setting, not by asking
  the prompt to "think less".
- **Down the ladder: small models read, never for edits.** Searches, logs,
  test runs, verification and review go to Explore, `verifier`, `reviewer` or
  a Sonnet/Haiku subagent; edits stay in the main session (a mechanical
  multi-file edit: main model at `low`). Pin each agent's `model` in its
  definition; do not set `CLAUDE_CODE_SUBAGENT_MODEL`, which moves every
  agent at once. Check the evidence of each subagent before accepting it (open
  the file:line it cites) and consolidate the results in a table.
- **Measure, do not estimate**: `/usage` gives the real cost of the session.
