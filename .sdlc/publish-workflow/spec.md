# Spec: Publish the workflow as a public repo, free of organization-specific rules

- **Derived from**: `intent.md`
- **Status**: implemented

## Requirements

| # | Requirement | Acceptance criterion |
|---|-------------|----------------------|
| R1 | The core names no organization, person, internal system, data category or internal incident | `scripts/check-public.sh` → 0 hits with the private denylist |
| R2 | The core is in English | Review |
| R3 | Profiles: `install.sh --profile <dir>` overlays `CLAUDE.md`, `profile.env`, evals, `settings.json`; remembered for reinstalls | Case 97 |
| R4 | `profile.env` is data: `KEY=VALUE`, whitelisted `WF_*` keys, never sourced | Case 98c |
| R5 | Core rules on by default: artifact chain, git reserved, TDD, guards, verifier, stopping and continuing, cost | Core suite green with no profile |
| R6 | Organization rules live in its profile, in its language; an equivalence checklist maps every previous rule to core or profile | Profile suite green; checklist complete |
| R7 | Deterministic leak control: nothing private tracked or addable under `profiles/`; no denylisted term in publishable files; git hooks for pre-commit/pre-push | Case 95 |
| R8 | `.gitignore`: `profiles/*` except `profiles/example/`, local settings, `.env*` | Case 96 |
| R9 | A public `profiles/example/` template | Install with it → green |
| R10 | Neutral examples and eval origins | Included in R1 |
| R11 | Internal history moves to the private profile; the public repo gets this anonymized chain | R1 |
| R12 | Version 2.0.0 (MAJOR); `install.sh` refuses 1.x → 2.x without `--profile`/`--no-profile` | Case 97 |
| R13 | MIT license, holder to be decided | `LICENSE` present; `check-public.sh` warns while the placeholder remains |

## Design

```
public repo                                  git-ignored
├── global/CLAUDE.md   core, EN              profiles/<org>/
├── hooks/ skills/ agents/ evals/            ├── profile.env   WF_* names used by hooks
├── scripts/check-public.sh                  ├── CLAUDE.md     org rules, any language
├── profiles/example/  template, EN          ├── evals/cases/  org evals
├── LICENSE (MIT)                            ├── denylist.txt  terms that must never be public
└── .sdlc/publish-workflow/                  └── .sdlc/        private history

install.sh --profile profiles/<org>
  ~/.claude/CLAUDE.md       = global/CLAUDE.md + profile/CLAUDE.md
  ~/.claude/evals/cases/p-* = profile/evals/cases/*
  ~/.claude/workflow/{profile,profile.env}
```

Composition by concatenation (deterministic, testable with `cmp`), not by
`@import`. Budgets: core ≤ 75 lines, installed ≤ 110.

## Policy applied

- **Personal data**: names removed from everything publishable.
- **Credentials**: none; fixtures use fake values.
- **Governance**: publishing a governance framework derived from an internal
  one is an organizational decision; the plan ends with a tree ready to
  publish, and publishing is a separate human step.

## Out of scope

Creating the public repo and pushing; packaging as a plugin; public CI.
