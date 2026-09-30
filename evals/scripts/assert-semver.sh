#!/bin/bash
# Exit 0 if the workflow VERSION under <root> is strict semver.
# Looks in <root>/VERSION (repo) or <root>/workflow/VERSION (installed).
#   usage: assert-semver.sh <root>
. "$(dirname "$0")/../../hooks/lib/semver.sh"
f="$1/VERSION"; [ -f "$f" ] || f="$1/workflow/VERSION"
v=$({ tr -d '[:space:]' < "$f"; } 2>/dev/null)
is_semver "$v" && { echo "semver ok: $v"; exit 0; }
echo "not semver: '${v}' in $f"; exit 1
