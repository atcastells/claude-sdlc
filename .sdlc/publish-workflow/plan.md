# Plan: Publish the workflow as a public repo, free of organization-specific rules

- **Derived from**: `spec.md`
- **Status**: APPROVED BY ENGINEER (2026-09-30), implemented

## Done means

- `scripts/check-public.sh` → exit 0 with the private denylist loaded.
- Clean install with no profile, with `profiles/example`, and with the
  organization's profile → suites green.
- Equivalence checklist complete for the organization's profile.
- `verifier` verdict green.

## Stop and ask if

- A previous rule fits neither core nor profile cleanly.
- `check-public.sh` finds a term that was not in the intent's inventory.
- Something outside the repo or a temporary HOME needs touching.

## Tasks

| # | Task | Status |
|---|------|--------|
| T1 | `.gitignore`, `scripts/check-public.sh`, `scripts/install-git-hooks.sh`, leak scenarios on throwaway repos | done |
| T2 | `hooks/lib/profile.sh`, `install.sh --profile/--no-profile`, 1.x → 2.x refusal, runner `WORKFLOW_PROFILE`/`{profile}`/`capture`/`repo_only`, profile-driven hook messages | done |
| T3 | Organization profile created **before** removing anything from the core, with an equivalence checklist | done (private) |
| T4 | `profiles/example/` | done |
| T5 | Core translated to English and made organization-neutral; evals translated with the files they test | done |
| T6 | `VERSION` 2.0.0, `CHANGELOG.md`, `migrations/2.0.0.md` | done |
| T7 | Internal history moved to the private profile; this anonymized chain written | done |
| T8 | MIT `LICENSE`, holder pending | done (holder pending) |
| T9 | Final verification: installs, checklist, `verifier` | see the private copy |
| T10 | Rename to `claude-sdlc` inside 2.0.0 (unreleased); a project behind with no migration in range (patch release) no longer gets an "incomplete install" notice | done |

## Verification commands

```
bash evals/run.sh
WORKFLOW_PROFILE=profiles/<org> bash evals/run.sh
bash scripts/check-public.sh
HOME=$(mktemp -d) ./install.sh --profile profiles/<org>
```
