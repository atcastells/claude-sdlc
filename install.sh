#!/bin/bash
# Installs Claudio, the agentic SDLC workflow, into this machine's ~/.claude.
#   usage: install.sh [--profile <dir> | --no-profile] [--company-repo <dir>] [--verbose]
# Verification runs in the background by default (result: ~/.claude/workflow/
# install-verify.json); --verbose or WORKFLOW_INSTALL_VERBOSE=1 runs the suite
# in the foreground and fails the install when it is red.
# With no option it reuses the previous installation's profile (if any).
# Idempotent: re-run it to update. Backs up what it overwrites and what it
# retires (files a previous version installed that no longer exist).
set -euo pipefail
src="$(cd "$(dirname "$0")" && pwd)"
dst="$HOME/.claude"
ts=$(date +%Y%m%d%H%M%S)
version=$(tr -d '[:space:]' < "$src/VERSION")
wf="$dst/workflow"

profile=""; profile_set=0; company_arg=""
verbose="${WORKFLOW_INSTALL_VERBOSE:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --profile)    [ $# -ge 2 ] || { echo "--profile needs a directory" >&2; exit 2; }
                  profile="$2"; profile_set=1; shift 2 ;;
    --no-profile) profile=""; profile_set=1; shift ;;
    --company-repo) [ $# -ge 2 ] || { echo "--company-repo needs a directory" >&2; exit 2; }
                  company_arg="$2"; shift 2 ;;
    --verbose)    verbose=1; shift ;;
    -h|--help)    sed -n '2,7p' "$0"; exit 0 ;;
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

# Company rules: a profile with company.json names a repo (url) and the rules
# file inside it. Resolved and validated before anything is written.
company_dir=""; company_rules_file=""; company_verbs_file=""; checked_file=""
check_company_file() { # label, relative path; sets checked_file or exits 1
  case "$2" in
    /*) echo "$1: path must be relative: $2" >&2; exit 1 ;;
    *$'\n'*) echo "$1: path has a newline" >&2; exit 1 ;;
  esac
  case "/$2/" in
    */../*) echo "$1: path must not contain '..': $2" >&2; exit 1 ;;
  esac
  cr="$company_dir/$2"
  if [ -L "$cr" ] || [ ! -f "$cr" ]; then
    echo "$1: not a regular file in $company_dir: $2 (check --company-repo)" >&2; exit 1
  fi
  cr_parent="$(cd "$(dirname "$cr")" && pwd -P)"
  case "$cr_parent/" in
    "$company_dir"/*) ;;
    *) echo "$1: file is outside the company repository: $2" >&2; exit 1 ;;
  esac
  cr_size=$(wc -c < "$cr" | tr -d '[:space:]')
  if [ "$cr_size" -gt 16384 ]; then
    echo "$1: $2 is $cr_size bytes (max 16384)" >&2; exit 1
  fi
  checked_file="$cr"
}
if [ -n "$company_arg" ] && { [ -z "$profile" ] || [ ! -f "$profile/company.json" ]; }; then
  echo "--company-repo needs a profile with company.json${profile:+ ($profile has none)}" >&2; exit 2
fi
if [ -n "$profile" ] && [ -f "$profile/company.json" ]; then
  c_url=$(jq -r 'if (.url|type)=="string" then .url else empty end' "$profile/company.json" 2>/dev/null || true)
  c_rules=$(jq -r 'if (.rules|type)=="string" then .rules else empty end' "$profile/company.json" 2>/dev/null || true)
  if [ -z "$c_url" ] || [ -z "$c_rules" ]; then
    echo "company rules: $profile/company.json needs non-empty string keys \"url\" and \"rules\"" >&2; exit 1
  fi
  if [ -n "$company_arg" ]; then company_dir="$company_arg"
  elif [ -s "$wf/company-repo" ] && { [ -d "$(cat "$wf/company-repo")" ] || [ ! -t 0 ]; }; then company_dir=$(cat "$wf/company-repo")
  elif [ -t 0 ]; then
    echo "This profile reads the company rules from a git repository." >&2
    echo "If you do not have it yet: git clone $c_url <dir>" >&2
    printf 'Path of the company repository: ' >&2
    read -r company_dir
    [ -n "$company_dir" ] || { echo "Cancelled. Use --company-repo <dir>." >&2; exit 1; }
    company_dir="${company_dir/#\~/$HOME}"
  else
    echo "This profile needs the company repository. Run again with --company-repo <dir>." >&2
    echo "If you do not have it yet: git clone $c_url <dir>" >&2
    exit 1
  fi
  [ -d "$company_dir" ] || { echo "company rules: no such directory: $company_dir (--company-repo <dir>; git clone $c_url <dir>)" >&2; exit 1; }
  company_dir="$(cd "$company_dir" && pwd -P)"
  check_company_file "company rules" "$c_rules"
  company_rules_file="$checked_file"
  if jq -e 'has("spinner_verbs")' "$profile/company.json" >/dev/null 2>&1; then
    c_verbs=$(jq -r 'if (.spinner_verbs|type)=="string" then .spinner_verbs else empty end' "$profile/company.json" 2>/dev/null || true)
    [ -n "$c_verbs" ] || { echo "company phrases: \"spinner_verbs\" in $profile/company.json must be a non-empty string path" >&2; exit 1; }
    check_company_file "company phrases" "$c_verbs"
    # Read once and use that copy: exactly one JSON value; no C0/C1 controls,
    # line/paragraph separators, bidi overrides or isolates; not blank
    company_verbs_json=$(jq -c -s 'select(length == 1) | .[0]
      | select(type=="array" and length>=1 and length<=200 and all(.[]; type=="string"
          and (length>=1 and length<=80) and test("\\S")
          and (explode | all(. as $c | ($c>=32 and $c<127) or ($c>=160 and ($c<8232 or $c>8238) and ($c<8294 or $c>8297))))))' \
      "$checked_file" 2>/dev/null || true)
    if [ -z "$company_verbs_json" ]; then
      echo "company phrases: $c_verbs must be one JSON array of 1-200 strings, each 1-80 characters, not blank, no control characters" >&2; exit 1
    fi
    company_verbs_file="$checked_file"
  fi
fi

mkdir -p "$dst" "$wf"
echo "Installing Claudio ${prev:+$prev -> }$version from $src -> $dst${profile:+ (profile: $profile)}"

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
if [ -n "$company_rules_file" ]; then
  {
    cat "$src/global/CLAUDE.md"; echo
    # leading YAML frontmatter (line 1 is exactly ---, closed by another ---) dropped,
    # plus one blank line after it; an unclosed block is not frontmatter: kept whole
    if [ "$(head -n 1 "$company_rules_file")" = "---" ] && tail -n +2 "$company_rules_file" | grep -qx -- '---'; then
      awk 'NR==1 {fm=1; next} fm==1 {if ($0=="---") fm=2; next} fm==2 {fm=0; if ($0=="") next} {print}' "$company_rules_file"
    else
      cat "$company_rules_file"
    fi
    if [ -f "$profile/CLAUDE.md" ]; then echo; cat "$profile/CLAUDE.md"; fi
  } > "$composed"
elif [ -n "$profile" ] && [ -f "$profile/CLAUDE.md" ]; then
  { cat "$src/global/CLAUDE.md"; echo; cat "$profile/CLAUDE.md"; } > "$composed"
else
  cp "$src/global/CLAUDE.md" "$composed"
fi
install_file "$composed" "$dst/CLAUDE.md"
rm -f "$composed"
install_file "$src/status-line.sh" "$dst/status-line.sh"

chmod +x "$dst"/hooks/*.sh "$dst"/evals/run.sh "$dst"/evals/install-verify.sh "$dst"/skills/repo-setup/check.sh "$dst"/status-line.sh
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
if [ -n "$company_dir" ]; then printf '%s\n' "$company_dir" > "$wf/company-repo"; else rm -f "$wf/company-repo"; fi
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
if [ -n "$company_verbs_file" ]; then
  jq --argjson v "$company_verbs_json" '.spinnerVerbs = {mode: "replace", verbs: $v}' "$template" > "$template.v" && mv "$template.v" "$template"
  echo "  progress phrases: $(jq -n --argjson v "$company_verbs_json" '$v | length') from the company profile (replaces your own)"
fi
if [ -f "$dst/settings.json" ]; then
  jq -s --arg cv "$company_verbs_file" '.[0] * {hooks: .[1].hooks, permissions: .[1].permissions, statusLine: .[1].statusLine} + (if $cv != "" then {spinnerVerbs: .[1].spinnerVerbs} else {} end)' \
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
  rm -f "$wf/install-verify.json"
  echo "Installed $version (not verified: WORKFLOW_INSTALL_NO_VERIFY)."
  exit 0
fi
if [ -n "$verbose" ]; then
  echo
  echo "Verifying: the eval suite must end green"
  if [ -s "$wf/install-verify.pid" ]; then
    oldpid=$(cat "$wf/install-verify.pid" 2>/dev/null)
    case "$oldpid" in ''|*[!0-9]*) ;; *) kill -0 "$oldpid" 2>/dev/null || rm -f "$wf/install-verify.pid" ;; esac
  fi
  EVALS_SKIP_REPO=1 EVALS_RESULT_JSON="$wf/install-verify.json" "$dst/evals/run.sh"
  echo
  echo "Installed $version. Hooks take effect in the NEXT Claude Code session."
else
  nohup bash "$dst/evals/install-verify.sh" "$dst" >/dev/null 2>&1 &
  echo
  echo "Installed $version. Hooks take effect in the NEXT Claude Code session."
  echo "Verifying in the background; Claude will tell you at session start if something fails."
fi
echo "Repos set up with an older version will say so when opened: /repo-setup upgrade."
echo "Plugins are not part of this repo: reinstall yours with /plugin."
