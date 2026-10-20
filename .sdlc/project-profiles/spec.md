# Spec: Secondary profile per repository

- **Derived from**: `intent.md`
- **Status**: approved (2026-10-20, "approved")
- **Approved by**: product owner (no policy owner needed: no personal or
  sensitive business data; see "Policy applied")

## Requirements

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | A repo declares a secondary profile in `.claude/workflow.json`: `"profile": "<relative dir>"` (e.g. `.claude/profile`). The path must be relative, without `..`, and resolve inside the repo (no symlink escape); otherwise it is ignored with a one-line notice | Decision "inside the repo that uses it" | Hook cases: valid path → loaded; absolute, `..`, symlink outside → notice, nothing loaded |
| R2 | New hook `project-profile.sh` on `SessionStart` (`startup\|clear\|compact`): when `cwd`'s `.claude/workflow.json` declares a profile with a `CLAUDE.md`, it outputs it as `additionalContext` under a header saying it adds to the organization profile for this repo only. Capped at 150 lines (a truncation note beyond). Silent without a declaration; silent on `resume` | "a session starts with the game profile in context … in every other repo nothing changes" | Cases: declared → header + content; not declared → no output; over 150 lines → truncation note |
| R3 | `credential-guard` and `production-gate` load the global `profile.env` and then, if `cwd` declares a profile with a `profile.env`, that one on top (same whitelisted `WF_*` keys, same parser) | Open question 2 (recommended, not contradicted) | Cases: repo profile names its own secrets manager / policy in the block message; without a repo profile, the global names stay |
| R4 | `evals/run.sh` accepts `WORKFLOW_PROFILE=<dir>` in installed mode too, adding `<dir>/evals/cases/*.json` with `{profile}` = `<dir>` | "evals that run with the suite" | Case: installed-mode run with a fixture profile includes its cases |
| R5 | `settings.template.json` registers `project-profile.sh` on `SessionStart` | R2 | Registration case |
| R6 | Public template `skills/repo-setup/templates/project-profile/` (`CLAUDE.md` skeleton with the four sections below, `profile.env`, `evals/cases/` example) and one line in the `repo-setup` skill on how to declare it | Mechanism reusable by any repo | Template files exist; skill mentions `"profile"` |
| R7 | The rune-world profile, in `rune-world/.claude/profile/` (Spanish, private to that repo, ≤ 120 lines): **Glosario y tono** (game-dev and world terms taken from its `docs/` and `lore/`, gameplay told as what the player sees / does / feels, real-game references); **Calidad de juego** (handheld performance budget, determinism by seed, sub-minute feedback loop in Godot, lore as the source of truth, world → story → gameplay order); **Política del repo** (no personal data, simulated people are fictional, no network client, third-party assets with their licence, no credentials); **Reglas de la organización sin objeto aquí** (customer and tax data, amounts in euros, company secrets manager, compliance contact for decisions about real people: nothing to act on; the organization's own account instructions still apply). Plus `profile.env` and `evals/cases/` | Content decisions | Profile cases (run with `WORKFLOW_PROFILE=rune-world/.claude/profile`): each section present; injection works from the rune-world root; no customer/ERP terms outside the "sin objeto" section |
| R8 | `rune-world/.claude/workflow.json` gains `"profile": ".claude/profile"` | R1 | Its SessionStart output has the header |
| R9 | Release 2.5.0: `VERSION`, `CHANGELOG.md`. No project migration: the key is optional and nothing `/repo-setup` creates by default changes | Release rules | Suite, profile suite, check-public, clean install green |

**Amended before the PR (2026-10-20), R10**: `/repo-setup upgrade` step 5
said "`.claude/workflow.json` ← version and date", which allows rewriting
the file from the template and dropping `profile`. It now sets only
`workflow_version` and `updated` and keeps every other key (case 108c).
Approved by the developer ("sí").

**Amended in Build (2026-10-20), R7**: the sources hold no handheld
performance figures (no fps, memory or GPU budget; the scout searched
`CLAUDE.md` and `docs/`). The profile states the repo's actual rule — no
benchmarks until something is really slow, then profile with a seed and
`--bench` — and says no budget is invented, instead of a "performance
budget".

## Design

- **Why SessionStart context and not `CLAUDE.md`.** `~/.claude/CLAUDE.md` loads
  in every repo, and the repo's own `CLAUDE.md` is over budget. The hook
  injects the profile only where it is declared; `compact` re-injects it
  after a compaction, `resume` does not (the transcript already holds it),
  like `workflow-version-check`.
- **Precedence.** The secondary profile adds to the organization profile;
  it does not remove it. Where an organization rule has nothing to act on in
  the repo, the profile says so explicitly. The organization's own account
  instructions are outside any profile.
- **Payload only.** The hook reads `cwd` from the payload and the files under
  it; no `CLAUDE_PROJECT_DIR`. Fixtures: a repo with a declared profile, one
  with a bad path, one with a symlink escape.
- **Glossary source.** Terms come from rune-world's `docs/` and `lore/`,
  gathered by a read-only `scout` (Haiku) and written by the main session;
  nothing is invented.
- **rune-world side.** Its files are written in Build; the commit there is
  the developer's (that repo allows local commits by its orchestrating
  session, but this change is driven from claude-sdlc).

## Policy applied

- **Personal data**: none. The game simulates fictional people; the profile
  says so.
- **Sensitive business data**: none.
- **Credentials**: none; `profile.env` holds names, never secrets.
- **Injected text**: the repo controls its profile, the same trust level as
  its `CLAUDE.md`; size cap and path checks bound it.
- **Amended after review (2026-10-20)**: repo input is treated as hostile.
  `profile.env` over 4 KB and `CLAUDE.md` over 16 KB are ignored before
  being read (a large `profile.env` made a 5 s guard time out, which could
  let a command through); injected content is capped at 150 lines and
  12 KB; notices never echo the declared value. The repo's `WF_*` names
  still appear in the guards' block messages (≤ 400 characters each): a
  channel at the same trust level as its `CLAUDE.md`, recorded here, not
  closed. Profile cases (`WORKFLOW_PROFILE`) cannot run code: no `script`,
  no `env`, `hook` only by bare name; they run with the developer's
  privileges, so review a repo's cases like its tests.
- **Decisions about people / high risk**: no. The organization's account
  instructions keep applying in that repo.

## Out of scope

- Replacing or disabling the organization profile per repo.
- Profiles in repos without `.claude/workflow.json`.
- Changing the `CLAUDE.md` budget rule of `/repo-setup`.
- Moving rune-world's existing `CLAUDE.md` content into the profile.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Profile text conflicts with organization rules | Ambiguous instructions | Profile only marks rules as "nothing to act on", never "ignore"; template states it |
| Large profile bloats every session | Cost per turn | 150-line cap in the hook, 120 in rune-world's |
| Path tricks in `workflow.json` | Reading files outside the repo | Relative, no `..`, resolved path must stay under `cwd` |
| Two SessionStart hooks both add context | Order or duplication | Each prefixes its own header; both silent on `resume` |

---
Next stage: Build reads this file and writes `plan.md`.
