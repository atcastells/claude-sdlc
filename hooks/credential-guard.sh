#!/bin/bash
# credential-guard: blocks Write/Edit/NotebookEdit when the content carries a hardcoded credential.
# Policy: credentials live in a secrets manager (named by the profile), never in the repo.
# PreToolUse hook. Exit 2 = block and report to the model.

. "$(dirname "$0")/lib/profile.sh"
load_profile

payload=$(cat)
content=$(printf '%s' "$payload" | jq -r '
  [.tool_input.content?, .tool_input.new_string?, .tool_input.new_source?, (.tool_input.edits[]?.new_string)?]
  | map(select(. != null)) | join("\n")' 2>/dev/null)

[ -z "$content" ] && exit 0

# High-confidence patterns only. Placeholders and env lookups are ignored below.
patterns=(
  'squ_[0-9a-f]{40}'                          # SonarQube
  '(ghp|gho|ghs|ghu|ghr)_[A-Za-z0-9]{36}'     # GitHub
  'AKIA[0-9A-Z]{16}'                          # AWS access key
  'sk-(proj-)?[A-Za-z0-9_-]{32,}'             # OpenAI-style
  'sk-ant-[A-Za-z0-9_-]{32,}'                 # Anthropic
  'xox[baprs]-[A-Za-z0-9-]{10,}'              # Slack
  'glpat-[A-Za-z0-9_-]{20}'                   # GitLab PAT
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'        # private keys
  '(password|passwd|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'$<{[:space:]]{12,}["'"'"']'
)

for p in "${patterns[@]}"; do
  hit=$(printf '%s' "$content" | grep -aoEm1 -e "$p") || continue
  # Ignore obvious placeholders / env indirection
  printf '%s' "$hit" | grep -qiE 'xxx|placeholder|example|changeme|your[_-]|dummy|fake|redacted|\$\{|process\.env|os\.environ' && continue
  printf '%s\n' "BLOCKED by credential-guard: the content contains what looks like a hardcoded credential (pattern: ${p:0:28}...). Credentials live in ${WF_SECRETS_MANAGER:-your secrets manager} and are injected through environment variables. Rewrite it using an env var reference." >&2
  exit 2
done

exit 0
