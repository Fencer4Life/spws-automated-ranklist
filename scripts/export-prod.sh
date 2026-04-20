#!/bin/bash
# =============================================================================
# Export PROD to single monolithic SQL dump (ADR-036).
# Usage: ./scripts/export-prod.sh
# Requires: SUPABASE_ACCESS_TOKEN env var (or ~/.supabase_token file)
# =============================================================================
set -e
cd "$(dirname "$0")/.."

# Load token from env, or from local file
if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  TOKEN_FILE="$HOME/.supabase_token"
  if [ -f "$TOKEN_FILE" ]; then
    export SUPABASE_ACCESS_TOKEN="$(cat "$TOKEN_FILE" | tr -d '[:space:]')"
  else
    echo "ERROR: SUPABASE_ACCESS_TOKEN not set and ~/.supabase_token not found" >&2
    echo "  Set the env var or create ~/.supabase_token with your org access token" >&2
    exit 1
  fi
fi

source .venv/bin/activate

echo "=== Exporting PROD ==="
python3 -m python.pipeline.export_seed --ref ywgymtgcyturldazcpmw
echo "=== Export complete ==="
