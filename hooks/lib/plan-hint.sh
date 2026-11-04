#!/bin/bash
# Sourced by status-line.sh. Never exits, never prints.
#   plan_hint <repo_root>  -> 0 and sets PH_PLAN PH_DONE PH_TOTAL PH_LEFT_MIN
#                             and PH_TASK PH_EST PH_ELAPSED PH_LEVEL (ok|over|way)
#                             1 when there is no open, usable plan.

# One awk pass over a plan: prints "done total left_min task est" ("-" = none), or nothing if unusable.
# Cells are split on '|' outside backticks; columns are found by header name.
_plan_hint_parse() {
  awk '
    function split_cells(line,   i, c, n, inbt, cur) {
      split("", cell); ncell = 0; inbt = 0; cur = ""
      line = substr(line, 2)
      for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (c == "`") inbt = !inbt
        if (c == "|" && !inbt) { cell[++ncell] = cur; cur = "" } else cur = cur c
      }
      # A row without a trailing pipe still has its last cell
      if (cur ~ /[^ \t\r]/) cell[++ncell] = cur
      for (i = 1; i <= ncell; i++) gsub(/^[ \t\r]+|[ \t\r]+$/, "", cell[i])
    }
    # Character-by-character split is quadratic: table lines are short, skip long ones
    length($0) > 2048 { next }
    /^\|/ {
      if (!ok && !hdr) {
        split_cells($0)
        for (i = 1; i <= ncell; i++) { if (cell[i] == "Est") ce = i; if (cell[i] == "Status") cs = i }
        if (ce && cs) hdr = 1; else ce = cs = 0
        next
      }
      if (hdr && $0 ~ /^\| *T[0-9]/) {
        split_cells($0); total++
        # Minutes as a plain decimal (08m -> 8); more than 5 digits is not an estimate
        em = match(cell[ce], /^[0-9]+m/) ? substr(cell[ce], 1, RLENGTH - 1) : ""
        if (length(em) > 5) em = ""; else if (em != "") em = em + 0
        if (tolower(cell[cs]) ~ /^done/) done++
        else if (em != "") left += em
        if (tid == "" && tolower(cell[cs]) ~ /^in progress/ && cell[1] ~ /^T[0-9]+$/) { tid = cell[1]; test = em }
      }
      next
    }
    hdr { exit }
    END { if (hdr && total) print done + 0, total, left + 0, (tid == "" ? "-" : tid), (test == "" ? "-" : test) }
  ' "$1" 2>/dev/null
}

# Whole minutes since the open start line of task $2 in actuals file $1, or nothing.
_plan_hint_elapsed() {
  local f="$1" now="${PLAN_HINT_NOW:-}"
  [ -f "$f" ] && [ ! -L "$f" ] || return 0
  [ "$(wc -c < "$f" 2>/dev/null || echo 999999)" -le 262144 ] || return 0
  case "$now" in ''|*[!0-9]*) now=$(date +%s) ;; esac
  jq -Rrn --arg id "$2" --argjson now "$now" '
    [inputs | fromjson? | select(type == "object" and .task == $id)] | last
    | select(.event == "start") | (.ts | fromdateiso8601?) as $t
    | select($t != null) | ([($now - $t) / 60 | floor, 0] | max)' "$f" 2>/dev/null
}

plan_hint() {
  local root="$1" f out best="" best_out="" d t l tk es el
  [ -d "$root/.sdlc" ] || return 1
  for f in "$root"/.sdlc/*/plan.md; do
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    [ "$(wc -c < "$f" 2>/dev/null || echo 999999)" -le 262144 ] || continue
    [ -z "$best" ] || [ "$f" -nt "$best" ] || continue
    out=$(_plan_hint_parse "$f")
    [ -n "$out" ] || continue
    set -- $out; d=$1 t=$2 l=$3
    [ "$d" -lt "$t" ] || continue
    best="$f"; best_out="$out"
  done
  [ -n "$best" ] || return 1
  set -- $best_out
  PH_PLAN="$best" PH_DONE=$1 PH_TOTAL=$2 PH_LEFT_MIN=$3
  tk=${4:--} es=${5:--}
  PH_TASK="" PH_EST="" PH_ELAPSED="" PH_LEVEL=ok
  [ "$tk" = - ] || PH_TASK=$tk
  [ "$es" = - ] || PH_EST=$es
  if [ -n "$PH_TASK" ]; then
    el=$(_plan_hint_elapsed "${best%/*}/actuals.jsonl" "$PH_TASK")
    case "$el" in ''|*[!0-9]*) ;; *) PH_ELAPSED=$el ;; esac
  fi
  if [ -n "$PH_ELAPSED" ] && [ -n "$PH_EST" ]; then
    if [ "$PH_ELAPSED" -gt $((2 * PH_EST)) ]; then PH_LEVEL=way
    elif [ "$PH_ELAPSED" -gt "$PH_EST" ]; then PH_LEVEL=over; fi
  fi
  return 0
}
