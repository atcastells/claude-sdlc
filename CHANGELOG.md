# Changelog

Semantic versioning. **MAJOR**: breaks something in a project or a machine
that the migration alone does not fix. **MINOR**: adds rules, skills or project
files (ships `migrations/<version>.md` if it touches projects). **PATCH**:
fixes with no change in expected behavior.

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
