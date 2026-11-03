# Spec: Interactive command to manage rules by scope

- **Derived from**: `intent.md`
- **Status**: approved (2026-10-27, "apruebo")
- **Approved by**: product owner (policy owner not needed: no personal or
  sensitive business data is designed in; see Policy applied)

## Requirements

Each one traces to a line of the intent.

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | A `/rules` skill asks, one question at a time, for the action: add, modify or delete a rule. | "chooses whether to add, modify or delete a rule" | Invoking `/rules` with no argument asks the action first; each of the three paths completes without the user editing a file. |
| R2 | The user chooses the scope: **global** (every repo of this user) or **this repo** (the repo of the session's working directory). | "the scope of that rule"; "this repo or global"; "this repo means the repo the user is working in" | The written file lands in the location of the chosen scope (Design) and loads in a new session in that scope only. |
| R3 | For **this repo**, the user chooses whole repo or some files; the command suggests globs built from files tracked in the repo and rejects a glob that matches no file. | "the user chooses whether the rule applies to the whole repo or only to some files, with globs suggested" | A rule limited to `**/*.sql` gets `paths:` frontmatter; a glob with zero matches is refused with a message. |
| R4 | Rules are never shared: nothing the command writes shows up in `git status` of any repo, and no tracked file is modified. | "They are personal rules, they are not shared" | After add/modify/delete in a repo, `git status --porcelain` is unchanged and no tracked file differs. |
| R5 | Modify and delete start from a list of the user's existing rules in the chosen scope, showing each rule's text and where it applies; delete asks for confirmation. | "add, modify and delete a rule only through the command … without needing to know where the rule is stored" | With two rules present, the list shows both with scope and paths; delete without confirmation leaves the file in place. |
| R6 | The command writes valid frontmatter itself and checks it parses, because Claude Code silently loads a rule with unparsable frontmatter as if it had no `paths` (source: code.claude.com/docs/en/memory, "Rule frontmatter reference"). | "applied cleanly depending on the context" (context of the request) | A path-scoped rule written by the command parses with a YAML check; globs with quotes or braces round-trip unchanged. |
| R7 | The command only lists, edits and deletes files it owns; it never touches `CLAUDE.md`, `CLAUDE.local.md`, project profiles or other files under `rules/`. | "Not asked for: editing the organization profile or any rule shared with the team" | Files outside the owned directories (Design) are not listed and cannot be selected. |

## Design

**Form.** A skill `skills/rules/SKILL.md` (invoked as `/rules`; there is no
built-in `/rules`, checked in code.claude.com/docs/en/commands, 2026-10-27)
that runs the conversation with `AskUserQuestion`, plus a helper
`skills/rules/rules.sh` (bash + jq, macOS compatible) that does every file
operation deterministically, so the skill never hand-edits rule files:

```
rules.sh list   [--repo <dir>]                     # JSON: scope, file, paths, first lines
rules.sh write  --scope global|repo [--repo <dir>] --topic <slug> [--path <glob>]... < text
rules.sh delete --scope global|repo [--repo <dir>] --topic <slug>
rules.sh globs  --repo <dir>                       # suggested globs from git ls-files
```

**Where rules live** (owned directories):

| Scope | File | Why it is not shared |
|---|---|---|
| Global | `~/.claude/rules/personal/<topic>.md` | Outside every repo. Claude Code loads `~/.claude/rules/` recursively in every project, before project rules. |
| This repo | `<repo root>/.claude/rules/personal/<topic>.md` | `rules.sh` adds `.claude/rules/personal/` to `$(git rev-parse --git-common-dir)/info/exclude`, which is local to the clone and never committed. `.gitignore` is not used because it is tracked (R4). |

The `personal/` subdirectory keeps the user's rules apart from rules a repo
or a future install ships in `rules/`, so R7 holds by directory. `install.sh`
does not copy, retire or back up anything under `rules/` today (its manifest
covers `skills agents hooks evals`); an eval pins that.

**Paths.** Global rules always load (the intent asks for file filtering only
within this repo). Repo rules carry `paths:` only when the user picks "some
files". `rules.sh write` quotes each glob as a YAML string, rejects a glob
with zero matches in `git ls-files`, and re-reads the frontmatter to confirm
it parses (R6).

**Topic.** One topic per file; `<topic>` is a kebab-case slug the skill
proposes from the rule text and the user can change. Writing to an existing
topic is a modify, and the skill says so.

**Flow.** Action → scope → (repo: whole repo or files → globs) → text →
preview of the final file → confirm → `rules.sh write` → one line saying
where it applies, e.g. "Applies in this repo when Claude reads or edits
`**/*.sql`". Modify and delete start from `rules.sh list`.

**What the user is told once, at the end of an add.** A rule is an
instruction, not a lock: Claude Code treats rules as context, and only a hook
blocks an action (source: code.claude.com/docs/en/memory). If the text reads
like "never …", the skill says so and points to hooks; it does not create
one.

**Size notice.** If the user's always-loaded personal rules (global plus
this repo without `paths`) pass 40 lines, the skill warns once; it does not
block. They do not count toward the installed budget of cases 65 and 65b,
which measures what `install.sh` installs.

**Touched.** New: `skills/rules/SKILL.md`, `skills/rules/rules.sh`, eval
cases and a script under `evals/scripts/`. Changed: `CHANGELOG.md`,
`VERSION` (minor). No hook, template or project setting changes, so no
`migrations/<version>.md`.

## Policy applied

- **Personal data**: none designed in. The rule text is the user's own
  instruction; the skill reminds once not to put customer data in a rule.
- **Sensitive business data**: none designed in. Same reminder covers
  costs, margins and stock.
- **Credentials**: none. A rule with a credential is blocked by
  `credential-guard` when the skill writes it through Write/Edit; `rules.sh`
  runs the same check on its input before writing.
- **Decisions about people / high risk**: no.

## Out of scope

- Organization profile and any rule shared with the team (intent: "Not
  asked for").
- Path-scoped **global** rules: the intent asks for file filtering only
  within this repo.
- Turning a rule into a blocking hook (open question in the intent; this
  spec only tells the user that rules do not block).
- `/repo-setup` auditing rule files.
- Rules in cloud sessions and Projects threads: a repo's excluded
  `personal/` folder is not in the cloud clone, and `~/.claude/rules/` is not
  read there (code.claude.com/docs/en/claude-projects).

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| A rule with bad frontmatter loads everywhere instead of on its files. | Rule noise in every turn of that repo. | `rules.sh` writes the frontmatter itself and verifies it parses (R6); eval. |
| A repo rule exists only in one worktree: `info/exclude` is shared by worktrees, the file is not. | The rule seems "lost" in another worktree. | The add confirmation names the worktree path. |
| Someone has already committed `.claude/rules/personal/` in a repo. | Writing there would modify a tracked file (breaks R4). | `rules.sh write` refuses when `git ls-files` lists anything under it. |
| User and repo rules contradict each other. | Claude may follow either one (docs). | On add, the skill shows rules in the other scope that mention the same topic. |
| The 40-line threshold is a guess. | Warning too early or too late. | Warning only; adjust with use. |

---
Next stage: Build reads this file and writes `plan.md`.
