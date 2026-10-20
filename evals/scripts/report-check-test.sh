#!/bin/bash
# Scenarios for hooks/subagent-report-check.sh on PreToolUse(SubagentHandback)
# and SubagentStop. Exit 0 = every scenario behaved.
#   usage: report-check-test.sh <path-to-hook> <fixtures-dir>
set -uo pipefail
hook="$1"; fx="$2"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp"
fails=0
fail() { echo "  FAIL $1: $2"; fails=$((fails+1)); }

bad=$'TASK: demo/T1\nRESULT: done\nFiles: a.sh'
good=$'TASK: demo/T1\nRESULT: done\nDeviation cause: none'

# pre <tool> <agent_type> <agent_id> <message> -> exit code of the hook
pre() {
  jq -n --arg tool "$1" --arg at "$2" --arg id "$3" --arg m "$4" \
    '{hook_event_name:"PreToolUse", tool_name:$tool, agent_type:$at, tool_input:{message:$m}}
     + (if $id == "" then {} else {agent_id:$id} end)' \
    | bash "$hook" >"$tmp/out" 2>"$tmp/err"
}

# a. bad implementer handback -> 2 and the marker exists
pre SubagentHandback implementer ag1 "$bad"; rc=$?
[ "$rc" -eq 2 ] || fail a "expected 2, got $rc"
[ -e "$tmp/claude-sdlc-report-ag1" ] || fail a "marker not created"
grep -q 'Deviation cause:' "$tmp/err" || fail a "stderr lacks the Deviation cause message"

# b. good handback -> 0
pre SubagentHandback implementer ag2 "$good"; rc=$?
[ "$rc" -eq 0 ] || fail b "expected 0, got $rc"

# c. the same bad handback again, same agent_id -> 0
pre SubagentHandback implementer ag1 "$bad"; rc=$?
[ "$rc" -eq 0 ] || fail c "expected 0, got $rc"

# d. foreign agent_type -> 0
pre SubagentHandback general-purpose ag3 "$bad"; rc=$?
[ "$rc" -eq 0 ] || fail d "expected 0, got $rc"

# e. other tool -> 0
pre Bash implementer ag4 "$bad"; rc=$?
[ "$rc" -eq 0 ] || fail e "expected 0, got $rc"

# f. no agent_id -> 0
pre SubagentHandback implementer "" "$bad"; rc=$?
[ "$rc" -eq 0 ] || fail f "expected 0, got $rc"

# g. SubagentStop with a handback in the transcript, empty last message -> 0
jq -n --arg t "$fx/two-handbacks.jsonl" \
  '{hook_event_name:"SubagentStop", agent_type:"implementer", agent_id:"ag5", agent_transcript_path:$t, last_assistant_message:"", stop_hook_active:false}' \
  | bash "$hook" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail g "expected 0, got $rc"

# h. SubagentStop without a handback keeps blocking an empty report
jq -n --arg t "$fx/no-handback.jsonl" \
  '{hook_event_name:"SubagentStop", agent_type:"implementer", agent_id:"ag6", agent_transcript_path:$t, last_assistant_message:"", stop_hook_active:false}' \
  | bash "$hook" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] || fail h "expected 2, got $rc"

# i. agent_id with path traversal -> 0 and no file outside TMPDIR
outer=$(mktemp -d)
mkdir "$outer/t"
before=$(ls -A "$outer")
TMPDIR="$outer/t" pre SubagentHandback implementer "../x" "$bad"; rc=$?
[ "$rc" -eq 0 ] || fail i "expected 0, got $rc"
[ "$(ls -A "$outer")" = "$before" ] || fail i "file created outside TMPDIR"
[ -z "$(ls -A "$outer/t")" ] || fail i "marker created for invalid agent_id"
rm -rf "$outer"

[ "$fails" -eq 0 ] && echo "report check scenarios: all passed" || echo "report check scenarios: $fails failed"
[ "$fails" -eq 0 ]
