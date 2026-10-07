# Spec: Delegate read-only work to Sonnet 5.5 and adopt recent Claude Code features

- **Derived from**: `intent.md`
- **Status**: approved (2026-10-07)
- **Approved by**: product owner (no policy owner needed: no data handling changes)

## Requirements

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | `verifier` declares `effort: high` and a `maxTurns` cap | Scope 1; "recommend `high` for verification" | Frontmatter has both; eval |
| R2 | New `reviewer` agent: `model: sonnet`, `effort: high`, tools `Read, Glob, Grep, Bash`, one pass (`bugs`, `security`, `conformance`) per invocation, report headed `PASS: <pass>`, findings in the `REVIEW.md` format, never edits | Scope 2; "three review passes keep running on the main model" | `agents/reviewer.md` exists with that frontmatter; evals |
| R3 | `sdlc` Stage 5 launches three `reviewer` subagents in parallel; the main session consolidates, opens every cited file:line, keeps at most 5 nits. A dynamic workflow only when the user asks for one | Scope 2, 6 | Text in Stage 5; evals |
| R4 | `sdlc` ladder gains the downward rung: Sonnet/Haiku for lookups, logs, tests, verification and review, never for edits; mechanical multi-file edits stay on the main model at `low` | Scope 3; decision "editing stays in the main session" | Text; eval |
| R5 | `sdlc` cache rule by provider: on API key or subscription changing effort keeps the cache; on Bedrock, Vertex or a gateway it clears it; changing model or toggling fast mode always pays a cache write | Scope 3; intent's cache quote | Text; eval |
| R6 | `sdlc` says to pin each agent's model in its definition and not to set `CLAUDE_CODE_SUBAGENT_MODEL` | Scope 4 | Text; eval; `settings.template.json` does not set it |
| R7 | `subagent-report-check` hook on `SubagentStop`: for `verifier` requires a `VERDICT: green\|amber\|red` line, for `reviewer` a `PASS: bugs\|security\|conformance` line; for both, every `[IMPORTANT]` line contains `demonstration:`. Otherwise exit 2 with the reason (the subagent continues and fixes its report). Other agent types and `stop_hook_active: true` → exit 0 | Scope 5; "nothing checks that an IMPORTANT finding carries its demonstration" | Hook evals: pass, block ×3, foreign agent, loop guard |
| R8 | `plan-resume` hook on `SessionStart` with matcher `compact`: for each `.sdlc/*/plan.md` under the payload's `cwd`, lists the task rows (`\| T<n> \|`) whose last cell does not start with `done`, as `additionalContext`. Silent when there are none | Scope 5; "nothing points the session back at `plan.md`" | Hook evals with fixtures: open tasks listed, all done silent, no `.sdlc` silent |
| R9 | Both hooks registered in `settings.template.json` (one `SubagentStop` entry per exact agent name) | R7, R8 | Registration evals |
| R11 | `sdlc` ladder names the advisor tool: before switching the main model to Fable, `/advisor fable` (Opus main accepts Fable or Opus as advisor); toggling it keeps the cache; subagents inherit it. Not enabled by default | Scope 3; added 2026-10-07 after reviewing community practices against code.claude.com/docs/en/advisor | Text; eval |
| R10 | Version 2.1.0 with a `CHANGELOG.md` entry; no migration (no project file changes) | Release rules in `CLAUDE.md` | `VERSION`; eval 40-style check; suite green; `check-public.sh` green; clean test install green |

## Design

- **Agents.** `agents/reviewer.md` mirrors `verifier.md`: same tools,
  report-only rules, data-protection line. Its body takes the pass name and
  the slug from the prompt, reads `REVIEW.md` (or the template) for the pass
  definition and the thresholds, reviews the diff (`git diff <base>`), and
  reports. With the main session on Opus, `model: sonnet` resolves to Sonnet
  5.5 (different family, so no inheritance of the main model; code.claude.com
  sub-agents, model resolution).
- **Skill.** Edits to `skills/sdlc/SKILL.md` Stage 5 and "Session, context
  and cost". The 160-line budget (case 79) holds: rewrite, do not append.
- **Hooks.** Bash + jq, payload-only (no `CLAUDE_PROJECT_DIR`, per repo
  conventions). Payload fields per code.claude.com hooks reference:
  `SubagentStop` → `agent_type`, `last_assistant_message`, `stop_hook_active`;
  `SessionStart` → `source`, `cwd`. `plan-resume` outputs
  `{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext}}`
  like `workflow-version-check`. `PreCompact` is not used: its output does not
  reach the model (hooks reference).
- **Install.** `install.sh` already copies `agents/` and `hooks/` and merges
  `hooks` from the template; no change expected there.

## Policy applied

- **Personal data**: none. `subagent-report-check` reads the subagent's last
  message in memory and does not store or log it.
- **Sensitive business data**: none.
- **Credentials**: none.
- **Decisions about people / high risk**: no.

## Out of scope

- An implementer subagent on Sonnet (decision: editing stays in the main
  session).
- Shipping a saved dynamic workflow for Stage 5.
- Distributing as a plugin / `claude plugin eval`.
- Changing the projects' `REVIEW.md` template.
- Haiku pricing in the docs (not confirmed at the source).
- `advisorModel` in `settings.template.json`: the tool is experimental, adds
  usage on every consultation, and a Fable advisor bills to usage credits on
  some plans. Documented as an option, not installed.
- Running the main session on Sonnet with an Opus advisor for Build: a
  documented pairing, but switching the main model mid-session rewrites the
  cache and the decision "editing stays on the main model" stands.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| `SubagentStop` block loops | Subagent burns turns | `stop_hook_active` guard: at most one bounce; `maxTurns` on both agents |
| A `\|` matcher is not treated as a regex for plain names | Hook never fires | One entry per exact name |
| Valid report wrapped in a code fence or indented | False block | Allow leading whitespace before `VERDICT:` / `PASS:` |
| Sonnet misreads during review | Wrong findings reach the human | Main session opens every cited file:line (existing rule) and keeps "Unconfirmed" for the undemonstrated |
| `sdlc` exceeds 160 lines | Case 79 red | Rewrite the session section instead of appending |

---
Next stage: Build reads this file and writes `plan.md`.
