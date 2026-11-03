# Sourced library: per-session mode marker (vibe mode). No exit, no side effects.
#   mode_marker <session_id>  prints the marker path; returns 1 (no output) on an invalid id
#   mode_is_vibe <session_id> returns 0 only when the id is valid and the marker exists

mode_marker() {
  case "${1:-}" in
    ""|*[!A-Za-z0-9_-]*) return 1 ;;
  esac
  local base="${TMPDIR:-/tmp}"
  base="${base%/}"
  printf '%s\n' "$base/claude-sdlc-mode-$1"
}

mode_is_vibe() {
  case "${1:-}" in
    ""|*[!A-Za-z0-9_-]*) return 1 ;;
  esac
  local base="${TMPDIR:-/tmp}"
  [ -e "${base%/}/claude-sdlc-mode-$1" ]
}
