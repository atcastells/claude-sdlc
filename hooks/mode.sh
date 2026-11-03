#!/bin/bash
# mode: per-session Vibe mode switch. /vibe turns it on, /vibe off returns to Spec.
# UserPromptSubmit toggles the session marker; SessionStart re-injects the Vibe notice
# after compact/resume and clears the marker on startup/clear. Never echoes the prompt.
# Always exit 0.

. "$(dirname "$0")/lib/mode.sh"

ON="claude-sdlc: this session is in Vibe mode (/vibe off returns to Spec). Follow ~/.claude/skills/vibe/SKILL.md (read it again after a compaction): read .sdlc/map.md and the open .sdlc/vibe/*.md first. Small, non-final changes open no .sdlc/<slug>/ and need no approval; promote an idea to intent.md when it settles. Git stays with the developer; credentials, the release rule and verifying before claiming still apply."
OFF="claude-sdlc: this session is back in Spec mode: the full artifact chain applies (intent, spec, approved plan)."

emit() {
  jq -n --arg e "$1" --arg c "$2" \
    '{hookSpecificOutput:{hookEventName:$e, additionalContext:$c}}'
}

payload=$(cat)
event=$(printf '%s' "$payload" | jq -r '.hook_event_name // ""' 2>/dev/null)
sid=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)
marker=$(mode_marker "$sid") || exit 0

case "$event" in
  UserPromptSubmit)
    first=$(printf '%s' "$payload" | jq -r '.prompt // "" | split("\n")[0]' 2>/dev/null)
    first="${first#"${first%%[![:space:]]*}"}"
    first="${first%"${first##*[![:space:]]}"}"
    rest="${first#/vibe}"
    [ "$first" = "/vibe" ] || [ "${rest# }" != "$rest" ] || exit 0
    read -r word _ <<< "$rest"
    if [ "$word" = off ]; then
      rm -f "$marker" 2>/dev/null
      [ -e "$marker" ] && exit 0
      emit UserPromptSubmit "$OFF"
    else
      # Never write through a planted link (shared /tmp): remove, then create exclusively
      rm -f "$marker"
      ( set -C; : > "$marker" ) 2>/dev/null || exit 0
      emit UserPromptSubmit "$ON"
    fi
    ;;
  SessionStart)
    src=$(printf '%s' "$payload" | jq -r '.source // ""' 2>/dev/null)
    case "$src" in
      compact|resume) [ -e "$marker" ] && emit SessionStart "$ON" ;;
      startup|clear) rm -f "$marker" ;;
    esac
    ;;
esac
exit 0
