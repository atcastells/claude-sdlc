# Intent: An install-verification notice that interrupts only when it should

- **Originator**: maintainer
- **Date**: 2026-11-03
- **Status**: approved by product owner (2026-11-03, "a", "apruebo")
- **Slug**: scoped-incident-notice

## The problem, in the originator's words

> "I want this notice to show up only in the repo that originated it."
> (translated from Spanish; said about the SessionStart notice
> "claude-sdlc: install verification of 2.6.0 failed 1 case. Blocking ...
> incident <product-app>: <regression test name> (hook): exit=1, expected=0",
> shown in a `claude-sdlc`
> session)

## What happens today (verified 2026-11-03)

- `hooks/workflow-version-check.sh` (quiet-install, unreleased 2.6.0) reads
  `~/.claude/workflow/install-verify.json` and lists every failed case in
  every session, whatever the project.
- Incident evals (`~/.claude/evals/cases/i-*.json`, 19 today) run a test in
  another repo through `evals/scripts/repo-jest.sh <repo> <test>`. They are
  `kind: hook`, so the notice marks them as **blocking**.
- That repo's state (branch, dependencies, a jest run in progress) can make
  the case fail when nothing in the workflow is broken: `i-11` failed at
  install-verify time and passes on re-run (`jest ok`, 2026-11-03; same on
  2026-11-02, see `.sdlc/autoimprove/intent.md`).

## Who it affects

The maintainer, in every session outside the repo the incident came from.

## What happens if we do nothing

Every session starts with a "blocking" alarm about another project's test.
Claude interrupts unrelated work, and a real workflow failure gets lost in
the noise.

Follow-up questions from the originator (2026-11-03), translated: "can it
interfere less with the user, what is that notice for, what action do you
expect from a workflow user?"

## How we will know it is solved

- A session start only interrupts the user when one of the workflow's
  protections (`credential-guard`, `test-guard`, `production-gate`) is not
  working, with an action any workflow user can take.
- Every other install-verification failure is mentioned in one line
  at the end of the run, without interrupting.
- Incident evals of a product repo do not run on install or on config
  changes; they run in the Test stage of that repo, where a regression can
  be fixed.

## Open questions

- None that block the spec.

## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|
| 2026-11-03 | Scope the notice to the originating repo (b), or move incident evals out of install verification and only interrupt for broken protections (a)? | "a" | maintainer |

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.
