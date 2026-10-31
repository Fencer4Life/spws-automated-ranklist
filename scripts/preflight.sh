#!/usr/bin/env bash
# Run every gate that can reject this work, in one pass.
#
# WHY THIS EXISTS. The gate list used to live in three places that could
# disagree: AGENTS.md prose, .github/workflows/ci.yml, and whatever list a plan
# happened to copy into its "Verification" section. On 2026-09-13 a plan copied
# a SUBSET — it had pytest, vitest, pgTAP, svelte-check, postgrestools and
# check_docs.py, and omitted basedpyright, ruff, check-coherence.sh and
# check-spec-sync.sh. Every one of those omissions then failed, but serially,
# discovered from a RED CI run on main instead of locally in one pass. Pushing
# main auto-deploys PROD, so that is an expensive way to find a missing gate.
#
# The fix is to stop maintaining a list. A plan's definition of done is now
# "scripts/preflight.sh exits 0", and this file is the single place the list is
# written down.
#
# CONTRACT. Runs every gate to completion even after one fails — the whole
# point is to surface all failures at once — then prints a summary and exits
# non-zero if any gate failed.
#
# Usage:
#   scripts/preflight.sh              # everything
#   scripts/preflight.sh --fast       # skip pgTAP only; postgrestools still needs the stack
#   scripts/preflight.sh --ci-only    # only what .github/workflows/ci.yml runs

set -uo pipefail
cd "$(dirname "$0")/.."

FAST=0
CI_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --fast)    FAST=1 ;;
    --ci-only) CI_ONLY=1 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

RESULTS=()
FAILED=0

# Run one gate, remember the outcome, never abort the run.
#   $1 = label (also says, in CI/AGENTS terms, who demands it)
#   $2+ = command
gate() {
  local label=$1; shift
  echo ""
  echo "═══ $label ═══"
  if "$@"; then
    RESULTS+=("PASS  $label")
  else
    RESULTS+=("FAIL  $label")
    FAILED=1
  fi
}

# The Python gates run against the project venv when there is one; CI installs
# into the job's own interpreter and needs no activation.
if [[ -f .venv/bin/activate ]]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi

PYTOOL_PATHS=(python/ scripts/ tools/)

# ---------------------------------------------------------------------------
# CI-blocking gates — .github/workflows/ci.yml, job by job.
# ---------------------------------------------------------------------------

# test-python
gate "ruff check (CI)"                ruff check "${PYTOOL_PATHS[@]}"
gate "ruff format --check (CI)"       ruff format --check "${PYTOOL_PATHS[@]}"
gate "basedpyright (CI)"              basedpyright "${PYTOOL_PATHS[@]}"
gate "render_adrs.py --check (CI)"    python scripts/render_adrs.py --check
gate "render_docs.py --check (CI)"    python scripts/render_docs.py --check
gate "render_handbook_frame.py --check (CI)" python scripts/render_handbook_frame.py --check
gate "check_docs.py (CI)"             python scripts/check_docs.py
gate "pytest (CI)"                    pytest -q

# test-frontend
gate "vitest (CI)"                    bash -c 'cd frontend && npm test --silent'

# coherence
gate "check-coherence.sh (CI)"        bash scripts/check-coherence.sh

# test-db — the Supabase stack is needed by both gates below. pgTAP is slow, so
# it is the one gate --fast drops. postgrestools is never dropped: it takes
# seconds, and the script fails (rather than passing quietly) when the stack is
# down, the version differs from the config's pin, or a positive control shows
# the database checks did not run. GATE.01–03.
# The CLI version decides which images the stack boots, so LOCAL runs the one
# every workflow pins, and its extensions are the versions those images ship,
# as on CI's empty database; otherwise LOCAL's checks prove nothing about CI's
# (WFSETUP.03–04).
gate "LOCAL stack = CI's (CLI pin, extensions)" python scripts/check_supabase_cli.py
gate "postgrestools (CI)"             bash scripts/check-postgrestools.sh
if [[ $FAST -eq 1 ]]; then
  RESULTS+=("SKIP  supabase test db (CI) — --fast")
else
  gate "supabase test db (CI)"        supabase test db
fi

# ---------------------------------------------------------------------------
# Gates AGENTS.md requires that CI does not run. A green CI does not make these
# optional; it means CI would not have caught them.
# ---------------------------------------------------------------------------
if [[ $CI_ONLY -eq 0 ]]; then
  gate "check-spec-sync.sh (AGENTS)"  bash scripts/check-spec-sync.sh
  # The anon allowlist lives in two files. pgTAP only reads one of them, so a
  # drift stays green through all of CI and fails in the deploy job instead.
  gate "anon allowlist in sync (deploy)" bash scripts/check-anon-allowlist-sync.sh
  # Warnings fail too (GATE.05): svelte-check alone exits 0 on them.
  gate "svelte-check (AGENTS)"        bash -c 'cd frontend && npm run check -- --fail-on-warnings'
  # The published calculator and scoring-table annex carry a GENERATED copy of
  # frontend/src/lib/scoring.ts. Nothing else may write between their markers,
  # and a stale copy means the pages and the database disagree about the
  # formula — which no other gate would notice.
  gate "published pages match scoring.ts" node frontend/scripts/build-scoring-pages.mjs --check
  # Trailing whitespace blocks scripts/integrate-agent-branch.sh, which runs
  # `git diff --check` before it will merge a task branch.
  gate "git diff --check (integrate)" bash -c 'git fetch origin main -q 2>/dev/null; git diff --check origin/main...HEAD'
  # The branch's name and description become main's merge title and explanation,
  # and GitHub titles the CI and Release runs with it; scripts/integrate-agent-
  # branch.sh refuses a branch this check fails. The check prints those titles.
  # main and integration/main are where branches are merged, not worker branches.
  current_branch=$(git symbolic-ref --quiet --short HEAD || true)
  if [[ "$current_branch" == "main" || "$current_branch" == "integration/main" ]]; then
    RESULTS+=("SKIP  branch, merge and release named (integrate) — $current_branch is not a worker branch")
  else
    gate "branch, merge and release named (integrate)" python3 scripts/branch_description.py check
  fi
fi

# ---------------------------------------------------------------------------
echo ""
echo "════════════════════════ preflight summary ════════════════════════"
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo "═══════════════════════════════════════════════════════════════════"

if [[ $FAILED -eq 1 ]]; then
  echo "PREFLIGHT FAILED — fix every FAIL above before pushing."
  echo "Reminder: a push to main auto-deploys PROD."
  exit 1
fi

echo "All gates passed."
echo "Still owed before a push: scripts/refresh-graph.sh (per-change, not global)."
