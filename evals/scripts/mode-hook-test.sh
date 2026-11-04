#!/bin/bash
# Scenarios: hooks/mode.sh toggles the per-session Vibe marker and re-injects context.
#   usage: mode-hook-test.sh <hooks-dir>
set -uo pipefail
hooks="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp"
fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }

HOOK_RC=0
# run_hook <event> <session_id> <prompt> <source>; sets OUT and HOOK_RC
run_hook() {
  local payload
  payload=$(jq -n --arg e "$1" --arg s "$2" --arg p "$3" --arg src "$4" \
    '{hook_event_name:$e, session_id:$s, prompt:$p, source:$src}')
  OUT=$(printf '%s' "$payload" | bash "$hooks/mode.sh" 2>/dev/null); HOOK_RC=$?
  [ "$HOOK_RC" = 0 ] || fail "$1/$2: exit $HOOK_RC"
}
prompt() { run_hook UserPromptSubmit "$1" "$2" ""; }
start() { run_hook SessionStart "$1" "" "$2"; }
marker="$tmp/claudio-mode-s1"

prompt s1 "/vibe"
[ -e "$marker" ] || fail "/vibe: marker not created"
case "$OUT" in *"Vibe mode"*) ;; *) fail "/vibe: output lacks Vibe mode" ;; esac
[ "$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)" = "UserPromptSubmit" ] || fail "/vibe: event name"

rm -f "$marker"
prompt s1 "/vibe try a bridge"
[ -e "$marker" ] || fail "/vibe args: marker not created"
case "$OUT" in *"Vibe mode"*) ;; *) fail "/vibe args: output lacks Vibe mode" ;; esac

prompt s1 "  /vibe off  "
[ ! -e "$marker" ] || fail "/vibe off: marker still there"
case "$OUT" in *"Spec mode"*) ;; *) fail "/vibe off: output lacks Spec mode" ;; esac

: > "$marker"
prompt s1 "hello there"
[ -z "$OUT" ] || fail "normal prompt: output '$OUT'"
[ -e "$marker" ] || fail "normal prompt: marker removed"
rm -f "$marker"
prompt s1 "hello there"
[ ! -e "$marker" ] || fail "normal prompt: marker created"

prompt s1 "/vibes"
[ -z "$OUT" ] || fail "/vibes: output '$OUT'"
[ ! -e "$marker" ] || fail "/vibes: marker created"

prompt s1 "$(printf 'hello\n/vibe')"
[ -z "$OUT" ] || fail "second line /vibe: output '$OUT'"
[ ! -e "$marker" ] || fail "second line /vibe: marker created"

prompt s2 "/vibe"
[ -e "$tmp/claudio-mode-s2" ] || fail "s2: marker not created"
[ ! -e "$marker" ] || fail "s2 /vibe touched s1"
: > "$marker"
prompt s2 "/vibe off"
[ -e "$marker" ] || fail "s2 /vibe off touched s1"
rm -f "$marker"

start s1 compact
[ -z "$OUT" ] || fail "compact without marker: output '$OUT'"
: > "$marker"
start s1 compact
case "$OUT" in *"Vibe mode"*) ;; *) fail "compact with marker: lacks Vibe mode" ;; esac
[ "$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)" = "SessionStart" ] || fail "compact: event name"
start s1 resume
case "$OUT" in *"Vibe mode"*) ;; *) fail "resume with marker: lacks Vibe mode" ;; esac
start s1 clear
[ -z "$OUT" ] || fail "clear: output '$OUT'"
[ ! -e "$marker" ] || fail "clear: marker kept"
: > "$marker"
start s1 startup
[ -z "$OUT" ] || fail "startup: output '$OUT'"
[ ! -e "$marker" ] || fail "startup: marker kept"
: > "$marker"
start s1 other
[ -z "$OUT" ] || fail "other source: output '$OUT'"
[ -e "$marker" ] || fail "other source: marker removed"
rm -f "$marker"

run_hook Stop s1 "/vibe" ""
[ -z "$OUT" ] || fail "other event: output '$OUT'"
[ ! -e "$marker" ] || fail "other event: marker created"

before=$(ls -A "$tmp" | wc -l | tr -d ' ')
prompt "../x" "/vibe"
[ -z "$OUT" ] || fail "invalid id ../x: output"
prompt "" "/vibe"
[ -z "$OUT" ] || fail "empty id: output"
printf '%s' '{"hook_event_name":"UserPromptSubmit","prompt":"/vibe"}' | bash "$hooks/mode.sh" >"$tmp.out" 2>/dev/null; rc=$?
[ "$rc" = 0 ] || fail "missing id: exit $rc"
[ ! -s "$tmp.out" ] || fail "missing id: output"
rm -f "$tmp.out"
after=$(ls -A "$tmp" | wc -l | tr -d ' ')
[ "$before" = "$after" ] || fail "invalid ids created files in TMPDIR ($before -> $after)"
[ ! -e "$tmp/../x" ] || fail "invalid id escaped TMPDIR"

prompt s3 "/vibe ZXQ-SECRET-PROMPT"
case "$OUT" in *ZXQ-SECRET-PROMPT*) fail "output echoes the prompt" ;; esac

# "off" as the first word after /vibe turns it off, whatever follows or the spacing
for p in "/vibe off now" "/vibe  off"; do
  : > "$marker"
  prompt s1 "$p"
  [ ! -e "$marker" ] || fail "'$p': marker still there"
  case "$OUT" in *"Spec mode"*) ;; *) fail "'$p': output lacks Spec mode" ;; esac
done
rm -f "$marker"
prompt s1 "/vibe offline sync"
[ -e "$marker" ] || fail "/vibe offline: should be an idea, marker not created"

# marker that cannot be written: no Vibe context announced
TMPDIR="$tmp/missing-dir" prompt s9 "/vibe"
[ -z "$OUT" ] || fail "unwritable marker: Vibe context announced anyway"

# a planted symlink is never written through
victim="$tmp/victim"; printf 'keep' > "$victim"
ln -s "$victim" "$tmp/claudio-mode-s7"
prompt s7 "/vibe"
[ "$(cat "$victim")" = "keep" ] || fail "symlinked marker: target was truncated"
[ -L "$tmp/claudio-mode-s7" ] && fail "symlinked marker: link left in place"

# /vibe off that cannot remove the marker does not announce Spec
mkdir "$tmp/claudio-mode-s6"
prompt s6 "/vibe off"
[ -z "$OUT" ] || fail "unremovable marker: Spec announced anyway"
rmdir "$tmp/claudio-mode-s6"

if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
exit 1
