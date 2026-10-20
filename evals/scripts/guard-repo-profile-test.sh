#!/bin/bash
# Scenarios: credential-guard and production-gate with a repo profile.
# The repo names are used only for a regular small profile.env; symlinked,
# oversized or undeclared profiles fall back to the global names; exit 2 always.
#   usage: guard-repo-profile-test.sh <hooks-dir>
set -uo pipefail
hooks="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp" CLAUDE_SDLC_ACTUALS="$tmp/actuals"
mkdir -p "$tmp/home" "$tmp/actuals"
export WORKFLOW_HOME="$tmp/home"
printf '%s\n' 'WF_SECRETS_MANAGER="global-vault"' 'WF_POLICY_NAME="global policy"' > "$tmp/home/profile.env"
unset CLAUDE_PROJECT_DIR RELEASE_APPROVAL
fails=0
fail() { echo "  FAIL $1: $2"; fails=$((fails+1)); }

REPO_VAULT="repo-vault"; REPO_POLICY="repo policy"
GLOBAL_VAULT="global-vault"; GLOBAL_POLICY="global policy"

# mkrepo <name> <declare yes|no> -> dir with .claude/profile
mkrepo() {
  local d="$tmp/$1"
  mkdir -p "$d/.claude/profile"
  [ "$2" = yes ] && printf '%s\n' '{"profile": ".claude/profile"}' > "$d/.claude/workflow.json"
  printf '%s\n' "WF_SECRETS_MANAGER=\"$REPO_VAULT\"" "WF_POLICY_NAME=\"$REPO_POLICY\"" > "$d/.claude/profile/profile.env"
  echo "$d"
}

cred="AKIA$(printf '%016d' 0)"
w1="prod"; w2="uction"
cmd="kubectl -n ${w1}${w2} rollout restart deploy/api"

# run <hook> <cwd> -> sets rc, err
run() {
  local h="$1" cwd="$2" t0 t1
  if [ "$h" = credential-guard.sh ]; then
    jq -n --arg c "$cwd" --arg k "$cred" '{cwd:$c, tool_name:"Write", tool_input:{file_path:"x.txt", content:("K=" + $k)}}'
  else
    jq -n --arg c "$cwd" --arg m "$cmd" '{cwd:$c, tool_name:"Bash", tool_input:{command:$m}}'
  fi | bash "$hooks/$h" >"$tmp/out" 2>"$tmp/err"
  rc=$?
}

# check <label> <hook> <cwd> <expected-name> <other-name> [max-seconds]
check() {
  local label="$1" h="$2" cwd="$3" want="$4" other="$5" max="${6:-}" s e
  s=$(date +%s)
  run "$h" "$cwd"
  e=$(date +%s)
  [ "$rc" -eq 2 ] || fail "$label/$h" "expected exit 2, got $rc"
  grep -qF -- "$want" "$tmp/err" || fail "$label/$h" "stderr lacks '$want'"
  ! grep -qF -- "$other" "$tmp/err" || fail "$label/$h" "stderr has '$other'"
  [ -z "$max" ] || [ $((e - s)) -lt "$max" ] || fail "$label/$h" "took $((e - s)) s"
}

for h in credential-guard.sh production-gate.sh; do
  if [ "$h" = credential-guard.sh ]; then
    rname="$REPO_VAULT"; gname="$GLOBAL_VAULT"
  else
    rname="$REPO_POLICY"; gname="$GLOBAL_POLICY"
  fi

  # a. declared, regular, small -> repo names
  d=$(mkrepo a yes)
  check a "$h" "$d" "$rname" "$gname"

  # b. profile.env symlinked to a file outside the repo -> global names
  d=$(mkrepo b yes)
  mkdir -p "$tmp/outside"
  printf '%s\n' "WF_SECRETS_MANAGER=\"$REPO_VAULT\"" "WF_POLICY_NAME=\"$REPO_POLICY\"" > "$tmp/outside/profile.env"
  rm "$d/.claude/profile/profile.env"
  ln -s "$tmp/outside/profile.env" "$d/.claude/profile/profile.env"
  check b "$h" "$d" "$gname" "$rname"

  # c. profile.env over 4 KB -> global names, fast
  d=$(mkrepo c yes)
  {
    printf '%s\n' "WF_SECRETS_MANAGER=\"$REPO_VAULT\"" "WF_POLICY_NAME=\"$REPO_POLICY\""
    head -c 6000 /dev/zero | tr '\0' 'x'
    printf '\n'
  } > "$d/.claude/profile/profile.env"
  check c "$h" "$d" "$gname" "$rname" 2

  # d. no .claude/workflow.json -> global names
  d=$(mkrepo d no)
  check d "$h" "$d" "$gname" "$rname"
done

if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails scenario(s) failed"; exit 1; fi
