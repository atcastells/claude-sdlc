# Spec: Read subagent reports from the handback and calibrate across repos

- **Derived from**: `intent.md`
- **Status**: approved (2026-10-20, "ok, I approve the recommendations": version 2.4.0);
  R11–R13 added and approved the same day ("1, yes, add it to this change")
- **Approved by**: product owner (no policy owner needed: see "Policy applied")

## Requirements

| # | Requirement | Traces to (intent) | Acceptance criterion |
|---|-------------|--------------------|----------------------|
| R1 | Shared helper `hooks/lib/report.sh`: `subagent_report <payload>` prints the subagent's report: the `message` input of the last `SubagentHandback` tool use in `agent_transcript_path`; if there is none, `last_assistant_message` | Problems 1, 2 | Helper scenarios: handback in transcript → its message; no handback → last message; missing transcript → last message |
| R2 | `subagent-report-check` validates the report **before** it is handed back: on `PreToolUse` with `tool_name` `SubagentHandback` and `agent_type` verifier / reviewer / implementer, it checks `tool_input.message` with the existing rules and exits 2 with the reasons. It blocks **at most once per `agent_id`** (marker file under `$TMPDIR`); the second attempt passes | Problem 2 | Cases: bad implementer handback → 2; good → 0; second bad attempt same agent → 0; foreign agent → 0 |
| R3 | On `SubagentStop`, `subagent-report-check` skips agents whose transcript has a `SubagentHandback` (already checked on R2) and keeps today's check for agents that end with plain text | Problem 2 | Cases: handback transcript + empty last message → 0; plain-text report without header → 2 (unchanged 82b, 82e, 82i) |
| R4 | `task-actuals` takes `Deviation cause:` from the R1 report | Problem 1 | Scenario: handback transcript → `cause` from the handback message |
| R5 | `task-actuals` also appends every closing line (not start lines) to a machine-level log, `${CLAUDE_SDLC_ACTUALS:-$HOME/.claude/actuals.jsonl}`, with an extra `repo` field (basename of `cwd`) and the same `agent_id` de-duplication | Decision "machine-level log" | Scenarios with the env override: one line in each log; repeat stop → still one in each; start lines only in the repo log |
| R6 | `calibrate.sh <repo>` reads the repo log and the machine log. Per runner it prints both medians (`repo n=… x…/x…`, `all n=… x…/x…`) and `use: repo` when the repo has ≥ 5 tasks of that runner, else `use: all`; amended in Build: also `use: repo` when the machine log has none of that runner yet (case 103f), since 2.3.0 history exists only in repo logs | Decision "repo's own median from 5" | Cases: repo 2 + global 6 → `use: all`; repo 5 → `use: repo`; no logs → starting table only |
| R7 | New starting table, printed by `calibrate.sh` and quoted in the plan template: implementer S 2m/200k, M 2m/300k, L 3m/400k; scout 1.5m/650k (each request under 100K); verifier/reviewer 8m/700k; main 5m/6M; rows with fewer than 3 samples marked `(low confidence)` | Measurements table; decision "rebuilt from the measurements" | Case on the printed table; plan template references it |
| R8 | `main` task cause: `task-actuals` takes it only from an explicit `cause:` in the Status cell (`done (cause: …)`); otherwise `""`. The plan template says so | Problem 5 | Scenarios: `done (cause: spec unclear)` → `spec unclear`; `done (10 tests; 271 OK)` → `""` |
| R9 | `settings.template.json`: `PreToolUse` entry with `"matcher": "SubagentHandback"` running `subagent-report-check.sh` | R2 | Registration case |
| R10 | Release 2.4.0: `VERSION`, `CHANGELOG.md`; `sdlc-README.md` template lists `context.md`, so a project migration `migrations/2.4.0.md` ships | Release rules; R11 | Migration case; suite, profile suite, check-public, clean install green |
| R11 | Template `skills/sdlc/templates/context.md` (≤ 30 lines): Decisions that shape the code, Conventions, Key paths, Do not, Learned (per wave). Says it is committed: no personal data, credentials or sensitive business data | Problem 6 | Template exists with those headings and the data rule |
| R12 | `implementer` reads `.sdlc/<slug>/context.md` first when it exists, and its report may carry one `Learned:` line: only what the next task needs, same data rule. `subagent-report-check` does not require it | Problem 6 | Agent text cases: reads `context.md`; report format has `Learned:` |
| R14 | `calibrate.sh` also prints, per runner, the **median actual** minutes and tokens (repo and all), and says to estimate with it: ratios mix tasks estimated with different starting tables (in W1 of this plan: ×0.34 overall vs. ~×1 on the new table). Added in Build, 2026-10-20 ("absolute median") | Problem 3; "later estimates move closer" | Case: history → `median 1.6m/150k`-style figures per runner |
| R13 | `sdlc` Stage 3: before the first wave the main session writes `context.md` from the template; after each wave it folds the reports' `Learned:` lines into it (no duplicates, ≤ 30 lines). `SKILL.md` stays ≤ 160 lines | Problem 6 | Skill text cases; case 79 green |

## Design

- **Report source.** The transcript line before `SubagentStop` already holds
  the handback (`assistant` line with a `tool_use` named `SubagentHandback`,
  input `{message}`; checked on the second repo's transcripts). The
  helper reads it with `jq --rawfile`-safe file reads (no `--arg` with
  transcript content: ARG_MAX, lesson of 2.3.0).
- **Check before handback.** `PreToolUse` fires on `SubagentHandback`
  (another hook's `PreToolUse:SubagentHandback` run is recorded in those
  transcripts). Its payload carries `agent_type` and `agent_id` (common
  fields) and `tool_input.message`. Exit 2 refuses the call and the subagent
  sees the reasons; the once-per-agent marker
  (`$TMPDIR/claude-sdlc-report-<agent_id>`) is the loop guard that
  `stop_hook_active` gives on `SubagentStop`.
- **Whether a `SubagentStop` block after a handback has effect** is not
  needed any more: R3 stops relying on it. It is still checked live in Test
  and recorded in the CHANGELOG.
- **Machine log.** Same JSON line as the repo log plus `repo`. Written only
  after the repo write succeeds (a `.sdlc/<slug>` must exist), so the two
  logs hold the same tasks. `install.sh` does not touch it.
- **Calibration.** The machine log already contains the current repo's lines,
  so `all` includes them; no double counting inside each figure.
- **SKILL.md** (160 lines) changes only for R13, rewriting Stage 3 rather
  than appending; the calibration change shows in `calibrate.sh`'s output
  and the plan template.
- **Shared context (R11–R13).** The implementer reads `context.md` with its
  own tools; nothing relies on prompt caching between subagents. The main
  session is the only writer of `context.md`, so parallel implementers
  never edit it (disjoint files holds). `Learned:` is optional so a task
  with nothing to add is not sent back.

## Policy applied

- **Personal data**: none. The machine log has no author, user or session
  field; `repo` is a directory name.
- **Sensitive business data**: none by design. `cause` is free text written
  by the agent (max 200 chars); it can name files or modules. The machine
  log stays in `~/.claude` on the developer's machine and is never committed
  or sent anywhere.
- **Credentials**: none.
- **`context.md`** is committed: the template and the implementer forbid
  personal data, credentials and sensitive business data in it (prices,
  margins, stock). The main session reviews every `Learned:` line before
  folding it in.
- **Decisions about people / high risk**: no; the log calibrates estimates,
  not people (unchanged rule).

## Out of scope

- Money conversion; per-plan wall-clock in the log.
- Pruning or rotating the machine log.
- Recalibrating the `main` token rate by context size.
- Recording permission-prompt waits separately (noted in 2.3.0).

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Exit 2 on `PreToolUse:SubagentHandback` does not refuse the call | Check still ineffective | Live test in Test; if it fails, report-check falls back to adding a warning to the parent via the SubagentStop path and the CHANGELOG says so |
| Marker files accumulate in `$TMPDIR` | Clutter | One empty file per subagent; `$TMPDIR` is cleaned by the OS |
| The handback tool or its `message` field is renamed in a Claude Code update | Cause lost again, check skipped | Helper falls back to `last_assistant_message`; fixture documents the shape |
| A `Learned:` line carries noise or sensitive data into git | Context degrades or leaks | Main session filters before folding; 30-line cap; data rule in template and agent |
| `SKILL.md` cannot fit R13 in 160 lines | Case 79 red | Rewrite Stage 3; stop and ask if a rule would be dropped |

---
Next stage: Build reads this file and writes `plan.md`.
