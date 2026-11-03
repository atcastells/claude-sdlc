#!/bin/bash
# Scenarios: hooks/lib/mode.sh marker path and session id validation.
#   usage: mode-lib-test.sh <hooks-dir>
set -uo pipefail
hooks="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp"
fails=0
fail() { echo "  FAIL $1"; fails=$((fails+1)); }

# shellcheck disable=SC1091
. "$hooks/lib/mode.sh" 2>/dev/null || { echo "  FAIL cannot source $hooks/lib/mode.sh"; exit 1; }

out=$(mode_marker "abc-123_X"); rc=$?
[ "$rc" = 0 ] || fail "valid id: rc=$rc"
[ "$out" = "$tmp/claude-sdlc-mode-abc-123_X" ] || fail "valid id: path '$out'"

TMPDIR="$tmp/" out=$(mode_marker "s1")
[ "$out" = "$tmp/claude-sdlc-mode-s1" ] || fail "trailing slash in TMPDIR: '$out'"

for bad in "" "../x" "a b" "a/b"; do
  out=$(mode_marker "$bad"); rc=$?
  [ "$rc" = 1 ] || fail "invalid id '$bad': rc=$rc"
  [ -z "$out" ] || fail "invalid id '$bad': output '$out'"
  mode_is_vibe "$bad" && fail "invalid id '$bad': mode_is_vibe true"
done

mode_is_vibe "s1" && fail "mode_is_vibe true without marker"
: > "$tmp/claude-sdlc-mode-s1"
mode_is_vibe "s1" || fail "mode_is_vibe false with marker"
mode_is_vibe "s2" && fail "mode_is_vibe true for another id"

if [ "$fails" -eq 0 ]; then echo "all passed"; exit 0; fi
exit 1
