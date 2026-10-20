#!/bin/bash
# calibrate: prints the starting estimate table and, when there is history,
# the per-runs_on correction factors: the repo's own logs
# (<repo>/.sdlc/*/actuals.jsonl) next to the machine log
# (${CLAUDE_SDLC_ACTUALS:-$HOME/.claude/actuals.jsonl}).
# Usage: calibrate.sh <repo-dir>. Ignores stdin; always exits 0.

repo="${1:-}"
machine="${CLAUDE_SDLC_ACTUALS:-$HOME/.claude/actuals.jsonl}"

cat <<'EOF'
Starting estimates (from 18 measured tasks; recalibrated by history)
Runs on                 S            M            L
scout (haiku)           1.5m/650k, each request under 100K prompt (low confidence)
implementer (sonnet)    2m/200k      2m/300k      3m/400k
verifier/reviewer       8m/700k (low confidence)
main (opus)             5m/6M (low confidence)
Size: S = one file and its test; M = 2-4 files; L = more, or unknown code.
EOF

# fromjson? drops malformed lines; the select drops start events and unusable rows
filter='(fromjson? // empty) | select(type == "object")
      | select(.event != "start")
      | select((.est_min | type) == "number" and (.min | type) == "number"
               and (.est_ktok | type) == "number" and (.ktok | type) == "number"
               and .est_min != 0 and .est_ktok != 0)'

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
: > "$tmp/repo"
: > "$tmp/all"
if [ -n "$repo" ] && [ -d "$repo/.sdlc" ]; then
  for f in "$repo"/.sdlc/*/actuals.jsonl; do
    [ -f "$f" ] || continue
    slug=$(basename "$(dirname "$f")")
    jq -R -c --arg slug "$slug" "$filter | . + {slug: \$slug}" "$f" >> "$tmp/repo" 2>/dev/null
  done
fi
[ -f "$machine" ] && jq -R -c "$filter" "$machine" >> "$tmp/all" 2>/dev/null

if [ ! -s "$tmp/repo" ] && [ ! -s "$tmp/all" ]; then
  echo
  echo "No history yet: use the starting table as is."
  exit 0
fi

echo
jq -n -r --slurpfile r "$tmp/repo" --slurpfile a "$tmp/all" '
  def median: sort | length as $n
    | if $n % 2 == 1 then .[($n - 1) / 2] else (.[$n / 2 - 1] + .[$n / 2]) / 2 end;
  def r2: (. * 100 | round) as $v
    | "\($v / 100 | floor).\(($v % 100) | tostring | if length < 2 then "0" + . else . end)";
  def of(rows; k): rows | map(select((.runs_on // "unknown") == k));
  def r1: (. * 10 | round) as $v | "\($v / 10 | floor).\($v % 10)";
  def actual(rows; k):
    of(rows; k) as $x
    | if ($x | length) == 0 then "-"
      else "\($x | map(.min) | median | r1)m/\($x | map(.ktok) | median | round)k" end;
  def side(rows; k):
    of(rows; k) as $x
    | if ($x | length) == 0 then "n=0"
      else "n=\($x | length) min x\($x | map(.min / .est_min) | median | r2) tok x\($x | map(.ktok / .est_ktok) | median | r2)" end;
  $r as $repo | $a as $all
  | (($repo + $all) | map(.runs_on // "unknown") | unique) as $runners
  | "History: \($repo | length) tasks in \($repo | map(.slug) | unique | length) plans, \($all | length) in the machine log",
    ($runners[] as $k
      | "\($k)  repo \(side($repo; $k))  all \(side($all; $k))  use: \((of($repo; $k) | length) as $r | (of($all; $k) | length) as $a
        | if $r >= 5 or ($a == 0 and $r > 0) then "repo" else "all" end)",
       "  median actual: repo \(actual($repo; $k))  all \(actual($all; $k))"),
    "Estimate with the median actual of the side marked \"use\"; the factors only compare with the starting table each task was estimated with.",
    (if ($repo | map(select(.flag == true)) | length) > 0 then
       "Flagged (|deviation| > 50 %):",
       ($repo[] | select(.flag == true)
         | "  \(.slug)/\(.task) \(.runs_on) min \(.dev_min_pct)% tok \(.dev_tok_pct)% — \(.cause // "")")
     else empty end)'
exit 0
