#!/bin/bash
# Scenarios for install.sh --company-repo, each on a throwaway HOME.
#   usage: company-install-test.sh <repo-root>
set -uo pipefail
src="$1"
fx="$src/evals/fixtures/profile-company"
co="$src/evals/fixtures/company-acme"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export WORKFLOW_INSTALL_NO_VERIFY=1
fails=0
check() { if eval "$2"; then :; else echo "  FAIL $1"; fails=$((fails+1)); fi; }
inst() { HOME="$1" bash "$src/install.sh" "${@:2}" </dev/null >"$1.log" 2>&1; }
body() { awk 'NR==1 && $0=="---" {fm=1; next} fm==1 {if ($0=="---") fm=2; next} fm==2 {fm=0; if ($0=="") next} {print}' "$1"; }

# 1. Composition: core + rules without frontmatter + profile, in order
h="$tmp/ok"; mkdir -p "$h"; inst "$h" --profile "$fx" --company-repo "$co"; rc=$?
check "install succeeds" "[ $rc -eq 0 ]"
exp="$tmp/exp"
{ cat "$src/global/CLAUDE.md"; echo; body "$co/docs/rules.md"; echo; cat "$fx/CLAUDE.md"; } > "$exp"
check "composed == core + rules(no frontmatter) + profile" "cmp -s '$exp' '$h/.claude/CLAUDE.md'"
check "no frontmatter left" "! grep -q '^description:' '$h/.claude/CLAUDE.md'"
check "company dir saved" "[ \"\$(cat '$h/.claude/workflow/company-repo')\" = '$co' ]"

# 2. Second install without the flag reuses the saved dir
inst "$h"; rc=$?
check "reinstall succeeds" "[ $rc -eq 0 ]"
check "reinstall keeps company rules" "grep -q 'formal English' '$h/.claude/CLAUDE.md'"

# 3. --no-profile removes company-repo
inst "$h" --no-profile
check "--no-profile removes company-repo" "[ ! -e '$h/.claude/workflow/company-repo' ]"

# 4. Profile without company.json: byte-identical to core + profile
h="$tmp/plain"; mkdir -p "$h"; inst "$h" --profile "$src/evals/fixtures/profile-acme"
check "no company.json: core + profile" "cmp -s <(cat '$src/global/CLAUDE.md'; echo; cat '$src/evals/fixtures/profile-acme/CLAUDE.md') '$h/.claude/CLAUDE.md'"
check "no company.json: no company-repo" "[ ! -e '$h/.claude/workflow/company-repo' ]"

# 5. No tty, no saved dir: exit 1, message, nothing created
h="$tmp/notty"; mkdir -p "$h"; inst "$h" --profile "$fx"; rc=$?
check "no tty: exit 1" "[ $rc -eq 1 ]"
check "no tty: names the flag" "grep -qF -- '--company-repo' '$h.log'"
check "no tty: shows clone command" "grep -qF 'git clone https://git.example.com/acme/docs.git' '$h.log'"
check "no tty: ~/.claude not created" "[ ! -e '$h/.claude' ]"

# 6. Rules validation
bad() { # name, rules value, repo-setup commands
  local n="$1" r="$2" setup="$3" repo="$tmp/repo-$1" p="$tmp/prof-$1" hh="$tmp/h-$1"
  mkdir -p "$repo" "$hh" "$p"; cp "$fx/CLAUDE.md" "$p/"
  ( cd "$repo" && eval "$setup" )
  jq -n --arg r "$r" '{url:"https://git.example.com/acme/docs.git",rules:$r}' > "$p/company.json"
  inst "$hh" --profile "$p" --company-repo "$repo"; local rc=$?
  check "$n: exit 1" "[ $rc -eq 1 ]"
  check "$n: message" "grep -q 'company rules:' '$hh.log'"
  check "$n: nothing written" "[ ! -e '$hh/.claude' ]"
}
echo outside > "$tmp/outside.md"
bad dotdot "../x" "true"
bad absolute "/etc/hosts" "true"
bad symlink "r.md" "ln -s '$tmp/outside.md' r.md"
bad missing "nope.md" "true"
bad big "r.md" "head -c 16385 /dev/zero | tr '\\0' a > r.md"
bad empty "" "true"
bad dirrules "d" "mkdir d"

# 7. Option without value
HOME="$tmp/x" bash "$src/install.sh" --company-repo >/dev/null 2>&1; rc=$?
check "--company-repo without value: exit 2" "[ $rc -eq 2 ]"

# 8. Unclosed frontmatter is not frontmatter: the rules are kept whole
u="$tmp/unclosed"; mkdir -p "$u/docs"; printf -- '---\ndescription: x\n\n## Rules\nline A\n' > "$u/docs/rules.md"
h="$tmp/uf"; mkdir -p "$h"; inst "$h" --profile "$fx" --company-repo "$u"; rc=$?
check "unclosed frontmatter: install succeeds" "[ $rc -eq 0 ]"
check "unclosed frontmatter: rules kept" "grep -q 'line A' '$h/.claude/CLAUDE.md'"

# 9. --company-repo with a profile without company.json: refused, nothing created
h="$tmp/nocj"; mkdir -p "$h"; inst "$h" --profile "$src/evals/fixtures/profile-acme" --company-repo "$co"; rc=$?
check "--company-repo without company.json: exit 2" "[ $rc -eq 2 ]"
check "--company-repo without company.json: message" "grep -q 'company.json' '$h.log'"
check "--company-repo without company.json: nothing created" "[ ! -e '$h/.claude' ]"

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
