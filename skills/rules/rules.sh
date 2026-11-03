#!/bin/bash
# rules.sh: deterministic file operations for the /rules skill.
# Exit 0 ok, 1 refused input (message on stderr, "rules: ..."), 2 usage.

usage() {
  echo "usage: rules.sh write --scope global|repo [--repo <dir>] --topic <slug> [--path <glob>]... < text" >&2
  echo "       rules.sh list [--repo <dir>]" >&2
  echo "       rules.sh delete --scope global|repo [--repo <dir>] --topic <slug>" >&2
  echo "       rules.sh globs [--repo <dir>]" >&2
  exit 2
}
refuse() { echo "rules: $*" >&2; exit 1; }

# Expands the first {a,b} group recursively (no nesting), one result per line.
expand_braces() {
  local s="$1" pre rest body post item
  case "$s" in
    *"{"*"}"*)
      pre=${s%%\{*}; rest=${s#*\{}
      body=${rest%%\}*}; post=${rest#*\}}
      local IFS=','
      for item in $body; do expand_braces "$pre$item$post"; done
      ;;
    *) printf '%s\n' "$s" ;;
  esac
}

glob_matches() {
  local root="$1" glob="$2" variant
  while IFS= read -r variant; do
    [ -n "$(git -C "$root" ls-files -- ":(glob)$variant" 2>/dev/null | head -n1)" ] && return 0
  done < <(expand_braces "$glob")
  return 1
}

validate_topic() {
  [ -n "$1" ] || refuse "--topic is required"
  [ ${#1} -le 48 ] && printf '%s' "$1" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' \
    || refuse "topic must be kebab-case (a-z, 0-9, hyphens), at most 48 characters"
}

cmd_write() {
  local scope="" repo="" topic="" paths=() text dir root file tmp guard_out
  while [ $# -gt 0 ]; do
    case "$1" in
      --scope) [ $# -ge 2 ] || usage; scope="$2"; shift 2 ;;
      --repo)  [ $# -ge 2 ] || usage; repo="$2"; shift 2 ;;
      --topic) [ $# -ge 2 ] || usage; topic="$2"; shift 2 ;;
      --path)  [ $# -ge 2 ] || usage; paths+=("$2"); shift 2 ;;
      *) usage ;;
    esac
  done
  case "$scope" in global|repo) ;; *) refuse "--scope must be global or repo" ;; esac
  validate_topic "$topic"

  text=$(cat)
  printf '%s' "$text" | grep -q '[^[:space:]]' || refuse "the rule text is empty"

  if [ ${#paths[@]} -eq 0 ] && [ "$(printf '%s\n' "$text" | head -n1)" = "---" ]; then
    refuse 'the text cannot start with "---" (it would be read as frontmatter)'
  fi

  guard_out=$(jq -n --arg t "$text" '{tool_name:"Write",tool_input:{content:$t}}' \
    | bash "$(dirname "$0")/../../hooks/credential-guard.sh" 2>&1 >/dev/null)
  [ $? -eq 2 ] || [ -n "$guard_out" ] && refuse "${guard_out:-the text looks like a credential}"

  if [ "$scope" = global ]; then
    [ ${#paths[@]} -eq 0 ] || refuse "global rules always load; --path is only for repo rules"
    dir="$HOME/.claude/rules/personal"
  else
    [ -n "$repo" ] || repo="$PWD"
    root=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null) || refuse "not a git work tree: $repo"
    if [ -n "$(git -C "$root" ls-files -- .claude/rules/personal | head -n1)" ]; then
      refuse ".claude/rules/personal/ has tracked files in this repo; writing there would modify tracked files"
    fi
    local p
    for p in "${paths[@]}"; do
      case "$p" in *$'\n'*|"") refuse "invalid glob" ;; esac
      glob_matches "$root" "$p" || refuse "glob matches no tracked file: $p"
    done
    dir="$root/.claude/rules/personal"
  fi

  file="$dir/$topic.md"
  mkdir -p "$dir" || refuse "cannot create $dir"
  tmp=$(mktemp "$dir/.$topic.XXXXXX") || refuse "cannot write in $dir"
  {
    if [ ${#paths[@]} -gt 0 ]; then
      echo '---'; echo 'paths:'
      for p in "${paths[@]}"; do printf '  - %s\n' "$(jq -rn --arg v "$p" '$v|tojson')"; done
      echo '---'; echo
    fi
    printf '%s\n' "$text"
  } > "$tmp" || { rm -f "$tmp"; refuse "cannot write $file"; }

  if ! verify_frontmatter "$tmp" "${paths[@]}"; then
    rm -f "$tmp"
    refuse "frontmatter did not round-trip; nothing written"
  fi
  chmod 644 "$tmp" 2>/dev/null
  if [ "$scope" = repo ]; then
    add_exclude "$root" || { rm -f "$tmp"; refuse "cannot update info/exclude"; }
  fi
  mv -f "$tmp" "$file" || { rm -f "$tmp"; refuse "cannot write $file"; }
  echo "rules: wrote $file"
}

# Re-reads the fixed frontmatter shape and compares with the expected globs.
verify_frontmatter() {
  local file="$1"; shift
  local got line want
  if [ $# -eq 0 ]; then
    [ "$(head -n1 "$file")" != "---" ]; return
  fi
  [ "$(sed -n 1p "$file")" = "---" ] && [ "$(sed -n 2p "$file")" = "paths:" ] || return 1
  got=""
  local i=3
  while line=$(sed -n "${i}p" "$file"); [ "$line" != "---" ]; do
    case "$line" in '  - "'*'"') ;; *) return 1 ;; esac
    got="$got$(printf '%s' "${line#  - }" | jq -r . 2>/dev/null)"$'\n' || return 1
    i=$((i+1)); [ $i -lt 1000 ] || return 1
  done
  want=""
  for line in "$@"; do want="$want$line"$'\n'; done
  [ "$got" = "$want" ]
}

add_exclude() {
  local root="$1" common ex
  common=$(git -C "$root" rev-parse --git-common-dir) || return 1
  case "$common" in /*) ;; *) common="$root/$common" ;; esac
  ex="$common/info/exclude"
  mkdir -p "$common/info" || return 1
  grep -qxF '.claude/rules/personal/' "$ex" 2>/dev/null && return 0
  { [ -s "$ex" ] && [ -n "$(tail -c1 "$ex")" ] && echo; echo '.claude/rules/personal/'; } >> "$ex"
}

# One JSON object per personal rule file in dir. Body = text after the frontmatter.
list_dir() {
  local scope="$1" dir="$2" f paths body
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    paths=$(awk 'NR==1&&$0=="---"{fm=1;next} fm==1&&$0=="---"{exit} fm==1{print}' "$f" \
      | jq -Rn '[inputs|select(startswith("  - "))|ltrimstr("  - ")|fromjson? // empty]')
    body=$(awk 'NR==1&&$0=="---"{fm=1;next} fm==1&&$0=="---"{fm=2;skip=1;next} fm==1{next} skip&&$0==""{skip=0;next} {skip=0;print}' "$f")
    jq -nc --arg scope "$scope" --arg file "$f" --arg topic "$(basename "$f" .md)" \
      --argjson paths "$paths" --arg body "$body" '
      ($body|split("\n")) as $l
      | {scope:$scope, topic:$topic, file:$file, paths:$paths,
         lines:(if $body=="" then 0 else ($l|length) end),
         preview:($l[0:3]|join("\n"))}'
  done
}

cmd_list() {
  local repo="" root
  while [ $# -gt 0 ]; do
    case "$1" in
      --repo) [ $# -ge 2 ] || usage; repo="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$repo" ] || repo="$PWD"
  {
    list_dir global "$HOME/.claude/rules/personal"
    if root=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null); then
      list_dir repo "$root/.claude/rules/personal"
    fi
  } | jq -s .
}

cmd_delete() {
  local scope="" repo="" topic="" dir root file
  while [ $# -gt 0 ]; do
    case "$1" in
      --scope) [ $# -ge 2 ] || usage; scope="$2"; shift 2 ;;
      --repo)  [ $# -ge 2 ] || usage; repo="$2"; shift 2 ;;
      --topic) [ $# -ge 2 ] || usage; topic="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  case "$scope" in global|repo) ;; *) refuse "--scope must be global or repo" ;; esac
  validate_topic "$topic"
  if [ "$scope" = global ]; then
    dir="$HOME/.claude/rules/personal"
  else
    [ -n "$repo" ] || repo="$PWD"
    root=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null) || refuse "not a git work tree: $repo"
    dir="$root/.claude/rules/personal"
  fi
  file="$dir/$topic.md"
  [ -f "$file" ] && [ ! -L "$file" ] || refuse "no such rule: $topic ($scope)"
  rm -f "$file" || refuse "cannot delete $file"
  echo "rules: deleted $file"
}

# Suggested globs from tracked files: one per extension and one per top-level directory.
cmd_globs() {
  local repo="" root tab=$'\t'
  while [ $# -gt 0 ]; do
    case "$1" in
      --repo) [ $# -ge 2 ] || usage; repo="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$repo" ] || repo="$PWD"
  root=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null) || refuse "not a git work tree: $repo"
  git -C "$root" ls-files -z | tr '\0' '\n' \
    | awk '
        { n = split($0, parts, "/"); base = parts[n]
          if (n > 1) print "d\t" parts[1] "/**"
          if (match(base, /^.+\.[A-Za-z0-9_+-]+$/)) {
            ext = base; sub(/^.*\./, "", ext); print "e\t**/*." ext } }' \
    | cut -f2 | LC_ALL=C sort | uniq -c \
    | awk '{ c = $1; sub(/^ *[0-9]+ /, ""); print c "\t" $0 }' \
    | LC_ALL=C sort -t "$tab" -k1,1nr -k2,2 | head -n 12 \
    | jq -Rn '[inputs | split("\t") | {glob: .[1], matches: (.[0]|tonumber)}]'
}

[ $# -ge 1 ] || usage
sub="$1"; shift
case "$sub" in
  write) cmd_write "$@" ;;
  list) cmd_list "$@" ;;
  delete) cmd_delete "$@" ;;
  globs) cmd_globs "$@" ;;
  *) usage ;;
esac
