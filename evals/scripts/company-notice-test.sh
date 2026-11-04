#!/bin/bash
# Scenarios for the company rules notice in hooks/workflow-version-check.sh.
# Everything lives in a temp WORKFLOW_HOME. Exit 0 = all behaved.
#   usage: company-notice-test.sh <path-to-workflow-version-check.sh>
set -uo pipefail
hook="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0
fail() { echo "  FAIL $1: $2"; fails=$((fails+1)); }
mkdir -p "$tmp/proj"

# mk <name> -> sets $wh (VERSION 2.6.0) and $pd (profile dir, recorded in $wh/profile)
mk() {
  wh="$tmp/$1"; pd="$tmp/$1-profile"; mkdir -p "$wh" "$pd"
  echo 2.6.0 > "$wh/VERSION"; printf '%s\n' "$pd" > "$wh/profile"
}
# repo <name> -> company repo with a rules file, recorded in $wh/company-repo
repo() {
  cr="$tmp/$1-company"; mkdir -p "$cr/rules"; echo "rules" > "$cr/rules/r.md"
  printf '%s\n' "$cr" > "$wh/company-repo"
}
run() {
  out=$(jq -n --arg cwd "$tmp/proj" '{hook_event_name:"SessionStart", cwd:$cwd, source:"startup"}' \
    | WORKFLOW_HOME="$wh" WORKFLOW_SOURCE="" bash "$hook" 2>/dev/null)
  rc=$?
  [ "$rc" = 0 ] || fail "$1" "exit $rc, expected 0"
  ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
}
cj() { jq -n '{url:"https://example.com/org/rules.git", rules:"rules/r.md"}' > "$pd/company.json"; }

# a. no company-repo file -> notice
mk a; cj; run a
case "$ctx" in "Claudio: "*"/workflow-install"*) ;; *) fail a "notice missing: $ctx";; esac
case "$ctx" in *"not found"*) ;; *) fail a "wording: $ctx";; esac

# a2. company-repo file empty -> notice
mk a2; cj; : > "$wh/company-repo"; run a2
case "$ctx" in *"/workflow-install"*) ;; *) fail a2 "empty file: $ctx";; esac

# b. saved dir gone -> notice
mk b; cj; repo b; rm -rf "$cr"; run b
case "$ctx" in *"/workflow-install"*) ;; *) fail b "dir removed: $ctx";; esac

# c. dir present, rules file removed -> notice
mk c; cj; repo c; rm "$cr/rules/r.md"; run c
case "$ctx" in *"/workflow-install"*) ;; *) fail c "rules removed: $ctx";; esac

# d. all present -> silent
mk d; cj; repo d; run d
[ -z "$out" ] || fail d "not silent: $ctx"

# e. profile without company.json -> silent
mk e; run e; [ -z "$out" ] || fail e "not silent: $ctx"

# f. malformed company.json -> silent, exit 0
mk f; echo '{broken' > "$pd/company.json"; run f; [ -z "$out" ] || fail f "not silent: $ctx"
mk f2; echo '{"url":"u"}' > "$pd/company.json"; run f2; [ -z "$out" ] || fail f2 "no rules not silent: $ctx"

# g. no profile pointer at all -> silent
mk g; rm "$wh/profile"; run g; [ -z "$out" ] || fail g "not silent: $ctx"

[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
