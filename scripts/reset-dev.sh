#!/usr/bin/env bash
# reset-dev.sh — Reset local Supabase DB and recreate the admin user.
#
# Usage:  ./scripts/reset-dev.sh
#
# After `supabase db reset`, the GoTrue auth database is wiped along with
# all app tables. This script re-runs the reset and then recreates the
# local admin account via GoTrue's Admin API.

set -euo pipefail

# Safety: this script ONLY targets the local Supabase instance.
# The service role key below is the well-known demo key that ships with
# `supabase init` — it does NOT work on CERT or PROD.
# CERT and PROD admin accounts are managed separately via Supabase Dashboard.

ADMIN_EMAIL="admin@spws.local"
ADMIN_PASSWORD="admin123"
SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
GOTRUE_URL="http://localhost:54321/auth/v1"

echo "=== Resetting local Supabase database ==="
supabase db reset

echo ""
echo "=== Waiting for GoTrue to be ready ==="
for i in $(seq 1 15); do
  if curl -sf "${GOTRUE_URL}/health" > /dev/null 2>&1; then
    echo "GoTrue ready after ${i}s"
    break
  fi
  if [ "$i" -eq 15 ]; then
    echo "ERROR: GoTrue not ready after 15s"
    exit 1
  fi
  sleep 1
done

echo "=== Creating admin user (${ADMIN_EMAIL}) ==="
MAX_RETRIES=3
for attempt in $(seq 1 ${MAX_RETRIES}); do
  RESPONSE=$(curl -s "${GOTRUE_URL}/admin/users" \
    -H "apikey: ${SERVICE_ROLE_KEY}" \
    -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\",\"email_confirm\":true}")

  if echo "${RESPONSE}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('email')" 2>/dev/null; then
    echo "Admin user created: ${ADMIN_EMAIL} / ${ADMIN_PASSWORD}"
    break
  fi

  if [ "$attempt" -eq ${MAX_RETRIES} ]; then
    echo "ERROR: Failed to create admin user after ${MAX_RETRIES} attempts"
    echo "${RESPONSE}"
    exit 1
  fi

  echo "Attempt ${attempt} failed, retrying in 2s..."
  sleep 2
done

echo ""
echo "=== Done. Open http://localhost:5173/?admin=1 to log in ==="
