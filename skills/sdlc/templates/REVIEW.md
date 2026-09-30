# Review policy

Copy to the repo root. Every PR gets the same set of passes.

## Three passes

**1. Bugs and logic**
Correctness, edge cases, race conditions, error handling that prevents data
loss. Callers affected by a signature change.

**2. Security**
OWASP Top 10 as the floor. Validation of all external input. Embedded
credentials (the `credential-guard` hook is the first line, not the only one).
Personal or sensitive business data in logs, errors or responses.

**3. Conformance**
Against `spec.md` and `plan.md`: does the change do what the plan intended?
Is there scope that traces to no requirement? Was the spec's policy section
applied?

## Thresholds

- **Important**: only what would block the merge. Correctness, security,
  data loss, deviation from the spec, policy breach. Each one carries file,
  line, why it is wrong and how to demonstrate the failure (an input, a test,
  a command). Without a demonstration it is a suspicion: it goes to
  "Unconfirmed".
- **Nit**: does not block. Style, naming, preferences. **At most 5 per
  review** — if there are more, pick the 5 that matter most and drop the rest.

## Exclusions

Do not review: generated paths, lock files, what CI already validates
(formatting, lint, types). Reviewing that is noise that buries the real
findings.

## Human attention

Automated review covers the three passes. **The human moves up a level**:
not every line, but whether the change does what the plan intended and
whether the risk is acceptable.

The code owner approves the PR. Production additionally requires the release
manager and `RELEASE_APPROVAL`. **Claude never approves its own PR** —
separation of duties is mandatory.

## Resolution

If someone tags `@claude` in a review comment, Claude addresses the comment.
The developer pushes (git is reserved, see `CLAUDE.md`).
