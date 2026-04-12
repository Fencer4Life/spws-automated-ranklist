#!/bin/bash
# =============================================================================
# Export PROD to single monolithic SQL dump (ADR-036).
# Usage: ./scripts/export-prod.sh
# =============================================================================
set -e
cd "$(dirname "$0")/.."

export SUPABASE_ACCESS_TOKEN="sbp_3dd15a0de5550c66f093090c7fd4c7e99039ce1d"
source .venv/bin/activate

echo "=== Exporting PROD ==="
python3 -m python.pipeline.export_seed --ref ywgymtgcyturldazcpmw
echo "=== Export complete ==="
