#!/bin/bash
# Status line for Claude Code
# Single line: [Model] | folder | [worktree] branch +added -removed | bar pct%

input=$(cat)

# ── Colors ──────────────────────────────────────────
R='\033[0m'
CYAN='\033[36m'
BLUE='\033[34m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
DIM='\033[2m'
BOLD='\033[1m'

# ── Extract fields ──────────────────────────────────
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // "~"')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
# Session cost so far and effort; omitted when the payload does not carry them
# Formatted in jq: bash printf follows the locale (some expect a decimal comma)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd | if type == "number" then
  ((. * 100) | round) as $c | "$\($c / 100 | floor).\(($c % 100) | tostring | if length < 2 then "0" + . else . end)"
  else empty end')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')

# Workflow mode (Spec by default; Vibe only with a valid id and its marker)
MODE_VIBE=0
if . "$(dirname "$0")/hooks/lib/mode.sh" 2>/dev/null; then
  mode_is_vibe "$SESSION_ID" && MODE_VIBE=1
fi

# ── Format values ───────────────────────────────────
FOLDER="${DIR##*/}"

# ── Progress bar (color shifts by usage) ────────────
if [ "$PCT" -ge 80 ]; then
  BAR_COLOR='\033[31m'
elif [ "$PCT" -ge 60 ]; then
  BAR_COLOR='\033[33m'
else
  BAR_COLOR='\033[32m'
fi

FILLED=$((PCT / 10))
EMPTY=$((10 - FILLED))
BAR=""
for ((i = 0; i < FILLED; i++)); do BAR+="█"; done
for ((i = 0; i < EMPTY; i++)); do BAR+="░"; done

# ── Git branch + worktree + diff stats ─────────────
GIT_PART=""
if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
  [ -z "$BRANCH" ] && BRANCH=$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)
  DIFF=$(git -C "$DIR" diff --shortstat 2>/dev/null)
  ADDED=$(echo "$DIFF" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
  DELETED=$(echo "$DIFF" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+')

  WORKTREE_DIR=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)
  WORKTREE_NAME=$(basename "$WORKTREE_DIR")
  MAIN_REPO=$(git -C "$DIR" worktree list 2>/dev/null | head -1 | awk '{print $1}')
  MAIN_REPO_NAME=$(basename "$MAIN_REPO")

  if [ -n "$WORKTREE_NAME" ] && [ "$WORKTREE_NAME" != "$MAIN_REPO_NAME" ]; then
    GIT_PART="${MAGENTA}🌲 ${WORKTREE_NAME}${R} ${GREEN}🌿 ${BRANCH}${R}"
  else
    GIT_PART="${GREEN}🌿 ${BRANCH}${R}"
  fi
  if [ -n "$ADDED" ] || [ -n "$DELETED" ]; then
    GIT_PART+=" "
    [ -n "$ADDED" ] && GIT_PART+="${GREEN}+${ADDED}${R}"
    [ -n "$ADDED" ] && [ -n "$DELETED" ] && GIT_PART+=" "
    [ -n "$DELETED" ] && GIT_PART+="${RED}-${DELETED}${R}"
  fi
fi

# Plan hint (ids and numbers only; nothing when there is no open usable plan)
PLAN_PART=""; HINT_OK=0
if [ -n "${WORKTREE_DIR:-}" ]; then
  HINT_ROOT="$WORKTREE_DIR"
  if . "$(dirname "$0")/hooks/lib/plan-hint.sh" 2>/dev/null \
     && plan_hint "$HINT_ROOT"; then
    HINT_OK=1
    case "$PH_LEVEL" in over) TC="$YELLOW" ;; way) TC="$RED" ;; *) TC="$DIM" ;; esac
    if [ -n "$PH_TASK" ]; then
      if [ -n "$PH_ELAPSED" ]; then TXT="$PH_TASK ${PH_ELAPSED}m/${PH_EST:-?}m"
      elif [ -n "$PH_EST" ]; then TXT="$PH_TASK ~${PH_EST}m"
      else TXT="$PH_TASK"; fi
      PLAN_PART+="${TC}${TXT}${R}${DIM} · ${R}"
    fi
    PLAN_PART+="${DIM}${PH_DONE}/${PH_TOTAL} · ~${PH_LEFT_MIN}m left${R}"
  fi
fi
COMPACT=""
if [ "$PCT" -ge 90 ] || { [ "$PCT" -ge 70 ] && [ "$HINT_OK" = 1 ] && [ -n "${PH_TASK:-}" ]; }; then
  COMPACT=" ${YELLOW}compact between tasks${R}"
fi

# ── Build single line ──────────────────────────────
SEP=" ${DIM}|${R} "
LINE="${BOLD}${CYAN}🤖 ${MODEL}${R}"
[ -n "$EFFORT" ] && LINE+=" ${DIM}${EFFORT}${R}"
if [ "$MODE_VIBE" = 1 ]; then
  LINE+="${SEP}${BOLD}${MAGENTA}Vibe${R}"
else
  LINE+="${SEP}${DIM}Spec${R}"
fi
[ -n "$PLAN_PART" ] && LINE+="${SEP}${PLAN_PART}"
LINE+="${SEP}${BLUE}📁 ${FOLDER}${R}"
[ -n "$GIT_PART" ] && LINE+="${SEP}${GIT_PART}"
LINE+="${SEP}${BAR_COLOR}${BAR} ${PCT}%${R}${COMPACT}"
[ -n "$COST" ] && LINE+="${SEP}${YELLOW}${COST}${R}"

printf '%b\n' "$LINE"
