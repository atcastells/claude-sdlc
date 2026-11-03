#!/bin/bash
# Checks run.sh EVALS_RESULT_JSON: green and red result files, and that stdout
# is byte-identical with and without the variable.
#   usage: run-result-json-test.sh <path to run.sh>
set -uo pipefail
runsh="$(cd "$(dirname "${1:?run.sh path}")" && pwd)/$(basename "$1")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
ok() { [ "$2" = "$3" ] || { echo "FAIL: $1: got '$2', expected '$3'"; fail=1; }; }

mkdir -p "$tmp/root/evals/cases" "$tmp/root/evals/work"
cp "$runsh" "$tmp/root/evals/run.sh"
echo "9.9.9" > "$tmp/root/VERSION"
printf 'hello\n' > "$tmp/root/present.txt"
jq -n --arg f "$tmp/root/present.txt" '{name:"ok case",kind:"file_contains",file:$f,contains:"hello"}' > "$tmp/root/evals/cases/a.json"

inner() { env -u WORKFLOW_PROFILE -u EVALS_RESULT_JSON EVALS_ROOT="$tmp/root" "$@" bash "$tmp/root/evals/run.sh" 2>&1; }

# Green
inner EVALS_RESULT_JSON="$tmp/green.json" > "$tmp/green.out"
inner > "$tmp/green.plain"
cmp -s "$tmp/green.out" "$tmp/green.plain" || { echo "FAIL: green stdout differs with the variable"; fail=1; }
j="$tmp/green.json"
ok "green status" "$(jq -r .status "$j")" green
ok "green pass" "$(jq -r .pass "$j")" 1
ok "green fail" "$(jq -r .fail "$j")" 0
ok "green failed" "$(jq -c .failed "$j")" '[]'
ok "green version" "$(jq -r .version "$j")" 9.9.9
jq -e '.started|test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$")' "$j" >/dev/null || { echo "FAIL: started format"; fail=1; }
jq -e '.finished|test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$")' "$j" >/dev/null || { echo "FAIL: finished format"; fail=1; }

# Red: planted failure
jq -n --arg f "$tmp/root/present.txt" '{name:"bad case",kind:"file_lacks",file:$f,pattern:"hello"}' > "$tmp/root/evals/cases/b.json"
inner EVALS_RESULT_JSON="$tmp/red.json" > "$tmp/red.out"; rc1=$?
inner > "$tmp/red.plain"; rc2=$?
cmp -s "$tmp/red.out" "$tmp/red.plain" || { echo "FAIL: red stdout differs with the variable"; fail=1; }
ok "red exit codes" "$rc1/$rc2" "1/1"
j="$tmp/red.json"
ok "red status" "$(jq -r .status "$j")" red
ok "red pass" "$(jq -r .pass "$j")" 1
ok "red fail" "$(jq -r .fail "$j")" 1
ok "red name" "$(jq -r '.failed[0].name' "$j")" "bad case"
ok "red kind" "$(jq -r '.failed[0].kind' "$j")" file_lacks
ok "red file" "$(jq -r '.failed[0].file' "$j")" "$tmp/root/present.txt"
ok "red detail" "$(jq -r '.failed[0].detail' "$j")" "exit=1, expected=0; line 1"

# file under HOME is reported with a leading ~
mkdir -p "$tmp/home"; printf 'hello\n' > "$tmp/home/h.txt"
rm -f "$tmp/root/evals/cases/b.json"
jq -n --arg f "$tmp/home/h.txt" '{name:"home case",kind:"file_contains",file:$f,contains:"absent-text"}' > "$tmp/root/evals/cases/c.json"
HOME="$tmp/home" inner EVALS_RESULT_JSON="$tmp/home.json" >/dev/null
ok "home file shown as ~" "$(jq -r '.failed[0].file' "$tmp/home.json")" "~/h.txt"
rm -f "$tmp/root/evals/cases/c.json"

# Unset variable: no file, and no stray temp files
rm -f "$tmp/root/evals/cases/b.json"
mkdir "$tmp/empty"
(cd "$tmp/empty" && inner >/dev/null)
ok "no file without variable" "$(ls "$tmp/empty" | wc -l | tr -d ' ')" 0
ok "no leftover temp files" "$(ls "$tmp" | grep -c '\.tmp')" 0

# Installed layout: no root/VERSION, only root/workflow/VERSION
mkdir -p "$tmp/inst/evals/cases" "$tmp/inst/workflow"
cp "$runsh" "$tmp/inst/evals/run.sh"
echo "8.8.8" > "$tmp/inst/workflow/VERSION"
cp "$tmp/root/evals/cases/a.json" "$tmp/inst/evals/cases/a.json"
env -u WORKFLOW_PROFILE EVALS_ROOT="$tmp/inst" EVALS_RESULT_JSON="$tmp/inst.json" bash "$tmp/inst/evals/run.sh" >/dev/null 2>&1
ok "workflow/VERSION fallback" "$(jq -r .version "$tmp/inst.json")" 8.8.8
# Neither file: null
rm "$tmp/inst/workflow/VERSION"
env -u WORKFLOW_PROFILE EVALS_ROOT="$tmp/inst" EVALS_RESULT_JSON="$tmp/inst2.json" bash "$tmp/inst/evals/run.sh" >/dev/null 2>&1
ok "no VERSION anywhere" "$(jq -c .version "$tmp/inst2.json")" null

[ "$fail" = 0 ] && echo "all passed"
exit "$fail"
