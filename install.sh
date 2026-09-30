#!/bin/bash
# Installs the agentic SDLC workflow into this machine's ~/.claude.
#   usage: install.sh [--profile <dir> | --no-profile]
# With no option it reuses the previous installation's profile (if any).
# Idempotent: re-run it to update. Backs up what it overwrites and what it
# retires (files a previous version installed that no longer exist).
set -euo pipefail
src="$(cd "$(dirname "$0")" && pwd)"
dst="$HOME/.claude"
ts=$(date +%Y%m%d%H%M%S)
version=$(tr -d '[:space:]' < "$src/VERSION")
wf="$dst/workflow"

profile=""; profile_set=0
while [ $# -gt 0 ]; do
  case "$1" in
    --profile)    [ $# -ge 2 ] || { echo "--profile needs a directory" >&2; exit 2; }
                  profile="$2"; profile_set=1; shift 2 ;;
    --no-profile) profile=""; profile_set=1; shift ;;
    -h|--help)    sed -n '2,4p' "$0"; exit 0 ;;
    *)            echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

prev=$({ tr -d '[:space:]' < "$wf/VERSION"; } 2>/dev/null || true)
# 1.0.0 installs predate workflow/VERSION; recognise them by the hooks they left
if [ -z "$prev" ] && [ -f "$dst/hooks/credential-guard.sh" ]; then prev=1.0.0; fi
# An unreadable VERSION is treated as the oldest release: the cautious side
if [ -n "$prev" ] && ! [[ "$prev" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then prev=1.0.0; fi
if [ "$profile_set" -eq 0 ] && [ -f "$wf/profile" ]; then
  profile=$(cat "$wf/profile"); profile_set=1
fi

# From 1.x to 2.x organization rules moved from the core into a profile:
# without an explicit choice, a 1.x machine would silently lose its rules.
if [ "$profile_set" -eq 0 ] && [ -n "$prev" ] && [ "${prev%%.*}" -lt 2 ] && [ "${version%%.*}" -ge 2 ]; then
  echo "This machine has $prev. Since 2.0.0 organization rules live in a profile." >&2
  if [ -t 0 ]; then
    printf 'Install WITHOUT a profile (organization rules are dropped)? [y/N] ' >&2
    read -r ans
    case "$ans" in y|Y|yes|YES) ;; *) echo "Cancelled. Use --profile <dir> or --no-profile." >&2; exit 1 ;; esac
  else
    echo "Choose: install.sh --profile <dir>  |  install.sh --no-profile" >&2
    exit 1
  fi
fi

if [ -n "$profile" ]; then
  [ -d "$profile" ] || { echo "no such profile: $profile" >&2; exit 1; }
  profile="$(cd "$profile" && pwd)"
fi

mkdir -p "$dst" "$wf"
echo "Installing workflow ${prev:+$prev -> }$version from $src -> $dst${profile:+ (profile: $profile)}"

# New manifest: paths relative to ~/.claude of everything installed
new_manifest=$(mktemp)
{
  ( cd "$src" && find skills agents hooks evals -type f ! -name '.DS_Store' )
  if [ -n "$profile" ] && [ -d "$profile/evals/cases" ]; then
    for f in "$profile"/evals/cases/*.json; do [ -e "$f" ] && echo "evals/cases/p-$(basename "$f")"; done
  fi
} | sort > "$new_manifest"

# Retire what the previous version installed that is no longer in the repo.
# Without a previous manifest (1.0.0 installs) only evals/cases/ is pruned: it
# belongs entirely to the workflow; the rest of ~/.claude may hold the user's files.
if [ -f "$wf/manifest" ]; then
  old=$(cat "$wf/manifest")
else
  old=$( [ -d "$dst/evals/cases" ] && cd "$dst" && find evals/cases -type f -name '*.json' | sort || true)
fi
removed=0
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  grep -qxF -- "$rel" "$new_manifest" && continue
  [ -e "$dst/$rel" ] || continue
  mkdir -p "$dst/backups/workflow-$ts/$(dirname "$rel")"
  mv "$dst/$rel" "$dst/backups/workflow-$ts/$rel"
  rmdir "$(dirname "$dst/$rel")" 2>/dev/null || true
  echo "  retired: $rel"
  removed=$((removed+1))
done <<< "$old"
[ "$removed" -gt 0 ] && echo "  backup of retired files: $dst/backups/workflow-$ts/"

# Skills, agents, hooks, evals (+ profile evals, prefixed p-)
for d in skills agents hooks evals; do
  mkdir -p "$dst/$d"
  cp -R "$src/$d/." "$dst/$d/"
done
if [ -n "$profile" ] && [ -d "$profile/evals/cases" ]; then
  for f in "$profile"/evals/cases/*.json; do [ -e "$f" ] && cp "$f" "$dst/evals/cases/p-$(basename "$f")"; done
fi

# Global CLAUDE.md (core + profile) and status line: backup if they differ
install_file() {
  local from="$1" to="$2"
  if [ -f "$to" ] && ! cmp -s "$from" "$to"; then
    cp "$to" "$to.bak-$ts"
    echo "  backup: $to.bak-$ts"
  fi
  cp "$from" "$to"
}
composed=$(mktemp)
if [ -n "$profile" ] && [ -f "$profile/CLAUDE.md" ]; then
  { cat "$src/global/CLAUDE.md"; echo; cat "$profile/CLAUDE.md"; } > "$composed"
else
  cp "$src/global/CLAUDE.md" "$composed"
fi
install_file "$composed" "$dst/CLAUDE.md"
rm -f "$composed"
install_file "$src/status-line.sh" "$dst/status-line.sh"

chmod +x "$dst"/hooks/*.sh "$dst"/evals/run.sh "$dst"/skills/repo-setup/check.sh "$dst"/status-line.sh
chmod +x "$dst"/evals/scripts/*.sh 2>/dev/null || true

# Version, source, profile, migrations and manifest
rm -rf "$wf/migrations"
cp -R "$src/migrations" "$wf/migrations"
printf '%s\n' "$version" > "$wf/VERSION"
printf '%s\n' "$src" > "$wf/source"
if [ -n "$profile" ]; then
  printf '%s\n' "$profile" > "$wf/profile"
  if [ -f "$profile/profile.env" ]; then cp "$profile/profile.env" "$wf/profile.env"; else rm -f "$wf/profile.env"; fi
else
  rm -f "$wf/profile" "$wf/profile.env"
fi
mv "$new_manifest" "$wf/manifest"

# settings.json: template (+ the profile's settings.json: permission lists
# unioned, the rest deep-merged). If it already exists, only the workflow keys
# (hooks, permissions, statusLine) are merged in and everything else is kept.
# Note: this is a deep merge. permissions arrays and hook events the template
# defines are replaced whole; hook events it does not define survive. Put your
# own rules in settings.local.json.
template=$(mktemp)
if [ -n "$profile" ] && [ -f "$profile/settings.json" ]; then
  jq -s '.[0] as $t | .[1] as $p | ($t * $p)
    | .permissions.allow = (($t.permissions.allow // []) + ($p.permissions.allow // []) | unique)
    | .permissions.deny  = (($t.permissions.deny  // []) + ($p.permissions.deny  // []) | unique)
    | .permissions.ask   = (($t.permissions.ask   // []) + ($p.permissions.ask   // []) | unique)' \
    "$src/settings.template.json" "$profile/settings.json" > "$template"
else
  cp "$src/settings.template.json" "$template"
fi
jq -e . "$template" >/dev/null
if [ -f "$dst/settings.json" ]; then
  jq -s '.[0] * {hooks: .[1].hooks, permissions: .[1].permissions, statusLine: .[1].statusLine}' \
    "$dst/settings.json" "$template" > "$dst/settings.json.new"
  jq -e . "$dst/settings.json.new" >/dev/null
  if cmp -s <(jq -S . "$dst/settings.json") <(jq -S . "$dst/settings.json.new"); then
    rm -f "$dst/settings.json.new"
  else
    cp "$dst/settings.json" "$dst/settings.json.bak-$ts"
    echo "  backup: $dst/settings.json.bak-$ts"
    mv "$dst/settings.json.new" "$dst/settings.json"
  fi
else
  cp "$template" "$dst/settings.json"
fi
rm -f "$template"

if [ -n "${WORKFLOW_INSTALL_NO_VERIFY:-}" ]; then
  echo "Installed $version (not verified: WORKFLOW_INSTALL_NO_VERIFY)."
  exit 0
fi
echo
echo "Verifying: the eval suite must end green"
"$dst/evals/run.sh"
echo
echo "Installed $version. Hooks take effect in the NEXT Claude Code session."
echo "Repos set up with an older version will say so when opened: /repo-setup upgrade."
echo "Plugins are not part of this repo: reinstall yours with /plugin."
