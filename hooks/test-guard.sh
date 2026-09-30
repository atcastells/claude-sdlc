#!/bin/bash
# test-guard: blocks edits that WEAKEN a test file.
# Playbook rule: "If a test fails, fix the code, not the test."
# PreToolUse hook on Write|Edit|MultiEdit|NotebookEdit. Exit 2 = block.

payload=$(cat)
path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null)

# Only guard test files
printf '%s' "$path" | grep -qEi '(\.|_)(test|spec)\.[a-z]+$|(^|/)(tests?|__tests__|spec)/' || exit 0

old=$(printf '%s' "$payload" | jq -r '[.tool_input.old_string?, (.tool_input.edits[]?.old_string)?] | map(select(.!=null)) | join("\n")' 2>/dev/null)
new=$(printf '%s' "$payload" | jq -r '[.tool_input.content?, .tool_input.new_string?, .tool_input.new_source?, (.tool_input.edits[]?.new_string)?] | map(select(.!=null)) | join("\n")' 2>/dev/null)

block() {
  printf '%s\n' "BLOCKED by test-guard in $(basename "$path"): $1
If a test fails, fix the code, not the test. If the test is genuinely wrong,
say so explicitly to the developer and wait for their decision." >&2
  exit 2
}

# 1. Introducing a skip / exclusive focus
added_skip=$(printf '%s' "$new" | grep -aoEm1 -e '\.skip\(|\.only\(|\bxit\(|\bxdescribe\(|@unittest\.skip|pytest\.mark\.skip|@Ignore|t\.Skip\(' ) || added_skip=""
if [ -n "$added_skip" ]; then
  printf '%s' "$old" | grep -qaF "$added_skip" || block "introduces '$added_skip' (disables or isolates a test)."
fi

# 2. Removing assertions (only meaningful on Edit, where we have both sides)
if [ -n "$old" ]; then
  # -o + wc -l counts occurrences; grep -c would count lines, and a test fits on one
  count() { printf '%s' "$1" | grep -aoE -e 'expect\(|assert[A-Za-z_]*\(|\bassert\b|should\.|\.toBe|require\.(New|Equal)' 2>/dev/null | wc -l | tr -d ' '; }
  o=$(count "$old"); n=$(count "$new")
  [ "$o" -gt 0 ] && [ "$n" -lt "$o" ] && block "removes assertions ($o -> $n)."
fi

# 3. Commenting out a test block
printf '%s' "$new" | grep -qaE '^[[:space:]]*(//|#)[[:space:]]*(it|test|describe|def test)' && block "comments out a test block."

exit 0
