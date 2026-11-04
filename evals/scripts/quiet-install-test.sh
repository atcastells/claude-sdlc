#!/bin/bash
# install.sh output modes: default (quiet, verification in the background) and
# --verbose (suite in the foreground). Throwaway HOME; the planted failing case
# goes into a scratch COPY of the repo, never the real tree.
#   usage: quiet-install-test.sh <repo-root>
set -uo pipefail
src="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset EVALS_ROOT WORKFLOW_PROFILE WORKFLOW_HOME WORKFLOW_INSTALL_NO_VERIFY WORKFLOW_INSTALL_VERBOSE EVALS_RESULT_JSON
fails=0
check() { if eval "$2"; then :; else echo "  FAIL $1"; fails=$((fails+1)); fi; }

# Every install runs from a scratch COPY of the repo whose suite holds one trivial
# passing case, so the installed suite is near-instant.
cp_src="$tmp/srccopy"; mkdir -p "$cp_src"
( cd "$src" && tar -cf - --exclude=.git --exclude=.sdlc --exclude=./evals/cases . ) | ( cd "$cp_src" && tar -xf - )
mkdir -p "$cp_src/evals/cases"
printf '#!/bin/bash\necho ok\n' > "$cp_src/evals/scripts/trivial-ok.sh"
printf '#!/bin/bash\necho planted\nexit 1\n' > "$cp_src/evals/scripts/planted-fail.sh"
chmod +x "$cp_src/evals/scripts/trivial-ok.sh" "$cp_src/evals/scripts/planted-fail.sh"
printf '%s\n' '{"name":"trivial ok","kind":"hook","script":"evals/scripts/trivial-ok.sh","args":[],"expect_exit":0,"contains":"ok"}' \
  > "$cp_src/evals/cases/001-trivial-ok.json"
src="$cp_src"

# 1. Default install: quiet, result file reaches green
h="$tmp/quiet"; mkdir -p "$h"
HOME="$h" bash "$src/install.sh" --no-profile </dev/null >"$tmp/quiet.out" 2>&1
rc=$?
check "default install exits 0" "[ $rc -eq 0 ]"
check "default prints no PASS/FAIL case lines" "! grep -Eq '^(PASS|FAIL)' '$tmp/quiet.out'"
check "default prints no suite summary" "! grep -q 'FAIL: ' '$tmp/quiet.out'"
check "default names Claudio in the Installing line" "grep -q '^Installing Claudio ' '$tmp/quiet.out'"
after=$(awk '/^Installing Claudio /{f=1;next} f' "$tmp/quiet.out" | wc -l | tr -d ' ')
check "default prints <= 6 lines after the Installing line ($after)" "[ $after -le 6 ]"
check "default says it verifies in the background" "grep -q 'Verifying in the background' '$tmp/quiet.out'"
res="$h/.claude/workflow/install-verify.json"
i=0; st=""
while [ $i -lt 600 ]; do
  st=$(jq -r .status "$res" 2>/dev/null || true)
  [ "$st" = "green" ] && break
  sleep 0.1; i=$((i+1))
done
check "result file reaches green (last: ${st:-none})" "[ '$st' = green ]"
check "install-verify.sh is executable" "[ -x '$h/.claude/evals/install-verify.sh' ]"

# 2. --verbose: suite in the foreground
h="$tmp/verbose"; mkdir -p "$h"
HOME="$h" bash "$src/install.sh" --no-profile --verbose </dev/null >"$tmp/verbose.out" 2>&1
rc=$?
check "--verbose exits 0 when green" "[ $rc -eq 0 ]"
check "--verbose prints the suite summary" "grep -Eq 'PASS: [0-9]+ +FAIL: 0' '$tmp/verbose.out'"
h="$tmp/envverbose"; mkdir -p "$h"
HOME="$h" WORKFLOW_INSTALL_VERBOSE=1 bash "$src/install.sh" --no-profile </dev/null >"$tmp/envverbose.out" 2>&1
check "WORKFLOW_INSTALL_VERBOSE=1 prints the suite summary" "grep -Eq 'PASS: [0-9]+ +FAIL: 0' '$tmp/envverbose.out'"

# 3. --verbose with a planted failing case exits 1
printf '%s\n' '{"name":"planted failure","kind":"hook","script":"evals/scripts/planted-fail.sh","args":[],"expect_exit":0,"contains":"never"}' \
  > "$cp_src/evals/cases/999-planted-fail.json"
h="$tmp/red"; mkdir -p "$h"
HOME="$h" bash "$src/install.sh" --no-profile --verbose </dev/null >"$tmp/red.out" 2>&1
rc=$?
check "--verbose with a failing case exits 1 (got $rc)" "[ $rc -eq 1 ]"

# 4. A stale red result must not survive a fixed reinstall of the same version
waitst() { # waitst <file> <status>: bounded wait (<= 20 s)
  local i=0 st=""
  while [ $i -lt 200 ]; do
    st=$(jq -r .status "$1" 2>/dev/null || true)
    [ "$st" = "$2" ] && break
    sleep 0.1; i=$((i+1))
  done
  echo "$st"
}
h="$tmp/stale"; mkdir -p "$h"; sres="$h/.claude/workflow/install-verify.json"
HOME="$h" bash "$src/install.sh" --no-profile </dev/null >/dev/null 2>&1
st=$(waitst "$sres" red)
check "stale: default install over a failing suite ends red (last: ${st:-none})" "[ '$st' = red ]"
rm -f "$cp_src/evals/cases/999-planted-fail.json"
HOME="$h" bash "$src/install.sh" --no-profile --verbose </dev/null >/dev/null 2>&1
check "stale: --verbose reinstall exits 0" "[ $? -eq 0 ]"
st=$(jq -r .status "$sres" 2>/dev/null || true)
check "stale: --verbose rewrites the result to green (got ${st:-none})" "[ '$st' = green ]"
printf '%s\n' '{"name":"planted failure","kind":"hook","script":"evals/scripts/planted-fail.sh","args":[],"expect_exit":0,"contains":"never"}' \
  > "$cp_src/evals/cases/999-planted-fail.json"
HOME="$h" bash "$src/install.sh" --no-profile </dev/null >/dev/null 2>&1
st=$(waitst "$sres" red)
check "stale: red again (last: ${st:-none})" "[ '$st' = red ]"
HOME="$h" WORKFLOW_INSTALL_NO_VERIFY=1 bash "$src/install.sh" --no-profile </dev/null >/dev/null 2>&1
check "stale: NO_VERIFY install removes the result file" "[ ! -e '$sres' ]"


[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
