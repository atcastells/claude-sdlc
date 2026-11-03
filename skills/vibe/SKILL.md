---
name: vibe
description: Vibe mode for the session — iterate on ideas fast, with a global mermaid map of the project and a local document per extension, instead of intent → spec → plan. Spec mode (the full chain) is the default; /vibe switches this session to Vibe and /vibe off returns it to Spec. Only the user switches modes, by typing /vibe or /vibe off.
disable-model-invocation: true
---

# Vibe mode

Two modes, per session. **Spec** is the default: the full artifact chain of
the `sdlc` skill. **Vibe** is for work that advances by trying ideas and
looking at the result. The `mode` hook records the switch when the user
types `/vibe` or `/vibe off`, and the status line shows `Spec` or `Vibe`.

- `/vibe` (optionally with an idea after it): enter Vibe and start the loop.
- `/vibe off`: back to Spec. Close the local document's log first.

## Start

1. Read `.sdlc/map.md`. If it does not exist, create it from
   `templates/map.md` with what the repo already shows (`README`, `docs/`,
   top-level modules): systems and features, not single changes. Say which
   nodes you inferred.
2. Find the extension in progress: an open `.sdlc/vibe/<topic>.md` whose
   state is not `done`. If the user names a new one, create it from
   `templates/topic.md` with the goal in the user's own words. One file per
   extension, not per change.
3. Say in two lines where we are: the map node, and what is left.

## The loop

Idea → the smallest change that shows it → run it → show the evidence →
the user reacts → next idea. No approval stops before touching code: the
user reviews the result.

- A small, non-final change opens no `.sdlc/<slug>/`: no intent, spec or
  plan. It lives in the local document's log.
- Run what you changed (build, run, capture). Show the output or the image,
  not a claim.
- Keep each step small enough that the user can say "yes", "no" or "more
  like this" from one look.

At the end of each iteration:

1. One line in the local log: what was tried, what was seen, what stays.
2. Tick *Done and left* in the local document; update its mermaid if the
   pieces changed.
3. Then update `.sdlc/map.md`: move node states (`idea`, `wip`, `done`,
   `dropped`) and add a node only for a new system or feature. History goes
   in the local log, never in the map.

## At the agent's discretion

None of these is mandatory in Vibe; use each when it adds value.

- **A red test first** when the change touches deterministic logic that
  other code builds on (a generator, a rule, a data contract). Not for
  tuning how something looks.
- **A capture** when the result is something you see. Store it under
  `.sdlc/vibe/<topic>/` and link it from the log line.
- **Promotion** when the same topic needs three or more iterations of
  design discussion, or when the user says it is final: the local document
  seeds `.sdlc/<slug>/intent.md` (goal, what was learned, link to the
  local document) and that work continues in Spec. Propose it; the user decides.

## What still applies

- Every stop in the core rules still applies: production, sensitive data, a
  compliance case, deleting data, changing anything outside the repo. Vibe
  lifts only the chain, the `plan.md` approval and mandatory TDD.
- Git stays with the developer: no commit, push or any other git write.
- Credentials never in plaintext; the release rule is unchanged.
- Verify before claiming: run it and show it.
- `test-guard`: a failing test is fixed in the code, not weakened.
- A PR goes through Spec: its review passes and the `verifier`.
- The map, the local documents and the captures are committed:
  same data rules as any artifact. Nothing the profile marks as sensitive, and no
  capture of a screen that shows secrets or personal data.

## The two documents

| File | Holds | Updated |
|------|-------|---------|
| `.sdlc/map.md` | The whole project: one mermaid flowchart of systems and features (about 40 nodes at most), each with its state; edges mean "builds on"; one line per node with its local document | Read at start, written at the end of each iteration |
| `.sdlc/vibe/<topic>.md` | One extension: the goal in the user's words, a mermaid of the pieces being touched, *Done and left*, the log | Every iteration |

Both are the agent's base: after a compaction or a resume that is still in
Vibe, read them again before anything else. `/clear` and a new session
start in Spec.
