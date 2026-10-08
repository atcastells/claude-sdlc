# Plan: Adopt Claude Haiku 5.5 in the delegation ladder

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-10-08)
- **Nothing is implemented until this file is approved.**

## Done means

- `bash evals/run.sh` → `FAIL: 0`, with every new case seen red first.
- Suite with the organization profile → `FAIL: 0`.
- `bash scripts/check-public.sh` → exit 0.
- `HOME=$(mktemp -d) ./install.sh --no-profile` → suite green, `scout.md`
  installed.
- `verifier` verdict green, or amber with every not-covered item closed.
- The real `./install.sh` is run by the developer.

## Stop and ask if

- `sdlc` cannot stay within 160 lines without dropping an existing rule.
- An existing eval turns red for a reason unrelated to this change.

## Tasks

| # | Task | Files | Test that proves it | Requirement (spec) | Status |
|---|------|-------|---------------------|--------------------|--------|
| T1 | `scout` agent | `agents/scout.md` | cases 86 (`model: haiku`), 86b (`effort: medium`), 86c (`maxTurns: 15`), 86d (`tools: Read, Glob, Grep, Bash`), 86e (cites file:line: `file:line`) | R1 | done |
| T2 | `sdlc` ladder | `skills/sdlc/SKILL.md` | cases 87a (`` `scout` (Haiku 5.5) ``), 87b (`100K`); 75, 79, 81, 85b stay green | R2, R3, R4 | done |
| T3 | Release 2.2.0 | `VERSION`, `CHANGELOG.md` | case 40; full suite; check-public; clean test install | R5 | done |
| T4 | Verification | — | `verifier`: change + two adjacent flows (Stage 5 text still consistent with `reviewer`; install copies all three agents) | all | done: verifier green |

## Order and dependencies

T1 → T2 (names the agent) → T3 → T4.

## Test strategy

TDD: each case written and seen red before the change.

- **Unit**: `file_contains` / `max_lines` cases.
- **Integration**: clean test install with a temp `HOME`.
- **Manual verification**: `verifier` reads the three agents and the
  ladder for consistency.

## Verification commands

```
bash -n hooks/*.sh hooks/lib/*.sh install.sh evals/run.sh scripts/*.sh
bash evals/run.sh
WORKFLOW_PROFILE=<org profile> bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile
```

## Implementation risks

- `sdlc` is at 157/160 lines.

## Outside this plan

See `spec.md` "Out of scope".

---
Next stage: Build implements, Test verifies, Deploy opens the PR.
