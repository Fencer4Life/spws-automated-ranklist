#!/usr/bin/env bash
# generate-manifest.sh — Generate release-manifest.json from current repo state.
#
# Usage:  ./scripts/generate-manifest.sh <SCHEMA_FINGERPRINT>
#
# Reads version from pyproject.toml, counts migrations, tests, etc.
# Writes release-manifest.json.

set -euo pipefail

FINGERPRINT="${1:?Usage: generate-manifest.sh <SCHEMA_FINGERPRINT>}"
MANIFEST_FILE="release-manifest.json"
SHA="${GITHUB_SHA:-$(git rev-parse --short HEAD)}"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Read version from pyproject.toml
VERSION=$(grep '^version' pyproject.toml | head -1 | sed 's/version *= *"\(.*\)"/\1/')

# Count migrations
MIGRATION_COUNT=$(ls -1 supabase/migrations/*.sql 2>/dev/null | wc -l | tr -d ' ')

# Determine new migrations since last manifest
if [ -f "$MANIFEST_FILE" ]; then
  PREV_TOTAL=$(jq '.migrations.total' "$MANIFEST_FILE" 2>/dev/null || echo 0)
else
  PREV_TOTAL=0
fi

if [ "$MIGRATION_COUNT" -gt "$PREV_TOTAL" ]; then
  # Get the last N migration filenames
  SKIP=$((PREV_TOTAL))
  NEW_SINCE=$(ls -1 supabase/migrations/*.sql | sort | tail -n +"$((SKIP + 1))" | xargs -n1 basename | jq -R . | jq -s .)
else
  NEW_SINCE="[]"
fi

# Count test files
PGTAP_FILES=$(ls -1 supabase/tests/*.sql 2>/dev/null | wc -l | tr -d ' ')
PYTEST_FILES=$(ls -1 python/tests/test_*.py 2>/dev/null | wc -l | tr -d ' ')
VITEST_FILES=$(ls -1 frontend/tests/*.test.ts 2>/dev/null | wc -l | tr -d ' ')

# Count pgTAP assertions (sum of plan(N) values)
PGTAP_ASSERTIONS=0
for f in supabase/tests/*.sql; do
  if [ -f "$f" ]; then
    N=$(grep -oP 'SELECT plan\(\K[0-9]+' "$f" 2>/dev/null || echo 0)
    PGTAP_ASSERTIONS=$((PGTAP_ASSERTIONS + N))
  fi
done

# Preserve existing deployment info
if [ -f "$MANIFEST_FILE" ]; then
  DEPLOYED=$(jq '.deployed' "$MANIFEST_FILE")
else
  DEPLOYED='{
    "cert": { "at": null, "sha": null, "schema_fingerprint": null },
    "prod": { "at": null, "sha": null, "schema_fingerprint": null }
  }'
fi

# Write manifest
jq -n \
  --arg version "$VERSION" \
  --arg sha "$SHA" \
  --arg now "$NOW" \
  --arg fp "$FINGERPRINT" \
  --argjson total "$MIGRATION_COUNT" \
  --argjson new_since "$NEW_SINCE" \
  --argjson pgtap_files "$PGTAP_FILES" \
  --argjson pgtap_asserts "$PGTAP_ASSERTIONS" \
  --argjson pytest_files "$PYTEST_FILES" \
  --argjson vitest_files "$VITEST_FILES" \
  --argjson deployed "$DEPLOYED" \
  '{
    version: $version,
    sha: $sha,
    created: $now,
    schema_fingerprint: $fp,
    migrations: {
      total: $total,
      new_since_last: $new_since
    },
    tests: {
      pgtap: { files: $pgtap_files, assertions: $pgtap_asserts },
      pytest: { files: $pytest_files },
      vitest: { files: $vitest_files }
    },
    deployed: $deployed
  }' > "$MANIFEST_FILE"

echo "Generated $MANIFEST_FILE (v$VERSION, SHA $SHA, fingerprint $FINGERPRINT)"
