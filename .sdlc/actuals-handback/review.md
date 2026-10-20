# Review: 2.3.0 + 2.4.0 — parallel, estimated plans with measured actuals

- **Slugs**: `.sdlc/parallel-plans/` (2.3.0) and `.sdlc/actuals-handback/`
  (2.4.0), shipped in one PR: neither has been committed yet.
- **Policy**: `skills/sdlc/templates/REVIEW.md` (the repo has no root
  `REVIEW.md`).
- **Passes**: three `reviewer` subagents (bugs, security, conformance) in
  parallel, then a `verifier` re-run after the fixes (green).

## PR description

### What

Plans gain estimates, parallel waves and measured actuals, and subtasks
share context.

- `plan.md` template: `Runs on`, `Depends`, `Est` columns; `Schedule`
  (waves, critical-path wall-clock) and `Estimate vs actual` sections;
  `main` tasks close as `done (cause: …)`.
- `implementer` agent (Sonnet 5.5, medium): one well-specified task, listed
  files only, red test first, no git writes; reads `.sdlc/<slug>/context.md`
  first; reports `Deviation cause:` and an optional `Learned:` line.
- `task-actuals` hook: measures minutes and tokens per task from the
  subagent transcript (`SubagentStop`) or from `plan.md` Status edits
  (`PostToolUse`, `main` tasks); writes `.sdlc/<slug>/actuals.jsonl` and the
  machine log `~/.claude/actuals.jsonl`; redacts credentials in `cause`;
  locked writes.
- `subagent-report-check`: checks implementer reports; validates the
  report on `PreToolUse:SubagentHandback`, before it leaves, once per agent.
- `skills/sdlc/calibrate.sh`: starting table (from 18 measured tasks) and
  per-runner median actuals, repo vs. machine log.
- `context.md` template and Stage 3 rules: written before the first wave,
  `Learned:` lines folded in after each wave.
- `plan-resume` reads only the `## Tasks` section when present.
- Ladder rule changed from 2.1.0: Haiku never edits; Sonnet edits only as
  `implementer`.
- Migrations `2.3.0` and `2.4.0`: `.sdlc/README.md` lists `actuals.jsonl`
  and `context.md`.

### Evidence

- Implementer minutes within ±50 % of the estimate: 0/15 with the 2.3.0
  starting table, 7/7 with the 2.4.0 one.
- Implementer tokens per task with `context.md`: median 154k (range
  95–457k, 7 runs) vs. about 240k in the 15 runs before.
- Live check (2.4.0 installed): an implementer report without
  `Deviation cause:` was refused once by `PreToolUse:SubagentHandback`, the
  second passed, and the cause reached both logs.

### Verification

- `bash evals/run.sh` → PASS 179, FAIL 0; with the organization profile
  → PASS 190, FAIL 0.
- `HOME=$(mktemp -d) ./install.sh --no-profile` → PASS 175, FAIL 0.
- `bash scripts/check-public.sh` → exit 0 (pre-existing WARN: `LICENSE`
  placeholder). `bash -n` clean.
- `verifier` re-run after the review fixes: green.

## Findings

### Important — all fixed before this PR

| # | Pass | Where | Defect | Demonstration | Fix |
|---|------|-------|--------|---------------|-----|
| 1 | security | `hooks/task-actuals.sh` | `cause` logged unfiltered into a committed file and the machine log | A reviewer report quoting a fake credential was stored by the hook in both logs (lines removed) | Redacted with the shared `credential-guard` patterns + user:password URLs; scenarios v, v2 |
| 2 | bugs, security | `hooks/task-actuals.sh` | Concurrent `SubagentStop` writes lost lines and printed `mv` errors | 12 concurrent stops: 6/13 repo lines, 5/12 machine lines, 13 stderr lines | `mkdir` lock, stale-lock recovery, unique tmp, rewrite only when the id is present; scenarios w, z (20 concurrent: 20/20, no stderr) |
| 3 | bugs | `hooks/task-actuals.sh:169` | One edit closing T2 and starting T3 skipped the machine log | Read in code; scenario x red | Per-line filter; scenario x |
| 4 | conformance | `.sdlc/*` | Non-English quotes and another repo's slug in public files | `grep` | Translated and neutralized |
| 5 | conformance | `hooks/plan-resume.sh` | `## Tasks` scoping traced to no requirement | spec/plan grep | Amendment in `parallel-plans/spec.md` |
| 6 | conformance | `CHANGELOG.md` | Token claim left out two runs | `jq` over the log | Median and full range |

Also fixed: plan path must be under `cwd`; `agent_id` validated before use
as a marker name; `main` cause cut at the first `)`; `calibrate.sh` `use:`
when the machine log is empty; SKILL/template wording on median actuals.

### Nits — not fixed

1. `subagent-report-check` is line-based: "No [IMPORTANT] findings" or a
   demonstration on the next line is a false positive (pre-existing).
2. Lock waits can add up to about 10 s on both logs against a 10 s hook
   timeout; the effect is a possibly lost line, never a block.
3. URL redaction keeps the host and path after the `@`.
4. Registration cases 84d–84f check a substring, not the event.
5. A blocked handback followed by a plain-text ending is not re-checked on
   `SubagentStop` (by design: blocks at most once).

### Unconfirmed

- A narrow race when two hooks see the same stale lock at once (code
  reading; not reproduced).
- Real `SubagentStop` / `PostToolUse` payload fields other than those seen
  in transcripts (`agent_id`, `cwd`) were checked with synthetic payloads.

## For the code owner

- Two log lines with `cause: …` prefixes (T6, T10 of this plan) come from
  the 2.3.0 hook; cosmetic.
- After merging, run `./install.sh` with the profile; repos set up with
  `/repo-setup` will be offered migrations 2.3.0 and 2.4.0.
