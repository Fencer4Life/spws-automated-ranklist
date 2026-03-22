#!/usr/bin/env bash
# apply-migrations.sh — Apply pending SQL migrations to a Supabase cloud project.
#
# Usage:  ./scripts/apply-migrations.sh <cert|prod> <LOCAL_FINGERPRINT>
#
# Env vars required:
#   SUPABASE_ACCESS_TOKEN  — Supabase Management API personal access token
#   SUPABASE_REF           — Target project ref (e.g. sdomfjncmfydlkygzpgw)
#
# Steps:
#   1. Determine pending migrations via check-new-migrations.sh
#   2. Apply each migration via Management API POST
#   3. Compute cloud schema fingerprint and compare to LOCAL_FINGERPRINT
#   4. Fail hard on any error or fingerprint mismatch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_ENV="${1:?Usage: apply-migrations.sh <cert|prod> <LOCAL_FINGERPRINT>}"
LOCAL_FINGERPRINT="${2:?Usage: apply-migrations.sh <cert|prod> <LOCAL_FINGERPRINT>}"

if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  echo "ERROR: SUPABASE_ACCESS_TOKEN env var required" >&2
  exit 1
fi
if [ -z "${SUPABASE_REF:-}" ]; then
  echo "ERROR: SUPABASE_REF env var required" >&2
  exit 1
fi

API_URL="https://api.supabase.com/v1/projects/${SUPABASE_REF}/database/query"

# Step 1: Get pending migrations
echo "=== Checking pending migrations for $TARGET_ENV ==="
PENDING_OUTPUT=$("$SCRIPT_DIR/check-new-migrations.sh" "$TARGET_ENV")
HAS_NEW=$(echo "$PENDING_OUTPUT" | grep "has_new_migrations=" | cut -d= -f2)
NEW_MIGRATIONS=$(echo "$PENDING_OUTPUT" | grep "new_migrations=" | sed 's/^new_migrations=//')

if [ "$HAS_NEW" = "false" ]; then
  echo "No pending migrations for $TARGET_ENV."

  # Still verify fingerprint even if no new migrations
  echo "=== Verifying schema fingerprint ==="
  CLOUD_FP=$("$SCRIPT_DIR/schema-fingerprint.sh" cloud "$SUPABASE_REF")
  if [ "$CLOUD_FP" = "$LOCAL_FINGERPRINT" ]; then
    echo "Fingerprint OK: $CLOUD_FP"
    exit 0
  else
    echo "ERROR: Fingerprint mismatch!" >&2
    echo "  LOCAL: $LOCAL_FINGERPRINT" >&2
    echo "  CLOUD: $CLOUD_FP" >&2
    exit 1
  fi
fi

# Step 2: Apply each pending migration
FILENAMES=$(echo "$NEW_MIGRATIONS" | jq -r '.[]')
APPLIED=()

echo "=== Applying migrations to $TARGET_ENV ==="
while IFS= read -r filename; do
  FILEPATH="supabase/migrations/$filename"
  if [ ! -f "$FILEPATH" ]; then
    echo "ERROR: Migration file not found: $FILEPATH" >&2
    exit 1
  fi

  echo "  Applying: $filename"
  SQL_CONTENT=$(cat "$FILEPATH")

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "$API_URL" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg q "$SQL_CONTENT" '{query: $q}')")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ]; then
    echo "ERROR: Migration $filename failed (HTTP $HTTP_CODE):" >&2
    echo "$BODY" >&2
    echo "" >&2
    echo "Applied before failure: ${APPLIED[*]:-none}" >&2
    exit 1
  fi

  # Check for SQL errors in the response body
  HAS_ERROR=$(echo "$BODY" | jq -r 'if type == "array" then .[0].error // empty elif type == "object" then .error // empty else empty end' 2>/dev/null || echo "")
  if [ -n "$HAS_ERROR" ]; then
    echo "ERROR: SQL error in $filename:" >&2
    echo "$HAS_ERROR" >&2
    echo "" >&2
    echo "Applied before failure: ${APPLIED[*]:-none}" >&2
    exit 1
  fi

  APPLIED+=("$filename")
  echo "    OK"

  # Rate limiting: 1s delay between migrations
  sleep 1
done <<< "$FILENAMES"

echo "=== All ${#APPLIED[@]} migrations applied ==="

# Step 3: Verify schema fingerprint
echo "=== Verifying schema fingerprint ==="
CLOUD_FP=$("$SCRIPT_DIR/schema-fingerprint.sh" cloud "$SUPABASE_REF")

if [ "$CLOUD_FP" = "$LOCAL_FINGERPRINT" ]; then
  echo "Fingerprint OK: $CLOUD_FP"
else
  echo "ERROR: Fingerprint mismatch after applying migrations!" >&2
  echo "  LOCAL: $LOCAL_FINGERPRINT" >&2
  echo "  CLOUD: $CLOUD_FP" >&2
  exit 1
fi

# Output applied migrations for tracking
echo "applied_migrations=$(printf '%s\n' "${APPLIED[@]}" | jq -R . | jq -s .)"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "applied_migrations=$(printf '%s\n' "${APPLIED[@]}" | jq -R . | jq -s .)" >> "$GITHUB_OUTPUT"
  echo "cloud_fingerprint=$CLOUD_FP" >> "$GITHUB_OUTPUT"
fi
