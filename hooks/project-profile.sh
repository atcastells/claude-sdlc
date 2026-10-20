#!/bin/bash
# project-profile: when the repo declares a secondary profile in
# .claude/workflow.json ("profile": "<relative dir>"), injects its CLAUDE.md
# (first 150 lines, at most 12 KB) as session context. It adds to the
# organization profile for this repo only. A declared path that is absolute, has
# "..", resolves outside the repo or does not exist is ignored with a one-line
# notice that never repeats the declared value (repo input is untrusted).
# SessionStart hook (startup|clear|compact; silent on resume). Never blocks: always exit 0.

. "$(dirname "$0")/lib/profile.sh"

emit() {
  jq -n --arg ctx "$1" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
}

payload=$(cat)
[ "$(printf '%s' "$payload" | jq -r '.source // "startup"' 2>/dev/null)" = resume ] && exit 0
cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0

dir=$(project_profile_dir "$cwd"); rc=$?
case "$rc" in
  0) ;;
  2) emit 'claude-sdlc: project profile ignored: the "profile" path in .claude/workflow.json must be relative and inside the repo.'; exit 0 ;;
  3) emit 'claude-sdlc: project profile ignored: the declared directory does not exist.'; exit 0 ;;
  *) exit 0 ;;
esac

f=$(project_profile_file "$cwd" CLAUDE.md 16384); rc=$?
case "$rc" in
  0) ;;
  4) emit 'claude-sdlc: project profile ignored: CLAUDE.md is over 16 KB.'; exit 0 ;;
  *) exit 0 ;;
esac

root=$(cd "$cwd" && pwd -P)
rel="${dir#"$root"/}"
size=$(wc -c < "$f" | tr -d ' ')
kept=$(head -n 150 "$f" | head -c 12000 | wc -c | tr -d ' ')
ctx="claude-sdlc: project profile ($rel), repo-authored (same trust as the repo's CLAUDE.md): adds to the organization profile, for this repo only.

$(head -n 150 "$f" | head -c 12000)"
if [ "$kept" -lt "$size" ]; then
  ctx="$ctx
claude-sdlc: project profile truncated (150 lines / 12 KB)."
fi
emit "$ctx"
exit 0
