#!/usr/bin/env bash
# schema-fingerprint.sh — Compute a deterministic hash of the public schema.
#
# Usage:
#   LOCAL:  ./scripts/schema-fingerprint.sh local
#   CLOUD:  ./scripts/schema-fingerprint.sh cloud <SUPABASE_REF>
#
# Requires: psql (local) or curl + SUPABASE_ACCESS_TOKEN env var (cloud)
#
# Output: prints the schema fingerprint (md5 hex string) to stdout.
# Exit 0 on success, 1 on error.

set -euo pipefail

MODE="${1:-local}"
SUPABASE_REF="${2:-}"

# The SQL that computes the fingerprint — two sub-hashes combined.
read -r -d '' FINGERPRINT_SQL << 'EOSQL' || true
WITH func_hash AS (
  SELECT md5(string_agg(
    coalesce(routine_name,'') || '|' || coalesce(routine_definition,''),
    E'\n' ORDER BY routine_name
  )) AS h
  FROM information_schema.routines
  WHERE routine_schema = 'public'
),
col_hash AS (
  SELECT md5(string_agg(
    table_name || '|' || column_name || '|' || data_type || '|' || coalesce(column_default,''),
    E'\n' ORDER BY table_name, ordinal_position
  )) AS h
  FROM information_schema.columns
  WHERE table_schema = 'public'
)
SELECT md5(coalesce(f.h,'') || coalesce(c.h,'')) AS schema_fingerprint
FROM func_hash f, col_hash c;
EOSQL

if [ "$MODE" = "local" ]; then
  # Local Docker Supabase — psql on port 54322
  RESULT=$(psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
    -t -A -c "$FINGERPRINT_SQL" 2>&1)
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to compute local fingerprint: $RESULT" >&2
    exit 1
  fi
  echo "$RESULT"

elif [ "$MODE" = "cloud" ]; then
  if [ -z "$SUPABASE_REF" ]; then
    echo "ERROR: SUPABASE_REF required for cloud mode" >&2
    exit 1
  fi
  if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
    echo "ERROR: SUPABASE_ACCESS_TOKEN env var required" >&2
    exit 1
  fi

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "https://api.supabase.com/v1/projects/${SUPABASE_REF}/database/query" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg q "$FINGERPRINT_SQL" '{query: $q}')")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ]; then
    echo "ERROR: Cloud query failed (HTTP $HTTP_CODE): $BODY" >&2
    exit 1
  fi

  FINGERPRINT=$(echo "$BODY" | jq -r '.[0].schema_fingerprint // empty')
  if [ -z "$FINGERPRINT" ]; then
    echo "ERROR: Could not extract fingerprint from response: $BODY" >&2
    exit 1
  fi
  echo "$FINGERPRINT"

else
  echo "ERROR: Unknown mode '$MODE'. Use 'local' or 'cloud'." >&2
  exit 1
fi
