#!/usr/bin/env bash
# update-tracking.sh — Update deployed_migrations.json and release-manifest.json
#                       after a successful migration deploy.
#
# Usage:  ./scripts/update-tracking.sh <cert|prod> <SHA> <FINGERPRINT> [APPLIED_JSON]
#
# APPLIED_JSON: JSON array of newly applied migration filenames, e.g. '["file1.sql","file2.sql"]'
#               If omitted or empty, only timestamps and fingerprint are updated.

set -euo pipefail

TARGET_ENV="${1:?Usage: update-tracking.sh <cert|prod> <SHA> <FINGERPRINT> [APPLIED_JSON]}"
SHA="${2:?Usage: update-tracking.sh <cert|prod> <SHA> <FINGERPRINT> [APPLIED_JSON]}"
FINGERPRINT="${3:?Usage: update-tracking.sh <cert|prod> <SHA> <FINGERPRINT> [APPLIED_JSON]}"
APPLIED_JSON="${4:-[]}"

TRACKING_FILE="deployed_migrations.json"
MANIFEST_FILE="release-manifest.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ ! -f "$TRACKING_FILE" ]; then
  echo "ERROR: $TRACKING_FILE not found" >&2
  exit 1
fi

echo "=== Updating tracking for $TARGET_ENV ==="

# Update deployed_migrations.json
# 1. Append new migrations to the applied array
# 2. Update last_updated, last_sha, schema_fingerprint
UPDATED=$(jq \
  --arg env "$TARGET_ENV" \
  --arg now "$NOW" \
  --arg sha "$SHA" \
  --arg fp "$FINGERPRINT" \
  --argjson new "$APPLIED_JSON" \
  '.[$env].applied = (.[$env].applied + $new | unique) |
   .[$env].last_updated = $now |
   .[$env].last_sha = $sha |
   .[$env].schema_fingerprint = $fp' \
  "$TRACKING_FILE")

echo "$UPDATED" > "$TRACKING_FILE"
echo "  $TRACKING_FILE updated"

# Update release-manifest.json if it exists
if [ -f "$MANIFEST_FILE" ]; then
  UPDATED_MANIFEST=$(jq \
    --arg env "$TARGET_ENV" \
    --arg now "$NOW" \
    --arg sha "$SHA" \
    --arg fp "$FINGERPRINT" \
    '.deployed[$env].at = $now |
     .deployed[$env].sha = $sha |
     .deployed[$env].schema_fingerprint = $fp' \
    "$MANIFEST_FILE")

  echo "$UPDATED_MANIFEST" > "$MANIFEST_FILE"
  echo "  $MANIFEST_FILE updated"
fi

echo "  Done."
