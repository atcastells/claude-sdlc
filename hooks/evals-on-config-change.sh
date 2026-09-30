#!/bin/bash
# evals-on-config-change: runs the eval suite when the agent's own configuration
# changes. Playbook rule: evals run whenever CLAUDE.md, skills or hooks change.
# No CI yet — this is the local gate.
# PostToolUse hook on Write|Edit|MultiEdit|NotebookEdit. Exit 2 reports red evals.

payload=$(cat)
path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null)
[ -z "$path" ] && exit 0

home="${WORKFLOW_HOME:-$HOME/.claude/workflow}"
src=$(cat "$home/source" 2>/dev/null)

# Installation (~/.claude) or the workflow source repo; each has its own suite
suite=""
case "$path" in
  */.claude/CLAUDE.md|*/.claude/settings.json) suite="$HOME/.claude/evals/run.sh" ;;
  */.claude/hooks/*|*/.claude/skills/*|*/.claude/agents/*|*/.claude/evals/*) suite="$HOME/.claude/evals/run.sh" ;;
esac
if [ -z "$suite" ] && [ -n "$src" ]; then
  case "$path" in
    "$src"/global/*|"$src"/hooks/*|"$src"/skills/*|"$src"/agents/*|"$src"/evals/*|"$src"/migrations/*|"$src"/profiles/*|"$src"/settings.template.json|"$src"/VERSION)
      suite="$src/evals/run.sh" ;;
  esac
fi
[ -z "$suite" ] && exit 0

# Never recurse: the suite itself writes nothing, but be explicit about it.
[ -n "${CLAUDE_EVALS_RUNNING:-}" ] && exit 0
export CLAUDE_EVALS_RUNNING=1

# Source repo: also run the installed profile's cases
profile_dir=$(cat "$home/profile" 2>/dev/null)
if [ -n "$src" ] && [ "$suite" = "$src/evals/run.sh" ] && [ -d "$profile_dir" ]; then
  out=$(WORKFLOW_PROFILE="$profile_dir" bash "$suite" 2>&1)
else
  out=$(bash "$suite" 2>&1)
fi
code=$?

if [ "$code" -ne 0 ]; then
  printf '%s\n' "EVALS RED after modifying $(basename "$path").

$out

The agent's configuration changed and the suite no longer passes. Fix this
before continuing: a control that is not verified is not a control." >&2
  exit 2
fi

printf 'evals: %s\n' "$(printf '%s' "$out" | grep -a '^PASS:')" >&2
exit 0
