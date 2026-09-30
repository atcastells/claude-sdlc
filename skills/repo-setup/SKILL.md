---
name: repo-setup
description: Sets up a new repository, audits an existing one, or upgrades it to the installed workflow version, against the agentic SDLC playbook and the installed rules (core + organization profile). Checks CLAUDE.md (line budget, real commands, paths that exist), .claude/settings.json with git reserved, .claude/workflow.json, REVIEW.md, .sdlc/, .gitignore and no tracked credentials; fixes what is missing, with confirmation. Use it with /repo-setup or /repo-setup upgrade, when cloning or creating a repo, when the session-start version notice says migrations are pending, when the user asks "set up this repo", "audit the repo", "update the repo's workflow", "prepare the project for Claude", or when a CLAUDE.md looks stale.
---

# Setting up or auditing a repository

A well-configured repo is one where the agent **reads true context** and
**cannot do what is forbidden** even if it wanted to. This skill checks the
first and sets up the second. Measure first, then fix, and always confirm
before writing.

## Step 1 — Measure

```bash
~/.claude/skills/repo-setup/check.sh <path>
```

Prints `PASS` / `WARN` / `FAIL` per item and exits 1 on any FAIL. It is
deterministic: it checks existence, references and patterns, it does not judge
quality. What the check cannot know, you assess in step 2.

Show the user the summary (`PASS: n WARN: n FAIL: n`) and the FAILs, not all
40 lines.

## Step 2 — Judge what the check cannot see

With the check in front of you, read `CLAUDE.md` (if any) and answer:

- **Do the commands say what "healthy" output looks like?** "`npm test`" is
  not enough; "`npm test` — 340 tests, ~40 s, all green" is. When the agent
  runs the command it has to know whether the result is normal.
- **Are the numbers still true?** Schema versions, module counts, directory
  lists. Verify each one with a command; a stale number is worse than none
  because the agent believes it.
- **Does it tell new from legacy?** It is the most valuable thing a CLAUDE.md
  can say, and what an `ls` does not tell.
- **Is there something the agent keeps getting wrong that is not written
  down?** Ask. It is the section that pays for itself the most.

Every deviation you find goes on the fix list, with the evidence
(`migrations.js:777 says 396, CLAUDE.md says 377`).

## Step 3 — Fix, with confirmation

Present the full fix list **before** touching anything, grouped:

**Objective** (one verified fact against another): dead paths, stale numbers,
scripts that do not exist. Applied as is.

**Structural** (create what is missing from a template):
- `.claude/settings.json` → `templates/settings.json`. If it exists, **merge**
  the git `deny` rules instead of replacing: the repo may have its own.
- `REVIEW.md` → `~/.claude/skills/sdlc/templates/REVIEW.md`.
- `.sdlc/README.md` → `templates/sdlc-README.md`.
- New `CLAUDE.md` → `templates/CLAUDE.md`, **with the real commands already
  filled in** from `package.json` / `Makefile` / `composer.json`. A skeleton
  with an unfilled `<build>` is not a CLAUDE.md, it is a pending task. Write it
  in the language the installed rules ask for.
- `.gitignore` without `.env*` → append the lines, do not rewrite the file.
- `.claude/workflow.json` → `templates/workflow.json`, with `workflow_version`
  = `~/.claude/workflow/VERSION` and today's date. It records which workflow
  version was applied; without it, the session-start notice cannot tell
  whether the repo is behind.

**Judgement calls** (need the user's decision): referenced documents that do
not exist — delete the references, generate them from the code, or note them
as pending? Ask with `AskUserQuestion`, with the three options and what each
costs. Do not decide yourself: generating six documents is real work and
deleting them loses intent.

Ask for a single confirmation for the whole block and apply it. Then run the
check again: the result must be `FAIL: 0`. If not, say what is left and why.

## Upgrade mode

With `/repo-setup upgrade`, or when the session-start notice
(`workflow-version-check`) says the repo is behind or has no version.

1. **Versions.** `v_project` = `workflow_version` in `.claude/workflow.json`
   (if missing, `1.0.0`: every repo set up before versioning existed is
   1.0.0). `v_installed` = `~/.claude/workflow/VERSION`. If the project is
   ahead, stop: the machine is stale and needs `install.sh`, not a migration.
2. **Pending migrations**: `~/.claude/workflow/migrations/<v>.md` with
   `v_project < v <= v_installed`, in order. Read them in full.
3. **Measure before proposing.** For each change in each migration, check
   whether it is already applied (sometimes someone did it by hand). What is
   applied is not proposed.
4. **Present the full block**: per migration, the missing changes, with file
   and what gets added. A single confirmation, as in step 3. Merge, do not
   replace: the repo may have its own rules in `settings.json` or `REVIEW.md`.
5. **Apply, bump the version and measure again.** `.claude/workflow.json` ←
   `v_installed` and today's date. Then `check.sh`: it must report
   `PASS  workflow up to date` and `FAIL: 0`.
6. Close with the list of touched files. The developer makes the commit;
   suggest `chore: workflow <v_project> -> <v_installed>` as the message.

If a migration does not apply ("Applies if" is not met), say so and skip it;
the version is bumped anyway.

## New repo (no CLAUDE.md, no .claude/)

Same flow, but step 2 becomes a short interview, **one question per turn**
(like the `intent` skill): what the repo is, what is legacy, what the agent
must never touch. Whatever you can get from `package.json`, the `README` and
an `ls`, do not ask.

## What this skill does not do

- It does not install another repo's station commands (`/analyze`,
  `/design`...). Those are each project's flavor; the global `sdlc` skill
  already provides the artifact chain without them.
- It does not commit. When done, it lists the files created or modified and
  reminds that the developer makes the commit.
- It does not generate architecture docs on its own. If the user chooses to
  generate them, that is a separate task with its own intent.

## Rules

- Verify before claiming. Every FAIL you report must come from the check or
  from a command you ran.
- Do not reproduce credentials even if the check finds them: give the file
  and line, not the value. And recommend revoking it, not just deleting it
  from the repo — it is still in the git history.
- If the repo handles personal data or decisions about people, note it in the
  CLAUDE.md Security section and recommend consulting the compliance contact
  named in the profile.
