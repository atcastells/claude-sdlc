# Intent: Delegate read-only work to Sonnet 5.5 and adopt recent Claude Code features

- **Originator**: maintainer
- **Date**: 2026-10-07
- **Status**: approved by product owner (2026-10-07, "ok con la propuesta")
- **Slug**: subagent-delegation

## The problem, in the originator's words

> "Review whether there are improvements we can apply, above all around
> delegating to Sonnet 5.5 and the new features that have come out."

> "Check claude.dev on costs and pricing, and the open questions about agents
> and subagents."

> "Subscription. OK with the proposal."

## Who it affects

Every developer with the workflow installed: each session runs the SDLC
stages on the main model (Opus 5.5 by default), including Stage 5 review,
which is almost entirely reading.

## What happens if we do nothing

- Stage 5's three review passes keep running on the main model, at twice the
  per-token price of Sonnet 5.5 (claude.dev, "Building with Claude Sonnet
  5.5": $4/$20 vs $2/$10 per Mtok).
- The `verifier` runs at whatever effort the session has; Sonnet 5.5's
  recalibrated levels recommend `high` for verification.
- The `sdlc` skill forbids changing effort mid-session, which is stricter
  than needed on a subscription: "On Opus 5.5 with an API key or a Claude
  subscription, changing effort keeps the cache" (claude.dev, "What a task
  costs on Opus 5.5").
- Subagent reports are accepted on trust of their format; nothing checks that
  an IMPORTANT finding carries its demonstration.
- After compaction, nothing points the session back at `plan.md`'s *Status*
  column, which the skill names as the resume point.

## How we will know it is solved

- Stage 5 runs its three passes as Sonnet 5.5 subagents; the main session
  only consolidates and checks evidence.
- A verifier/reviewer report without a verdict line, or with an IMPORTANT
  finding without a demonstration, is sent back to the subagent.
- After a compaction in a repo with an open `plan.md`, the session receives
  the unfinished tasks as context.
- The ladder in `sdlc` says what goes down to Sonnet/Haiku, and never edits.
- Evals cover each rule; suite green.

## Agreed scope (from the reviewed proposal)

1. `verifier`: `effort: high`, `maxTurns`.
2. New `reviewer` agent: Sonnet 5.5, `effort: high`, read-only, one pass per
   invocation.
3. `sdlc`: downward rung of the ladder; cache rule by provider.
4. Pin each agent's model in its definition; no `CLAUDE_CODE_SUBAGENT_MODEL`.
5. Hooks: report check on `SubagentStop`; resume pointer after compaction.
6. Dynamic workflows only on explicit request, never by default.

## Decisions taken

- Editing stays in the main session. Sources: "Move down to Sonnet or Haiku
  for lookups, not for writing code" (what a task costs); Sonnet 5.5 is
  recommended for "well-scoped verification and code review" (Sonnet 5.5
  guide).
- Provider: subscription.

## Open questions

- Haiku 4.5 pricing: not found on claude.dev. The ladder names Haiku without
  a price.
