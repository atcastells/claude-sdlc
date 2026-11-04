# Spec: Claudio — new name, plain README, plan hints, company phrases

- **Derived from**: `intent.md`
- **Status**: approved (2026-11-04, "ok, aprobado")
- **Approved by**: product owner (maintainer, 2026-11-04)

One release, 3.0.0 (intent, decision "One release or several?"). MAJOR by
the `CHANGELOG.md` criteria: the notice prefix and the temp marker names
change, and an install from an old clone path keeps working only because
the recorded source is reused (R3), not because of a migration.

## Requirements

Each one traces to a line of the intent.

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | Every user-facing text says **Claudio**: README, the new `CHANGELOG.md` entry, skill and agent descriptions, `install.sh` output, `skills/repo-setup/check.sh` messages and the prefix of every hook notice (`Claudio:` instead of `claude-sdlc:`). Past `.sdlc/` artifacts and past `CHANGELOG.md` entries are not rewritten (audit trail). | Ask 1; decision "How far does the rename go?" | `git grep -n claude-sdlc -- ':!.sdlc' ':!CHANGELOG.md' ':!migrations'` returns only the compatibility lines R3 allows; case 39b renamed and asserting `Claudio:`. |
| R2 | Internal names follow: temp markers `claudio-mode-<id>` and `claudio-report-<id>`. | Same decision | Cases 113* and the report-check scripts assert the new names; full suite green. |
| R3 | Default clone path `~/claudio` and URL `github.com/atcastells/claudio` in README and notices. Existing installs keep working: `install.sh` and `workflow-version-check.sh` keep reading the recorded `source` and `profile` paths (e.g. `~/claude-sdlc`, `~/Repos/claude-sdlc/profiles/elektro3`), and clone detection stays by files, not by folder name. | Same decision ("existing installs keep working from the old path") | Eval: a fake clone in a folder named `claude-sdlc` is still recognised (88e/88f/88g green); a clean install from a folder named `claudio` ends green. |
| R4 | README main part, for any Claude Code user: what Claudio is in two or three sentences, one sentence to paste, what changes for you in plain bullets, and how to get help. None of: hook, eval, jq, semver, subagent, model names, `.sdlc`, YAML/JSON. Fits on one screen (≤ 40 lines above the first technical heading). Everything technical moves to `docs/technical.md`, linked once at the end. | Ask 2; signal "README without jargon"; decision "Who reads the plain README?" | New file case: README lines above `## Technical details` contain none of the listed terms and are ≤ 40; `docs/technical.md` holds the by-hand install and the feature list that left the README. |
| R5 | The paste sentence asks the user's agent to do everything: check `git` and `jq` and install them if missing (asking the user first), clone or update `~/claudio`, ask whether there is an organization profile, run the install, and explain the result in plain words. | Signal "Install with one sentence" | Case checks the sentence is in the README and names those steps. Manual check, left to the maintainer: one run in a clean `HOME` pasting only the sentence. |
| R6 | Status line, **task segment**: when the repo has an open plan (R8), shows the task whose Status starts with `in progress` as `T3 4m/6m` (elapsed / estimate). Elapsed comes from that task's `start` line in `actuals.jsonl` (main-run tasks); for other runners, which have no start line, `T3 ~6m`. Yellow above the estimate, red above twice it. | Decision "Which meta hints": task vs estimate | Status-line cases: fixture plan + actuals with a known `start` ts and a fixed clock show `T3 4m/6m`; over 6m yellow, over 12m red; a non-main task shows `~6m`. |
| R7 | Status line, **plan segment**: `5/12 · ~22m left`: rows whose Status starts with `done` over all task rows, and the sum of the minutes in `Est` of the rows not done. A row whose `Est` has no leading minutes counts in the total but adds nothing to the time. | Decision "Which meta hints": what is left of the plan | Cases with a fixture plan: counts and sum match; a malformed `Est` is skipped, not fatal. |
| R8 | Which plan: among `<repo>/.sdlc/*/plan.md` with at least one row not done, the most recently modified one. None open → no task or plan segment, the line is as today. | Open question "which plan counts" | Cases: two open plans → the newer wins; all done → no segment. |
| R9 | **Context hint**: at 70% context or more while a plan task is open, the line adds `compact between tasks`; at 90% or more, always. The existing cost figure stays; being over the estimate (R6 red) is the cost signal. | Decision "Which meta hints": context/cost warning; open question "thresholds" | Cases at 69/70/90% with and without an open task. |
| R10 | The hints never break or slow the line: they read only the repo's `.sdlc/*/plan.md` and `actuals.jsonl`, skip symlinks and files over 256 KB, print only the task id and numbers (never task text), and any parse error drops the segment. Texts in English, like every public text. | Constraint of R6–R9 (status line runs on every refresh) | Cases: symlinked plan, 300 KB plan, garbage plan → line as today; cases 90-92 and 113* still green; `time` of the line with a 30-row plan under 150 ms on the maintainer's machine. |
| R11 | `company.json` may name a phrases file: optional key `spinner_verbs`, a relative path inside the company repo, validated like `rules` (regular file, inside the repo, no `..`, ≤ 16 KB). Content: a JSON array of 1–200 strings, each 1–80 characters, no control characters. Invalid → `install.sh` stops before writing anything, as it does for `rules`. | Ask 4; decision "Company progress phrases" | Install cases with fixtures: valid, missing file, `..`, symlink, not an array, 201 items, an 81-character item, a control character. |
| R12 | When the profile names phrases, `install.sh` sets `spinnerVerbs` in `~/.claude/settings.json` to `{"mode": "replace", "verbs": [...]}`, replacing the user's phrases (the usual `settings.json.bak-<ts>` is the backup), and prints one line saying so. Without the key, the user's `spinnerVerbs` is left untouched. If a later install has no phrases, the last ones stay (answers the open question: left as they are; the backup holds the user's originals). | Decisions "Company phrases vs the user's own", "Only phrases" | Cases: user with own phrases + profile with phrases → replaced and backup has the old ones; profile without key → untouched; only `spinnerVerbs` changes besides the keys merged today. |
| R13 | Elektro3 content: `IA/Perfil Elektro3/Frases de progreso.json` in the documentation repo with the 64 starter kit phrases ("Buscando el punto y coma" wording), and `"spinner_verbs"` added to `profiles/elektro3/company.json`. | Decisions "Company progress phrases", "punto y coma" | Install with the Elektro3 profile: `jq '.spinnerVerbs.verbs | length'` is 64 and contains "Buscando el punto y coma". |

## Design

**Rename (R1–R3).** A mechanical rename over the tracked tree, excluding
`.sdlc/`, past `CHANGELOG.md` entries and `migrations/` (written once).
`is_clone` already checks files (`install.sh`, `VERSION`, `global/CLAUDE.md`,
`hooks/workflow-version-check.sh`), so a clone in any folder is recognised.
The recorded `~/.claude/workflow/source` and `profile` paths are reused as
they are; nothing moves on disk. A session that is in Vibe during the
upgrade loses its mode once (the old marker name is not read); stated in
the `CHANGELOG.md` entry. No project file `/repo-setup` leaves carries the
name (only a `check.sh` message, which is installed, not left in projects),
so no `migrations/3.0.0.md`; Build confirms with a grep of
`skills/repo-setup/templates`.

The GitHub repository is renamed by the maintainer. GitHub redirects the
old URL after a rename (to be confirmed in GitHub's docs in Build), so
clones with the old remote keep pulling.

**README (R4, R5).** Structure: title and two-line pitch; "Install" with the
paste sentence; "What changes for you" (five plain bullets: you approve
before anything is built, it checks its own work, your secrets and git stay
yours, a quick mode for trying ideas, your company's rules on top); "Need
help?"; then `## Technical details` with one link to `docs/technical.md`.
The paste sentence is written for the agent, the bullets for the person.

**Status line hints (R6–R10).** A new `hooks/lib/plan-hint.sh`, sourced by
`status-line.sh` like `mode.sh`, prints the segments or nothing. It finds
the repo root with the `git rev-parse` the line already runs, lists
`.sdlc/*/plan.md` (regular files ≤ 256 KB), and parses the task table with
one `awk` pass: header row with `Est` and `Status` columns, then rows that
start with `| T`. Minutes are the leading integer before `m` in `Est`
(`4m/650k`, `3m`). The `start` timestamp comes from `actuals.jsonl` with
`jq`; the clock is injectable (`PLAN_HINT_NOW`) for evals. Order on the
line: after the mode, `T3 4m/6m · 5/12 · ~22m left`, then the rest as
today; the context hint after the bar.

**Company phrases (R11–R13).** `install.sh` reads `spinner_verbs` next to
`rules`, with the same path checks and the content checks of R11 in `jq`.
At the settings step, after today's merge of `hooks`, `permissions` and
`statusLine`, it sets `.spinnerVerbs = {mode: "replace", verbs: $v}`. The
Elektro3 files live outside this repo: the phrases file in the
documentation repo (the maintainer commits it to GitLab) and the key in the
git-ignored `profiles/elektro3/company.json` of `~/Repos/claude-sdlc`.

## Policy applied

- **Personal data**: none. The phrases are generic; status line hints show
  only task ids and numbers.
- **Sensitive business data** (as the Elektro3 profile defines it): none.
  Estimates and actuals are about agent tasks, not costs, margins or stock.
  The company name in phrases ("Elektro3ficando") stays in the company repo;
  `scripts/check-public.sh` must stay green so it never reaches the public
  repo.
- **Credentials**: none.
- **Decisions about people / high risk**: no. Actuals calibrate estimates,
  not people (existing playbook rule); the hints show them per task, never
  per person.

## Out of scope

- Other display settings (spinner tips, themes): only phrases now; they can
  be considered later if visible in desktop, terminal and T3 Code (decision
  "Only phrases").
- A "next workflow step" hint: not chosen.
- Translating the hints or the README (public texts are in English).
- Renaming the GitHub repository and committing to the documentation repo:
  the maintainer's actions.
- Rewriting past `.sdlc/` artifacts or `CHANGELOG.md` entries.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Desktop or T3 Code may not render the status line or `spinnerVerbs` | Signal "useful hints in the bar" holds only in the terminal | Build T1 checks the official Claude Code docs for both settings per client; if not supported, say so in the README, do not fake it |
| `spinnerVerbs` schema (`mode`/`verbs`) differs from what the installed settings show | Phrases ignored silently | T1 confirms it in the settings reference before coding R12 |
| Plan tables vary between plans (extra columns, statuses like `done (W1; diff read)`) | Wrong counts | Columns found by header name; Status by prefix; cases built from real plans in `.sdlc/` |
| Status line slower on every refresh | Laggy UI | One `awk` pass, size cap, timing check in R10 |
| Old-path users miss the rename | Confusion, not breakage | Notice prefix and `CHANGELOG.md` say "claude-sdlc is now Claudio" once |
| A non-technical user's machine lacks `git`/`jq` and refuses installs | Signal "Install with one sentence" fails | The sentence asks the agent to request permission and explain; documented as a known limit |

---
Next stage: Build reads this file and writes `plan.md`.
