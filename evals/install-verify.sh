#!/usr/bin/env bash
# Runs the installed suite in the background and records the result.
# Usage: install-verify.sh <installed-root>
set -u
root="${1:?usage: install-verify.sh <installed-root>}"
wh="${WORKFLOW_HOME:-$HOME/.claude/workflow}"
json="$wh/install-verify.json"
log="$wh/install-verify.log"
pidf="$wh/install-verify.pid"
mkdir -p "$wh"

# Stop a live previous run, only if it really is one of ours.
if [ -s "$pidf" ]; then
  old="$(cat "$pidf" 2>/dev/null)"
  case "$old" in ''|*[!0-9]*) old="" ;; esac
  if [ -n "$old" ] && [ "$old" != "$$" ] && kill -0 "$old" 2>/dev/null; then
    cmd="$(ps -p "$old" -o command= 2>/dev/null)"
    case "$cmd" in
      *install-verify.sh*|*evals/run.sh*)
        kill "$old" 2>/dev/null
        i=0
        while kill -0 "$old" 2>/dev/null && [ $i -lt 50 ]; do sleep 0.1; i=$((i+1)); done ;;
    esac
  fi
fi
echo $$ > "$pidf"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
ver=""
[ -f "$root/workflow/VERSION" ] && ver="$(tr -d '[:space:]' < "$root/workflow/VERSION")"
[ -z "$ver" ] && [ -f "$root/VERSION" ] && ver="$(tr -d '[:space:]' < "$root/VERSION")"
started="$(now)"

write() { # write <jq-filter-args...> ; atomic
  jq -n "$@" > "$json.tmp" && mv "$json.tmp" "$json"
}
write --arg v "$ver" --arg s "$started" \
  '{version: (if $v=="" then null else $v end), started:$s, finished:null, status:"running", pass:0, fail:0, failed:[]}'

child=""
trap '[ -n "$child" ] && kill "$child" 2>/dev/null; exit 143' TERM INT
EVALS_SKIP_REPO=1 EVALS_RESULT_JSON="$json" bash "$root/evals/run.sh" > "$log" 2>&1 &
child=$!
wait "$child"
rc=$?
child=""

# run.sh finished: if the file still says running it never wrote a result.
if [ "$(jq -r .status "$json" 2>/dev/null)" = "running" ]; then
  write --arg v "$ver" --arg s "$started" --arg f "$(now)" --arg d "exit code $rc; see install-verify.log" \
    '{version: (if $v=="" then null else $v end), started:$s, finished:$f, status:"red", pass:0, fail:1,
      failed:[{name:"run.sh did not write a result", kind:"suite", file:"", detail:$d}]}'
fi
rm -f "$pidf"
exit 0
