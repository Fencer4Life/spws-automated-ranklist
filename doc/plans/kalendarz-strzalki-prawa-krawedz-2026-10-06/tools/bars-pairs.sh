#!/bin/bash
# Compare the recaptured English widths pairwise and print the table bar's line.
S=/private/tmp/claude-501/-Users-aleks-coding-SPWSranklist/695986ee-c7d8-4901-8d14-a59bc55fc0f9/scratchpad
B="$S/shots-bars"
for f in wp-768-en wp-1280-en; do
  for pair in "after-1 after-2" "fixed-1 fixed-2" "after-1 fixed-1" "after-2 fixed-2" "after-1 fixed-2" "after-2 fixed-1"; do
    set -- $pair
    out="$B/cmp-$f-$1-vs-$2"
    node "$S/cap/compare-right.mjs" "$B/$1-$f" "$B/$2-$f" "$out" > /dev/null 2>&1
    printf '%-11s %-8s vs %-8s | %s | %s\n' "$f" "$1" "$2" "$(grep -- "-table-bar" "$out/compare.txt" | sed 's/  */ /g')" "$(tail -n 1 "$out/compare.txt")"
  done
done
