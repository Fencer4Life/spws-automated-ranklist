#!/bin/bash
# =============================================================================
# Mirror PROD to local DB (ADR-036).
# Export → reset → verify. One command.
# Usage: ./scripts/mirror-prod.sh
# =============================================================================
set -e
cd "$(dirname "$0")/.."

echo "========================================"
echo "  PROD → Local DB Mirror"
echo "========================================"

echo ""
echo "=== Step 1: Export PROD ==="
./scripts/export-prod.sh

echo ""
echo "=== Step 2: Reset local DB ==="
./scripts/reset-dev.sh

echo ""
echo "=== Step 2.5: Update test expected values ==="
./scripts/update-test-values.sh

echo ""
echo "=== Step 3: Verify local matches PROD ==="
source .venv/bin/activate
python3 -m pytest python/tests/test_prod_mirror.py -v

echo ""
echo "=== Step 4: Run pgTAP tests ==="
supabase test db

echo ""
echo "========================================"
echo "  Mirror complete. Local DB = PROD."
echo "========================================"
