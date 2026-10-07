#!/bin/bash
# plan-resume: after a compaction, points the session back at the open tasks
# of every .sdlc/<slug>/plan.md. Playbook rule: the Status column is the live
# task list and the resume point.
# SessionStart hook (matcher: compact). Output = additionalContext; never blocks.

payload=$(cat)
proj=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$proj" ] && [ -d "$proj/.sdlc" ] || exit 0

lines=()
for plan in "$proj"/.sdlc/*/plan.md; do
  [ -f "$plan" ] || continue
  # Task rows: | T<n> | ... | <status> |  — the last non-empty cell is the status
  open=$(awk -F'|' '
    $1 ~ /^[[:space:]]*$/ && $2 ~ /^[[:space:]]*T[0-9]+[a-z]?[[:space:]]*$/ {
      id = $2; n = NF; while (n > 2 && $n ~ /^[[:space:]]*$/) n--; st = $n
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", id); gsub(/^[[:space:]]+|[[:space:]]+$/, "", st)
      if (tolower(st) !~ /^done/) out = out (out ? ", " : "") id " (" st ")"
    }
    END { print out }' "$plan")
  [ -n "$open" ] && lines+=("${plan#"$proj"/}: $open")
done
[ ${#lines[@]} -eq 0 ] && exit 0

ctx="claude-sdlc: context was compacted. Resume from the Status column of the plan, not from memory. Open tasks:
$(printf -- '- %s\n' "${lines[@]}")"
jq -n --arg ctx "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
