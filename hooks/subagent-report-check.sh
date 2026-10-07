#!/bin/bash
# subagent-report-check: sends a verifier/reviewer report back when it lacks
# its header or an IMPORTANT finding lacks its demonstration.
# Playbook rule: an Important finding carries how to demonstrate the failure.
# SubagentStop hook. Exit 2 = the subagent keeps working and fixes its report.

payload=$(cat)
agent=$(printf '%s' "$payload" | jq -r '.agent_type // ""' 2>/dev/null)
active=$(printf '%s' "$payload" | jq -r '.stop_hook_active // false' 2>/dev/null)
report=$(printf '%s' "$payload" | jq -r '.last_assistant_message // ""' 2>/dev/null)

case "$agent" in
  verifier) header='^[[:space:]]*VERDICT: (green|amber|red)'; want='VERDICT: green | amber | red' ;;
  reviewer) header='^[[:space:]]*PASS: (bugs|security|conformance)'; want='PASS: bugs | security | conformance' ;;
  *) exit 0 ;;
esac
# Already sent back once: let it stop rather than loop
[ "$active" = true ] && exit 0

problems=()
printf '%s\n' "$report" | grep -qaE "$header" || problems+=("no '$want' line")
missing=$(printf '%s\n' "$report" | grep -aF '[IMPORTANT]' | grep -avF 'demonstration:')
[ -n "$missing" ] && problems+=("[IMPORTANT] without 'demonstration:':
$missing")

[ ${#problems[@]} -eq 0 ] && exit 0
{
  printf 'subagent-report-check: the %s report does not follow its format:\n' "$agent"
  printf -- '- %s\n' "${problems[@]}"
  printf 'Fix the report. A finding you cannot demonstrate goes under "Unconfirmed".\n'
} >&2
exit 2
