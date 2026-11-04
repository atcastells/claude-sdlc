#!/bin/bash
# Scenarios: hooks/lib/plan-hint.sh plan choice and parsing.
#   usage: plan-hint-test.sh <hooks-dir> <fixtures-dir> <scenario>
set -uo pipefail
hooks="$1"; fx="$2"; scen="$3"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }
# shellcheck disable=SC1091
. "$hooks/lib/plan-hint.sh" 2>/dev/null || { echo "  FAIL cannot source plan-hint.sh"; exit 1; }
repo="$tmp/repo"; cp -R "$fx/$scen" "$repo"
want() { [ "$PH_DONE/$PH_TOTAL/$PH_LEFT_MIN" = "$1" ] || fail "$scen: got $PH_DONE/$PH_TOTAL/$PH_LEFT_MIN want $1"; }
case "$scen" in
  two-open)
    touch -t 202401010000 "$repo/.sdlc/new/plan.md"; touch -t 202501010000 "$repo/.sdlc/old/plan.md"
    plan_hint "$repo" || fail "rc"; want 1/2/5; [ "$PH_PLAN" = "$repo/.sdlc/old/plan.md" ] || fail "old should win"
    touch -t 202601010000 "$repo/.sdlc/new/plan.md"
    plan_hint "$repo" || fail "rc"; want 1/3/10; [ "$PH_PLAN" = "$repo/.sdlc/new/plan.md" ] || fail "new should win" ;;
  all-done) plan_hint "$repo" && fail "expected rc 1" ;;
  bad-est) plan_hint "$repo" || fail "rc"; want 1/4/12 ;;
  extra-cols)
    plan_hint "$repo" || fail "rc"; want 1/3/9
    ln -s "$repo/.sdlc/a/plan.md" "$tmp/l"; rm "$repo/.sdlc/a/plan.md"; mv "$tmp/l" "$repo/.sdlc/a/plan.md"
    plan_hint "$repo" && fail "symlink should be skipped" ;;
  task-clock)
    # start at 2026-11-03T09:00:00Z = 1793696400
    t0=1793696400
    chk() { PLAN_HINT_NOW=$((t0 + $1 * 60 + 30)) plan_hint "$repo" || fail "rc"
      [ "$PH_TASK/$PH_EST/$PH_ELAPSED/$PH_LEVEL" = "$2" ] || fail "$scen $1m: got $PH_TASK/$PH_EST/$PH_ELAPSED/$PH_LEVEL want $2"; }
    chk 4 T2/6/4/ok; chk 6 T2/6/6/ok; chk 7 T2/6/7/over; chk 12 T2/6/12/over; chk 13 T2/6/13/way
    ln -s "$repo/.sdlc/a/plan.md" "$tmp/l"; rm "$repo/.sdlc/a/actuals.jsonl"; mv "$tmp/l" "$repo/.sdlc/a/actuals.jsonl"
    PLAN_HINT_NOW=$((t0 + 780)) plan_hint "$repo" || fail "rc"
    [ -z "$PH_ELAPSED" ] && [ "$PH_LEVEL" = ok ] || fail "symlinked actuals should be ignored" ;;
  octal)
    # 08m must read as 8, not as invalid octal
    cp -R "$fx/task-clock" "$repo"
    perl -pi -e 's{\| 6m/300k \|}{| 08m/300k |}' "$repo/.sdlc/a/plan.md"
    # In a child shell: a bash arithmetic error aborts the caller, so check its output
    got=$(PLAN_HINT_NOW=$((1793696400 + 20 * 60)) bash -c '. "$1/lib/plan-hint.sh"; plan_hint "$2" && echo "$PH_TASK/$PH_EST/$PH_ELAPSED/$PH_LEVEL"' _ "$hooks" "$repo" 2>"$tmp/err")
    [ "$got" = "T2/8/20/way" ] || fail "octal: got '$got' want T2/8/20/way"
    [ ! -s "$tmp/err" ] || fail "octal: stderr not empty: $(cat "$tmp/err")" ;;
  short-row)
    # A short row must not inherit the previous row's cells; a row without a trailing pipe still counts
    mkdir -p "$repo/.sdlc/a"
    printf '%s\n' '| # | Task | Est | Status |' '|---|---|---|---|' '| T1 | a | 5m/1k | done |' '| T2 | b |' \
      '| T3 | c | 7m/1k | pending' > "$repo/.sdlc/a/plan.md"
    plan_hint "$repo" || fail "rc"; want 1/3/7 ;;
  huge-est)
    mkdir -p "$repo/.sdlc/a"
    printf '%s\n' '| # | Est | Status |' '|---|---|---|' '| T1 | 99999999999999999999m | in progress |' '| T2 | 4m | pending |' > "$repo/.sdlc/a/plan.md"
    plan_hint "$repo" || fail "rc"; want 0/2/4; [ -z "$PH_EST" ] || fail "huge-est: est should be empty, got $PH_EST" ;;
  long-line)
    # A 250 KB line must not stall the parse (quadratic cell split)
    mkdir -p "$repo/.sdlc/a"
    { printf '| '; head -c 250000 /dev/zero | tr '\0' a; printf '\n'
      printf '%s\n' '| # | Est | Status |' '|---|---|---|' '| T1 | 3m | pending |'; } > "$repo/.sdlc/a/plan.md"
    s0=$(date +%s); plan_hint "$repo" || fail "rc"; s1=$(date +%s)
    want 0/1/3; [ $((s1 - s0)) -le 1 ] || fail "long-line: took $((s1 - s0)) s" ;;
  task-closed|task-nostart)
    plan_hint "$repo" || fail "rc"
    [ "$PH_TASK/$PH_EST" = "T2/6" ] || fail "$scen: got $PH_TASK/$PH_EST want T2/6"
    [ -z "$PH_ELAPSED" ] || fail "$scen: elapsed should be empty, got $PH_ELAPSED"
    [ "$PH_LEVEL" = ok ] || fail "$scen: level $PH_LEVEL" ;;
esac
if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
exit 1
