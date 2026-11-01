#!/bin/bash
# =============================================================================
# Export PROD to single monolithic SQL dump (ADR-036).
# Usage: ./scripts/export-prod.sh
# Requires: SUPABASE_ACCESS_TOKEN in .env or the environment (supabase-token.sh),
#           or a ~/.supabase_token file
# =============================================================================
set -e
cd "$(dirname "$0")/.."

# The token by the one rule: .env first, then the environment (supabase-token.sh).
source "scripts/supabase-token.sh"
export_supabase_access_token
# Neither holds one: the older local file.
if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  TOKEN_FILE="$HOME/.supabase_token"
  if [ -f "$TOKEN_FILE" ]; then
    export SUPABASE_ACCESS_TOKEN="$(cat "$TOKEN_FILE" | tr -d '[:space:]')"
  else
    echo "ERROR: SUPABASE_ACCESS_TOKEN not in .env or the environment, and ~/.supabase_token not found" >&2
    echo "  Put it in .env (SUPABASE_ACCESS_TOKEN=...) or create ~/.supabase_token" >&2
    exit 1
  fi
fi

source .venv/bin/activate

echo "=== Exporting PROD ==="
python3 -m python.pipeline.export_seed --ref ywgymtgcyturldazcpmw
echo "=== Export complete ==="
