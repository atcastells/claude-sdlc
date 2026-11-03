#!/bin/bash
# Scenarios for the install-verification notice in hooks/workflow-version-check.sh.
# Result files are built with jq in a temp WORKFLOW_HOME. Exit 0 = all behaved.
#   usage: install-verify-notice-test.sh <path-to-workflow-version-check.sh>
set -uo pipefail
hook="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0
fail() { echo "  FAIL $1: $2"; fails=$((fails+1)); }
mkdir -p "$tmp/proj"

# mk <name> -> sets $wh with a VERSION 2.6.0
mk() { wh="$tmp/$1"; mkdir -p "$wh"; echo 2.6.0 > "$wh/VERSION"; }
# res <status> <version> <started> <failed-json>
res() {
  jq -n --arg st "$1" --arg v "$2" --arg s "$3" --argjson f "$4" \
    '{version:$v, started:$s, finished:null, status:$st, pass:10, fail:($f|length), failed:$f}' > "$wh/install-verify.json"
}
run() {
  out=$(jq -n --arg cwd "$tmp/proj" '{hook_event_name:"SessionStart", cwd:$cwd, source:"startup"}' \
    | WORKFLOW_HOME="$wh" WORKFLOW_SOURCE="" bash "$hook" 2>/dev/null)
  rc=$?
  [ "$rc" = 0 ] || fail "$1" "exit $rc, expected 0"
  ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
}
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ago() { date -u -v-"$1"M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "$1 minutes ago" +%Y-%m-%dT%H:%M:%SZ; }
case_json() { jq -n --arg n "$1" --arg k "$2" --arg f "$3" --arg d "$4" --arg h "${5:-}" '{name:$n, kind:$k, file:$f, detail:$d, hook:$h}'; }

# a. red mixed -> both groups, guard hook blocking
mk a; echo /opt/sdlc-src > "$wh/source"
f=$(jq -s '.' <(case_json hook-x hook "" "boom hook" credential-guard.sh) <(case_json tmpl-y file_contains templates/REVIEW.md "missing text") <(case_json cfg-z file_contains settings.json "no key"))
res red 2.6.0 "$now" "$f"; run a
case "$ctx" in "claude-sdlc: install verification of 2.6.0 failed 3 cases."*) ;; *) fail a "header: $ctx";; esac
case "$ctx" in *"Protection not active (tell the user now): credential-guard.sh — hook-x: boom hook. Action: bash /opt/sdlc-src/install.sh; if it persists, tell the workflow maintainer."*) ;; *) fail a "blocking group: $ctx";; esac
case "$ctx" in *"Not blocking (do not interrupt; mention in one line under Found at the end of the run): "*"tmpl-y (file_contains): missing text"*"cfg-z (file_contains): no key"*) ;; *) fail a "not-blocking group: $ctx";; esac
case "$ctx" in *"Blocking"*|*"Can wait"*) fail a "old wording: $ctx";; esac
case "$ctx" in *"Re-check: bash ~/.claude/evals/run.sh"*"install-verify.log"*) ;; *) fail a "commands: $ctx";; esac
case "$ctx" in *"tmpl-y"*"credential-guard.sh"*) fail a "tmpl-y listed before blocking";; esac

# a2. only non-blocking (workflow-version-check hook, file_contains) -> no protection text
mk a2; res red 2.6.0 "$now" "$(jq -s '.' <(case_json c1 hook "" d workflow-version-check.sh) <(case_json c2 file_contains settings.json d))"; run a2
case "$ctx" in *"Protection not active"*|*"Blocking"*) fail a2 "unexpected blocking: $ctx";; esac
case "$ctx" in *"do not interrupt"*"Found"*) ;; *) fail a2 "not-blocking text: $ctx";; esac

# a3. missing source file -> fallback text; missing hook key -> not blocking
mk a3; res red 2.6.0 "$now" "$(jq -s '.' <(case_json g1 hook "" d test-guard.sh))"; run a3
case "$ctx" in *"test-guard.sh — g1: d. Action: ./install.sh in the claude-sdlc repo; if it persists, tell the workflow maintainer."*) ;; *) fail a3 "fallback: $ctx";; esac
mk a4; res red 2.6.0 "$now" "$(jq -n '[{name:"n",kind:"hook",file:"",detail:"d"}]')"; run a4
case "$ctx" in *"Protection not active"*) fail a4 "missing hook treated as blocking";; esac

# a5. production-gate counts too
mk a5; echo /s > "$wh/source"; res red 2.6.0 "$now" "$(jq -s '.' <(case_json p1 hook "" d production-gate.sh))"; run a5
case "$ctx" in *"production-gate.sh — p1: d"*) ;; *) fail a5 "production-gate: $ctx";; esac

# b. green / running recent / other version -> silent
mk b; res green 2.6.0 "$now" '[]'; run b; [ -z "$out" ] || fail b "green not silent"
mk b2; res running 2.6.0 "$now" '[]'; run b2; [ -z "$out" ] || fail b2 "running not silent"
mk b3; res red 2.5.0 "$now" "$(jq -s '.' <(case_json c hook "" d credential-guard.sh))"; run b3; [ -z "$out" ] || fail b3 "older version not silent"
mk b4; run b4; [ -z "$out" ] || fail b4 "no file not silent"
mk b5; echo '{broken' > "$wh/install-verify.json"; run b5; [ -z "$out" ] || fail b5 "broken json not silent"

# c. stuck running (> 10 min) -> re-run notice
mk c; res running 2.6.0 "$(ago 30)" '[]'; run c
case "$ctx" in *"did not finish"*"bash ~/.claude/evals/run.sh"*) ;; *) fail c "stuck notice: $ctx";; esac

# d. 7 blocking, 3 not blocking -> 5 + "and 2 more", 3 listed
mk d; echo /s > "$wh/source"
f=$(jq -n '[range(1;8) | {name:("b\(.)"), kind:"hook", file:"", detail:"d", hook:"credential-guard.sh"}] + [range(1;4) | {name:("w\(.)"), kind:"file_contains", file:"x.md", detail:"d", hook:""}]')
res red 2.6.0 "$now" "$f"; run d
case "$ctx" in *"b5 — "*|*"— b5:"*) ;; *) fail d "b5 missing: $ctx";; esac
case "$ctx" in *"— b6:"*) fail d "b6 should be cut";; esac
case "$ctx" in *"and 2 more"*) ;; *) fail d "and 2 more missing: $ctx";; esac
case "$ctx" in *"w3 (file_contains)"*) ;; *) fail d "w3 missing";; esac
case "$ctx" in *"and 0 more"*) fail d "spurious and 0 more";; esac

# e. both notices in one additionalContext
mk e; src="$tmp/src"; mkdir -p "$src"; echo 2.7.0 > "$src/VERSION"
res red 2.6.0 "$now" "$(jq -s '.' <(case_json hook-x hook "" boom credential-guard.sh))"
out=$(jq -n --arg cwd "$tmp/proj" '{hook_event_name:"SessionStart", cwd:$cwd, source:"startup"}' | WORKFLOW_HOME="$wh" WORKFLOW_SOURCE="$src" bash "$hook" 2>/dev/null)
ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')
case "$ctx" in *"source repo"*) ;; *) fail e "version notice missing";; esac
case "$ctx" in *"install verification of 2.6.0 failed 1 case."*) ;; *) fail e "install notice missing: $ctx";; esac
[ "$(printf '%s' "$out" | jq -s 'length')" = 1 ] || fail e "more than one JSON object"

[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
