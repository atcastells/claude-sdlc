# Changelog

Semantic versioning. **MAJOR**: breaks something in a project or a machine
that the migration alone does not fix. **MINOR**: adds rules, skills or project
files (ships `migrations/<version>.md` if it touches projects). **PATCH**:
fixes with no change in expected behavior.

## 2.7.0 — 2026-11-03

- **Spec and Vibe modes, per session.** Spec (the full chain) stays the
  default. `/vibe` switches the session to Vibe, for work that advances by
  trying ideas and looking at the result; `/vibe off` returns to Spec. In
  Vibe, a new `vibe` skill replaces intent → spec → plan, the `plan.md`
  approval and mandatory TDD; git, credentials, the release rule, verifying
  before claiming and `test-guard` still apply, and a PR still goes
  through Spec.
  - Two documents are the agent's base: `.sdlc/map.md`, a mermaid map of
    the project's systems and features with their state (`idea`, `wip`,
    `done`, `dropped`), read at start and updated each iteration; and
    `.sdlc/vibe/<topic>.md`, one per extension (goal, pieces, done and
    left, log). An idea that settles is promoted to `.sdlc/<slug>/intent.md`.
  - New hook `mode.sh` (`UserPromptSubmit` and `SessionStart`) keeps a
    per-session marker in `$TMPDIR`, keyed by a validated `session_id`.
    Vibe survives compaction and resume; `/clear` and a new session start
    in Spec. It never echoes the prompt.
  - The status line shows `Spec` or `Vibe` after the model.
  - `settings.template.json` adds the `UserPromptSubmit` event. As with
    every event the template defines, `install.sh` replaces an existing
    `UserPromptSubmit` in `~/.claude/settings.json` whole: keep your own
    hooks for it in `settings.local.json`.
- No migration: nothing `/repo-setup` leaves in projects changes.

## 2.6.0 — 2026-10-27

- **`/rules`: personal rules by scope.** A new skill adds, modifies or
  deletes the user's own rules, one question at a time: the action, the
  scope (every repo of this user, or the repo of this session) and, for
  this repo, whole repo or only some files (globs suggested from tracked
  files, each with its match count). Nothing it writes is shared:
  - Global rules go to `~/.claude/rules/personal/<topic>.md`.
  - Repo rules go to `<repo>/.claude/rules/personal/<topic>.md`, excluded
    through `.git/info/exclude` (never `.gitignore`), so `git status` does
    not change; path-scoped ones carry `paths:` frontmatter.
- Every file operation goes through `skills/rules/rules.sh`
  (`write`, `list`, `delete`, `globs`): it writes the frontmatter itself and
  checks it round-trips (a broken one would load the rule everywhere),
  refuses globs with no tracked match, credential-shaped text (through
  `credential-guard`), and a `personal/` dir that is tracked in the repo.
- The skill tells the user once that a rule is not a lock (only a hook
  blocks), that customer data never goes in a rule, and when always-loaded
  personal rules pass 40 lines.
- Eval: `install.sh` leaves `~/.claude/rules/` alone on install and upgrade.
- **Quieter install.** `install.sh` no longer prints the suite case by case:
  it starts `evals/install-verify.sh` in the background and ends with four
  lines. The result goes to `~/.claude/workflow/install-verify.json`
  (`running`, `green` or `red`, with each failed case's name, kind, file and
  detail) and the log to `install-verify.log`.
  - **Behavior change**: a red suite no longer fails the install. Instead,
    `workflow-version-check` tells Claude at the next session start. It only
    interrupts the user when a protection is not active (a failed
    `credential-guard`, `test-guard` or `production-gate` case), naming it
    and the action: reinstall, and tell the workflow maintainer if it
    persists. Any other failure is mentioned in one line under "Found" at
    the end of the run. A run stuck in `running` for over 10 minutes is
    reported too.
  - **Repo cases.** A case can declare `"repo"`: the product repo it tests
    (incident evals). `EVALS_SKIP_REPO=1` skips them; the background
    verification, `--verbose` and `evals-on-config-change` set it, since
    neither an install nor a config change touches that repo's code.
    `EVALS_REPO=<dir>` runs only the cases of that repo; the `verifier`
    runs it in the Test stage. A session in a git worktree of the repo does
    not match (different path). Existing incident evals need `"repo"` added
    by hand.
  - `--verbose` (or `WORKFLOW_INSTALL_VERBOSE=1`) keeps the old foreground
    run that fails the install when red, and also writes the result file;
    this repo's clean test install uses it. `WORKFLOW_INSTALL_NO_VERIFY`
    removes the result file, so an old red result never outlives a reinstall.
    The result shows a file under the home directory as `~/…`, and each
    failed case's `hook`.
  - `evals/run.sh` accepts `EVALS_RESULT_JSON=<file>` for a machine-readable
    result; stdout is unchanged.
- **Company rules from their own repo.** A profile may carry
  `company.json` (`url`, `rules`): the company rules then live in a
  separate repo that names nothing of this workflow. `install.sh
  --company-repo <dir>` composes core + those rules (leading YAML
  frontmatter stripped) + the profile's `CLAUDE.md`, and remembers the dir.
  The rules path must be relative, inside the repo, a regular file, at most
  16 KB; anything else stops the install before it writes. Without a
  terminal and no saved dir, the install stops naming the flag and the
  clone command; nothing searches the disk.
  - New skill `/workflow-install`: asks where the company repo is (or to
    clone it) and shows the one command to run; it runs nothing.
  - At session start, a saved company repo that is gone, or that lost its
    rules file, brings a notice suggesting `/workflow-install`.
  - `profiles/example/company.json.example` documents the format.
- No project migration: nothing `/repo-setup` leaves in projects changes.

## 2.5.0 — 2026-10-20

- **Secondary profile per repository.** A repo declares
  `"profile": ".claude/profile"` in `.claude/workflow.json`. The new
  `project-profile` hook (`SessionStart`: startup, clear, compact; silent on
  resume) injects that profile's `CLAUDE.md` (≤ 150 lines) for that repo
  only. It adds to the organization profile and never disables it: where an
  organization rule has nothing to act on, the profile says so. The repo's
  own `CLAUDE.md` does not grow.
- The path must be relative, without `..`, and stay inside the repo; a
  symlinked `CLAUDE.md` or `profile.env` is ignored.
- `credential-guard` and `production-gate` load the repo profile's
  `profile.env` on top of the global one, so their messages name that
  repo's secrets manager and policy.
- `evals/run.sh` accepts `WORKFLOW_PROFILE=<dir>` in installed mode too:
  a repo profile's `evals/cases/` run with the installed suite.
- Template `skills/repo-setup/templates/project-profile/` (glossary and
  tone, quality criteria, repository policy, organization rules with nothing
  to act on here) and a line in `repo-setup`.
- **Review fixes** (three `reviewer` passes before the PR):
  - Repo profile files are size-capped before reading (`profile.env`
    ≤ 4 KB, `CLAUDE.md` ≤ 16 KB): a large `profile.env` could make a guard
    exceed its 5 s timeout.
  - Injected content is capped at 150 lines and 12 KB; notices never echo
    the declared path; a missing profile dir gets its own notice; the header
    says the text is repo-authored.
  - Profile cases cannot run code (`script`, `env`, path-like `hook` are
    skipped). New case kind `file_lacks` (pattern, optional `until`).
  - Evals for the public template and for guards ignoring symlinked,
    oversized or undeclared repo `profile.env`.
- `/repo-setup upgrade` sets only `workflow_version` and `updated` in
  `.claude/workflow.json` and keeps every other key, such as `profile`.
- No project migration: the key is optional.

## 2.4.0 — 2026-10-20

- **Fix: reports handed back through `SubagentHandback` were not read.**
  Subagents deliver their report as the `message` of that tool, not as final
  text, so in 2.3.0 every `Deviation cause:` was lost and
  `subagent-report-check` saw an empty message. New `hooks/lib/report.sh`
  reads the last handback from the subagent transcript, falling back to
  `last_assistant_message`.
- `subagent-report-check` now checks the report **before** it leaves, on
  `PreToolUse` with matcher `SubagentHandback`; it blocks at most once per
  `agent_id`. On `SubagentStop` it skips agents that handed back.
- **Machine-level log** `~/.claude/actuals.jsonl` (override:
  `CLAUDE_SDLC_ACTUALS`): every closing line also lands there with a `repo`
  field, so a new repo's first plan can calibrate from the others. Never
  committed, never sent anywhere.
- `calibrate.sh`: per runner, repo and machine-log figures side by side;
  `use: repo` from 5 tasks of that runner, else the machine log (or the
  repo when the machine log has none of that runner yet). It prints
  the **median actual** minutes and tokens, which is what to estimate with:
  ratios mix tasks estimated with different starting tables.
- **New starting table** from 18 measured tasks: implementer S 2m/200k,
  M 2m/300k, L 3m/400k; scout 1.5m/650k (each request under 100K);
  verifier/reviewer 8m/700k; main 5m/6M. Rows with under 3 samples are
  marked low confidence.
- **Shared context per plan**: `templates/context.md` (≤ 30 lines). The
  main session writes `.sdlc/<slug>/context.md` before the first wave; every
  implementer reads it first and may add one `Learned:` line to its report;
  the main session folds those lines in after each wave. In this release's
  own plan, the 7 implementer runs had a median of 154k tokens (range
  95–457k) against a median of about 240k in the 15 runs before.
- `main` task causes come only from an explicit `done (cause: …)` in the
  Status cell.
- **Review fixes** (three `reviewer` passes before the PR):
  - `cause` is redacted before it is logged: the `credential-guard`
    patterns (now shared in `hooks/lib/leak-patterns.sh`) and URLs with
    user:password become `[redacted]`. Found live: a reviewer's report
    quoted a fake credential and the hook stored it.
  - Concurrent writes no longer lose lines: `mkdir` lock (a lock older than
    a minute is treated as left by a killed hook), unique tmp file,
    rewrite only when the `agent_id` is already logged.
  - One plan edit that closes a task and starts the next now records the
    closing line in the machine log too.
  - `task-actuals` acts only on a `plan.md` under `cwd`;
    `subagent-report-check` uses `agent_id` as a marker name only when it
    matches `^[A-Za-z0-9_-]+$`.
- Project migration `2.4.0`: `.sdlc/README.md` lists `context.md`.
- Sources: live transcripts of 2.3.0 runs (handback shape, hook events);
  code.claude.com (hooks, sub-agents); claude.dev ("What a task costs on
  Opus 5.5" for the agent-team cost).

## 2.3.0 — 2026-10-20

- **Plans with estimates and parallel waves.** The `plan.md` task table
  gains `Runs on`, `Depends` and `Est` (minutes / tokens); *Status* stays
  last. New sections: `Schedule` (waves of tasks with no pending dependency
  and disjoint files; critical-path wall-clock next to the sequential sum)
  and `Estimate vs actual`.
- **`implementer` agent** (Sonnet 5.5, `effort: medium`, `maxTurns: 40`):
  one well-specified plan task per invocation, only its listed files, red
  test first, no git writes. Its report carries `TASK:`, `RESULT:` and
  `Deviation cause:`; `subagent-report-check` sends it back otherwise.
- **Rule change** from 2.1.0: small models no longer "never edit". Haiku
  never edits; Sonnet edits only as `implementer`, for a task with a clear
  spec and a test that proves it ("Building with Claude Sonnet 5.5",
  claude.dev). Integration and decisions stay in the main session.
- **`task-actuals` hook** (`SubagentStop`; `PostToolUse` on `plan.md`
  edits): appends measured minutes and tokens per task to
  `.sdlc/<slug>/actuals.jsonl`, with the deviation from the estimate and its
  cause; deviations over 50 % are flagged, never blocked. Delegated tasks
  are found by the tag `[sdlc:<slug>/T<n> est=<min>m/<ktok>k]` on the first
  line of the prompt; `main` tasks by their *Status* going from
  `in progress` to `done`. Output tokens are not recorded: transcripts store
  usage at stream start.
- **`skills/sdlc/calibrate.sh`**: prints the starting estimate table and
  the median actual/estimate per runner from past `actuals.jsonl`.
- `plan-resume`: when the plan has a `## Tasks` heading, only that section
  is read; the `Estimate vs actual` table also has `T<n>` rows. Plans
  without the heading keep the old behavior.
- `sdlc` Stage 3: estimate with `calibrate.sh`, route down the ladder,
  launch a wave in one message, check `git diff --stat` after each wave.
- Sources: claude.dev ("Building with Claude Sonnet 5.5", "What a task
  costs on Opus 5.5", "Spending your effort"), code.claude.com (sub-agents,
  hooks), platform.claude.com (models overview).
- Project migration `2.3.0`: `.sdlc/README.md` lists `actuals.jsonl`.
- Known, unchanged: `install.sh` takes each hook event from the template
  wholesale, so a user-defined `PostToolUse` entry in `~/.claude/settings.json`
  is replaced (the backup `settings.json.bak-<timestamp>` keeps it). 2.3.0
  adds a second template `PostToolUse` entry.

## 2.2.1 — 2026-10-08

- **Fix:** `workflow-version-check` stayed silent when the installation came
  from one clone and the developer worked in another clone that was ahead.
  It now notices any claude-sdlc clone ahead of the installation and does
  not treat a clone as a project.
- Every notice that asks for an install ends with the command to run, for
  the agent to show verbatim and the developer to run with `!`:
  `! cd '<clone>' && ./install.sh` (with `git pull --ff-only &&` when a
  project is ahead of the source). Paths are single-quoted.
- No project migration.

## 2.2.0 — 2026-10-08

- **`scout` agent** (Haiku 5.5, `effort: medium`, read-only, `maxTurns:
  15`): lookups, logs and test output, with a summary that cites file:line.
  `effort: medium` because at `low` Haiku 5.5 is more likely to skip a search
  or a check; the turn cap keeps its prompt under the 100K-token price step.
- `sdlc`: the ladder names the models — `scout` (Haiku 5.5) reads, `verifier`
  / `reviewer` (Sonnet 5.5) verify and review, the main session edits — and
  the Haiku 5.5 price step (prompts over 100K tokens cost 5×).
- `verifier` and `reviewer` stay on Sonnet 5.5.
- The `haiku` alias is Haiku 5.5 on the Anthropic API from Claude Code
  2.1.293; on Bedrock, Google Cloud and Foundry it is still Haiku 4.5.
- Sources: platform.claude.com (Haiku 5.5 overview, "Prompting Claude Haiku
  5.5"), code.claude.com (model config, changelog).
- No project migration: nothing `/repo-setup` leaves in projects changes.

## 2.1.0 — 2026-10-07

- **`reviewer` agent** (Sonnet 5.5, `effort: high`, read-only): one pass of
  `REVIEW.md` per invocation. Stage 5 launches three in parallel; the main
  session consolidates and checks every cited file:line.
- `verifier`: `effort: high`, `maxTurns: 40`.
- **`subagent-report-check` hook** (`SubagentStop`, `verifier` and
  `reviewer`): a report without its `VERDICT:` / `PASS:` line, or an
  `[IMPORTANT]` finding without `demonstration:`, is sent back once.
- **`plan-resume` hook** (`SessionStart`, matcher `compact`): after a
  compaction, lists the open tasks of every `.sdlc/*/plan.md` as context.
- `sdlc`: downward rung of the ladder (small models read, never edit; pin the
  model per agent, no `CLAUDE_CODE_SUBAGENT_MODEL`); `/advisor fable` before
  switching to Fable; effort changes keep the cache on API key or
  subscription; dynamic workflow for review only on request.
- Sources: claude.dev ("What a task costs on Opus 5.5", "Building with Claude
  Sonnet 5.5"), code.claude.com (sub-agents, hooks, advisor).
- No project migration: nothing `/repo-setup` leaves in projects changes.

## 2.0.0 — 2026-09-30

- **Profiles.** The core is organization-neutral and in English. Organization
  rules (language, data protection, secrets manager, compliance contact) move
  to a profile: `install.sh --profile <dir>` appends its `CLAUDE.md`, installs
  its evals as `p-*`, merges its `settings.json` and remembers it for
  reinstalls. `profile.env` is parsed as data, never sourced.
- **Breaking:** a 1.x machine that relied on organization rules must reinstall
  with `--profile`. `install.sh` refuses to upgrade 1.x → 2.x without
  `--profile` or `--no-profile`.
- Hook messages name the profile's secrets manager and policy
  (`WF_SECRETS_MANAGER`, `WF_POLICY_NAME`); generic text without a profile.
- `scripts/check-public.sh`: fails if a private profile is tracked or addable,
  or if any publishable file contains a term from a local
  `profiles/*/denylist.txt`. `scripts/install-git-hooks.sh` runs it on
  pre-commit and pre-push.
- `profiles/example/`: a template for your own profile.
- The repo is named `claude-sdlc`; notices are prefixed `claude-sdlc:`.
- A project behind with no migration in range (a patch release) is not
  notified and `check.sh` passes: there is nothing to change in it.
- `check.sh` accepts CLAUDE.md section names in English or Spanish.
- Eval runner: `WORKFLOW_PROFILE`, `{profile}`, `capture: all`, `repo_only`.
- **Project migration**: `migrations/2.0.0.md` (no project file changes).

## 1.1.0 — 2026-09-30

- Versioning: `VERSION`, `migrations/`, `~/.claude/workflow/` and the
  `workflow-version-check` hook (SessionStart), which tells you when a project
  or the machine is behind. `.claude/workflow.json` in every project.
- `/repo-setup upgrade` applies pending migrations; `check.sh` reports the
  version and the CLAUDE.md budget (≤ 200 lines, global + project).
- `install.sh` retires, with a backup, what a previous version installed.
- The suite runs against the repo before installing; the evals hook also
  fires when the source repo is edited.
- Guards also on `NotebookEdit`; bare `git add`, `git commit` and `git push`
  denied.
- Practices from the Opus 5.5 and Sonnet 5.5 guides and the cost-per-task
  guide: stopping and continuing, three closing headings, `plan.md` as a live
  task list, findings that block merge, effort and model ladder, cheap
  subagents, cache-friendly pauses.
- Status line: effort and session cost (USD, from the payload).
- `production-gate` no longer fires on its own name in docs (backticked or
  `production-gate.sh`) and still blocks namespaces such as `production-gate`
  or `production-gateway`.
- `test-guard` on notebooks too; `install.sh` backs up `settings.json` only
  when it changes.
- **Project migration**: `migrations/1.1.0.md`.

## 1.0.0 — 2026-09-28

Baseline: `sdlc`, `intent`, `repo-setup` skills; `verifier` agent;
`credential-guard`, `test-guard`, `production-gate`, `evals-on-config-change`
hooks; a suite of 26 evals.
