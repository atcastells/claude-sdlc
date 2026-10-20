#!/bin/bash
# Profile loader shared by hooks and install.sh. Source it; defines functions only.
# profile.env is data, not code: it is never sourced. Only whitelisted WF_* keys
# with printable values are read, so "$(...)" in a value stays a literal string.

WF_PROFILE_KEYS="WF_ORG_NAME WF_SECRETS_MANAGER WF_COMPLIANCE_CONTACT WF_POLICY_NAME"

# load_profile [FILE] -> sets the WF_* variables found in FILE
# Default FILE: $WORKFLOW_HOME/profile.env (WORKFLOW_HOME defaults to ~/.claude/workflow)
load_profile() {
  local f="${1:-${WORKFLOW_HOME:-$HOME/.claude/workflow}/profile.env}" line k v
  [ -f "$f" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    [[ "$line" =~ ^(WF_[A-Z_]+)=(.*)$ ]] || continue
    k="${BASH_REMATCH[1]}"; v="${BASH_REMATCH[2]}"
    case " $WF_PROFILE_KEYS " in *" $k "*) ;; *) continue ;; esac
    # Optional surrounding double quotes
    if [[ "$v" =~ ^\"(.*)\"$ ]]; then v="${BASH_REMATCH[1]}"; fi
    # Reject control characters and overlong values. Checked byte-wise in the C
    # locale so the result does not depend on the caller's locale (UTF-8 accents
    # are allowed; [[:print:]] would drop them under LC_ALL=C).
    local LC_ALL=C
    [[ "$v" =~ [[:cntrl:]] ]] && continue
    [ "${#v}" -le 400 ] || continue
    printf -v "$k" '%s' "$v"
  done < "$f"
}

# project_profile_dir CWD -> prints the absolute dir of the profile CWD's
# .claude/workflow.json declares ("profile": "<relative dir>").
# Return 0 = valid dir printed; 1 = nothing declared; 2 = declared but invalid
# (absolute, with "..", or resolving outside CWD, e.g. via symlink); 3 = declared
# (relative, no "..") but the directory does not exist.
project_profile_dir() {
  local cwd="$1" wf v root dir
  [ -n "$cwd" ] || return 1
  wf="$cwd/.claude/workflow.json"
  [ -f "$wf" ] || return 1
  v=$(jq -r '.profile // empty | tostring' "$wf" 2>/dev/null) || return 1
  [ -n "$v" ] || return 1
  case "$v" in
    /*|..|../*|*/..|*/../*|*$'\n'*) return 2 ;;
  esac
  root=$(cd "$cwd" 2>/dev/null && pwd -P) || return 1
  dir=$(cd "$cwd/$v" 2>/dev/null && pwd -P) || return 3
  case "$dir/" in "$root"/*) ;; *) return 2 ;; esac
  [ "$dir" != "$root" ] || return 2
  printf '%s\n' "$dir"
}

# project_profile_file CWD NAME [MAX_BYTES] -> prints CWD's profile dir/NAME only
# if the profile dir is valid and NAME is a regular file, not a symlink,
# physically inside that dir, of at most MAX_BYTES (default 4096; checked before
# anything reads the content). Returns 1 otherwise, 4 when only the size failed.
project_profile_file() {
  local dir f max="${3:-4096}" size
  dir=$(project_profile_dir "$1") || return 1
  f="$dir/$2"
  [ -f "$f" ] && [ ! -L "$f" ] || return 1
  [ "$(cd "$(dirname "$f")" 2>/dev/null && pwd -P)" = "$dir" ] || return 1
  size=$(wc -c < "$f" | tr -d ' ')
  [ "$size" -le "$max" ] 2>/dev/null || return 4
  printf '%s\n' "$f"
}
