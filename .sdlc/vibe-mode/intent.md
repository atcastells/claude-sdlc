# Intent: Vibe mode for idea-driven, visual projects

- **Originator**: maintainer
- **Date**: 2026-11-03
- **Status**: approved by product owner (2026-11-03, "apruebo")
- **Slug**: vibe-mode

## The problem, in the originator's words

> "I want to work on a mode for projects with another kind of iteration,
> like rune world, which is a game and a less structured process, where we
> move forward with IDEAS and everything has to be more visual, and it is
> harder to work with the SDLC flow."
> (translated from Spanish)

## Who it affects

The maintainer, in rune-world (Rust core + Godot client, personal game
project). Possibly any other repo where work advances by trying ideas and
looking at the result rather than by fixed requirements.

What the workflow does today there, verified in the repo (2026-11-03):

- `.claude/workflow.json` declares the secondary profile `.claude/profile`
  (2.5.0); the chain itself is the same as in every other repo.
- `.sdlc/` has 138 entries, numbered intents (`001-` ... `111-`).
- The latest one, `111-constructor-de-edificios`, has `intent.md` (87
  lines), `plan.md` (723 lines) and an extra `mejoras.md` (137 lines) that
  is not part of the chain; it has no `spec.md`.
- Visual evidence (Godot captures with `--capture`) is stored ad hoc, e.g.
  `.sdlc/water-mvp-salidas/capturas/`; no stage of the chain reads it.

## Prior art (web search, 2026-11-03)

Asked by the originator before choosing scope. Mostly blogs and vendor
pages; only the Claude Code docs are official.

- Kiro (AWS) ships two modes, Spec and Vibe; community guides describe Vibe
  for exploring and prototyping when requirements are unclear, and refining
  in Vibe before moving to Spec. Persistent project context lives in
  steering files loaded every turn.
  https://awsugbne.github.io/kiro-workshop-feb26/core-concepts/spec-vs-vibe
- Spec vs vibe is framed as complementary, not either/or (RedMonk); a
  middle ground with light planning docs has no settled name yet (DEV).
  https://redmonk.com/rstephens/2025/07/31/spec-vs-vibes/
  https://dev.to/incomplete_developer/is-there-a-middle-ground-between-vibe-coding-and-spec-driven-development-31ek
- Claude Code best practices: planning is not worth it for small changes;
  ask directly. Visual work loops implement, screenshot, compare, fix; the
  agent shows evidence instead of claiming done.
  https://code.claude.com/docs/en/best-practices
- Godot with agents: the common loop is edit, run (`godot --headless`),
  capture, read the frame, fix. MCP servers (Open Godot MCP, Beckett) add
  in-game captures and recorded playtests; none has independent benchmarks.
  https://dev.to/abagames/godot-is-well-suited-for-game-development-with-ai-coding-agents-2lcm
  https://forum.godotengine.org/t/beckett-zero-sidecar-mcp-server-for-godot-4-2-the-ai-sees-and-optionally-playtests-your-game/141177
- Living architecture docs with Mermaid that agents read before editing
  appear as a team practice, not a tool feature; no source found for a
  global map plus per-task map pattern as such.
  https://zol-documentation.pages.dev/docs/methodology/philosophy/living-documentation

## What happens if we do nothing

Chosen by the originator (2026-11-03):

- Speed is lost: every small idea pays for an intent and a plan, so fewer
  iterations fit in a session.
- Noise in `.sdlc/`: intents for non-final changes keep piling up (138
  entries today) and what matters gets harder to find.

## How we will know it is solved

Chosen by the originator (2026-11-03), all four signals:

- Fewer intents: small, non-final changes no longer open a folder in
  `.sdlc/`; an intent is opened only when an idea is promoted.
- Map up to date: at session start, the global mermaid map reflects what
  the previous sessions did, without the developer updating it.
- See where we are: at any moment the local document shows the extension
  in progress: what has been touched and what is left.
- Idea to result: from an idea to a visible change in the same session,
  with no stops for approval.

## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|
| 2026-11-03 | What part of the flow slows you down most? | "Many intents for changes that are not final; I want more speed, more vision of the big picture. Touch small things and move forward." (translated) | maintainer |
| 2026-11-03 | What gives you the big picture? | "A document the coding agent uses as its base. A global one, a mermaid fed across sessions, and a local one for the current task, where you can see what we are working on in that extension." (translated) | maintainer |
| 2026-11-03 | What stays even when going fast? (options: core Rust tests, capture as proof, promotion to a formal intent, no approvals) | Chose only "no approvals": the agent iterates without approving a plan first; the developer reviews the result; git stays the developer's. The other three were not chosen. | maintainer |
| 2026-11-03 | What do the unchosen ones mean? | "Optional, at discretion": not mandatory in the mode; the agent uses them when they add value (a test when it touches the deterministic core, a capture when the change is visual, promotion when an idea settles). | maintainer |
| 2026-11-03 | How is the mode switched on? (after the prior-art search) | Per session: a command at the start (e.g. `/explore`) switches it on for that session, in any repo. | maintainer |
| 2026-11-03 | Naming and default (with the approval) | "Take the same names as Kiro; by default we go in Spec." (translated) The modes are Spec (the full chain, default) and Vibe. | maintainer |
| 2026-11-03 | Added while reviewing the spec | "The agent will have a status line that shows the mode it is in." (translated) | maintainer |

## Open questions

- Answered in part (2026-11-03): the friction is opening a full intent for
  changes that are not final; the later answers drop the approval gates
  and make TDD optional in the mode.
- Answered (2026-11-03): two documents the agent reads as its base and
  keeps up to date: a global mermaid map fed session after session, and a
  local one for the current task. Still open: what a node of the global map
  is (idea, system, feature), and whether the existing
  `.sdlc/roadmap.html` is replaced or fed.
- What the unit of work is in this mode: an idea, a playtest, a capture.
- Answered (2026-11-03): core tests, capture as proof and promotion to a
  formal intent are optional, at the agent's discretion. Today
  `global/CLAUDE.md` makes TDD for business logic and the approved
  `plan.md` core rules for every repo, so this mode would relax core rules
  for one session; Design must say how, and keep git, credentials and the
  no-release rule untouched.
- Answered (2026-11-03): per session, in any repo. Still open: where the
  global map lives in a repo that has never used the mode, and whether the
  mode survives `/clear` and compaction within the same session.

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.
