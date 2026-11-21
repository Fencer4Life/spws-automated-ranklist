#!/usr/bin/env bash
# Whitespace gate: everything this branch would carry, committed or not (I24).
#
# WHY THIS EXISTS. scripts/integrate-agent-branch.sh refuses a branch whose
# commits fail `git diff --check`. Preflight used to run that same commit-only
# check, but preflight runs BEFORE the commit, so a blank line at the end of a
# staged or new file passed it — twice on 2026-11-21 — and was caught only
# afterwards. Plan: doc/plans/i24-preflight-checks-uncommitted-whitespace-2026-11-21.html.
#
# Four views, because no single git command sees them all:
#   1. the commits since the base       (what the integrate script checks)
#   2. the index against the base       (what the next commit would carry)
#   3. the worktree against the base    (changes not yet staged)
#   4. every new file git does not ignore, which no `git diff` shows
# A new file is checked with `git diff --no-index`, which exits 1 for any
# difference at all, so problems are judged by what it prints, not its exit.
#
# Usage: scripts/check-diff-whitespace.sh [base-ref]   (default origin/main)
# Exit: 0 clean · 1 problems found (each printed with its file and line) · 2 no base
set -uo pipefail

base_ref=${1:-origin/main}
if ! base=$(git merge-base "$base_ref" HEAD 2>/dev/null); then
  echo "whitespace gate: no merge base between $base_ref and HEAD" >&2
  exit 2
fi

found=0
git diff --check "$base_ref...HEAD" || found=1
git diff --cached --check "$base" || found=1
git diff --check "$base" || found=1

while IFS= read -r -d '' file; do
  problems=$(git diff --no-index --check /dev/null "$file" 2>/dev/null || true)
  if [[ -n "$problems" ]]; then
    echo "$problems"
    found=1
  fi
done < <(git ls-files -z --others --exclude-standard)

if [[ $found -ne 0 ]]; then
  echo "whitespace gate: fix the lines above; scripts/integrate-agent-branch.sh refuses them once committed" >&2
fi
exit "$found"
