#!/usr/bin/env bash
# check-new-migrations.sh — Determine which migrations are pending for an environment.
#
# Usage:  ./scripts/check-new-migrations.sh <cert|prod>
#
# Reads deployed_migrations.json and compares against supabase/migrations/*.sql.
# Outputs GitHub Actions outputs:
#   has_new_migrations=true|false
#   new_migrations=["file1.sql","file2.sql"]
#   new_migration_count=N

set -euo pipefail

TARGET_ENV="${1:?Usage: check-new-migrations.sh <cert|prod>}"
TRACKING_FILE="deployed_migrations.json"

if [ ! -f "$TRACKING_FILE" ]; then
  echo "ERROR: $TRACKING_FILE not found" >&2
  exit 1
fi

# Get list of already-applied migrations for this environment
APPLIED=$(jq -r ".${TARGET_ENV}.applied[]" "$TRACKING_FILE" 2>/dev/null || echo "")

# Get all migration filenames (sorted = chronological)
ALL_MIGRATIONS=()
for f in supabase/migrations/*.sql; do
  [ -f "$f" ] && ALL_MIGRATIONS+=("$(basename "$f")")
done

# Find new migrations (in ALL but not in APPLIED)
NEW_MIGRATIONS=()
for m in "${ALL_MIGRATIONS[@]}"; do
  if ! echo "$APPLIED" | grep -qF "$m"; then
    NEW_MIGRATIONS+=("$m")
  fi
done

COUNT=${#NEW_MIGRATIONS[@]}

if [ "$COUNT" -eq 0 ]; then
  HAS_NEW="false"
  JSON_ARRAY="[]"
else
  HAS_NEW="true"
  JSON_ARRAY=$(printf '%s\n' "${NEW_MIGRATIONS[@]}" | jq -R . | jq -sc .)
fi

echo "has_new_migrations=$HAS_NEW"
echo "new_migration_count=$COUNT"
echo "new_migrations=$JSON_ARRAY"

# Write to GitHub Actions outputs if running in CI
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "has_new_migrations=$HAS_NEW" >> "$GITHUB_OUTPUT"
  echo "new_migration_count=$COUNT" >> "$GITHUB_OUTPUT"
  echo "new_migrations=$JSON_ARRAY" >> "$GITHUB_OUTPUT"
fi
