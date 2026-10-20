#!/bin/bash
# task-actuals: records the real minutes and tokens of a delegated plan task so
# calibrate.sh can compare them with the estimate. Playbook rule: actuals
# calibrate estimates, not people.
# One script, branches on hook_event_name:
#   SubagentStop: reads the subagent transcript, finds the tag
#     [sdlc:<slug>/<task> est=<min>m/<ktok>k] in the prompt and appends one JSON
#     line to .sdlc/<slug>/actuals.jsonl (only if that directory already exists).
#   PostToolUse: after an Edit/Write of .sdlc/<slug>/plan.md, measures the rows
#     whose "Runs on" is main: "in progress" appends a start line, "done" appends
#     the closing line (same schema) with minutes and tokens from the main
#     transcript between both timestamps. Other runners are ignored.
# Output tokens are not recorded: transcripts store usage at stream start.
# Never blocks and never prints: any missing or bad input exits 0 silently.

. "$(dirname "$0")/lib/report.sh"
. "$(dirname "$0")/lib/leak-patterns.sh"

payload=$(cat)
event=$(printf '%s' "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null)

# append_log <log> <lines> <agent_id>: appends under a mkdir lock. When the
# agent_id is already in the log, rewrites it first without that agent's lines
# (a report sent back stops the same subagent again). Silent; gives up after
# ~5 s without removing a lock that is not ours.
append_log() {
  local log="$1" lines="$2" aid="$3" lock="$1.lock" n=0 tmp
  while ! mkdir "$lock" 2>/dev/null; do
    # A lock older than a minute was left by a killed hook (timeout is 10 s)
    [ -n "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ] && rmdir "$lock" 2>/dev/null && continue
    n=$((n+1)); [ "$n" -ge 50 ] && return 0
    sleep 0.1
  done
  if [ -n "$aid" ] && [ -f "$log" ] && grep -qF -- "$aid" "$log" 2>/dev/null; then
    tmp=$(mktemp "$log.XXXXXX" 2>/dev/null)
    if [ -n "$tmp" ]; then
      if jq -R -r --arg id "$aid" '(try fromjson catch null) as $o
          | if ($o | type) == "object" and $o.agent_id == $id then empty else . end' \
          "$log" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$log" 2>/dev/null || rm -f "$tmp"
      else
        rm -f "$tmp"
      fi
    fi
  fi
  printf '%s\n' "$lines" >> "$log" 2>/dev/null
  rmdir "$lock" 2>/dev/null
  return 0
}

# machine_append <lines> <cwd> <agent_id>: the closing lines (not "start") plus
# "repo", in the machine-level log
machine_append() {
  local lines="$1" cwd="$2" aid="$3" mlog mdir mine
  mlog="${CLAUDE_SDLC_ACTUALS:-$HOME/.claude/actuals.jsonl}"
  mdir=$(dirname "$mlog")
  if [ ! -d "$mdir" ]; then
    [ "$mdir" = "$HOME/.claude" ] && return 0
    mkdir -p "$mdir" 2>/dev/null || return 0
  fi
  mine=$(printf '%s\n' "$lines" | jq -c --arg repo "$(basename "$cwd")" \
    'select(.event != "start") | . + {repo: $repo}' 2>/dev/null)
  [ -n "$mine" ] || return 0
  append_log "$mlog" "$mine" "$aid"
  return 0
}

subagent_stop() {
  local cwd agent aid tpath report out slug logf line
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
  aid=$(printf '%s' "$payload" | jq -r '.agent_id // empty' 2>/dev/null)
  agent=$(printf '%s' "$payload" | jq -r '.agent_type // empty' 2>/dev/null)
  tpath=$(printf '%s' "$payload" | jq -r '.agent_transcript_path // empty' 2>/dev/null)
  report=$(subagent_report "$payload")
  [ -n "$cwd" ] && [ -n "$tpath" ] && [ -r "$tpath" ] || return 0

  out=$(jq -Rn -c --arg agent "$agent" --arg report "$report" --argjson pats "$(leak_patterns_json)" '
    def ts: sub("\\.[0-9]+"; "") | fromdateiso8601;
    def r1: (. * 10 | round) / 10;
    def dev($a; $e): (($a - $e) / $e * 100 | round);
    def redact: reduce $pats[] as $p (.; gsub($p; "[redacted]"));
    [inputs | fromjson? | select(type == "object")] as $l
    | ([$l[] | select(.type == "user")] | first) as $u
    | ($u.message.content
       | if type == "string" then .
         elif type == "array" then [.[] | select(.type? == "text") | .text] | join("\n")
         else "" end) as $prompt
    | ($prompt | capture("\\[sdlc:(?<slug>[a-z0-9-]+)/(?<task>T[0-9]+[a-z]?) est=(?<m>[0-9]+(?:\\.[0-9]+)?)m/(?<k>[0-9]+(?:\\.[0-9]+)?)k\\]")) as $tag
    | ($tag.m | tonumber) as $em | ($tag.k | tonumber) as $ek
    | select($em > 0 and $ek > 0)
    | [$l[] | select(.timestamp? | type == "string") | .timestamp] as $t
    | ([$l[] | select(.type == "assistant" and (.message.id? | type == "string"))]
       | group_by(.message.id) | map(last)) as $msgs
    | ([$msgs[] | .message.usage | (.input_tokens // 0) + (.output_tokens // 0)
        + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)] | add // 0) as $tok
    | ((($t | last | ts) - ($t | first | ts)) / 60 | r1) as $min
    | (($tok / 1000) | round) as $ktok
    | dev($min; $em) as $dm | dev($ktok; $ek) as $dt
    | ($report | capture("Deviation cause:[ \t]*(?<c>[^\n]*)").c // ""
       | sub("^\\s+"; "") | sub("\\s+$"; "") | redact | .[0:200]) as $cause
    | {slug: $tag.slug,
       rec: {task: $tag.task, runs_on: $agent,
             model: ([$l[] | select(.type == "assistant") | .message.model? // empty] | first // ""),
             est_min: $em, est_ktok: $ek, min: $min, ktok: $ktok,
             dev_min_pct: $dm, dev_tok_pct: $dt,
             flag: (($dm | fabs) > 50 or ($dt | fabs) > 50), cause: $cause,
             date: ($t | last | .[0:10])}}
  ' "$tpath" 2>/dev/null) || return 0
  [ -n "$out" ] || return 0

  slug=$(printf '%s' "$out" | jq -r '.slug' 2>/dev/null)
  [ -n "$slug" ] && [ -d "$cwd/.sdlc/$slug" ] || return 0
  logf="$cwd/.sdlc/$slug/actuals.jsonl"
  line=$(printf '%s' "$out" | jq -c --arg id "$aid" '.rec + (if $id == "" then {} else {agent_id: $id} end)' 2>/dev/null) || return 0
  [ -n "$line" ] || return 0
  append_log "$logf" "$line" "$aid"
  machine_append "$line" "$cwd" "$aid"
  return 0
}

post_tool_use() {
  local cwd tool fpath tpath now logf lsrc tsrc out
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
  tool=$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null)
  fpath=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  tpath=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)
  case "$tool" in Edit|Write|MultiEdit) ;; *) return 0 ;; esac
  [ -n "$fpath" ] || return 0
  case "$fpath" in /*) ;; *) [ -n "$cwd" ] && fpath="$cwd/$fpath" || return 0 ;; esac
  printf '%s' "$fpath" | grep -Eq '/\.sdlc/[a-z0-9-]+/plan\.md$' || return 0
  [ -r "$fpath" ] && [ -n "$cwd" ] || return 0
  local rdir rcwd
  rdir=$(cd "$(dirname "$fpath")" 2>/dev/null && pwd -P) || return 0
  rcwd=$(cd "$cwd" 2>/dev/null && pwd -P) || return 0
  case "$rdir/" in "$rcwd"/*) ;; *) return 0 ;; esac
  now=${TASK_ACTUALS_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
  logf="$(dirname "$fpath")/actuals.jsonl"
  # --rawfile, not --arg: a main transcript is several MB, above ARG_MAX
  lsrc=/dev/null; [ -r "$logf" ] && lsrc="$logf"
  tsrc=/dev/null; [ -n "$tpath" ] && [ -r "$tpath" ] && tsrc="$tpath"

  out=$(jq -Rn -c --arg now "$now" --argjson pats "$(leak_patterns_json)" --rawfile log "$lsrc" --rawfile tr "$tsrc" '
    def ts: sub("\\.[0-9]+"; "") | fromdateiso8601;
    def r1: (. * 10 | round) / 10;
    def trim: sub("^\\s+"; "") | sub("\\s+$"; "");
    def redact: reduce $pats[] as $p (.; gsub($p; "[redacted]"));
    def cells: split("|") | .[1:-1] | map(trim);
    def dev($a; $e): (($a - $e) / $e * 100 | round);
    def cell($c; $i): if $i == null then "" else ($c[$i] // "") end;
    [inputs] as $lines
    | ($log | split("\n") | map(fromjson? | select(type == "object"))) as $recs
    | ($tr | split("\n") | map(fromjson? | select(type == "object"))) as $tl
    | ([$lines | to_entries[] | select(.value | contains("| # |"))] | first) as $h
    | select($h != null)
    | ($h.value | cells) as $hc
    | ($hc | index("Runs on")) as $ri | ($hc | index("Est")) as $ei | ($hc | index("Status")) as $si
    | select($ri != null and $si != null)
    | ($now | ts) as $n
    | $lines[($h.key + 1):][] | select(startswith("|"))
    | cells as $c
    | select(($c[0] // "") | test("^T[0-9]+[a-z]?$"))
    | $c[0] as $task
    | select(cell($c; $ri) | ascii_downcase | startswith("main"))
    | cell($c; $si) as $st
    | [$recs[] | select(.task == $task)] as $mine
    | ($mine | length > 0 and (last | .event? == "start")) as $open
    | ($mine | any(.[]; .event? != "start")) as $closed
    | if ($st | test("^in progress"; "i")) and ($open | not) and ($closed | not)
      then {task: $task, event: "start", ts: $now}
      elif ($st | test("^done"; "i")) and $open then
        ($mine | last | .ts | ts) as $s
        | (cell($c; $ei) | (capture("^(?<m>[0-9]+(?:\\.[0-9]+)?)m/(?<k>[0-9]+(?:\\.[0-9]+)?)(?<u>[kM])$") // null)) as $e
        | (if $e == null then null else ($e.m | tonumber) end) as $em
        | (if $e == null then null else ($e.k | tonumber) * (if $e.u == "M" then 1000 else 1 end) end) as $ek
        | [$tl[] | select(.type == "assistant"
            and ((.timestamp? | type) == "string")
            and ((try (.timestamp | ts) catch null) as $x | $x != null and $x >= $s and $x <= $n))] as $w
        | ([$w[] | select((.message.id? | type) == "string")] | group_by(.message.id) | map(last)) as $msgs
        | ([$msgs[] | .message.usage | (.input_tokens // 0) + (.output_tokens // 0)
            + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)] | add // 0) as $tok
        | ((($n - $s) / 60) | r1) as $min
        | (($tok / 1000) | round) as $ktok
        | (if $em != null and $em > 0 then dev($min; $em) else null end) as $dm
        | (if $ek != null and $ek > 0 then dev($ktok; $ek) else null end) as $dt
        | {task: $task, runs_on: "main",
           model: ([$w[] | .message.model? // empty] | first // ""),
           est_min: $em, est_ktok: $ek, min: $min, ktok: $ktok,
           dev_min_pct: $dm, dev_tok_pct: $dt,
           flag: ((($dm // 0) | fabs) > 50 or (($dt // 0) | fabs) > 50),
           cause: (($st | capture("cause:[ \t]*(?<c>.*)") // {c: ""}) | .c | trim | sub("\\)$"; "") | trim | redact | .[0:200]),
           date: $now[0:10]}
      else empty end
  ' "$fpath" 2>/dev/null) || return 0
  [ -n "$out" ] || return 0
  append_log "$logf" "$out" ""
  machine_append "$out" "$cwd" ""
  return 0
}

case "$event" in
  SubagentStop) subagent_stop ;;
  PostToolUse) post_tool_use ;;
  *) ;;
esac
exit 0
