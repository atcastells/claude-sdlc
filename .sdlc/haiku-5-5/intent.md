# Intent: Adopt Claude Haiku 5.5 in the delegation ladder

- **Originator**: maintainer
- **Date**: 2026-10-08
- **Status**: approved by product owner (2026-10-08, asked for in the request)
- **Slug**: haiku-5-5

## The problem, in the originator's words

> "The new Haiku is out: review it and update the workflow with the best
> practices you can find."

## Who it affects

Every developer with the workflow installed. Since 2.1.0 the ladder sends
lookups, logs and test output to "a Sonnet/Haiku subagent" without saying
which, and only `verifier` and `reviewer` (both Sonnet 5.5) are defined.

## What happens if we do nothing

- Cheap read-only work keeps landing on Sonnet 5.5 or on the main model,
  while Haiku 5.5 costs $0.10 / $0.50 per Mtok for prompts up to 100K tokens,
  against $2 / $10 for Sonnet 5.5 (platform.claude.com, Haiku 5.5 overview).
- Nobody knows the 100K price step: above it Haiku 5.5 costs 5× ($0.50 /
  $2.50). A subagent that runs many turns crosses it without noticing.
- The ladder does not say what Haiku should not do. Its prompting guide
  warns that at `low` and `medium` effort it "sometimes reports a code change
  as done without running a check", and at `low` with a long agent prompt it
  stops early.

## How we will know it is solved

- A pinned Haiku 5.5 agent exists for lookups, with a turn cap that keeps its
  prompt under the price step.
- The ladder names which model does what: Haiku 5.5 for lookups, logs and
  test output; Sonnet 5.5 for verification and review; the main session
  edits.
- Evals cover it; suite green.

## Decisions taken

- `verifier` and `reviewer` stay on Sonnet 5.5: their job is judgement and
  running checks, where the Haiku guide reports skipped verification.

## Open questions

- Which model the built-in Explore agent uses is not documented
  (code.claude.com model-config, read 2026-10-08). The new agent pins Haiku
  5.5 explicitly so the answer does not matter.
