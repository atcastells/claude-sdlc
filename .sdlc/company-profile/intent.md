# Intent: Read a workflow-agnostic company profile

- **Originator**: maintainer
- **Date**: 2026-11-03
- **Status**: approved by product owner (2026-11-03, direction answered: "a path")
- **Slug**: company-profile

## The problem, in the originator's words

> "Move it to the folder `Perfil <org>`: the point is that the company
> profile lives there. The company profile must be workflow-agnostic; it
> does not need nor name anything of this workflow."
> (translated from Spanish; "there" = the IA folder of the organization's
> documentation repo)

## What exists (verified 2026-11-03)

- The organization's profile lives in a git-ignored `profiles/<org>/` of a
  local clone, never versioned. It mixes two things:
  - Company content: the rules (`CLAUDE.md`) and four facts (org name,
    secrets manager, compliance contact, policy name).
  - Workflow plumbing: `profile.env` with `WF_*` keys, `evals/cases/` in
    this repo's case format, `denylist.txt` for `check-public.sh`, `.sdlc/`
    history, the "closing headings" translation and the "adds to the core
    rules" sentence in `CLAUDE.md`.
- `install.sh --profile <dir>` appends `<dir>/CLAUDE.md` to the core rules,
  copies `profile.env` and installs `evals/cases/` as `p-*` cases.
- The company content now also exists, without workflow references, in the
  documentation repo: `<docs>/IA/Perfil <org>/Reglas <org>.md` (rules, YAML
  frontmatter on top) and `00 - Léeme.md` (a "Datos de la organización"
  table with the four facts). Written 2026-11-03, not committed.

## Who it affects

Everyone installing the workflow with that organization's profile.

## What happens if we do nothing

The company rules stay unversioned and tied to this workflow's format; the
same rules are kept by hand in more than one place and drift.

## How we will know it is solved

To be confirmed by the originator. Proposal:

- The company profile has no file, key, field or wording from this workflow;
  the dependency only goes workflow → company profile.
- The workflow profile (`profiles/<org>/`, still local) keeps only the
  plumbing and points to the company profile; `install.sh` builds the same
  installed `CLAUDE.md` and `profile.env` as today from it.
- Editing the company profile and reinstalling changes the installed rules;
  the profile's evals still check them.

## Open questions

- How the workflow profile points to the company rules: a path in a new
  file (`company.path`) read by `install.sh`, or a Claude Code `@` import in
  the installed `CLAUDE.md` (no copy, but line budget and `file_contains`
  evals would not see the content).
- Where the four facts come from: the workflow profile keeps its own
  `profile.env` (simple, duplicated), or `install.sh` reads them from the
  company profile (no duplication, but couples to its table layout).
- Whether the YAML frontmatter of the rules file is stripped on install.

## Decisions

| Date | Question | Answer | Who |
|------|----------|--------|-----|
| 2026-11-03 | How the workflow profile points to the company rules | "A path. The installer asks, with the AskUserQuestion skill, for the path of that repository, offering some default paths like home etc." (translated) | maintainer |
| 2026-11-03 | Disk search for candidate paths | "No: the user says where that repo is or clones it to install the company rules, with no script that searches the PC." (translated) | maintainer |
| 2026-11-03 | Facts source; frontmatter | Not answered: the spec takes the recommended defaults (workflow profile keeps `profile.env`; frontmatter stripped), marked for approval | maintainer |

---
Next stage: Design reads this file and writes `spec.md`.
Requires product owner approval.
