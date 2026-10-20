#!/bin/bash
# Checks run.sh in installed mode: profile cases are added, profile cases may
# not run code, and the file_lacks kind.
#   usage: run-profile-installed-test.sh <fixture-profile-dir> [lacks]
# With "lacks" only the file_lacks scenarios run.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
fixture="${1:-$here/../fixtures/profile-cases}"
fixture="$(cd "$fixture" && pwd)" || exit 1
only="${2:-}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/evals/cases" "$tmp/hooks"
cp "$here/../run.sh" "$tmp/evals/run.sh"

# The caller may export EVALS_ROOT (the suite does): the inner run must not inherit it
inner() { env -u EVALS_ROOT -u WORKFLOW_PROFILE WORKFLOW_PROFILE="$1" bash "$tmp/evals/run.sh" 2>&1; }

fail=0
check() { # <label> <output> <expected line fragment>
  case "$2" in *"$3"*) ;; *) echo "FAIL: $1: expected '$3'"; fail=1 ;; esac
}

if [ "$only" != lacks ]; then
  out=$(inner "$fixture")
  line=$(printf '%s\n' "$out" | grep -F 'fixture profile case: loaded from profile dir')
  case "$out" in *"installed:"*) ;; *) echo "FAIL: not in installed mode"; fail=1 ;; esac
  case "$line" in *PASS*) ;; *) echo "FAIL: fixture case missing or not PASS: $line"; fail=1 ;; esac

  # Profile cases must not run code: each one would touch the marker
  p="$tmp/p-code"; mkdir -p "$p/evals/cases"
  for h in touch.sh; do printf 'touch "%s/ran"\n' "$tmp" > "$tmp/hooks/$h"; done
  printf 'touch "%s/ran"\n' "$tmp" > "$tmp/touch.sh"
  jq -n '{name:"pc script", kind:"hook", script:"touch.sh"}' > "$p/evals/cases/a.json"
  jq -n '{name:"pc env", kind:"hook", hook:"touch.sh", env:{A:"b"}}' > "$p/evals/cases/b.json"
  jq -n '{name:"pc slash", kind:"hook", hook:"../touch.sh"}' > "$p/evals/cases/c.json"
  out=$(inner "$p")
  check "script case" "$(printf '%s\n' "$out" | grep 'pc script')" "SKIP (profile cases may not run code"
  check "env case" "$(printf '%s\n' "$out" | grep 'pc env')" "SKIP (profile cases may not run code"
  check "slash case" "$(printf '%s\n' "$out" | grep 'pc slash')" "SKIP (profile cases may not run code"
  [ -e "$tmp/ran" ] && { echo "FAIL: a profile case ran code"; fail=1; }
fi

# file_lacks: PASS and FAIL, with and without until
lf="$fixture/lacks.txt"
p="$tmp/p-lacks"; mkdir -p "$p/evals/cases"
mk() { jq -n --arg n "$1" --arg f "$lf" --arg p "$2" --arg u "${3:-}" \
  '{name:$n, kind:"file_lacks", file:$f, pattern:$p} + (if $u == "" then {} else {until:$u} end)' > "$p/evals/cases/$1.json"; }
mk fl-pass 'gamma|delta'
mk fl-fail 'SECRET'
mk fl-until-pass 'secret' '## cut'
mk fl-until-fail 'beta' '## cut'
mk fl-nofile-fail 'x'
jq '.file="/nonexistent/none.txt"' "$p/evals/cases/fl-nofile-fail.json" > "$p/x" && mv "$p/x" "$p/evals/cases/fl-nofile-fail.json"
out=$(inner "$p")
check "lacks pass" "$(printf '%s\n' "$out" | grep '^fl-pass ')" "PASS"
check "lacks fail (case-insensitive, line 4)" "$(printf '%s\n' "$out" | grep '^fl-fail ')" "FAIL (exit=1, expected=0; line 4)"
check "lacks until pass" "$(printf '%s\n' "$out" | grep '^fl-until-pass ')" "PASS"
check "lacks until fail" "$(printf '%s\n' "$out" | grep '^fl-until-fail ')" "FAIL (exit=1, expected=0; line 2)"
check "lacks no file" "$(printf '%s\n' "$out" | grep '^fl-nofile-fail ')" "FAIL"

if [ "$fail" = 0 ]; then [ "$only" = lacks ] && echo "lacks passed" || echo "all passed"; fi
exit "$fail"
