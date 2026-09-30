#!/bin/bash
# Scenarios for scripts/check-public.sh on throwaway git repos (git init only;
# no staging or commits). Exit 0 = every scenario behaved as expected.
#   usage: check-public-test.sh <path-to-check-public.sh>
set -uo pipefail
cp_sh="$1"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0
expect() { # name want_exit dir
  bash "$cp_sh" "$3" >"$tmp/out" 2>&1; local got=$?
  if [ "$got" != "$2" ]; then echo "  FAIL $1: exit $got, expected $2"; sed 's/^/    /' "$tmp/out"; fails=$((fails+1)); fi
}
mkrepo() { # dir -> minimal repo with .gitignore and a private profile carrying a denylist
  mkdir -p "$1/profiles/acme" "$1/profiles/example"
  git -C "$1" init -q
  printf 'profiles/*\n!profiles/example/\n' > "$1/.gitignore"
  printf '# private terms\nacmecorp\njane roe\n' > "$1/profiles/acme/denylist.txt"
  printf 'rules for acmecorp\n' > "$1/profiles/acme/CLAUDE.md"
  printf 'generic example profile\n' > "$1/profiles/example/CLAUDE.md"
  printf 'core rules\n' > "$1/README.md"
}

mkrepo "$tmp/clean";   expect "clean tree passes" 0 "$tmp/clean"

mkrepo "$tmp/term";    printf 'Ask Jane Roe first\n' > "$tmp/term/README.md"
expect "denylisted term in a publishable file fails (case-insensitive)" 1 "$tmp/term"

mkrepo "$tmp/noign";   printf '' > "$tmp/noign/.gitignore"
expect "private profile not ignored fails" 1 "$tmp/noign"

mkrepo "$tmp/example"; printf 'acmecorp\n' > "$tmp/example/profiles/example/CLAUDE.md"
expect "denylisted term inside the public example profile fails" 1 "$tmp/example"

mkrepo "$tmp/nodeny";  mv "$tmp/nodeny/profiles/acme/denylist.txt" "$tmp/nodeny/profiles/acme/terms.bak"
expect "no denylist at all fails (nothing was checked)" 1 "$tmp/nodeny"

[ "$fails" -eq 0 ] && echo "check-public scenarios: all passed" || echo "check-public scenarios: $fails failed"
[ "$fails" -eq 0 ]
