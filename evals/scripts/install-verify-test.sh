#!/usr/bin/env bash
# Tests evals/install-verify.sh against stub roots (never the real ~/.claude).
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
script="$here/install-verify.sh"
tmp="$(mktemp -d)"
trap 'kill $(cat "$tmp"/*.mark 2>/dev/null) 2>/dev/null; rm -rf "$tmp"' EXIT
fail=0
check() { if [ "$2" = "$3" ]; then :; else echo "FAIL: $1 (got '$2', want '$3')"; fail=1; fi; }

wait_for() { # wait_for <file> : up to 20 s
  local i=0
  while [ ! -s "$1" ] && [ $i -lt 200 ]; do sleep 0.1; i=$((i+1)); done
  [ -s "$1" ]
}

mkroot() { # mkroot <dir> <mode>
  mkdir -p "$1/evals"
  echo "9.9.9" > "$1/VERSION"
  cat > "$1/evals/run.sh" <<'STUB'
#!/usr/bin/env bash
case "$STUB_MODE" in
  green)
    cp "$EVALS_RESULT_JSON" "$STUB_WITNESS"
    echo "${EVALS_SKIP_REPO:-unset}" > "$STUB_SKIP"
    echo "PASS: 1 FAIL: 0"
    jq -n '{version:"9.9.9",started:"s",finished:"f",status:"green",pass:1,fail:0,failed:[]}' > "$EVALS_RESULT_JSON.tmp" \
      && mv "$EVALS_RESULT_JSON.tmp" "$EVALS_RESULT_JSON" ;;
  silent) echo "crashed"; exit 3 ;;
  slow) echo $$ > "$STUB_MARK"; exec sleep 60 ;;
esac
STUB
  chmod +x "$1/evals/run.sh"
}

root="$tmp/root"; mkroot "$root"
export WORKFLOW_HOME="$tmp/wh"; mkdir -p "$WORKFLOW_HOME"
export STUB_SKIP="$tmp/skip.txt" STUB_WITNESS="$tmp/witness.json" STUB_MARK="$tmp/run.mark"

# 1. running then final, log written
STUB_MODE=green bash "$script" "$root"; rc=$?
check "exit 0" "$rc" "0"
check "EVALS_SKIP_REPO reaches run.sh" "$(cat "$STUB_SKIP")" "1"
check "initial status" "$(jq -r .status "$STUB_WITNESS")" "running"
check "initial version" "$(jq -r .version "$STUB_WITNESS")" "9.9.9"
check "initial started set" "$(jq -r '.started|length>0' "$STUB_WITNESS")" "true"
check "initial finished null" "$(jq -r .finished "$STUB_WITNESS")" "null"
check "final status" "$(jq -r .status "$WORKFLOW_HOME/install-verify.json")" "green"
grep -q "PASS: 1" "$WORKFLOW_HOME/install-verify.log" || { echo "FAIL: log missing stub output"; fail=1; }

# 2. run.sh exits without writing a result
STUB_MODE=silent bash "$script" "$root"
j="$WORKFLOW_HOME/install-verify.json"
check "silent status" "$(jq -r .status "$j")" "red"
check "silent fail" "$(jq -r .fail "$j")" "1"
check "silent name" "$(jq -r '.failed[0].name' "$j")" "run.sh did not write a result"
check "silent finished set" "$(jq -r '.finished|length>0' "$j")" "true"
check "silent version" "$(jq -r .version "$j")" "9.9.9"

# 3. a second start kills the first
rm -f "$STUB_MARK" "$WORKFLOW_HOME/install-verify.json"
STUB_MODE=slow bash "$script" "$root" >/dev/null 2>&1 &
first=$!
wait_for "$STUB_MARK" || { echo "FAIL: slow stub did not start"; fail=1; }
runpid="$(cat "$STUB_MARK" 2>/dev/null)"
check "running while slow" "$(jq -r .status "$j")" "running"
STUB_MODE=green bash "$script" "$root"
i=0; while kill -0 "$first" 2>/dev/null && [ $i -lt 200 ]; do sleep 0.1; i=$((i+1)); done
kill -0 "$first" 2>/dev/null && { echo "FAIL: first install-verify still alive"; fail=1; }
[ -n "$runpid" ] && kill -0 "$runpid" 2>/dev/null && { echo "FAIL: first run.sh still alive"; fail=1; }
check "after second status" "$(jq -r .status "$j")" "green"

# 4. unrelated PID in the pid file is not killed
sleep 60 & other=$!
echo "$other" > "$WORKFLOW_HOME/install-verify.pid"
STUB_MODE=green bash "$script" "$root"
kill -0 "$other" 2>/dev/null || { echo "FAIL: unrelated process was killed"; fail=1; }
kill "$other" 2>/dev/null

[ $fail = 0 ] && echo "all passed"
exit $fail
