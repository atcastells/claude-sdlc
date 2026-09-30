# Incident: <title>

- **Detected**: <YYYY-MM-DD HH:MM> by <person | alert>
- **Severity**: critical | high | medium | low
- **Status**: open | mitigated | closed
- **Service owner**: <who>

## What broke

<Observed symptom. No hypotheses yet.>

## Impact

<Who was affected, for how long, what was lost. No personal data.>

## Which control failed

<The hook, test, eval or review that should have stopped it and did not.
If there was none, say so — that is the finding.>

## Root cause

<Cause, not symptom. Verified, not assumed.>

## Mitigation applied

<What was done to stop the bleeding.>

## Mandatory outputs

- [ ] New `intent.md` for the definitive fix → `.sdlc/<slug>/intent.md`
- [ ] Permanent eval in `~/.claude/evals/` that reproduces this failure
- [ ] New or corrected control (hook / test / rule in CLAUDE.md)

---
Every production incident becomes an eval that is never removed.
