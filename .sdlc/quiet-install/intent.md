# Intent: Quieter install output

- **Originator**: maintainer
- **Date**: 2026-10-27
- **Status**: approved by product owner (2026-10-27, "apruebo", including
  that a red suite no longer fails the install)
- **Slug**: quiet-install

## The problem, in the originator's words

> "Also, I would like the installation to be a bit cleaner; right now you
> see a lot of tests running and it dirties the experience a bit."
> (translated from Spanish)

Answer to the scoping question (2026-10-27), verbatim, translated:

> "They run in the background, and if there are errors they are left
> somewhere so that it [Claude] takes them into account to suggest
> corrections to the user if that blocks the workflow from working."

## Who it affects

Everyone who runs `./install.sh`: first install, upgrades and profile
changes. How many and how often: not known yet.

What the install does today, verified in the repo (2026-10-27):

- `install.sh` ends by running the whole eval suite (`"$dst/evals/run.sh"`,
  lines 167-169), which prints one line per case: 194 lines in the core
  suite at 2.5.0, more with a profile's cases.
- Before that it prints the version line, retired files and backups.
- `WORKFLOW_INSTALL_NO_VERIFY` skips verification entirely and prints
  "not verified".

## What happens if we do nothing

To be confirmed with the originator.

## How we will know it is solved

- The install does not show the suite case by case; the evals run in the
  background.
- When a case fails, the failure is recorded somewhere Claude reads, and in
  a later session Claude tells the user and suggests a fix when the failure
  blocks the workflow.

## Open questions

- What counts as "blocks the workflow" versus a failure that can wait.
- Whether the install still reports anything about verification (e.g. "the
  evals are running") and whether a verbose option is still wanted.
- Today a red suite fails the install; with background evals the install
  exits before knowing. Whether that change of guarantee is acceptable.

## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|
| 2026-10-27 | What the install should show | Evals in the background; failures recorded for Claude to suggest fixes when they block the workflow | maintainer |
| 2026-10-27 | Approval | Approved, including that a red suite no longer fails the install | maintainer |

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.
