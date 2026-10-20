#!/bin/bash
# Credential patterns shared by hooks. Source it; defines data and functions only.
# credential-guard blocks writes that match them; task-actuals redacts them.

# High-confidence patterns only (ERE).
LEAK_PATTERNS=(
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

# URL with user:password
LEAK_URL_PATTERN='[A-Za-z][A-Za-z0-9+.-]*://[^/@ ]+:[^/@ ]+@'

# leak_patterns_json -> JSON array with every pattern plus the URL one, to pass
# to jq as data (--argjson) and use with gsub
leak_patterns_json() {
  printf '%s\n' "${LEAK_PATTERNS[@]}" "$LEAK_URL_PATTERN" | jq -R -s -c 'split("\n") | map(select(. != ""))'
}
