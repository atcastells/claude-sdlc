#!/bin/bash
# Scenarios for install.sh profiles, each on a throwaway HOME.
# The installer's own eval run is skipped (WORKFLOW_INSTALL_NO_VERIFY=1) to keep
# this under the PostToolUse timeout; the suite runs separately.
#   usage: install-test.sh <repo-root>
set -uo pipefail
src="$1"
fx="$src/evals/fixtures/profile-acme"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export WORKFLOW_INSTALL_NO_VERIFY=1
fails=0
check() { if eval "$2"; then :; else echo "  FAIL $1"; fails=$((fails+1)); fi; }
inst() { HOME="$1" bash "$src/install.sh" "${@:2}" </dev/null >"$1.log" 2>&1; }

# 1. No profile: core CLAUDE.md only, no profile.env
h="$tmp/none"; mkdir -p "$h"; inst "$h" --no-profile
check "no-profile installs" "[ -f '$h/.claude/workflow/VERSION' ]"
check "no-profile CLAUDE.md == core" "cmp -s '$src/global/CLAUDE.md' '$h/.claude/CLAUDE.md'"
check "no-profile has no profile.env" "[ ! -e '$h/.claude/workflow/profile.env' ]"

# 2. With profile: composed CLAUDE.md, profile.env, p-* evals, merged deny
h="$tmp/acme"; mkdir -p "$h"; inst "$h" --profile "$fx"
check "profile CLAUDE.md == core + profile" "cmp -s <(cat '$src/global/CLAUDE.md'; echo; cat '$fx/CLAUDE.md') '$h/.claude/CLAUDE.md'"
check "profile.env installed" "cmp -s '$fx/profile.env' '$h/.claude/workflow/profile.env'"
check "profile evals copied as p-*" "[ -f '$h/.claude/evals/cases/p-acme-rule.json' ]"
check "profile deny merged into settings" "jq -e '.permissions.deny | index(\"Bash(acme-deploy *)\")' '$h/.claude/settings.json' >/dev/null"
check "core deny kept alongside profile deny" "jq -e '.permissions.deny | index(\"Bash(git push *)\")' '$h/.claude/settings.json' >/dev/null"
check "profile path remembered" "[ \"\$(cat '$h/.claude/workflow/profile')\" = '$fx' ]"
check "denylist not installed" "[ ! -e '$h/.claude/workflow/denylist.txt' ]"

# 3. Reinstall without flags keeps the remembered profile
inst "$h"
check "reinstall keeps profile" "grep -q 'pirate speak' '$h/.claude/CLAUDE.md'"

# 4. Switching to --no-profile removes profile evals and profile.env
inst "$h" --no-profile
check "--no-profile prunes p-* evals" "[ ! -e '$h/.claude/evals/cases/p-acme-rule.json' ]"
check "--no-profile removes profile.env" "[ ! -e '$h/.claude/workflow/profile.env' ]"

# 5. Upgrading a 1.x machine with no flag, non-interactive: refuse, change nothing
h="$tmp/old"; mkdir -p "$h/.claude/workflow"; echo 1.1.0 > "$h/.claude/workflow/VERSION"
echo '# old rules' > "$h/.claude/CLAUDE.md"
inst "$h"; code=$?
check "1.x upgrade without --profile/--no-profile exits non-zero" "[ $code -ne 0 ]"
check "1.x upgrade refusal leaves CLAUDE.md untouched" "grep -q 'old rules' '$h/.claude/CLAUDE.md'"
check "1.x upgrade refusal explains --profile" "grep -q -- '--profile' '$h.log'"

# 5b. A 1.0.0 machine has no workflow/VERSION at all, only the old hooks: same refusal
h="$tmp/v100"; mkdir -p "$h/.claude/hooks"; echo '# 1.0.0 hook' > "$h/.claude/hooks/credential-guard.sh"
echo '# old rules' > "$h/.claude/CLAUDE.md"
inst "$h"; code=$?
check "1.0.0 machine (no VERSION) without --profile/--no-profile exits non-zero" "[ $code -ne 0 ]"
check "1.0.0 refusal leaves CLAUDE.md untouched" "grep -q 'old rules' '$h/.claude/CLAUDE.md'"

# 5c. An unreadable workflow/VERSION is treated as the oldest release: same refusal
h="$tmp/garbled"; mkdir -p "$h/.claude/workflow"; echo 'abc' > "$h/.claude/workflow/VERSION"
echo '# old rules' > "$h/.claude/CLAUDE.md"
inst "$h"; code=$?
check "garbled VERSION without --profile/--no-profile exits non-zero" "[ $code -ne 0 ]"

# 6. Unknown profile path fails cleanly
h="$tmp/bad"; mkdir -p "$h"; inst "$h" --profile "$tmp/does-not-exist"; code=$?
check "missing profile dir exits non-zero" "[ $code -ne 0 ]"

[ "$fails" -eq 0 ] && echo "install scenarios: all passed" || echo "install scenarios: $fails failed"
[ "$fails" -eq 0 ]
