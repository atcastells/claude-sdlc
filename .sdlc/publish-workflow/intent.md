# Intent: Publish the workflow as a public repo, free of organization-specific rules

- **Originator**: maintainer
- **Date**: 2026-09-30
- **Status**: implemented (see `plan.md`)
- **Slug**: publish-workflow

> This is the public, anonymized copy of the chain. The original lives in the
> originating organization's private profile.

## The problem, in the originator's words

> "Prepare the workflow to be uploaded to a public repo, that is, abstract
> away every rule that is custom to our organization."

## Who it affects

- Anyone adopting it outside the originating organization: they need a
  workflow that works without that organization's secrets manager, compliance
  contact or catalog of sensitive data.
- The originating organization: its machines must keep exactly the rules they
  had before.

## What happens if we do nothing

Publishing the repo as it was would expose people's names (personal data),
the corporate secrets manager, categories of sensitive business data, internal
repository names and internal incidents.

## What was already known (inventory)

| Kind | Where |
|------|-------|
| Organization identity and policy | global `CLAUDE.md`, hook messages, skills, spec template, verifier |
| People | global `CLAUDE.md`, the `intent` skill's decisions table |
| Examples taken from internal code | the `intent` skill |
| Internal incidents | `origin` of some evals |
| Evals that test organization rules | two cases |
| Internal history | the previous `.sdlc/` chain |
| Local configuration | `.claude/settings.local.json`, only ignored by a global gitignore |

## How we will know it is solved

- A deterministic check with a denylist that lives outside the public repo
  finds zero hits.
- An install with no profile works and passes its evals.
- An install with the organization's profile yields the same rules as before
  and also passes the profile's evals.

## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|
| 2026-09-30 | Language of the public repo | Core in English; the organization profile brings its own language | maintainer |
| 2026-09-30 | Where the organization profile lives | A git-ignored folder in this repo (`profiles/<org>/`) | maintainer |
| 2026-09-30 | Core vs profile | Core, on by default: artifact chain, git reserved, TDD, test-guard, credential-guard, production-gate, verifier. Profile: data-protection law, compliance contact, secrets manager, sensitive business data | maintainer |
| 2026-09-30 | What to do with the previous internal chain | Move it to the private profile; the public repo starts with this chain | maintainer |
| 2026-09-30 | License | MIT | maintainer |
| 2026-09-30 | Public repo name | `claude-sdlc` (chosen knowing it carries a third-party brand) | maintainer |
| 2026-09-30 | Keep `claude-sdlc` after seeing ~108 GitHub repos with that name (6 exact) | Kept; README gets a copy-paste install prompt | maintainer |
| 2026-09-30 | Where it is published | github.com/atcastells/claude-sdlc (personal account; the name was free) | maintainer |

## Accepted risk

The private profile lives in the same tree and only `.gitignore` protects it.
The design must add a deterministic control, not just an instruction.

## Open questions

- The copyright holder in `LICENSE`.

---
Next stage: Design reads this file and writes `spec.md`.
