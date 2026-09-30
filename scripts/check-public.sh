#!/bin/bash
# check-public: fails if publishing this repo would leak a private profile.
#   usage: scripts/check-public.sh [repo-root]
# Checks, deterministically:
#   1. nothing under profiles/ except profiles/example/ is tracked, staged, or
#      addable (i.e. private profiles are really ignored);
#   2. no publishable file contains a term from any profiles/*/denylist.txt
#      (case-insensitive substring, fixed strings; # starts a comment).
# Publishable = tracked + untracked-not-ignored. Exit 1 on any finding.
set -uo pipefail
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$root" 2>/dev/null || { echo "FAIL  no such directory: $root"; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "FAIL  not a git repository: $root"; exit 1; }

fail=0
terms=$(mktemp)
trap 'rm -f "$terms"' EXIT

# 1. Private profiles stay out of git
leak=$( { git ls-files --cached -- profiles; git ls-files --others --exclude-standard -- profiles; } \
        | grep -v '^profiles/example/' | sort -u)
if [ -n "$leak" ]; then
  echo "FAIL  private profile files would be published (check .gitignore, never 'git add -f'):"
  printf '%s\n' "$leak" | sed 's/^/        /'
  fail=1
else
  echo "PASS  private profiles are ignored"
fi

# 2. Denylisted terms in publishable files
cat profiles/*/denylist.txt 2>/dev/null \
  | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | sort -u > "$terms"
if [ ! -s "$terms" ]; then
  echo "FAIL  no denylist terms found in profiles/*/denylist.txt: nothing was checked"
  fail=1
else
  # Print file:line:term only, never the whole line
  hits=$(git ls-files -co --exclude-standard -z \
         | grep -zv '^profiles/[^/]*/denylist\.txt$' \
         | xargs -0 grep -IinoF -f "$terms" -- 2>/dev/null)
  if [ -n "$hits" ]; then
    echo "FAIL  denylisted terms in publishable files ($(printf '%s\n' "$hits" | wc -l | tr -d ' ')):"
    printf '%s\n' "$hits" | sed 's/^/        /'
    fail=1
  else
    echo "PASS  no denylisted terms ($(wc -l < "$terms" | tr -d ' ') terms checked)"
  fi
fi

# Advisory only
if [ -f LICENSE ] && grep -q '<copyright holder>' LICENSE; then
  echo "WARN  LICENSE still has the <copyright holder> placeholder"
fi
if [ -f README.md ] && grep -q 'github.com/OWNER/' README.md; then
  echo "WARN  README install line still points to github.com/OWNER/: set the real owner"
fi

[ "$fail" -eq 0 ]
