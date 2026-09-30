#!/bin/bash
# Semver helpers shared by workflow-version-check.sh and repo-setup/check.sh.
# Source it; it defines functions only.

# is_semver X.Y.Z (no prerelease: the workflow does not publish them)
is_semver() { [[ "${1:-}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; }

# ver_lt A B -> true if A < B
ver_lt() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" = "$1" ]
}

# pending_migrations DIR FROM TO -> "version<TAB>title" for FROM < v <= TO, ascending
pending_migrations() {
  local dir="$1" from="$2" to="$3" f v
  [ -d "$dir" ] || return 0
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    v=$(basename "$f" .md)
    is_semver "$v" || continue
    ver_lt "$from" "$v" && ! ver_lt "$to" "$v" && printf '%s\t%s\n' "$v" "$(head -1 "$f" | sed 's/^# *//')"
  done | sort -t. -k1,1n -k2,2n -k3,3n
}
