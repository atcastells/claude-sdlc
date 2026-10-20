# Context: actuals-handback

Shared by every task of this plan. Read it before anything else. The main
session is the only writer. Committed: no personal data, credentials or
sensitive business data.

## Decisions that shape the code

- Reports arrive through the `SubagentHandback` tool: an `assistant` line
  with a `tool_use` named `SubagentHandback`, input `{message}`. Read it
  from `agent_transcript_path`; fall back to `last_assistant_message`.
- Transcripts are several MB: read files with `jq --rawfile` or as jq input,
  never through `--arg` (ARG_MAX is 1 MB on macOS).
- Machine log: `${CLAUDE_SDLC_ACTUALS:-$HOME/.claude/actuals.jsonl}`. Tests
  always set `CLAUDE_SDLC_ACTUALS` to a temp path.

## Conventions

- bash 3.2 + jq 1.8 on macOS. No `sort -V`, no suffix-less `sed -i`,
  decimals formatted in jq (never `printf %f`).
- Hooks never print to stdout unless they return JSON context; they exit 0
  on bad input. Exit 2 only in `subagent-report-check`.
- Script tests copy fixtures into `mktemp -d` and print `all passed`; the
  eval case runs the script (see `evals/cases/102a-*.json`).
- Use Write/Edit for files, not heredocs in Bash.

## Key paths

- Hooks: `hooks/`; shared libs: `hooks/lib/` (sourced with
  `. "$(dirname "$0")/lib/<name>.sh"`).
- Eval runner: `bash evals/run.sh '<pattern>'`; cases in `evals/cases/`.

## Do not

- Edit files outside your task's `Files`; other implementers are working
  in the same tree.
- Touch `~/.claude` or read real transcripts under `~/.claude/projects`.
- Run git writes or `install.sh`.

## Learned

- W1: `evals-on-config-change` reruns the suite after every eval write and
  shows other tasks' in-flight reds; judge by your own cases and the final
  `bash evals/run.sh`.
- W1: `subagent_report` (in `hooks/lib/report.sh`) does not say whether it
  found a handback. To know that, test the transcript itself:
  `grep -q '"name":"SubagentHandback"' "$agent_transcript_path"`.
- W1: `$(subagent_report ...)` strips the trailing newline it prints.
- Review: hooks run for real in this session. Any manual run of a hook must
  set `CLAUDE_SDLC_ACTUALS` and `TMPDIR` to temp paths, or it writes to the
  real logs. A report that quotes a fake credential lands in the log.
- Review: `evals/run.sh` takes a glob (`'102*'`), not a substring.
