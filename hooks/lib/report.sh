#!/bin/bash
# Subagent report reader shared by hooks. Source it; defines functions only.
# Transcripts are read as jq input (never through --arg: ARG_MAX is 1 MB on macOS).

# subagent_report <payload-json> -> prints the subagent's report.
# It is the "message" input of the last SubagentHandback tool use found in the
# file at .agent_transcript_path; without one (or without a readable file) it
# is .last_assistant_message. Lines that are not JSON are skipped. Returns 0.
subagent_report() {
  local payload="${1:-}" path out
  path=$(printf '%s' "$payload" | jq -r '.agent_transcript_path // empty' 2>/dev/null)
  if [ -n "$path" ] && [ -r "$path" ] && [ -f "$path" ]; then
    out=$(jq -Rrn '
      [ inputs | fromjson? | objects
        | (.message.content // .content // empty) | arrays | .[]
        | select(type == "object" and .type == "tool_use" and .name == "SubagentHandback")
        | .input.message | strings ] | last // empty' "$path" 2>/dev/null)
    if [ -n "$out" ]; then
      printf '%s\n' "$out"
      return 0
    fi
  fi
  printf '%s\n' "$payload" | jq -r '.last_assistant_message // ""' 2>/dev/null
  return 0
}
