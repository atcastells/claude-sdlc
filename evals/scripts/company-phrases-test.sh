#!/bin/bash
# company.json "spinner_verbs" validation in install.sh, one scenario per call.
#   usage: company-phrases-test.sh <repo-root> <scenario>
# Fixtures are generated at runtime on a throwaway repo and HOME.
set -uo pipefail
src="$1"; sc="$2"
inst_sh="${INSTALL_SH:-$src/install.sh}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export WORKFLOW_INSTALL_NO_VERIFY=1
repo="$tmp/repo"; p="$tmp/prof"; h="$tmp/home"
mkdir -p "$repo/docs" "$p" "$h"
cp "$src/evals/fixtures/company-acme/docs/rules.md" "$repo/docs/rules.md"
cp "$src/evals/fixtures/profile-company/CLAUDE.md" "$p/"
verbs="docs/phrases.json"; valid='["Thinking about the thing","Pensando en el codigo","Buscando el punto y coma"]'
echo "$valid" > "$repo/$verbs"
expect=fail
case "$sc" in
  valid) expect=ok ;;
  missing) verbs="docs/nope.json" ;;
  dotdot) verbs="../phrases.json" ;;
  symlink) echo "$valid" > "$tmp/outside.json"; ln -s "$tmp/outside.json" "$repo/docs/link.json"; verbs="docs/link.json" ;;
  notarray) echo '{"a":"b"}' > "$repo/$verbs" ;;
  toomany) jq -n '[range(201)|"phrase \(.)"]' > "$repo/$verbs" ;;
  longitem) jq -n --arg s "$(printf 'a%.0s' $(seq 81))" '["ok",$s]' > "$repo/$verbs" ;;
  settings-replace|settings-nokey|settings-fresh) expect=settings ;;
  control) jq -n '["ok","bad\u0007bell"]' > "$repo/$verbs" ;;
  multivalue) { jq -n '[range(201)|"x"]'; echo '["ok"]'; } > "$repo/$verbs" ;;
  c1control) jq -n '["ok","bad\u009bcsi"]' > "$repo/$verbs" ;;
  bidi) jq -n '["ok","a‮b"]' > "$repo/$verbs" ;;
  blank) jq -n '["ok","   "]' > "$repo/$verbs" ;;
  *) echo "unknown scenario: $sc"; exit 2 ;;
esac
if [ "$expect" = settings ]; then
  mine='{"mode":"append","verbs":["My own phrase","Otra mia"]}'
  case "$sc" in
    settings-replace|settings-nokey)
      mkdir -p "$h/.claude"
      jq -n --argjson s "$mine" '{model:"opus",spinnerVerbs:$s,env:{KEEP:"1"}}' > "$h/.claude/settings.json" ;;
  esac
  jq -n '{url:"https://git.example.com/acme/docs.git",rules:"docs/rules.md"}' > "$p/company.json"
  if [ "$sc" != settings-nokey ]; then
    jq '.spinner_verbs="docs/phrases.json"' "$p/company.json" > "$p/c.tmp" && mv "$p/c.tmp" "$p/company.json"
  fi
  HOME="$h" bash "$inst_sh" --profile "$p" --company-repo "$repo" </dev/null >"$tmp/log" 2>&1 || { echo "FAIL $sc: install failed"; cat "$tmp/log"; exit 1; }
  st="$h/.claude/settings.json"
  fail() { echo "FAIL $sc: $1"; exit 1; }
  case "$sc" in
    settings-replace)
      jq -e --argjson v "$valid" '.spinnerVerbs=={mode:"replace",verbs:$v} and .model=="opus" and .env.KEEP=="1"' "$st" >/dev/null || fail "verbs not replaced or other keys lost"
      bak=$(ls "$h/.claude"/settings.json.bak-* 2>/dev/null | head -1); [ -n "$bak" ] || fail "no backup"
      jq -e --argjson s "$mine" '.spinnerVerbs==$s' "$bak" >/dev/null || fail "backup lacks the old verbs"
      grep -q 'progress phrases: 3 from the company profile' "$tmp/log" || fail "no output line" ;;
    settings-nokey)
      jq -e --argjson s "$mine" '.spinnerVerbs==$s' "$st" >/dev/null || fail "user spinnerVerbs changed"
      ! grep -q 'progress phrases' "$tmp/log" || fail "unexpected output line" ;;
    settings-fresh)
      jq -e --argjson v "$valid" '.spinnerVerbs=={mode:"replace",verbs:$v}' "$st" >/dev/null || fail "fresh settings lack the phrases" ;;
  esac
  echo "scenario $sc: all passed"; exit 0
fi
jq -n --arg v "$verbs" '{url:"https://git.example.com/acme/docs.git",rules:"docs/rules.md",spinner_verbs:$v}' > "$p/company.json"
HOME="$h" bash "$inst_sh" --profile "$p" --company-repo "$repo" </dev/null >"$tmp/log" 2>&1; rc=$?
if [ "$expect" = ok ]; then
  [ "$rc" -eq 0 ] && [ -f "$h/.claude/CLAUDE.md" ] && echo "scenario $sc: all passed" && exit 0
  echo "FAIL $sc: expected install to succeed (rc=$rc)"; cat "$tmp/log"; exit 1
fi
[ "$rc" -eq 1 ] || { echo "FAIL $sc: expected exit 1, got $rc"; exit 1; }
grep -q 'company phrases:' "$tmp/log" || { echo "FAIL $sc: no 'company phrases:' message"; exit 1; }
[ ! -e "$h/.claude" ] || { echo "FAIL $sc: something was written"; exit 1; }
echo "scenario $sc: all passed"
