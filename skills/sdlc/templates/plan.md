# Plan: <title>

- **Derived from**: `spec.md`
- **Status**: draft | APPROVED BY ENGINEER
- **Nothing is implemented until this file is approved.**

## Done means

<A verifiable criterion, not an intention. E.g. "every endpoint uses the new
client, the old one is deleted, and `npm test` passes".>

## Stop and ask if

<When to stop during Build instead of deciding alone. E.g. "an existing test
fails for a reason unrelated to this change", "the DB schema must change".>

## Tasks

The *Status* column is updated as each task closes: it is the live list and
the resume point after compaction or a new session.

| # | Task | Files | Test that proves it | Requirement (spec) | Status |
|---|------|-------|---------------------|--------------------|--------|
| T1 | | | | R1 | pending |

## Order and dependencies

<What goes before what, and why.>

## Test strategy

TDD for business logic: a red test before implementing.
If a test fails: fix the code, not the test.

- **Unit**: <what they cover>
- **Integration**: <what they cover>
- **Manual verification**: <what the verifier subagent looks at>

## Verification commands

```
<build>
<test>
<lint>
```

## Implementation risks

<What can go wrong when touching this code. Affected callers.>

## Outside this plan

<What is left for later, explicitly.>

---
Next stage: Build implements, Test verifies, Deploy opens the PR.
