#!/bin/bash
# production-gate: blocks commands targeting production without RELEASE_APPROVAL.
# Policy: the agent never acts on production. This is the deterministic backstop.
# PreToolUse hook on Bash. Exit 2 = block.

. "$(dirname "$0")/lib/profile.sh"
load_profile

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# This hook's own name in docs is not an environment: without stripping it,
# writing a CHANGELOG that also mentions "git push" got blocked. Only the docs
# forms (backticked, or the .sh file): the bare name may be a real namespace
# (production-gate, production-gateway...).
scan=$(printf '%s' "$cmd" | sed -e 's/`production-gate`//g' -e 's/production-gate\.sh//g')

# Does the command reference production as a whole word or name segment?
printf '%s' "$scan" | grep -qaEi '(^|[^a-z0-9])(prod|production)([^a-z0-9]|$)' || exit 0

# Is it an action, not a read? Reads against prod are still discouraged but not gated here.
printf '%s' "$scan" | grep -qaEi '\b(deploy|release|publish|apply|push|migrate|rollout|restart|scale|delete|drop|truncate|terraform|helm|kubectl|eas|fastlane)\b' || exit 0

if [ -z "${RELEASE_APPROVAL:-}" ]; then
  printf '%s\n' "BLOCKED by production-gate: the command targets production and RELEASE_APPROVAL is not set.

  Command: $cmd

${WF_POLICY_NAME:-Workflow policy}: the agent never acts on production. Production
releases are run by the release manager, not the agent. If this is a false
positive (the word 'prod' appears in another context), rephrase the command." >&2
  exit 2
fi

printf '%s\n' "production-gate: RELEASE_APPROVAL set, allowed. Command: $cmd" >&2
exit 0
