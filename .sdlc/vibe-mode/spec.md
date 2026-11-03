# Spec: Vibe mode, with Spec as the default

- **Derived from**: `intent.md`
- **Status**: approved (2026-11-03, "apruebo")
- **Approved by**: product owner (maintainer, 2026-11-03)

## Requirements

Each one traces to a line of the intent.

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | Two modes, named as in Kiro: **Spec** (today's full chain) and **Vibe**. Every session starts in Spec. | Decision "Naming and default" | A session with no command behaves exactly as 2.6.0; the core suite stays green with no case changed. |
| R2 | `/vibe` switches the current session to Vibe; `/vibe off` returns it to Spec. Works in any repo. | Decision "How is the mode switched on?" | Hook evals: `/vibe` writes the session marker, `/vibe off` removes it, another session id is not affected. |
| R3 | Vibe survives compaction and resume (resume added in Build, `plan.md` "T1 findings"); `/clear` and a new session start in Spec again. | Open question "/clear and compaction" | Hook evals: `compact` with the marker re-injects the Vibe context; `clear` and `startup` do not. |
| R4 | In Vibe, a small non-final change opens no `.sdlc/<slug>/`: no intent, spec or plan. | Success "Fewer intents"; problem quote | `vibe` skill says so; eval checks the skill text and that no `.sdlc/<slug>/` is listed as a Vibe artifact. |
| R5 | In Vibe there are no approval stops before touching code; the developer reviews the result. Git stays reserved. | Decision "no approvals"; success "Idea to result" | Global rule names Vibe as the only exception to "I do not implement until the engineer approves `plan.md`"; git, credential and release rules unchanged (existing cases 65, 65b and the hook cases still green). |
| R6 | A **global map**, `.sdlc/map.md`: one mermaid diagram of the project's systems and features, fed every Vibe session. The agent reads it when Vibe starts and updates it at the end of each iteration. | Decision "What gives you the big picture?"; success "Map up to date" | Template in `skills/vibe/templates/map.md`; skill says when to read and when to write it; eval checks both. |
| R7 | A **local document** per extension, `.sdlc/vibe/<topic>.md`: the goal in the developer's words, a mermaid of the pieces being touched, a list of done and left, and a short log per iteration. | Same decision; success "See where we are" | Template in `skills/vibe/templates/topic.md`; one file per extension, not per change. |
| R8 | Tests for the deterministic core, a capture as proof of a visual change, and promotion to a formal intent are optional, at the agent's discretion. | Decision "What do the unchosen ones mean?" | Skill text says "when it adds value" for each, with the rule of thumb below; no hook enforces them in Vibe. |
| R10 | The status line always shows the session's mode: `Spec` or `Vibe`, next to the model. | Decision "Added while reviewing the spec" | Status-line evals: payload with a `session_id` that has the marker shows `Vibe`; without it, or with no `session_id`, shows `Spec`; an invalid `session_id` shows `Spec` and reads no file. Cases 90-92 still green. |
| R9 | Promotion: when an idea settles, the local document seeds an `intent.md` in `.sdlc/<slug>/` and the chain continues in Spec. | Same decision | Skill describes the step; the promoted intent links the local document. |

## Design

**Mode state, per session.** A new hook, `hooks/mode.sh`, one script with
two events:

- `UserPromptSubmit`: if the prompt is exactly `/vibe` (optionally with
  text after it) it writes the marker `${TMPDIR:-/tmp}/claude-sdlc-mode-<session_id>`
  and injects the Vibe context; `/vibe off` removes it and injects one line
  saying the session is back in Spec. A `session_id` that does not match
  `[A-Za-z0-9_-]+` is ignored, as `subagent-report-check.sh` already does.
- `SessionStart` with matcher `compact`: if the marker exists, injects the
  Vibe context again (so the summary cannot drop it). On `startup` and
  `clear` it deletes the marker if present: Spec again.

The Vibe context is short (under 15 lines): "this session is in Vibe mode,
follow the `vibe` skill; read `.sdlc/map.md` and the open `.sdlc/vibe/*.md`".
It never repeats the prompt text.

**Skill `skills/vibe/SKILL.md`** (`/vibe`, `/vibe off`). The loop:

1. Read `.sdlc/map.md` (create it from the template if missing, from what
   the repo shows: `README`, `docs/`, top-level modules) and the local
   document of the extension in progress, or create one.
2. Idea → smallest change that shows it → run it (build, run, capture when
   it is visual) → show the evidence → developer reacts → next idea.
3. At the end of each iteration: one line in the local log, tick done/left,
   update the node states in the map.
4. Rule of thumb for R8: a red test first when the change touches
   deterministic logic other code depends on; a capture when the result is
   something you see; propose promotion when the same topic has needed
   three or more iterations of design discussion, or when the developer
   says it is final.

**Global map format.** A `flowchart` in a fenced `mermaid` block. Nodes are
systems or features (not single changes), at most about 40, with a state
class: `idea`, `wip`, `done`, `dropped`. Edges mean "builds on". Under the
diagram, one line per node with its local document, if any.

**Global rules.** `global/CLAUDE.md` gets one bullet in the artifact chain
section, replacing nothing: "Spec mode is the default. In Vibe mode
(`/vibe`, per session) the `vibe` skill replaces intent → spec → plan and
the approval of `plan.md`; git, credentials, the release rule and verifying
before claiming still apply." Budget: core 73 → 75 lines, at the limit of
case 65 (≤ 75); if it does not fit, merge it with the "never skip a stage"
bullet.

**What stays the same in Vibe**: git reserved, `credential-guard`,
`production-gate`, `test-guard` (it only stops weakening tests), "verify
before claiming" (the agent runs what it changed and shows it; the capture
is the visual form of that). The `verifier` subagent and the review passes
belong to the PR, which goes through Spec.

**Status line.** `status-line.sh` reads `.session_id` from its payload,
checks it against `[A-Za-z0-9_-]+`, and looks for the same marker
`${TMPDIR:-/tmp}/claude-sdlc-mode-<session_id>`. It adds one segment right
after the model and effort: `Spec` dimmed by default, `Vibe` in bold
magenta when the marker exists, so the change of mode is visible at a
glance. The marker path is built in one shared function
(`hooks/lib/mode.sh`) used by both `mode.sh` and the status line, so the two
cannot disagree.

**Wiring.** `settings.template.json` gains the `UserPromptSubmit` entry and
the `compact|startup|clear` entry for `mode.sh`; `install.sh` already merges
`hooks`. `rune-world`'s `.sdlc/roadmap.html` is not touched.

**Release.** 2.7.0 (new feature, no breaking change). No `migrations/`
file: nothing that `/repo-setup` leaves in projects changes.

## Policy applied

- **Personal data**: none.
- **Sensitive business data**: none in this repo. The map and the local
  documents are committed; in an organization repo they follow the same
  rule as every artifact (no costs, margins, rates or stock). The skill
  says so in one line.
- **Credentials**: none. Captures are files in the repo; the skill says not
  to capture screens that show secrets.
- **Decisions about people / high risk**: no.

## Out of scope

- A per-repo default mode in `.claude/workflow.json` (the originator chose
  per session).
- Godot-specific tooling (MCP servers, playtest recording); a repo profile
  can add it.
- Migrating rune-world's 138 existing `.sdlc/` entries or its
  `roadmap.html` into the map.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| `UserPromptSubmit` may not receive a skill slash command as typed (`/vibe`), or `session_id` may be missing | The mode cannot be tracked by the hook | First Build task checks it in a real session before anything else; fallback: the skill writes the marker itself through a small script, keyed by the transcript path |
| `/clear` keeps the same `session_id` in some versions | Vibe would leak past a clear | `SessionStart` on `clear` deletes the marker explicitly (R3) |
| The map grows unbounded or drifts into a change log | Loses the big-picture value | Nodes are systems or features, about 40 at most; history goes in the local log, not the map |
| Vibe used for work that should have gone through Spec | Untraced decisions | Promotion rule of thumb (R9); a PR still needs Spec, its review passes and the verifier |
| The status-line payload may not carry `session_id`, or the status line may not find the hook's `TMPDIR` | Shows `Spec` while the session is in Vibe | Checked in the same first Build task as the `UserPromptSubmit` risk; the status line falls back to `Spec`, never invents `Vibe` (same principle as case 92) |
| Core budget at 75 lines | Case 65 red | Merge bullets as noted in Design |

---
Next stage: Build reads this file and writes `plan.md`.
