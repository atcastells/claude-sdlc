#!/bin/bash
# Drives rules.sh in a temp HOME and a temp git repo. Arg 1: path to rules.sh.
RULES=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
[ -x "$RULES" ] || [ -f "$RULES" ] || { echo "FAIL: rules.sh not found: $RULES"; exit 1; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"
mkdir -p "$HOME"
REPO="$T/repo"
git init -q "$REPO"
mkdir -p "$REPO/src/db" "$REPO/docs"
echo a > "$REPO/src/db/a.sql"
echo b > "$REPO/src/app.ts"
echo c > "$REPO/src/view.tsx"
echo d > "$REPO/docs/it's \"q\".md"
git -C "$REPO" -c user.email=t@t -c user.name=t add -A
git -C "$REPO" -c user.email=t@t -c user.name=t commit -q -m init

fail() { echo "FAIL: $1"; exit 1; }
rules() { bash "$RULES" "$@"; }

# global write
out=$(printf 'Prefer short answers.\n' | rules write --scope global --topic style 2>&1) || fail "global write: $out"
[ -f "$HOME/.claude/rules/personal/style.md" ] || fail "global file missing"
case "$out" in "rules: wrote "*) ;; *) fail "global output: $out";; esac
grep -q '^---' "$HOME/.claude/rules/personal/style.md" && fail "global rule must have no frontmatter"

# repo write whole repo, status unchanged
before=$(git -C "$REPO" status --porcelain)
printf 'Use tabs.\n' | rules write --scope repo --repo "$REPO" --topic tabs >/dev/null 2>&1 || fail "repo write"
[ -f "$REPO/.claude/rules/personal/tabs.md" ] || fail "repo file missing"
[ "$before" = "$(git -C "$REPO" status --porcelain)" ] || fail "git status changed"

# exclude once
printf 'Second.\n' | rules write --scope repo --repo "$REPO" --topic second >/dev/null 2>&1 || fail "second write"
n=$(grep -cx '.claude/rules/personal/' "$REPO/.git/info/exclude")
[ "$n" = 1 ] || fail "exclude line count $n"
[ "$before" = "$(git -C "$REPO" status --porcelain)" ] || fail "git status changed after second write"

# glob
printf 'SQL rule.\n' | rules write --scope repo --repo "$REPO" --topic sql --path '**/*.sql' >/dev/null 2>&1 || fail "sql glob"
f="$REPO/.claude/rules/personal/sql.md"
[ "$(sed -n 1,4p "$f")" = "$(printf -- '---\npaths:\n  - "**/*.sql"\n---')" ] || fail "frontmatter shape"
[ "$(sed -n 5p "$f")" = "" ] || fail "blank line after frontmatter"
[ "$(sed -n 6p "$f")" = "SQL rule." ] || fail "text after frontmatter"

# zero-match refused
out=$(printf 'x\n' | rules write --scope repo --repo "$REPO" --topic none --path '**/*.rs' 2>&1); rc=$?
[ "$rc" = 1 ] || fail "zero-match exit $rc"
case "$out" in rules:*) ;; *) fail "zero-match message: $out";; esac
[ -f "$REPO/.claude/rules/personal/none.md" ] && fail "zero-match left a file"

# braces and quotes
printf 'TS.\n' | rules write --scope repo --repo "$REPO" --topic ts --path 'src/**/*.{ts,tsx}' >/dev/null 2>&1 || fail "brace glob"
grep -qxF '  - "src/**/*.{ts,tsx}"' "$REPO/.claude/rules/personal/ts.md" || fail "brace round trip"
printf 'Q.\n' | rules write --scope repo --repo "$REPO" --topic quote --path 'docs/it'"'"'s "q".md' >/dev/null 2>&1 || fail "quote glob"
grep -qxF '  - "docs/it'"'"'s \"q\".md"' "$REPO/.claude/rules/personal/quote.md" || fail "quote escaping"

# multiple paths
printf 'M.\n' | rules write --scope repo --repo "$REPO" --topic multi --path '**/*.sql' --path 'src/*.ts' >/dev/null 2>&1 || fail "multi path"
[ "$(grep -c '^  - ' "$REPO/.claude/rules/personal/multi.md")" = 2 ] || fail "multi path lines"

# refusals
printf 'x\n' | rules write --scope global --topic Bad_Topic >/dev/null 2>&1; [ $? = 1 ] || fail "bad topic"
printf '   \n' | rules write --scope global --topic empty >/dev/null 2>&1; [ $? = 1 ] || fail "empty text"
printf 'x\n' | rules write --scope global --topic g --path '*.sql' >/dev/null 2>&1; [ $? = 1 ] || fail "path with global"
cred=$(printf 'ghp_%s' "$(printf 'a%.0s' $(seq 36))")
out=$(printf 'token %s\n' "$cred" | rules write --scope global --topic cred 2>&1); rc=$?
[ "$rc" = 1 ] || fail "credential exit $rc"
[ -f "$HOME/.claude/rules/personal/cred.md" ] && fail "credential left a file"
printf 'x\n' | rules write --scope bogus --topic t >/dev/null 2>&1; [ $? = 1 ] || [ $? = 2 ] || fail "bad scope"
rules bogus >/dev/null 2>&1; [ $? = 2 ] || fail "unknown subcommand exit"

# not a git repo
mkdir "$T/plain"
printf 'x\n' | rules write --scope repo --repo "$T/plain" --topic t >/dev/null 2>&1; [ $? = 1 ] || fail "non-git repo"

# tracked personal dir
REPO2="$T/repo2"
git init -q "$REPO2"
mkdir -p "$REPO2/.claude/rules/personal"
echo x > "$REPO2/.claude/rules/personal/old.md"
git -C "$REPO2" -c user.email=t@t -c user.name=t add -A
git -C "$REPO2" -c user.email=t@t -c user.name=t commit -q -m init
printf 'x\n' | rules write --scope repo --repo "$REPO2" --topic new >/dev/null 2>&1; [ $? = 1 ] || fail "tracked personal dir"
[ -f "$REPO2/.claude/rules/personal/new.md" ] && fail "tracked dir got a file"

# repo defaults to PWD
(cd "$REPO" && printf 'P.\n' | rules write --scope repo --topic pwd >/dev/null 2>&1) || fail "default repo PWD"
[ -f "$REPO/.claude/rules/personal/pwd.md" ] || fail "pwd file missing"

# T2: list
mkdir -p "$HOME/.claude/rules" "$REPO/.claude/rules"
echo "shared" > "$HOME/.claude/rules/x.md"
echo "shared" > "$REPO/.claude/rules/x.md"
printf 'L1\nL2\nL3\nL4\nL5\n' | rules write --scope global --topic long >/dev/null 2>&1 || fail "long write"
out=$(rules list --repo "$REPO" 2>&1) || fail "list: $out"
[ "$(printf '%s' "$out" | jq -r '[.[]|select(.topic=="x")]|length')" = 0 ] || fail "list shows non-personal file"
[ "$(printf '%s' "$out" | jq -r '[.[]|select(.scope=="global")]|length')" = 2 ] || fail "list global count"
[ "$(printf '%s' "$out" | jq -c '.[]|select(.scope=="repo" and .topic=="sql")|.paths')" = '["**/*.sql"]' ] || fail "list sql paths"
[ "$(printf '%s' "$out" | jq -c '.[]|select(.topic=="quote")|.paths')" = '["docs/it'"'"'s \"q\".md"]' ] || fail "list quote paths"
[ "$(printf '%s' "$out" | jq -r '.[]|select(.topic=="sql")|.lines')" = 1 ] || fail "list sql body lines"
[ "$(printf '%s' "$out" | jq -r '.[]|select(.topic=="sql")|.preview')" = "SQL rule." ] || fail "list sql preview"
[ "$(printf '%s' "$out" | jq -c '.[]|select(.topic=="style")|.paths')" = '[]' ] || fail "list global paths"
[ "$(printf '%s' "$out" | jq -r '.[]|select(.topic=="long")|.lines')" = 5 ] || fail "list long lines"
[ "$(printf '%s' "$out" | jq -r '.[]|select(.topic=="long")|.preview')" = "$(printf 'L1\nL2\nL3')" ] || fail "list long preview"
[ "$(printf '%s' "$out" | jq -r '.[]|select(.topic=="long")|.file' | sed 's|.*/||')" = long.md ] || fail "list file"
out=$(cd "$REPO" && rules list 2>&1) || fail "list default PWD"
[ "$(printf '%s' "$out" | jq -r '[.[]|select(.scope=="repo")]|length')" -ge 2 ] || fail "list PWD repo rules"
out=$(rules list --repo "$T/plain" 2>&1) || fail "list outside git: $out"
[ "$(printf '%s' "$out" | jq -r '[.[]|select(.scope=="repo")]|length')" = 0 ] || fail "list outside git has repo rules"
[ "$(printf '%s' "$out" | jq -r 'length')" -ge 1 ] || fail "list outside git lost global"
HOME="$T/emptyhome" rules list --repo "$T/plain" | jq -e '. == []' >/dev/null || fail "list empty"

# T2: delete
rules delete --scope repo --repo "$REPO" --topic quote >/dev/null 2>&1 || fail "delete repo"
[ -f "$REPO/.claude/rules/personal/quote.md" ] && fail "delete left file"
[ -f "$REPO/.claude/rules/personal/ts.md" ] || fail "delete removed another rule"
[ -f "$REPO/.claude/rules/x.md" ] || fail "delete touched non-personal"
out=$(rules delete --scope global --topic long 2>&1) || fail "delete global"
case "$out" in "rules: deleted "*"/long.md") ;; *) fail "delete output: $out";; esac
rules delete --scope global --topic long >/dev/null 2>&1; [ $? = 1 ] || fail "delete missing"
rules delete --scope global --topic '../x' >/dev/null 2>&1; [ $? = 1 ] || fail "delete traversal"
rules delete --scope repo --repo "$REPO" --topic '../x' >/dev/null 2>&1; [ $? = 1 ] || fail "delete repo traversal"
rules delete --scope global --topic '' >/dev/null 2>&1; [ $? = 1 ] || fail "delete empty topic"
rules delete --scope repo --repo "$T/plain" --topic t >/dev/null 2>&1; [ $? = 1 ] || fail "delete non-git"
[ -f "$HOME/.claude/rules/x.md" ] || fail "traversal deleted shared file"
mkdir "$HOME/.claude/rules/personal/dir.md"
rules delete --scope global --topic dir >/dev/null 2>&1; [ $? = 1 ] || fail "delete directory"
rmdir "$HOME/.claude/rules/personal/dir.md"

# T2: globs
out=$(rules globs --repo "$REPO" 2>&1) || fail "globs: $out"
want='[{"glob":"src/**","matches":3},{"glob":"**/*.md","matches":1},{"glob":"**/*.sql","matches":1},{"glob":"**/*.ts","matches":1},{"glob":"**/*.tsx","matches":1},{"glob":"docs/**","matches":1}]'
[ "$(printf '%s' "$out" | jq -c .)" = "$want" ] || fail "globs output: $out"
[ "$(printf '%s' "$out" | jq '[.[]|select(.matches<1)]|length')" = 0 ] || fail "globs zero match"
REPO3="$T/repo3"
git init -q "$REPO3"
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do echo x > "$REPO3/f.e$i"; done
mkdir "$REPO3/top"; echo x > "$REPO3/top/y"; echo x > "$REPO3/top/z"
git -C "$REPO3" -c user.email=t@t -c user.name=t add -A
git -C "$REPO3" -c user.email=t@t -c user.name=t commit -q -m init
[ "$(rules globs --repo "$REPO3" | jq length)" = 12 ] || fail "globs cap"
[ "$(rules globs --repo "$REPO3" | jq -r '.[0].glob')" = 'top/**' ] || fail "globs top dir first"
rules globs --repo "$T/plain" >/dev/null 2>&1; [ $? = 1 ] || fail "globs non-git"

# T8: a refused modify keeps the old rule; leading --- refused up front
D="$REPO/.claude/rules/personal"
cp "$D/tabs.md" "$T/tabs.before"
out=$(printf -- '---\nnew\n' | rules write --scope repo --repo "$REPO" --topic tabs 2>&1); rc=$?
[ "$rc" = 1 ] || fail "leading --- exit $rc"
[ "$out" = 'rules: the text cannot start with "---" (it would be read as frontmatter)' ] || fail "leading --- message: $out"
cmp -s "$D/tabs.md" "$T/tabs.before" || fail "refused modify changed the old rule"
out=$(printf -- '---\nnew\n' | rules write --scope repo --repo "$REPO" --topic fresh 2>&1); rc=$?
[ "$rc" = 1 ] || fail "leading --- new topic exit $rc"
[ -f "$D/fresh.md" ] && fail "leading --- created a file"
printf -- '---\nnew\n' | rules write --scope global --topic fresh >/dev/null 2>&1; [ $? = 1 ] || fail "leading --- global"
[ -f "$HOME/.claude/rules/personal/fresh.md" ] && fail "leading --- created a global file"
ls -A "$D" | grep -q '^\.tabs\.' && fail "temp leftovers for tabs"
[ -z "$(find "$D" "$HOME/.claude/rules/personal" -name '.*.??????' -type f 2>/dev/null)" ] || fail "temp leftovers"
# a successful modify replaces the content and leaves no temp
printf 'Use spaces.\n' | rules write --scope repo --repo "$REPO" --topic tabs >/dev/null 2>&1 || fail "modify"
[ "$(cat "$D/tabs.md")" = "Use spaces." ] || fail "modify content"
[ -z "$(find "$D" -name '.*' -type f)" ] || fail "temp after modify"
rules list --repo "$REPO" | jq -e '[.[]|select(.topic|startswith("."))]|length==0' >/dev/null || fail "list shows temp"

echo "all passed"
