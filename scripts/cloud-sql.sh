#!/usr/bin/env bash
# =============================================================================
# cloud-sql.sh — run an ad-hoc SQL statement against a CERT or PROD Supabase
# project via the Management API.
#
# Sibling of apply-migrations.sh and schema-fingerprint.sh, which already reach
# cloud projects through the same endpoint. Those two are purpose-built (apply a
# migration file / compute a fingerprint); this one covers the gap they leave —
# inspection and one-off maintenance that has no migration to carry it, e.g.
# reading a row count on PROD, or removing a test registration.
#
# It is NOT a substitute for a migration. Schema changes belong in
# supabase/migrations/ and must flow through CI so CERT and PROD converge and
# the fingerprint gate stays meaningful. Use this for data, not DDL.
#
# Usage:
#   scripts/cloud-sql.sh <cert|prod> "SELECT count(*) FROM tbl_registration;"
#   scripts/cloud-sql.sh prod < some-query.sql
#
# Environment:
#   SUPABASE_ACCESS_TOKEN  Management API personal access token. Read from the
#                          environment, falling back to .env (never echoed).
#   SUPABASE_CERT_REF /    Project refs. Read from the environment, falling back
#   SUPABASE_PROD_REF      to .env.
#
# Anything that changes rows prints the statement and the target project first
# and requires an explicit confirmation, because "which environment am I on"
# is the mistake this script would otherwise make easy.
# =============================================================================
set -euo pipefail

ENV_NAME="${1:-}"
if [ "$ENV_NAME" != "cert" ] && [ "$ENV_NAME" != "prod" ]; then
  echo "ERROR: first argument must be 'cert' or 'prod'" >&2
  echo "Usage: scripts/cloud-sql.sh <cert|prod> \"SQL\"" >&2
  exit 1
fi

SQL="${2:-}"
if [ -z "$SQL" ]; then
  SQL="$(cat)"
fi
if [ -z "${SQL// /}" ]; then
  echo "ERROR: no SQL supplied (pass as \$2 or on stdin)" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

# Pull a single key out of .env without sourcing the whole file (which would
# also drag in FTL and Telegram credentials this script has no business
# touching). Values are used, never printed.
env_lookup() {
  [ -f "$ENV_FILE" ] || return 0
  sed -n "s/^$1=//p" "$ENV_FILE" | head -1 | tr -d '"'\''' | tr -d '\r'
}

# .env WINS over the shell environment, which is the opposite of the usual
# convention and deliberate. A stale SUPABASE_ACCESS_TOKEN exported from a
# shell profile silently shadowed the good value in .env and produced a flat
# HTTP 401 — indistinguishable from an expired token, and it cost a long
# debugging detour on 2026-08-17. .env is the file a human edits when they
# rotate the token, so .env is the value that should take effect.
# Set CLOUD_SQL_TOKEN_FROM_ENV=1 to invert this for CI, which injects the
# secret as a real environment variable and ships no .env at all.
if [ "${CLOUD_SQL_TOKEN_FROM_ENV:-}" = "1" ]; then
  TOKEN="${SUPABASE_ACCESS_TOKEN:-$(env_lookup SUPABASE_ACCESS_TOKEN)}"
else
  TOKEN="$(env_lookup SUPABASE_ACCESS_TOKEN)"
  TOKEN="${TOKEN:-${SUPABASE_ACCESS_TOKEN:-}}"
fi
if [ -z "$TOKEN" ]; then
  echo "ERROR: SUPABASE_ACCESS_TOKEN not found in .env or environment" >&2
  exit 1
fi

if [ "$ENV_NAME" = "prod" ]; then
  REF="${SUPABASE_PROD_REF:-$(env_lookup SUPABASE_PROD_REF)}"
else
  REF="${SUPABASE_CERT_REF:-$(env_lookup SUPABASE_CERT_REF)}"
fi
if [ -z "$REF" ]; then
  echo "ERROR: project ref for '$ENV_NAME' not found in environment or .env" >&2
  echo "       expected SUPABASE_$(echo "$ENV_NAME" | tr '[:lower:]' '[:upper:]')_REF" >&2
  exit 1
fi

# Write statements get a confirmation gate. Matching on the leading keyword is
# deliberately crude — it is a speed bump against the wrong environment, not a
# security boundary (the token can do anything regardless).
# Take the first WORD, not the first six characters of the whitespace-stripped
# statement — "WITH f AS (SELECT ..." collapses to "WITHfA" and never matches,
# so read-only CTEs were being sent to the confirmation gate. Failing safe, but
# wrong. Leading SQL comments are stripped first.
FIRST_WORD="$(printf '%s' "$SQL" \
  | sed -E 's@/\*([^*]|\*[^/])*\*/@ @g' \
  | sed -E 's@--[^\n]*@ @g' \
  | grep -oiE '[a-z]+' | head -1 | tr '[:lower:]' '[:upper:]')"
case "$FIRST_WORD" in
  SELECT|WITH|EXPLAIN|SHOW|TABLE|VALUES)
    ;;
  *)
    if [ "${CLOUD_SQL_CONFIRM:-}" != "yes" ]; then
      echo "About to run a NON-SELECT statement against $(echo "$ENV_NAME" | tr '[:lower:]' '[:upper:]') (project ${REF:0:6}***):" >&2
      echo "  $SQL" >&2
      echo "Re-run with CLOUD_SQL_CONFIRM=yes to proceed." >&2
      exit 2
    fi
    ;;
esac

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "https://api.supabase.com/v1/projects/${REF}/database/query" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg q "$SQL" '{query: $q}')")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ]; then
  echo "ERROR: query failed (HTTP $HTTP_CODE): $BODY" >&2
  exit 1
fi

echo "$BODY" | jq .
