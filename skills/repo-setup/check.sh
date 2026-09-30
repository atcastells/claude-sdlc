#!/bin/bash
# Audit a repo against the SDLC playbook and the installed rules. Deterministic
# checks only; judgement calls (is CLAUDE.md actually useful?) belong to the skill.
#   usage: check.sh [repo-path]   (default: cwd)
#   exit 0 = no FAIL; exit 1 = at least one FAIL. WARN never fails.
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/../../hooks/lib/semver.sh"
wf_home="${WORKFLOW_HOME:-$HOME/.claude/workflow}"
global_md="${CLAUDE_GLOBAL_MD:-$HOME/.claude/CLAUDE.md}"
# Absolute before cd into the repo
case "$wf_home" in /*) ;; *) wf_home="$PWD/$wf_home" ;; esac
case "$global_md" in /*) ;; *) global_md="$PWD/$global_md" ;; esac
repo="${1:-.}"
cd "$repo" 2>/dev/null || { echo "FAIL  no such directory: $repo"; exit 1; }

pass=0; fail=0; warn=0
ok()   { printf 'PASS  %s\n' "$1"; pass=$((pass+1)); }
ko()   { printf 'FAIL  %s\n' "$1"; fail=$((fail+1)); }
wn()   { printf 'WARN  %s\n' "$1"; warn=$((warn+1)); }

# --- CLAUDE.md -----------------------------------------------------------------
if [ -f CLAUDE.md ]; then
  ok "CLAUDE.md exists"
  n=$(wc -l < CLAUDE.md | tr -d ' ')
  [ "$n" -le 120 ] && ok "CLAUDE.md fits on one page ($n lines)" || wn "CLAUDE.md is long ($n lines, playbook: one page)"
  # Resent on every turn together with the global one: joint budget of 200 lines
  g=0; [ -f "$global_md" ] && g=$(wc -l < "$global_md" | tr -d ' ')
  [ $((n+g)) -le 200 ] && ok "CLAUDE.md global + project: $((n+g)) lines (<= 200)" \
    || ko "CLAUDE.md global + project: $((n+g)) lines (> 200; resent every turn, move detail to linked docs)"

  # Section names in English or Spanish: the CLAUDE.md follows the project's language
  for sec in 'Commands|Comandos' 'Conventions|Convenciones' 'Structure|Architecture|Estructura|Arquitectura' 'Security|Seguridad' 'Git'; do
    grep -qiE "^##+ .*($sec)" CLAUDE.md && ok "CLAUDE.md section: ${sec%%|*}" || ko "CLAUDE.md missing section: ${sec%%|*}"
  done
  grep -qiE '^##+ .*(claude gets wrong|claude (keeps|gets)|recurring mistakes|claude (se |falla|equivoca)|errores (recurrentes|frecuentes)|lo que claude)' CLAUDE.md \
    && ok "CLAUDE.md has 'What Claude gets wrong'" \
    || wn "CLAUDE.md has no 'What Claude gets wrong' section (fill it when a mistake repeats twice)"

  # File references: markdown links always; backticked paths only with a segment
  # on each side of a / (`src/x.ts` yes; `actions/` or `x.ts` no: they are relative
  # to a directory named in prose and would be false positives)
  refs=$(grep -oE '\]\(([^)#]+)\)|`\.?[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+`' CLAUDE.md \
         | sed -E 's/^\]\(//; s/\)$//; s/`//g; s:/$::' | grep -vE '^(https?:|#|@)' | sort -u)
  missing=0
  while IFS= read -r r; do
    [ -z "$r" ] && continue
    [ -e "$r" ] || { ko "CLAUDE.md references a missing path: $r"; missing=$((missing+1)); }
  done <<< "$refs"
  [ "$missing" -eq 0 ] && ok "CLAUDE.md: every referenced path exists"

  # npm/make commands mentioned actually exist
  if [ -f package.json ]; then
    for s in $(grep -oE 'npm run [a-zA-Z0-9:_-]+' CLAUDE.md | awk '{print $3}' | sort -u); do
      jq -e ".scripts[\"$s\"]" package.json >/dev/null 2>&1 && ok "npm script exists: $s" || ko "CLAUDE.md cites 'npm run $s' but package.json has no such script"
    done
  fi
  if [ -f Makefile ]; then
    for t in $(grep -oE 'make [a-zA-Z0-9_-]+' CLAUDE.md | awk '{print $2}' | sort -u); do
      grep -qE "^$t:" Makefile && ok "make target exists: $t" || ko "CLAUDE.md cites 'make $t' but the Makefile has no such target"
    done
  fi
else
  ko "CLAUDE.md does not exist"
fi

# --- Test command defined ------------------------------------------------------
if [ -f package.json ] && jq -e '.scripts.test' package.json >/dev/null 2>&1; then ok "test command: npm test"
elif [ -f Makefile ] && grep -qE '^test:' Makefile; then ok "test command: make test"
elif [ -f composer.json ] && jq -e '.scripts.test' composer.json >/dev/null 2>&1; then ok "test command: composer test"
elif [ -f pyproject.toml ] || [ -f pytest.ini ]; then ok "test command: pytest"
else wn "no test command detected (package.json/Makefile/composer.json/pytest)"; fi

# --- .claude/settings.json with git reserved -----------------------------------
if [ -f .claude/settings.json ]; then
  if jq -e '.permissions.deny[]? | select(test("git (commit|push)"))' .claude/settings.json >/dev/null 2>&1; then
    ok ".claude/settings.json denies git commit/push (deterministic backstop)"
  else
    ko ".claude/settings.json exists but does not deny git commit/push"
  fi
else
  ko ".claude/settings.json does not exist (git reserved only as an instruction, no backstop)"
fi

# --- Applied workflow version --------------------------------------------------
inst=$({ tr -d '[:space:]' < "$wf_home/VERSION"; } 2>/dev/null)
if ! is_semver "$inst"; then
  wn "no installed workflow version ($wf_home/VERSION): run install.sh"
elif [ -f .claude/workflow.json ]; then
  pv=$(jq -r '.workflow_version // empty' .claude/workflow.json 2>/dev/null)
  if ! is_semver "$pv"; then ko ".claude/workflow.json: workflow_version is not semver"
  elif ver_lt "$pv" "$inst"; then
    pend=$(pending_migrations "$wf_home/migrations" "$pv" "$inst" | cut -f1 | tr '\n' ' ' | sed 's/ $//')
    if [ -n "$pend" ]; then wn "workflow $pv < installed $inst: /repo-setup upgrade ($pend)"
    else ok "workflow $pv, no project changes up to $inst"; fi
  elif ver_lt "$inst" "$pv"; then wn "workflow $pv > installed $inst: update claude-sdlc and run install.sh"
  else ok "workflow up to date ($inst)"; fi
else
  wn ".claude/workflow.json does not exist: no record of which workflow version was applied"
fi

# --- Artifact chain ------------------------------------------------------------
[ -f REVIEW.md ] && ok "REVIEW.md (review policy) exists" || ko "REVIEW.md missing at the repo root"
[ -d .sdlc ] && ok ".sdlc/ exists" || ko ".sdlc/ does not exist (intent -> spec -> plan chain)"

# --- Sensitive files -----------------------------------------------------------
if [ -f .gitignore ]; then
  grep -qE '^\.env' .gitignore && ok ".gitignore covers .env*" || ko ".gitignore does not cover .env*"
  grep -qE '\.(keystore|p12|jks)' .gitignore && ok ".gitignore covers keystores/p12" || wn ".gitignore does not mention *.keystore / *.p12"
else
  ko ".gitignore does not exist"
fi

# Sensitive files tracked in git
if git rev-parse --git-dir >/dev/null 2>&1; then
  tracked=$(git ls-files 2>/dev/null | grep -E '(^|/)\.env(\.|$)|\.(p12|jks)$|\.keystore$' | grep -v 'debug\.keystore' | grep -vE '\.env\.(dist|example|sample|template)$')
  [ -z "$tracked" ] && ok "no sensitive files tracked" || { ko "sensitive files in git:"; printf '        %s\n' $tracked; }

  # Credentials in tracked files (same patterns as credential-guard)
  hits=$(git grep -nE 'squ_[0-9a-f]{40}|gh[pousr]_[A-Za-z0-9]{36}|AKIA[0-9A-Z]{16}|sk-ant-[A-Za-z0-9_-]{32,}|glpat-[A-Za-z0-9_-]{20}|BEGIN [A-Z ]*PRIVATE KEY' -- . ':!*.lock' 2>/dev/null | head -5)
  [ -z "$hits" ] && ok "no recognizable credentials in tracked files" || { ko "possible tracked credentials:"; printf '%s\n' "$hits" | sed 's/^/        /' | cut -c1-100; }
else
  wn "not a git repo: tracking checks skipped"
fi

echo "-----------------------------------------------------------"
echo "PASS: $pass   WARN: $warn   FAIL: $fail"
[ "$fail" -eq 0 ]
