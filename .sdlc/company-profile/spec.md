# Spec: Read a workflow-agnostic company profile

- **Derived from**: `intent.md`
- **Status**: approved (2026-11-03, "apruebo")
- **Approved by**: product owner (no policy owner needed: see Policy applied)

## Requirements

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | A workflow profile may declare the company repo in `company.json`: `{"url": "<git clone URL>", "rules": "<path relative to the company repo>"}`. The company repo needs nothing from the workflow. | "does not need nor name anything of this workflow" | The fixture company repo has no workflow file, key or wording; a `file_lacks` case on it checks `WF_`, `claude-sdlc`, `core`. |
| R2 | `install.sh --company-repo <dir>` composes the installed `CLAUDE.md` as core + company rules (leading YAML frontmatter stripped) + the workflow profile's `CLAUDE.md`. The dir is saved in `~/.claude/workflow/company-repo` and reused, like `profile`. | "A path" | Temp HOME: composed file has the three parts in order, no `---` frontmatter; a second install without the flag reuses the dir. |
| R3 | The rules path is validated: relative, no `..`, a regular file (not a symlink) physically inside the company repo, ≤ 16 KB. Otherwise the install stops with a message naming the flag. | safety | Scenarios: `..`, absolute, symlink out, missing file, oversized → exit 1 with the message; nothing written to `~/.claude`. |
| R4 | `install.sh` with a profile that has `company.json` and no known company repo: on a terminal it asks for the path, showing the clone command (`git clone <url> <dir>`) for who does not have it; without a terminal it exits 1 naming `--company-repo` and the clone command. Nothing searches the disk. | "the user says where that repo is or clones it ... no script that searches the PC" (2026-11-03) | tty-less run → exit 1 + message with the flag and the URL; no `find` over `$HOME` in the code. |
| R5 | (dropped 2026-11-03: no disk search) | — | — |
| R6 | A `workflow-install` skill asks with `AskUserQuestion` where the company repo is. Options: `~/Repos/<name>` and `~/<name>` (fixed suggestions built from the URL's basename, not checked in advance), "Not cloned yet: clone it", and the free-text "Other". Only the chosen path is checked (exists, holds the rules file). Then it shows the developer one command to run: `! cd '<source>' && ./install.sh --company-repo '<dir>'`, prefixed with `git clone '<url>' '<dir>' &&` when cloning (asking where, with the same suggestions). It does not run it. | "the installer asks, with the AskUserQuestion skill ... offering some default paths like home"; "the user says where that repo is or clones it" | `file_contains` cases on the skill: `AskUserQuestion`, `git clone`, the command shape, "does not run", "does not search". |
| R7 | At session start, when the installed profile has `company.json` but the saved company repo is missing or no longer holds the rules file, the notice suggests `/workflow-install`. | keeps it working when a clone moves | Hook scenario: saved dir removed → notice with `/workflow-install`; present → silent. |
| R8 | The four facts stay in the workflow profile's `profile.env` (unchanged); the company table is not parsed. | open question 2, recommended default | No code reads the company repo except the rules file. |

## Design

**Workflow profile** (`profiles/<org>/`, local): gains `company.json` (`url`, `rules`); its
`CLAUDE.md` keeps only workflow-specific text (the "adds to the core"
sentence, the closing headings translation). `profile.env`, `evals/`,
`denylist.txt` stay.

**`install.sh`**: after resolving `--profile`, if `$profile/company.json`
exists: company repo = `--company-repo`, else `workflow/company-repo`, else
ask (R4). Validate (R3) with the same physical-path checks as
`project_profile_file`. Compose: core, blank line, rules without a leading
`---`…`---` block, blank line, profile `CLAUDE.md`. Save the dir. No
`company.json` → today's behavior, byte-identical.

**`skills/workflow-install/SKILL.md`**: the questions of R6; reads `url`
and `rules` from the installed profile's `company.json` (path in
`workflow/profile`). No helper script.

**`workflow-version-check.sh`**: one more check (R7), reads
`workflow/profile`/`company.json` and `workflow/company-repo`.

**Example**: `profiles/example/company.json` and a fixture company repo
under `evals/fixtures/company-acme/` with a frontmatter'd rules file.

## Policy applied

- **Personal data**: none.
- **Sensitive business data**: none. The company rules may name a
  compliance contact; they are already in the installed `CLAUDE.md` today.
- **Credentials**: none.
- **Decisions about people / high risk**: no. The company rules carry the
  organization's AI governance text: changes to them are reviewed in the
  company repo by its owner, not here.

## Out of scope

- Parsing facts from the company repo (R8).
- Moving `check-public.sh`'s denylist to the installed profile (Found in
  the previous session; separate change).
- Committing anything in the company repo.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Company rules edited and not reinstalled | Installed rules lag | Same as today's profile; R7 only covers a missing file. Possible later: hash check at session start |
| Company file grows past the installed budget (case 65b, ≤ 110 lines) | Suite red after install | The budget case already runs on the composed file; it names the cause |
| A compromised company repo injects instructions | Every installer gets them | Text only, never executed; size cap; reviewed by MR there |

---
Next stage: Build reads this file and writes `plan.md`.
