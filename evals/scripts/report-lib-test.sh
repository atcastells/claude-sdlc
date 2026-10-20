#!/bin/bash
# Scenarios for hooks/lib/report.sh (subagent_report) on synthetic transcripts.
# Exit 0 = every scenario behaved.
#   usage: report-lib-test.sh <path-to-report.sh> <fixtures-dir>
set -uo pipefail
lib="$1"; fx="$2"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0
fail() { echo "  FAIL $1: $2"; fails=$((fails+1)); }

. "$lib"

LAST="plain last message"
# report <transcript path> -> prints subagent_report output
report() {
  jq -n --arg t "$1" --arg m "$LAST" '{agent_transcript_path:$t, last_assistant_message:$m}' > "$tmp/payload.json"
  subagent_report "$(cat "$tmp/payload.json")"
}
want_handback=$'TASK: demo/T1\nRESULT: done\nDeviation cause: none'

# a. two handbacks -> the last one
out=$(report "$fx/two-handbacks.jsonl")
[ "$out" = "$want_handback" ] || fail a "got: $out"

# b. no handback -> last_assistant_message
out=$(report "$fx/no-handback.jsonl")
[ "$out" = "$LAST" ] || fail b "got: $out"

# c. missing transcript -> last_assistant_message
out=$(report "$tmp/does-not-exist.jsonl")
[ "$out" = "$LAST" ] || fail c "got: $out"

# d. transcript above 1.1 MB
pad=$(printf '%01000d' 0)
jq -nc --arg pad "$pad" '{type:"user", message:{role:"user", content:$pad}}' > "$tmp/one.jsonl"
: > "$tmp/big.jsonl"
i=0; while [ "$i" -lt 1200 ]; do cat "$tmp/one.jsonl" >> "$tmp/big.jsonl"; i=$((i+1)); done
cat "$fx/two-handbacks.jsonl" >> "$tmp/big.jsonl"
[ "$(wc -c < "$tmp/big.jsonl" | tr -d ' ')" -gt 1100000 ] || fail d "fixture not above 1.1 MB"
out=$(report "$tmp/big.jsonl")
[ "$out" = "$want_handback" ] || fail d "large transcript: got: ${out:0:80}"

# e. garbage line in the transcript
out=$(report "$fx/garbage.jsonl")
[ "$out" = "report after garbage" ] || fail e "got: $out"

# f. always returns 0, even with an empty payload
subagent_report '{}' >/dev/null || fail f "non-zero exit on empty payload"

[ "$fails" -eq 0 ] && echo "report lib scenarios: all passed" || echo "report lib scenarios: $fails failed"
[ "$fails" -eq 0 ]
