# Plan: Suggest the exact install command when the machine is behind

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-10-08)
- **Nothing is implemented until this file is approved.**

## Done means

- New cases seen red, then the full suite `FAIL: 0` (with and without the
  organization profile).
- `check-public.sh` exit 0; clean test install green.
- Running the installed-to-be hook by hand with this machine's real
  `~/.claude/workflow` and `cwd = this clone` prints the command
  `! cd '/Users/<dev>/claude-sdlc' && ./install.sh`.
- `verifier` green, or amber with every not-covered item closed.

## Stop and ask if

- An existing version-check eval must change its expected text.

## Tasks

| # | Task | Files | Test that proves it | Requirement (spec) | Status |
|---|------|-------|---------------------|--------------------|--------|
| T1 | Command in the existing install notices | `hooks/workflow-version-check.sh` | 88a source ahead → `' && ./install.sh`; 88b → `the developer runs it`; 88c project ahead → `git pull --ff-only && ./install.sh`; 88d incomplete → `' && ./install.sh`; 35, 36, 37d green | R1, R4 | done |
| T2 | Clone detection | same hook; fixture `evals/fixtures/sdlc-clone/` (VERSION 9.0.0) and `sdlc-clone-current/` (VERSION 1.1.0) | 88e clone ahead → `this repo is a claude-sdlc clone`; 88f clone ahead → no `workflow.json`; 88g clone equal → silent | R2, R3 | done |
| T3 | Release 2.2.1 | `VERSION`, `CHANGELOG.md` | full suite; check-public; clean install | R5 | done |
| T4 | Verification | — | `verifier`: change + R4 quoting + two adjacent flows (pending-migrations notice; `plan-resume` unaffected) + the real-machine run from "Done means" | all | done: verifier green, 1 nit fixed (88h) |

## Order and dependencies

T1 → T2 → T3 → T4.

## Verification commands

```
bash -n hooks/*.sh
bash evals/run.sh
WORKFLOW_PROFILE=<org profile> bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --no-profile
```

## Implementation risks

- The fixture `sdlc-clone` contains an `install.sh` and a hook path: the
  installer copies `evals/`, so they land in `~/.claude/evals/fixtures/`.
  They are empty placeholder files, never executed.

---
Next stage: Build implements, Test verifies, Deploy opens the PR.
