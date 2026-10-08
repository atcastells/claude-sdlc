# Spec: Suggest the exact install command when the machine is behind

- **Derived from**: `intent.md`
- **Status**: approved (2026-10-08)
- **Approved by**: product owner (no policy owner needed)

## Requirements

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | Every `workflow-version-check` notice that asks for an install ends with a command block: `! cd '<dir>' && ./install.sh` (plus `git pull --ff-only &&` when the project is ahead of the source clone), and tells the agent to show it verbatim and let the developer run it | "one command the developer can run as is" | Hook evals on the three existing install notices |
| R2 | If the session's project is a claude-sdlc clone (has `install.sh`, `VERSION`, `global/CLAUDE.md`, `hooks/workflow-version-check.sh`) and its `VERSION` is ahead of the installed one, the notice says so and gives the command for **that** clone, naming the recorded source when it differs | "Opening a claude-sdlc clone that is ahead … triggers the notice" | Hook evals with a clone fixture: ahead → notice; equal → silent |
| R3 | A claude-sdlc clone is not treated as a project (no `.claude/workflow.json` notices), like the recorded source today | Consequence of R2 | Hook eval: no `workflow.json` notice in the clone fixture |
| R4 | Paths in the command are single-quoted with embedded quotes escaped | Safety of a command the developer pastes | Manual check by `verifier` with a path containing a space and a quote |
| R5 | Ships as 2.2.1 (2.2.0 was installed on 2026-10-08 before this change): a fix, the notice failed to fire; `CHANGELOG.md` entry | Release rules | Suite, check-public, clean test install |

## Design

- `hooks/workflow-version-check.sh`: a `run_cmd <dir> [pull]` helper builds
  the command; a `quote` helper single-quotes paths. Existing messages keep
  the text the current evals check (`install.sh`, "installation is
  incomplete, recommend running install.sh") and gain the command.
- No profile flag in the command: `install.sh` reuses the recorded profile
  (`install.sh:30-31`), and it now records the clone it runs from as the new
  source (`install.sh:121`).
- Still no network and no git in the hook. The developer runs `git pull`, not
  the hook.

## Policy applied

- **Personal data**: none. The notice contains local paths only.
- **Sensitive business data**: none.
- **Credentials**: none.
- **Decisions about people / high risk**: no.

## Out of scope

- Running `install.sh` automatically (it writes outside the repo; the
  developer runs it).
- Comparing a clone with its remote (needs network).
- Machines still on 1.x, where `install.sh` asks for `--profile` itself.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| A path with a quote breaks the command | Developer pastes a broken command | `quote` helper; R4 check |
| A non-claude-sdlc repo that happens to have those four files | False notice | Four specific paths, including the hook itself |
| Existing evals 35, 36, 37d change meaning | Silent regression | Keep their substrings; run them |

---
Next stage: Build reads this file and writes `plan.md`.
