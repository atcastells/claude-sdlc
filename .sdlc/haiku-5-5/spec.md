# Spec: Adopt Claude Haiku 5.5 in the delegation ladder

- **Derived from**: `intent.md`
- **Status**: approved (2026-10-08)
- **Approved by**: product owner (no policy owner needed: no data handling changes)

## Requirements

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | New `scout` agent: `model: haiku`, `effort: medium`, tools `Read, Glob, Grep, Bash`, `maxTurns: 15`. Finds, reads and summarises (where something is defined, what a log or test run says); every claim cites file:line or the command output; never edits, never judges a change | "A pinned Haiku 5.5 agent exists for lookups, with a turn cap" | Frontmatter + body; evals |
| R2 | `sdlc` ladder names the models: `scout` (Haiku 5.5) for lookups, logs and test output; `verifier` / `reviewer` (Sonnet 5.5) for verification and review; the main session edits | "The ladder names which model does what" | Text; evals |
| R3 | `sdlc` states the Haiku 5.5 price step: prompts over 100K tokens cost 5×; keep Haiku tasks short and bounded | "Nobody knows the 100K price step" | Text; eval |
| R4 | `verifier` and `reviewer` stay `model: sonnet` | Decision taken | Existing cases 75 and 81 stay green |
| R5 | Version 2.2.0 (new agent = MINOR), `CHANGELOG.md` entry with sources and the alias note: `haiku` is Haiku 5.5 on the Anthropic API from Claude Code 2.1.293; Haiku 4.5 on Bedrock, Google Cloud and Foundry. No migration (no project file changes) | Release rules | `VERSION`; suite; check-public; clean test install |

## Design

- `agents/scout.md` follows the shape of `verifier.md` / `reviewer.md`:
  frontmatter, a short "what you do", a report format, rules. Its
  description is short: descriptions take context in every session (Haiku
  5.5 prompting guide and sub-agents docs).
- `effort: medium` explicit: the Haiku guide says `low` makes it "more
  likely to skip a search, stop early, or skip a check" in long agent
  prompts, and `medium` is the default in Claude Code.
- `maxTurns: 15`: every turn resends the conversation; the cap keeps a
  lookup from growing past the 100K price step. It is a guard, not a
  guarantee (one large file read can cross it), so the body also tells it to
  read excerpts, not whole large files.
- The body carries a short version of the guide's two fixes that apply to
  a read-only agent: keep working until the question is answered, and do not
  report what was not observed.
- `skills/sdlc/SKILL.md` stays within 160 lines (case 79): rewrite the
  "Down the ladder" bullet, do not append.
- `subagent-report-check` is not extended to `scout`: its output is
  free-form, there is no verdict to enforce.

## Policy applied

- **Personal data**: none.
- **Sensitive business data**: none.
- **Credentials**: none.
- **Decisions about people / high risk**: no.

## Out of scope

- Moving `verifier` or `reviewer` to Haiku.
- `ANTHROPIC_DEFAULT_HAIKU_MODEL` or `CLAUDE_CODE_SUBAGENT_MODEL` in the
  settings template.
- A minimum Claude Code version check in hooks.
- Prices in the skill beyond the 100K step (they change; the skill cites
  the source).

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Haiku misreads a lookup and sends the main session after the wrong file | Detour paid on the main model | Every claim cites file:line; main session opens it (existing rule) |
| On Bedrock / Google Cloud / Foundry `haiku` is Haiku 4.5 (no effort levels, different price) | Different behaviour than documented | CHANGELOG note; the org is on a subscription |
| `sdlc` over 160 lines | Case 79 red | Rewrite instead of append |

---
Next stage: Build reads this file and writes `plan.md`.
