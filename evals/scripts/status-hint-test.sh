#!/bin/bash
# Scenarios: status-line.sh plan and context hints, run in a throwaway git repo.
#   usage: status-hint-test.sh <root> <fixtures-dir> <scenario>
set -uo pipefail
root="$1"; fx="$2"; scen="$3"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }
repo="$tmp/repo"; mkdir -p "$repo/.sdlc/a"
git -C "$repo" init -q 2>/dev/null
t0=1793696400   # 2026-11-03T09:00:00Z, the T2 start line in the fixture
now=$((t0 + 4 * 60 + 30))
# run <pct>: the status line for the repo at that context percentage
run() {
  jq -n --arg d "$repo" --argjson p "$1" \
    '{model:{display_name:"Opus"},workspace:{current_dir:$d},context_window:{used_percentage:$p}}' |
    PLAN_HINT_NOW=$now bash "$root/status-line.sh" 2>/dev/null
}
has() { printf '%s' "$out" | grep -qaF -- "$1" || fail "$scen: output lacks '$1'"; }
lacks() { printf '%s' "$out" | grep -qaF -- "$1" && fail "$scen: output has '$1'"; }
open_plan() { cp "$fx/task-clock/.sdlc/a/plan.md" "$fx/task-clock/.sdlc/a/actuals.jsonl" "$repo/.sdlc/a/"; }
case "$scen" in
  open-task) open_plan; out=$(run 10); has "T2 4m/6m"; has "left"; has "1/3"; lacks "compact" ;;
  plan-only)
    printf '%s\n' '| # | Task | Est | Status |' '|---|---|---|---|' '| T1 | a | 4m/1k | done |' '| T2 | b | 5m/1k | pending |' > "$repo/.sdlc/a/plan.md"
    out=$(run 10); has "1/2"; has "~5m left"; lacks "T2" ;;
  ctx-69) open_plan; out=$(run 69); has "T2 4m/6m"; lacks "compact" ;;
  ctx-70) open_plan; out=$(run 70); has "compact between tasks" ;;
  ctx-90-noplan) out=$(run 90); has "compact between tasks"; lacks "left"; out=$(run 89); lacks "compact" ;;
  robust)
    printf 'garbage\n| not | a plan\n' > "$repo/.sdlc/a/plan.md"; out=$(run 10); lacks "left"
    rm "$repo/.sdlc/a/plan.md"; open_plan; cp "$repo/.sdlc/a/plan.md" "$tmp/real.md"
    rm "$repo/.sdlc/a/plan.md"; ln -s "$tmp/real.md" "$repo/.sdlc/a/plan.md"; out=$(run 10); lacks "left"
    rm "$repo/.sdlc/a/plan.md"; { cat "$tmp/real.md"; head -c 300000 /dev/zero | tr '\0' 'x'; } > "$repo/.sdlc/a/plan.md"
    out=$(run 10); lacks "left"; lacks "T2" ;;
  timing)
    open_plan; { sed -n 1,4p "$fx/task-clock/.sdlc/a/plan.md"; i=3; while [ $i -le 32 ]; do echo "| T$i | x | f | t | R1 | main | — | 4m/1k | pending |"; i=$((i+1)); done; } > "$repo/.sdlc/a/plan.md"
    s=$(date +%s); n=0; while [ $n -lt 10 ]; do run 10 >/dev/null; n=$((n+1)); done
    e=$(date +%s); echo "10 runs in $((e - s)) s"
    a=$(perl -MTime::HiRes=time -e 'print time'); run 10 >/dev/null; b=$(perl -MTime::HiRes=time -e 'print time')
    echo "one run: $(perl -e "printf '%d', ($b - $a) * 1000") ms" ;;
esac
if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
exit 1
