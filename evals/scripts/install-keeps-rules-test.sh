#!/bin/bash
# install.sh must leave ~/.claude/rules/ alone, on a first install and on an
# upgrade (second run, with a manifest). Throwaway HOME; installer's own eval
# run skipped (WORKFLOW_INSTALL_NO_VERIFY=1).
#   usage: install-keeps-rules-test.sh <repo-root>
set -uo pipefail
src="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export WORKFLOW_INSTALL_NO_VERIFY=1
fail() { echo "FAIL: $1"; exit 1; }

h="$tmp/home"
mkdir -p "$h/.claude/rules/personal"
printf 'personal rule body\n' > "$h/.claude/rules/personal/x.md"
printf 'shared rule body\n' > "$h/.claude/rules/y.md"
printf 'personal rule body\n' > "$tmp/x.expected"
printf 'shared rule body\n' > "$tmp/y.expected"

inst() {
  out=$(HOME="$h" bash "$src/install.sh" --no-profile </dev/null 2>&1) \
    || { echo "$out"; fail "install.sh ($1) exited non-zero"; }
}
verify() {
  [ -f "$h/.claude/rules/personal/x.md" ] || fail "$1: rules/personal/x.md missing"
  [ -f "$h/.claude/rules/y.md" ] || fail "$1: rules/y.md missing"
  cmp -s "$tmp/x.expected" "$h/.claude/rules/personal/x.md" || fail "$1: x.md changed"
  cmp -s "$tmp/y.expected" "$h/.claude/rules/y.md" || fail "$1: y.md changed"
  if [ -d "$h/.claude/backups" ] && find "$h/.claude/backups" -path '*rules*' | grep -q .; then
    fail "$1: backups contain a rules/ path"
  fi
}

inst first;  verify "first install"
inst second; verify "second install (upgrade)"
echo "all passed"
