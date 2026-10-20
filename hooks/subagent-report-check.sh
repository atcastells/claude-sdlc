#!/bin/bash
# subagent-report-check: sends a verifier/reviewer/implementer report back when
# it lacks its header or an IMPORTANT finding lacks its demonstration.
# Playbook rule: an Important finding carries how to demonstrate the failure.
# Two events. PreToolUse on SubagentHandback checks tool_input.message before
# the report leaves; it blocks at most once per agent (marker file
# ${TMPDIR:-/tmp}/claude-sdlc-report-<agent_id>; no agent_id, or one not matching [A-Za-z0-9_-]+, = never blocks).
# SubagentStop checks last_assistant_message, except when the transcript holds
# a SubagentHandback call (already checked on PreToolUse).
# Exit 2 = the subagent keeps working and fixes its report.

payload=$(cat)
tool=$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null)
agent_id=$(printf '%s' "$payload" | jq -r '.agent_id // ""' 2>/dev/null)
tpath=$(printf '%s' "$payload" | jq -r '.agent_transcript_path // ""' 2>/dev/null)
pre=false
agent=$(printf '%s' "$payload" | jq -r '.agent_type // ""' 2>/dev/null)
active=$(printf '%s' "$payload" | jq -r '.stop_hook_active // false' 2>/dev/null)
report=$(printf '%s' "$payload" | jq -r '.last_assistant_message // ""' 2>/dev/null)

case "$agent" in
  verifier) header='^[[:space:]]*VERDICT: (green|amber|red)'; want='VERDICT: green | amber | red' ;;
  reviewer) header='^[[:space:]]*PASS: (bugs|security|conformance)'; want='PASS: bugs | security | conformance' ;;
  implementer) header='^[[:space:]]*TASK: [a-z0-9-]+/T[0-9]+[a-z]?'; want='TASK: <slug>/T<n>' ;;
  *) exit 0 ;;
esac
if [ "$tool" = SubagentHandback ]; then
  pre=true
  report=$(printf '%s' "$payload" | jq -r '.tool_input.message // ""' 2>/dev/null)
  [[ "$agent_id" =~ ^[A-Za-z0-9_-]+$ ]] || exit 0
  marker="${TMPDIR:-/tmp}/claude-sdlc-report-$agent_id"
  [ -e "$marker" ] && exit 0
elif [ -n "$tool" ]; then
  exit 0
else
  # SubagentStop: the handback was already checked on PreToolUse
  [ -n "$tpath" ] && [ -r "$tpath" ] && grep -q '"name":"SubagentHandback"' "$tpath" && exit 0
  # Already sent back once: let it stop rather than loop
  [ "$active" = true ] && exit 0
fi

problems=()
printf '%s\n' "$report" | grep -qaE "$header" || problems+=("no '$want' line")
if [ "$agent" = implementer ]; then
  printf '%s\n' "$report" | grep -qaE '^[[:space:]]*RESULT: (done|blocked)([[:space:]]|$)' || problems+=("no 'RESULT: done | blocked' line")
  printf '%s\n' "$report" | grep -qaE '^[[:space:]]*Deviation cause: .+' || problems+=("no 'Deviation cause:' line (use 'none' if there was no deviation)")
fi
missing=$(printf '%s\n' "$report" | grep -aF '[IMPORTANT]' | grep -avF 'demonstration:')
[ -n "$missing" ] && problems+=("[IMPORTANT] without 'demonstration:':
$missing")

[ ${#problems[@]} -eq 0 ] && exit 0
[ "$pre" = true ] && : > "$marker"
{
  printf 'subagent-report-check: the %s report does not follow its format:\n' "$agent"
  printf -- '- %s\n' "${problems[@]}"
  printf 'Fix the report. A finding you cannot demonstrate goes under "Unconfirmed".\n'
} >&2
exit 2
