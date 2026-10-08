#!/bin/bash
# workflow-version-check: compares the workflow version a project declares
# (.claude/workflow.json) with the one installed on this machine and with the
# source repo, and leaves a notice in the session context.
# SessionStart hook (startup|clear). Never blocks: always exit 0. No network, no git.

. "$(dirname "$0")/lib/semver.sh"

payload=$(cat)
src_evt=$(printf '%s' "$payload" | jq -r '.source // "startup"' 2>/dev/null)
case "$src_evt" in startup|clear) ;; *) exit 0 ;; esac

home="${WORKFLOW_HOME:-$HOME/.claude/workflow}"
installed=$({ tr -d "[:space:]" < "$home/VERSION"; } 2>/dev/null)
is_semver "$installed" || exit 0

proj="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)}"
[ -n "$proj" ] && [ -d "$proj" ] || exit 0
proj=$(cd "$proj" && pwd)

source_dir="${WORKFLOW_SOURCE:-$(cat "$home/source" 2>/dev/null)}"
source_ver=$({ tr -d "[:space:]" < "$source_dir/VERSION"; } 2>/dev/null)

msgs=()

# Single-quotes a path for a shell command the developer will paste
quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
# install.sh writes to ~/.claude: the agent shows the command, the developer runs it
run_cmd() {
  [ -d "$1" ] || return 0
  local pull=""
  [ "${2:-}" = pull ] && pull="git pull --ff-only && "
  printf '\nShow the developer this command verbatim; the developer runs it (the ! prefix runs it from this session):\n  ! cd %s && %s./install.sh' "$(quote "$1")" "$pull"
}

# A claude-sdlc clone (the recorded source or another one) is not a project
is_clone() { [ -f "$1/install.sh" ] && [ -f "$1/VERSION" ] && [ -f "$1/global/CLAUDE.md" ] && [ -f "$1/hooks/workflow-version-check.sh" ]; }

# The source repo has a version this machine has not installed yet
if is_semver "$source_ver" && ver_lt "$installed" "$source_ver"; then
  msgs+=("claude-sdlc: this machine has $installed installed and the source repo ($source_dir) is at $source_ver. Recommend the developer runs install.sh.$(run_cmd "$source_dir")")
fi

# Working in a clone other than the recorded source, ahead of the installation
if [ "$proj" != "$source_dir" ] && is_clone "$proj"; then
  clone_ver=$({ tr -d "[:space:]" < "$proj/VERSION"; } 2>/dev/null)
  if is_semver "$clone_ver" && ver_lt "$installed" "$clone_ver"; then
    msgs+=("claude-sdlc: this repo is a claude-sdlc clone at $clone_ver and this machine has $installed installed${source_dir:+ (from $source_dir)}. To install from this clone:$(run_cmd "$proj")")
  fi
fi

# Nothing to migrate in a claude-sdlc clone itself
if [ "$proj" != "$source_dir" ] && ! is_clone "$proj"; then
  wf="$proj/.claude/workflow.json"
  if [ -f "$wf" ]; then
    pv=$(jq -r '.workflow_version // empty' "$wf" 2>/dev/null)
    if ! jq -e . "$wf" >/dev/null 2>&1; then
      msgs+=("claude-sdlc: .claude/workflow.json is not valid JSON. Offer /repo-setup upgrade to regenerate it.")
    elif [ -z "$pv" ]; then
      msgs+=("claude-sdlc: .claude/workflow.json has no workflow_version. Offer /repo-setup upgrade to record it.")
    elif ! is_semver "$pv"; then
      msgs+=("claude-sdlc: .claude/workflow.json declares a version that is not semver (X.Y.Z, no leading zeros). Offer /repo-setup upgrade to fix it.")
    elif ver_lt "$pv" "$installed" && [ ! -d "$home/migrations" ]; then
      msgs+=("claude-sdlc: this project is at $pv and the installed version is $installed, but $home/migrations is missing: the installation is incomplete, recommend running install.sh.${source_dir:+$(run_cmd "$source_dir")}")
    elif ver_lt "$pv" "$installed"; then
      # No migration in range (e.g. a patch release) = nothing to change in the project
      list=$(pending_migrations "$home/migrations" "$pv" "$installed" | sed 's/^[^	]*	/  - /')
      [ -n "$list" ] && msgs+=("claude-sdlc: this project is at $pv and the installed version is $installed. Pending migrations:
$list
Before anything else, tell the developer and offer \`/repo-setup upgrade\` to apply them (with confirmation).")
    elif ver_lt "$installed" "$pv"; then
      msgs+=("claude-sdlc: this project declares $pv but this machine has $installed. Recommend updating the claude-sdlc repo and running install.sh before touching workflow files.${source_dir:+$(run_cmd "$source_dir" pull)}")
    fi
  elif [ -d "$proj/.sdlc" ] || [ -f "$proj/REVIEW.md" ]; then
    msgs+=("claude-sdlc: this project uses the workflow but has no .claude/workflow.json, so there is no record of which version it applied. Offer \`/repo-setup upgrade\` to record it (installed: $installed).")
  fi
fi

[ ${#msgs[@]} -eq 0 ] && exit 0
ctx=$(printf '%s\n\n' "${msgs[@]}")
jq -n --arg ctx "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
exit 0
