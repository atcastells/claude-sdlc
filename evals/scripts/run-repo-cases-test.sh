#!/bin/bash
# Checks run.sh case field "repo", EVALS_SKIP_REPO, EVALS_REPO and the "hook"
# key in failed entries of EVALS_RESULT_JSON.
#   usage: run-repo-cases-test.sh <path to run.sh>
set -uo pipefail
runsh="$(cd "$(dirname "${1:?run.sh path}")" && pwd)/$(basename "$1")"
tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok() { [ "$2" = "$3" ] || { echo "FAIL: $1: got '$2', expected '$3'"; fail=1; }; }

mkdir -p "$tmp/root/evals/cases" "$tmp/app/sub" "$tmp/app-2" "$tmp/link-parent"
cp "$runsh" "$tmp/root/evals/run.sh"
printf 'hello\n' > "$tmp/root/present.txt"

# Passing case without repo, passing case with repo
jq -n --arg f "$tmp/root/present.txt" '{name:"plain",kind:"file_contains",file:$f,contains:"hello"}' > "$tmp/root/evals/cases/a.json"
mk_repo_case() { # <repo> [contains]
  jq -n --arg f "$tmp/root/present.txt" --arg r "$1" --arg c "${2:-hello}" \
    '{name:"repo case",kind:"file_contains",file:$f,contains:$c,repo:$r}' > "$tmp/root/evals/cases/b.json"
}

run() { env -u WORKFLOW_PROFILE -u EVALS_RESULT_JSON -u EVALS_SKIP_REPO -u EVALS_REPO EVALS_ROOT="$tmp/root" "$@" bash "$tmp/root/evals/run.sh" 2>&1; }
counts() { printf '%s\n' "$1" | sed -n 's/^PASS: \([0-9]*\)   FAIL: \([0-9]*\).*/\1\/\2/p'; }

# Plain run counts the repo case
mk_repo_case "$tmp/app"
out=$(run); ok "plain run counts" "$(counts "$out")" "2/0"

# EVALS_SKIP_REPO=1: not counted, green even if the repo case fails
mk_repo_case "$tmp/app" "absent-text"
out=$(run EVALS_SKIP_REPO=1); rc=$?
ok "skip counts" "$(counts "$out")" "1/0"
ok "skip exit" "$rc" 0
printf '%s\n' "$out" | grep -q 'SKIP (repo case)' || { echo "FAIL: no 'SKIP (repo case)' line"; fail=1; }
run EVALS_SKIP_REPO=1 EVALS_RESULT_JSON="$tmp/skip.json" >/dev/null
ok "skip status" "$(jq -r .status "$tmp/skip.json")" green

# EVALS_REPO matching
mk_repo_case "$tmp/app"
out=$(run EVALS_REPO="$tmp/app"); ok "repo = dir runs" "$(counts "$out")" "1/0"
out=$(run EVALS_REPO="$tmp/app/sub"); ok "subdir runs" "$(counts "$out")" "1/0"
out=$(run EVALS_REPO="$tmp/app-2"); rc=$?
ok "sibling prefix not run" "$(counts "$out")" "0/0"
ok "sibling exit" "$rc" 0
printf '%s\n' "$out" | grep -q 'SKIP (not this repo)' || { echo "FAIL: no 'SKIP (not this repo)' line"; fail=1; }

# Symlinked EVALS_REPO resolves
ln -s "$tmp/app/sub" "$tmp/link-parent/l"
out=$(run EVALS_REPO="$tmp/link-parent/l"); ok "symlink resolves" "$(counts "$out")" "1/0"

# Missing repo path never matches
mk_repo_case "$tmp/missing"
out=$(run EVALS_REPO="$tmp/app"); ok "missing repo not run" "$(counts "$out")" "0/0"

# No matching case at all: 0/0, exit 0
rm -f "$tmp/root/evals/cases/b.json"
out=$(run EVALS_REPO="$tmp/app"); rc=$?
ok "no case 0/0" "$(counts "$out")" "0/0"
ok "no case exit" "$rc" 0

# Result JSON: failed entries carry hook
jq -n --arg f "$tmp/root/present.txt" '{name:"hooked",kind:"file_contains",file:$f,contains:"nope",hook:"credential-guard.sh"}' > "$tmp/root/evals/cases/c.json"
jq -n --arg f "$tmp/root/present.txt" '{name:"unhooked",kind:"file_contains",file:$f,contains:"nope"}' > "$tmp/root/evals/cases/d.json"
run EVALS_RESULT_JSON="$tmp/red.json" >/dev/null
ok "failed hook set" "$(jq -r '.failed[] | select(.name=="hooked") | .hook' "$tmp/red.json")" "credential-guard.sh"
ok "failed hook empty" "$(jq -c '.failed[] | select(.name=="unhooked") | .hook' "$tmp/red.json")" '""'

[ "$fail" = 0 ] && echo "all passed"
exit "$fail"
