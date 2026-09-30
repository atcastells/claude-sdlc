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
