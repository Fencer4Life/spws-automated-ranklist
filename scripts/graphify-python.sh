#!/usr/bin/env bash
#
# graphify-python.sh — run a script under graphify's own interpreter.
#
# graphify is installed as a uv tool with its own Python, never in the project
# venv. Two things run there: the graph refresh (scripts/refresh-graph.sh) and
# preflight's check that the .svelte rescue still has something to rescue
# (scripts/graphify_svelte_extract.py --check-premise, ADR-119 G24). Both find
# the interpreter here, so they cannot disagree about which one it is.
#
#   scripts/graphify-python.sh <script.py> [args...]
#
# The interpreter is the one pinned in graphify-out/.graphify_python, else uv's
# default tool location. It must import graphify; if it does not, this exits 2.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

PY_PIN="graphify-out/.graphify_python"
PY_FALLBACK="/Users/aleks/.local/share/uv/tools/graphifyy/bin/python"

PYTHON=""
if [ -f "$PY_PIN" ]; then PYTHON="$(cat "$PY_PIN")"; fi
if [ -z "$PYTHON" ] || [ ! -x "$PYTHON" ]; then PYTHON="$PY_FALLBACK"; fi
if [ ! -x "$PYTHON" ] || ! "$PYTHON" -c "import graphify" 2>/dev/null; then
  echo "graphify-python: graphify interpreter not found (looked at '$PYTHON')." >&2
  echo "  Install with: uv tool install graphifyy   then run a full /graphify ." >&2
  exit 2
fi

exec "$PYTHON" "$@"
