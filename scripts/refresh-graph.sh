#!/usr/bin/env bash
#
# refresh-graph.sh — keep the graphify knowledge graph (graphify-out/) current
# before committing. Smart about cost: code changes use a free targeted AST
# merge (no LLM); doc changes are flagged for the /graphify . --update flow that
# only the agent can drive; no-op / whitespace-only commits are skipped.
#
# Run from anywhere; it locates the repo root from its own path.
#
#   scripts/refresh-graph.sh [--skip-whitespace] [--quiet]
#
# Exit-code contract (the agent acts on this before committing):
#   0  — graph is current: refreshed headlessly, or nothing relevant changed.
#        Safe to commit.
#   10 — doc/paper/image files changed: re-extraction needs LLM subagents.
#        Run `/graphify . --update`, THEN commit. Changed files + a sentinel line
#        `GRAPHIFY_NEEDS_SEMANTIC=<n>` are printed.
#   3  — no graph yet (graphify-out/graph.json missing). Run a full `/graphify .`.
#   2  — usage / environment error (graphify interpreter not found, shrink guard).
#
# Flags:
#   --skip-whitespace  Skip when the only changes vs HEAD are whitespace (catches
#                      pure-formatting commits). Off by default — lint passes that
#                      drop imports DO change the AST graph and should refresh.
#   --quiet            Less chatter.
#
# All real logic lives in scripts/graphify_refresh.py; this wrapper only resolves
# graphify's isolated interpreter (NOT the project venv) and forwards arguments.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

PY_PIN="graphify-out/.graphify_python"
PY_FALLBACK="/Users/aleks/.local/share/uv/tools/graphifyy/bin/python"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
fi

PYTHON=""
if [ -f "$PY_PIN" ]; then PYTHON="$(cat "$PY_PIN")"; fi
if [ -z "$PYTHON" ] || [ ! -x "$PYTHON" ]; then PYTHON="$PY_FALLBACK"; fi
if [ ! -x "$PYTHON" ] || ! "$PYTHON" -c "import graphify" 2>/dev/null; then
  echo "refresh-graph: graphify interpreter not found (looked at '$PYTHON')." >&2
  echo "  Install with: uv tool install graphifyy   then run a full /graphify ." >&2
  exit 2
fi

exec "$PYTHON" "${SCRIPT_DIR}/graphify_refresh.py" "$@"
