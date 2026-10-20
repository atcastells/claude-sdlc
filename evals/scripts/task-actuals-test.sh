#!/bin/bash
# Scenarios for hooks/task-actuals.sh (SubagentStop branch) on throwaway
# workspaces with synthetic transcripts. Exit 0 = every scenario behaved.
#   usage: task-actuals-test.sh <path-to-task-actuals.sh> <fixtures-dir>
set -uo pipefail
hook="$1"; fx="$2"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export CLAUDE_SDLC_ACTUALS="$tmp/machine.jsonl"
fails=0
fail() { echo "  FAIL $1: $2"; fails=$((fails+1)); }

# run <name> <fixture|-> <with_sdlc_dir 1|0> [transcript_override] -> sets $ws, $rc
run() {
  local name="$1" fixture="$2" withdir="$3" tpath="${4:-}"
  ws="$tmp/$name"; mkdir -p "$ws"
  [ "$withdir" = 1 ] && mkdir -p "$ws/.sdlc/demo"
  [ "$fixture" != - ] && cp "$fx/$fixture" "$ws/transcript.jsonl"
  [ -n "$tpath" ] || tpath="$ws/transcript.jsonl"
  jq -n --arg cwd "$ws" --arg t "$tpath" \
    '{hook_event_name:"SubagentStop", cwd:$cwd, agent_type:"general-purpose", agent_transcript_path:$t,
      last_assistant_message:"Done.\nDeviation cause: extra fixtures were needed  \nNotes: none"}' \
    | bash "$hook" > "$ws/stdout" 2> "$ws/stderr"
  rc=$?
  [ "$rc" = 0 ] || fail "$name" "exit $rc, expected 0"
  [ -s "$ws/stdout" ] && fail "$name" "wrote to stdout"
  return 0
}

# a. tagged transcript with duplicated message ids
run a tagged.jsonl 1
f="$ws/.sdlc/demo/actuals.jsonl"
if [ ! -f "$f" ] || [ "$(wc -l < "$f" | tr -d ' ')" != 1 ]; then
  fail a "expected exactly one line in actuals.jsonl"
else
  jq -e '.task=="T4" and .runs_on=="general-purpose" and .model=="model-x"
    and .est_min==5 and .est_ktok==400 and .min==7.5 and .ktok==401
    and .dev_min_pct==50 and .dev_tok_pct==0 and .flag==false
    and .cause=="extra fixtures were needed" and .date=="2026-10-14"' "$f" >/dev/null \
    || fail a "unexpected record: $(cat "$f")"
fi

# b. over 50 percent in minutes
run b over.jsonl 1
f="$ws/.sdlc/demo/actuals.jsonl"
jq -e '.min==10 and .dev_min_pct==150 and .flag==true' "$f" >/dev/null 2>&1 \
  || fail b "expected flag true: $(cat "$f" 2>/dev/null)"

# c. untagged
run c untagged.jsonl 1
[ -e "$ws/.sdlc/demo/actuals.jsonl" ] && fail c "wrote actuals for an untagged transcript"

# d. tagged, slug directory missing
run d tagged.jsonl 0
[ -e "$ws/.sdlc" ] && fail d "created .sdlc"

# e. transcript path does not exist
run e - 1 "$tmp/does-not-exist.jsonl"
[ -e "$ws/.sdlc/demo/actuals.jsonl" ] && fail e "wrote actuals without a transcript"

# f. content as array of text blocks
run f blocks.jsonl 1
f="$ws/.sdlc/demo/actuals.jsonl"
jq -e '.task=="T4" and .est_min==5' "$f" >/dev/null 2>&1 || fail f "tag in text blocks not found"

# g. unknown event is ignored
ws="$tmp/g"; mkdir -p "$ws/.sdlc/demo"
jq -n --arg cwd "$ws" '{hook_event_name:"Other", cwd:$cwd}' | bash "$hook" >/dev/null 2>&1 \
  || fail g "unknown event did not exit 0"

# PostToolUse branch (main-session rows). Fixtures in <fixtures>/../actuals-main.
mx="$(dirname "$fx")/actuals-main"
# post <name> <plan fixture> <now> [file path override] -> sets $ws, $pf, $lg; keeps ws per name
post() {
  local name="$1" fixture="$2" now="$3" fp="${4:-}"
  ws="$tmp/$name"; mkdir -p "$ws/.sdlc/demo"
  pf="$ws/.sdlc/demo/plan.md"; lg="$ws/.sdlc/demo/actuals.jsonl"
  cp "$mx/$fixture" "$pf"; cp "$mx/main-transcript.jsonl" "$ws/transcript.jsonl"
  [ -n "$fp" ] || fp="$pf"
  jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg f "$fp" \
    '{hook_event_name:"PostToolUse", cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}, transcript_path:$t}' \
    | TASK_ACTUALS_NOW="$now" bash "$hook" > "$ws/stdout" 2> "$ws/stderr"
  rc=$?
  [ "$rc" = 0 ] || fail "$name" "exit $rc, expected 0"
  [ -s "$ws/stdout" ] && fail "$name" "wrote to stdout"
  return 0
}
lines() { [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }
T0=2026-10-20T10:00:00Z; T1=2026-10-20T10:06:00Z

# h. main row in progress -> one start line
post h plan-progress.md "$T0"
[ "$(lines "$lg")" = 1 ] && jq -e --arg t "$T0" '.task=="T2" and .event=="start" and .ts==$t' "$lg" >/dev/null \
  || fail h "expected one start line: $(cat "$lg" 2>/dev/null)"
post h plan-progress.md "$T0"
[ "$(lines "$lg")" = 1 ] || fail h "second edit duplicated the start line"

# i. then done, 6 minutes later
cp "$mx/plan-done.md" "$pf"
jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg f "$pf" \
  '{hook_event_name:"PostToolUse", cwd:$cwd, tool_name:"Write", tool_input:{file_path:$f}, transcript_path:$t}' \
  | TASK_ACTUALS_NOW="$T1" bash "$hook" > "$ws/stdout" 2>&1
[ -s "$ws/stdout" ] && fail i "wrote to stdout"
[ "$(lines "$lg")" = 2 ] && tail -n 1 "$lg" | jq -e '.task=="T2" and .runs_on=="main" and .model=="model-main"
  and .est_min==5 and .est_ktok==400 and .min==6 and .ktok==3
  and .dev_min_pct==20 and .dev_tok_pct==-99 and .flag==true
  and .cause=="spec was ambiguous" and .date=="2026-10-20" and (has("out_ktok")|not)' >/dev/null \
  || fail i "unexpected closing line: $(cat "$lg" 2>/dev/null)"

# j. second edit with the row still done
cp "$mx/plan-done.md" "$pf"
jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg f "$pf" \
  '{hook_event_name:"PostToolUse", cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}, transcript_path:$t}' \
  | TASK_ACTUALS_NOW="2026-10-20T10:20:00Z" bash "$hook" > "$ws/stdout" 2>&1; rc=$?
[ "$rc" = 0 ] && [ ! -s "$ws/stdout" ] || fail j "exit $rc or stdout"
[ "$(lines "$lg")" = 2 ] || fail j "duplicate line on a later edit"

# k. implementer rows are measured by SubagentStop, not here
post k plan-impl-progress.md "$T0"
post k plan-impl-done.md "$T1"
[ -e "$lg" ] && fail k "wrote a line for an implementer row"

# l. not a .sdlc/<slug>/plan.md
mkdir -p "$tmp/l/docs"; cp "$mx/plan-progress.md" "$tmp/l/docs/plan.md"
post l plan-progress.md "$T0" "$tmp/l/docs/plan.md"
[ -e "$lg" ] && fail l "wrote actuals for a file outside .sdlc/<slug>/plan.md"

# m. no Runs on column
post m plan-no-runson.md "$T0"
[ -e "$lg" ] && fail m "wrote actuals without a Runs on column"

# n. Est in millions of tokens
post n plan-bigest-progress.md "$T0"
cp "$mx/plan-bigest-done.md" "$pf"
jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg f "$pf" \
  '{hook_event_name:"PostToolUse", cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}, transcript_path:$t}' \
  | TASK_ACTUALS_NOW="$T1" bash "$hook" > "$ws/stdout" 2>&1
tail -n 1 "$lg" | jq -e '.est_min==15 and .est_ktok==2000 and .cause==""' >/dev/null \
  || fail n "expected est_ktok 2000: $(cat "$lg" 2>/dev/null)"

# p. the same subagent stops twice (report sent back once): one line, the last one
ws="$tmp/p"; mkdir -p "$ws/.sdlc/demo"; cp "$fx/tagged.jsonl" "$ws/transcript.jsonl"
for c in partial final; do
  jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg c "$c" \
    '{hook_event_name:"SubagentStop", cwd:$cwd, agent_type:"implementer", agent_id:"agent-p1",
      agent_transcript_path:$t, last_assistant_message:("Deviation cause: " + $c)}' \
    | bash "$hook" >/dev/null 2>&1
done
jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" \
  '{hook_event_name:"SubagentStop", cwd:$cwd, agent_type:"implementer", agent_id:"agent-p2",
    agent_transcript_path:$t, last_assistant_message:"Deviation cause: retry"}' \
  | bash "$hook" >/dev/null 2>&1
f="$ws/.sdlc/demo/actuals.jsonl"
[ "$(lines "$f")" = 2 ] && jq -s -e '.[0].agent_id=="agent-p1" and .[0].cause=="final" and .[1].cause=="retry"' "$f" >/dev/null \
  || fail p "expected one line per subagent, the last stop winning: $(cat "$f" 2>/dev/null)"

# o. a real main transcript is several MB: above ARG_MAX it must still be read
post o plan-progress.md "$T0"
pad=$(printf '%01000d' 0)
jq -c --arg pad "$pad" '. + {pad: $pad}' "$mx/main-transcript.jsonl" > "$ws/one.jsonl"
: > "$ws/transcript.jsonl"
i=0; while [ "$i" -lt 400 ]; do cat "$ws/one.jsonl" >> "$ws/transcript.jsonl"; i=$((i+1)); done
cp "$mx/plan-done.md" "$pf"
jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg f "$pf" \
  '{hook_event_name:"PostToolUse", cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}, transcript_path:$t}' \
  | TASK_ACTUALS_NOW="$T1" bash "$hook" > "$ws/stdout" 2>&1
[ "$(wc -c < "$ws/transcript.jsonl" | tr -d ' ')" -gt 1100000 ] || fail o "fixture not above 1.1 MB"
[ "$(lines "$lg")" = 2 ] && tail -n 1 "$lg" | jq -e '.min==6 and .ktok==3' >/dev/null \
  || fail o "large transcript not measured: $(cat "$lg" 2>/dev/null)"

# q. handback transcript: cause comes from the SubagentHandback message
ws="$tmp/q"; mkdir -p "$ws/.sdlc/demo"; cp "$fx/tagged.jsonl" "$ws/transcript.jsonl"
jq -n -c '{type:"assistant", timestamp:"2026-10-14T10:07:31.000Z", message:{id:"msg_h", content:[{type:"tool_use", name:"SubagentHandback", input:{message:"TASK: demo/T4\nRESULT: done\nDeviation cause: slow fixture\n"}}]}}' >> "$ws/transcript.jsonl"
jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" \
  '{hook_event_name:"SubagentStop", cwd:$cwd, agent_type:"implementer", agent_id:"agent-q",
    agent_transcript_path:$t, last_assistant_message:""}' | bash "$hook" >/dev/null 2>&1
f="$ws/.sdlc/demo/actuals.jsonl"
jq -e '.cause=="slow fixture"' "$f" >/dev/null 2>&1 || fail q "cause not taken from the handback: $(cat "$f" 2>/dev/null)"

# r. machine log: one closing line with repo, only there; repeat stop keeps one in each
M="$CLAUDE_SDLC_ACTUALS"
rm -f "$M"
ws="$tmp/r"; mkdir -p "$ws/.sdlc/demo"; cp "$fx/tagged.jsonl" "$ws/transcript.jsonl"
for c in first second; do
  jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg c "$c" \
    '{hook_event_name:"SubagentStop", cwd:$cwd, agent_type:"implementer", agent_id:"agent-r",
      agent_transcript_path:$t, last_assistant_message:("Deviation cause: " + $c)}' | bash "$hook" >/dev/null 2>&1
done
f="$ws/.sdlc/demo/actuals.jsonl"
[ "$(lines "$f")" = 1 ] && [ "$(lines "$M")" = 1 ] \
  && jq -e '.cause=="second" and (has("repo")|not)' "$f" >/dev/null \
  && jq -e '.cause=="second" and .repo=="r" and .agent_id=="agent-r" and .task=="T4"' "$M" >/dev/null \
  || fail r "expected one line in each log, repo only in the machine log: $(cat "$f" 2>/dev/null) / $(cat "$M" 2>/dev/null)"

# s. main start line goes only to the repo log; the closing line to both
rm -f "$M"
post s plan-progress.md "$T0"
[ "$(lines "$lg")" = 1 ] && [ ! -s "$M" ] || fail s "start line must not reach the machine log"
cp "$mx/plan-done.md" "$pf"
jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg f "$pf" \
  '{hook_event_name:"PostToolUse", cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}, transcript_path:$t}' \
  | TASK_ACTUALS_NOW="$T1" bash "$hook" >/dev/null 2>&1
[ "$(lines "$M")" = 1 ] && jq -e '.task=="T2" and .runs_on=="main" and .repo=="s" and .cause=="spec was ambiguous"' "$M" >/dev/null \
  || fail s "closing line missing from the machine log: $(cat "$M" 2>/dev/null)"

# t. notes in the Status cell are not a cause
post t plan-progress.md "$T0"
cp "$mx/plan-done-notes.md" "$pf"
jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg f "$pf" \
  '{hook_event_name:"PostToolUse", cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}, transcript_path:$t}' \
  | TASK_ACTUALS_NOW="$T1" bash "$hook" >/dev/null 2>&1
tail -n 1 "$lg" | jq -e '.event? == null and .cause==""' >/dev/null \
  || fail t "expected empty cause: $(cat "$lg" 2>/dev/null)"

# z. a lock left by a killed hook (older than a minute) does not block forever
ws="$tmp/z"; mkdir -p "$ws/.sdlc/demo"; cp "$fx/tagged.jsonl" "$ws/transcript.jsonl"
mkdir "$ws/.sdlc/demo/actuals.jsonl.lock"; touch -t 202001010000 "$ws/.sdlc/demo/actuals.jsonl.lock"
jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" \
  '{hook_event_name:"SubagentStop", cwd:$cwd, agent_type:"implementer", agent_id:"agent-z",
    agent_transcript_path:$t, last_assistant_message:"Deviation cause: none"}' \
  | bash "$hook" > "$ws/stdout" 2>&1
[ "$(lines "$ws/.sdlc/demo/actuals.jsonl")" = 1 ] && [ ! -e "$ws/.sdlc/demo/actuals.jsonl.lock" ] && [ ! -s "$ws/stdout" ] \
  || fail z "stale lock blocked the write or was left behind"

# u. a cause with parentheses inside is kept whole
post u plan-progress.md "$T0"
cp "$mx/plan-done-parens.md" "$pf"
jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg f "$pf" \
  '{hook_event_name:"PostToolUse", cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}, transcript_path:$t}' \
  | TASK_ACTUALS_NOW="$T1" bash "$hook" >/dev/null 2>&1
tail -n 1 "$lg" | jq -e '.cause=="fixed foo() twice"' >/dev/null \
  || fail u "expected the whole cause: $(cat "$lg" 2>/dev/null)"

# v. credentials in the cause are redacted in both logs (inputs built at runtime)
rm -f "$M"
ws="$tmp/v"; mkdir -p "$ws/.sdlc/demo"; cp "$fx/tagged.jsonl" "$ws/transcript.jsonl"
tok=$(printf 'squ_%040d' 0); url='postgres://u:p@h/db'
jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg c "Deviation cause: used $tok and $url today" \
  '{hook_event_name:"SubagentStop", cwd:$cwd, agent_type:"implementer", agent_id:"agent-v",
    agent_transcript_path:$t, last_assistant_message:$c}' | bash "$hook" >/dev/null 2>&1
for f in "$ws/.sdlc/demo/actuals.jsonl" "$M"; do
  if grep -qF "$tok" "$f" 2>/dev/null || grep -qF 'u:p@' "$f" 2>/dev/null \
     || [ "$(jq -r '.cause' "$f" 2>/dev/null | grep -o '\[redacted\]' | wc -l | tr -d ' ')" != 2 ]; then
    fail v "cause not redacted in $f: $(cat "$f" 2>/dev/null)"
  fi
done
# v2. same through the main row's cause
post v2 plan-progress.md "$T0"
sed "s|spec was ambiguous|used $tok|" "$mx/plan-done.md" > "$pf"
rm -f "$M"
jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg f "$pf" \
  '{hook_event_name:"PostToolUse", cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}, transcript_path:$t}' \
  | TASK_ACTUALS_NOW="$T1" bash "$hook" >/dev/null 2>&1
if grep -qF "$tok" "$lg" "$M" 2>/dev/null || ! tail -n 1 "$lg" | jq -e '.cause|test("redacted")' >/dev/null 2>&1; then
  fail v2 "main cause not redacted: $(cat "$lg" 2>/dev/null)"
fi

# w. 12 concurrent stops with distinct agent_id against a repo log with 1 line (3 rounds)
for round in 1 2 3; do
  rm -f "$M"
  ws="$tmp/w$round"; mkdir -p "$ws/.sdlc/demo"; cp "$fx/tagged.jsonl" "$ws/transcript.jsonl"
  echo '{"task":"T0","agent_id":"seed"}' > "$ws/.sdlc/demo/actuals.jsonl"
  for n in 1 2 3 4 5 6 7 8 9 10 11 12; do
    jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg id "agent-w$n" \
      '{hook_event_name:"SubagentStop", cwd:$cwd, agent_type:"implementer", agent_id:$id,
        agent_transcript_path:$t, last_assistant_message:"Deviation cause: x"}' \
      | bash "$hook" >/dev/null 2> "$ws/err$n" &
  done
  wait
  [ "$(lines "$ws/.sdlc/demo/actuals.jsonl")" = 13 ] && [ "$(lines "$M")" = 12 ] \
    || fail w "round $round: expected 13/12 lines, got $(lines "$ws/.sdlc/demo/actuals.jsonl")/$(lines "$M")"
  [ -z "$(cat "$ws"/err* 2>/dev/null)" ] || fail w "round $round: stderr not empty"
  [ ! -e "$ws/.sdlc/demo/actuals.jsonl.lock" ] && [ ! -e "$M.lock" ] || fail w "round $round: lock left behind"
done

# x. one edit closes T2 and starts T3: T2 closing line in the machine log, no start line there
rm -f "$M"
post x plan-progress.md "$T0"
sed 's/| T3 \(.*\)| pending |/| T3 \1| in progress |/' "$mx/plan-done.md" > "$pf"
jq -n --arg cwd "$ws" --arg t "$ws/transcript.jsonl" --arg f "$pf" \
  '{hook_event_name:"PostToolUse", cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}, transcript_path:$t}' \
  | TASK_ACTUALS_NOW="$T1" bash "$hook" >/dev/null 2>&1
[ "$(lines "$lg")" = 3 ] && [ "$(lines "$M")" = 1 ] && jq -e '.task=="T2" and .event==null' "$M" >/dev/null \
  && ! grep -q '"event"' "$M" || fail x "expected T2 closing only in the machine log: $(cat "$M" 2>/dev/null)"

# y. plan.md outside cwd: nothing written
rm -f "$M"
post y plan-progress.md "$T0"; rm -f "$lg"
ws2="$tmp/y-other"; mkdir -p "$ws2"
jq -n --arg cwd "$ws2" --arg t "$ws/transcript.jsonl" --arg f "$pf" \
  '{hook_event_name:"PostToolUse", cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}, transcript_path:$t}' \
  | TASK_ACTUALS_NOW="$T0" bash "$hook" >/dev/null 2>&1
[ -e "$lg" ] || [ -e "$M" ] && fail y "wrote actuals for a plan outside cwd"

[ "$fails" -eq 0 ] && echo "task-actuals scenarios: all passed" || echo "task-actuals scenarios: $fails failed"
[ "$fails" -eq 0 ]
