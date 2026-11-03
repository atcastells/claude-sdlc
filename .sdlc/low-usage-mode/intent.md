# Intent: Low-usage mode for Pro plans

- **Originator**: maintainer
- **Date**: 2026-10-21
- **Status**: draft
- **Slug**: low-usage-mode

## The problem, in the originator's words

> "I want a mode to spend little, above all focused on 20 € plans."
> (translated from Spanish)

## Who it affects

Developers who install the workflow on a Claude Pro subscription (the
~20 €/month plan). How many and how often they hit the limit: not known yet.

What the workflow does today, verified in the repo (2026-10-21):

- `settings.template.json` installs `"model": "opus[1m]"` and
  `"effortLevel": "medium"` for everyone. On a machine that already has a
  `settings.json`, `install.sh` only merges `hooks`, `permissions` and
  `statusLine`, so model and effort are not changed there.
- The ladder in `skills/sdlc/SKILL.md` ("Session, context and cost") climbs
  to `xhigh`, `/advisor fable` and Fable 5.1 as the main model.
- Subagents pinned in `agents/`: `scout` Haiku/medium (15 turns),
  `implementer` Sonnet/medium (40), `verifier` Sonnet/high (40), `reviewer`
  Sonnet/high (30). Deploy launches three `reviewer` in parallel; Test
  launches `verifier`; Build launches one `implementer` per task, in waves.
- The status line already shows model, effort and session cost when the
  payload carries them (`status-line.sh`).

## What happens if we do nothing

To be confirmed with the originator.

## How we will know it is solved

To be confirmed with the originator.

## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|

## Open questions

- What "spend" means on Pro: dollars, or the usage limit (5-hour window,
  weekly cap)? Facts on Pro limits and models are being checked against the
  Claude Code docs.
- Scope: a mode the developer switches on, a profile chosen at install, or a
  change to the defaults.
- Which parts of the chain may get lighter (review passes, verifier, effort
  ladder) and which must stay.

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.
