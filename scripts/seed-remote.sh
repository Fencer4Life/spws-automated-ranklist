#!/usr/bin/env bash
# seed-remote.sh — Truncate and re-seed a remote Supabase database.
#
# Usage:  SUPABASE_ACCESS_TOKEN=... SUPABASE_REF=... ./scripts/seed-remote.sh
#
# Steps:
#   1. TRUNCATE all data tables in FK-safe order
#   2. Push seed.sql (seasons, organizers)
#   3. Push seed_tbl_fencer.sql
#   4. Push each data/**/*.sql in alphabetical glob order
#
# Safety:
#   - Refuses to run against PROD ref (ywgymtgcyturldazcpmw) without --force
#   - Each SQL file is sent via Supabase Management API POST
#   - Stops on first error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROD_REF="ywgymtgcyturldazcpmw"

if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  echo "ERROR: SUPABASE_ACCESS_TOKEN env var required" >&2
  exit 1
fi
if [ -z "${SUPABASE_REF:-}" ]; then
  echo "ERROR: SUPABASE_REF env var required" >&2
  exit 1
fi

# Safety: block PROD unless --force
if [ "$SUPABASE_REF" = "$PROD_REF" ] && [ "${1:-}" != "--force" ]; then
  echo "ERROR: Refusing to seed PROD without --force flag" >&2
  exit 1
fi

API_URL="https://api.supabase.com/v1/projects/${SUPABASE_REF}/database/query"

# ── Helper: execute SQL via Management API ──────────────────────────────────
run_sql() {
  local label="$1"
  local sql="$2"

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "$API_URL" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg q "$sql" '{query: $q}')")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ]; then
    echo "ERROR: $label failed (HTTP $HTTP_CODE):" >&2
    echo "$BODY" >&2
    exit 1
  fi

  # Check for SQL errors in response
  HAS_ERROR=$(echo "$BODY" | jq -r 'if type == "array" then .[0].error // empty elif type == "object" then .error // empty else empty end' 2>/dev/null || echo "")
  if [ -n "$HAS_ERROR" ]; then
    echo "ERROR: SQL error in $label:" >&2
    echo "$HAS_ERROR" >&2
    exit 1
  fi
}

# ── Step 1: Truncate all data tables (FK-safe order) ────────────────────────
echo "=== Step 1: Truncating all data tables ==="
TRUNCATE_SQL="
TRUNCATE TABLE
  tbl_audit_log,
  tbl_match_candidate,
  tbl_result,
  tbl_scoring_config,
  tbl_tournament,
  tbl_event,
  tbl_fencer,
  tbl_organizer,
  tbl_season
RESTART IDENTITY CASCADE;
"
run_sql "TRUNCATE" "$TRUNCATE_SQL"
echo "  Truncated all tables."
sleep 1

# ── Step 2: Push seed.sql ───────────────────────────────────────────────────
echo "=== Step 2: Seeding bootstrap data (seasons, organizers) ==="
run_sql "seed.sql" "$(cat "$PROJECT_ROOT/supabase/seed.sql")"
echo "  seed.sql OK"
sleep 1

# ── Step 3: Push seed_tbl_fencer.sql ────────────────────────────────────────
echo "=== Step 3: Seeding fencer data ==="
run_sql "seed_tbl_fencer.sql" "$(cat "$PROJECT_ROOT/supabase/seed_tbl_fencer.sql")"
echo "  seed_tbl_fencer.sql OK"
sleep 1

# ── Step 4: Push data/**/*.sql in sorted order ──────────────────────────────
echo "=== Step 4: Seeding season data files ==="
FILE_COUNT=0

for sql_file in $(find "$PROJECT_ROOT/supabase/data" -name '*.sql' -type f | sort); do
  REL_PATH="${sql_file#"$PROJECT_ROOT/"}"
  echo "  Seeding: $REL_PATH"
  run_sql "$REL_PATH" "$(cat "$sql_file")"
  echo "    OK"
  FILE_COUNT=$((FILE_COUNT + 1))
  sleep 1
done

echo ""
echo "=== Seed complete: 2 bootstrap files + $FILE_COUNT data files ==="

# ── Step 5: Quick verification ──────────────────────────────────────────────
echo "=== Verifying seed data ==="
VERIFY_SQL="
SELECT json_build_object(
  'seasons', (SELECT count(*) FROM tbl_season),
  'organizers', (SELECT count(*) FROM tbl_organizer),
  'fencers', (SELECT count(*) FROM tbl_fencer),
  'events', (SELECT count(*) FROM tbl_event),
  'tournaments', (SELECT count(*) FROM tbl_tournament),
  'results', (SELECT count(*) FROM tbl_result)
);
"

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "$API_URL" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg q "$VERIFY_SQL" '{query: $q}')")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  echo "$BODY" | jq '.[0].json_build_object // .[0]' 2>/dev/null || echo "$BODY"
else
  echo "WARNING: Verification query failed (HTTP $HTTP_CODE), but seed may still be OK" >&2
fi

echo ""
echo "Done."
