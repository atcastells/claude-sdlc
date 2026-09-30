#!/bin/bash
# Eval runner. Checks that the agent's configuration (CLAUDE.md, skills, hooks)
# still does what it should. Playbook: run it whenever the config changes.
#   usage: evals/run.sh [pattern]
# Root = the parent of evals/: in the repo it tests the repo, in ~/.claude it
# tests the installation. EVALS_ROOT overrides it; WORKFLOW_PROFILE=<dir> adds
# that profile's cases (repo mode).
set -uo pipefail
# Relative EVALS_ROOT/WORKFLOW_PROFILE resolve from the caller, before the cd
[ -n "${EVALS_ROOT:-}" ] && { EVALS_ROOT="$(cd "$EVALS_ROOT" && pwd)" || exit 1; }
[ -n "${WORKFLOW_PROFILE:-}" ] && { WORKFLOW_PROFILE="$(cd "$WORKFLOW_PROFILE" && pwd)" || exit 1; }
cd "$(dirname "$0")"
# Claude Code sets it for hooks; cases use their own payload.cwd
unset CLAUDE_PROJECT_DIR

root="${EVALS_ROOT:-$(cd .. && pwd)}"
root="$(cd "$root" && pwd)"
fixtures="$(pwd)/fixtures"
# In the repo some files live under a different name than once installed
[ -f "$root/install.sh" ] && mode=repo || mode=installed

profile="${WORKFLOW_PROFILE:-}"

# Expands {root}, {fixtures}, {profile} and ~ without evaluating the string as shell
expand() {
  local s="${1//\{root\}/$root}"
  s="${s//\{fixtures\}/$fixtures}"
  s="${s//\{profile\}/$profile}"
  printf '%s' "${s/#\~/$HOME}"
}

pat="${1:-*}"
pass=0; fail=0; failed=()

# Repo mode: WORKFLOW_PROFILE=<dir> adds the profile cases
case_files=(cases/$pat.json)
[ -n "$profile" ] && [ "$mode" = repo ] && case_files+=("$profile"/evals/cases/$pat.json)

for f in "${case_files[@]}"; do
  [ -e "$f" ] || continue
  name=$(jq -r '.name' "$f")
  kind=$(jq -r '.kind' "$f")
  printf '%-58s' "$name"
  detail=""
  # Cases about files that only exist in the repo (scripts/, profiles/)
  if [ "$mode" = installed ] && [ "$(jq -r '.repo_only // false' "$f")" = true ]; then
    echo "SKIP (repo only)"; continue
  fi

  target_file() {
    local t
    if [ "$mode" = repo ] && jq -e 'has("file_repo")' "$f" >/dev/null; then t=$(jq -r '.file_repo' "$f")
    else t=$(jq -r '.file' "$f"); fi
    expand "$t"
  }

  case "$kind" in
    hook)
      # .hook: script in hooks/ | .script: path relative to the root. Optional:
      # .args[], .env{}, .contains / .not_contains on the output
      if jq -e 'has("script")' "$f" >/dev/null; then script="$root/$(jq -r '.script' "$f")"
      else script="../hooks/$(jq -r '.hook' "$f")"; fi
      payload=$(expand "$(jq -c '.payload // {}' "$f")")
      want=$(jq -r '.expect_exit // 0' "$f")
      args=()
      while IFS= read -r a; do [ -n "$a" ] && args+=("$(expand "$a")"); done < <(jq -r '.args[]?' "$f")
      envs=()
      while IFS= read -r kv; do [ -n "$kv" ] && envs+=("$(expand "$kv")"); done < <(jq -r '.env // {} | to_entries[] | "\(.key)=\(.value)"' "$f")
      # .capture: "stdout" (default) or "all" (stdout + stderr, for block messages)
      if [ "$(jq -r '.capture // "stdout"' "$f")" = all ]; then
        out=$(printf '%s' "$payload" | env ${envs[@]+"${envs[@]}"} bash "$script" ${args[@]+"${args[@]}"} 2>&1)
      else
        out=$(printf '%s' "$payload" | env ${envs[@]+"${envs[@]}"} bash "$script" ${args[@]+"${args[@]}"} 2>/dev/null)
      fi
      got=$?
      if [ "$got" = "$want" ]; then
        needle=$(jq -r '.contains // empty' "$f")
        if [ -n "$needle" ] && ! printf '%s' "$out" | grep -qaF -- "$needle"; then got=x; detail="output lacks '$needle'"; fi
        needle=$(jq -r '.not_contains // empty' "$f")
        if [ -n "$needle" ] && printf '%s' "$out" | grep -qaF -- "$needle"; then got=x; detail="output has '$needle'"; fi
      fi
      ;;
    file_contains)
      target=$(target_file)
      needle=$(jq -r '.contains' "$f")
      want=0
      grep -qaF -- "$needle" "$target" 2>/dev/null && got=0 || got=1
      ;;
    file_absent)
      target=$(target_file)
      want=0
      [ -e "$target" ] && got=1 || got=0
      ;;
    max_lines)
      target=$(target_file)
      max=$(jq -r '.max' "$f")
      want=0
      n=$(wc -l < "$target" 2>/dev/null | tr -d ' ')
      [ -n "$n" ] && [ "$n" -le "$max" ] && got=0 || { got=1; detail="${n:-no file} > $max lines"; }
      ;;
    *) echo "SKIP (unknown kind: $kind)"; continue ;;
  esac

  if [ "$got" = "$want" ]; then echo "PASS"; pass=$((pass+1))
  else echo "FAIL (exit=$got, expected=$want${detail:+; $detail})"; fail=$((fail+1)); failed+=("$name"); fi
done

echo "---------------------------------------------------------"
echo "PASS: $pass   FAIL: $fail   ($mode: $root${profile:+; profile: $profile})"
if [ "$fail" -gt 0 ]; then
  printf 'Failed:\n'; printf '  - %s\n' "${failed[@]}"
  exit 1
fi
