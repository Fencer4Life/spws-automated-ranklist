#!/usr/bin/env bash
# commit-tracking.sh — record a finished deploy on main as a [skip ci] commit.
#
# Usage:  scripts/commit-tracking.sh <cert|prod> <DEPLOYED_SHA> <FINGERPRINT> [APPLIED_JSON]
#
# Run from the deploy job's checkout: the commit build fingerprinted
# (release.yml needs.build.outputs.sha), which may be behind main by the time the
# deploy finishes. The record is written on top of origin/main in a separate
# worktree, so the job's tree stays the deployed one:
#   deployed_migrations.json  <env>.last_sha, applied, fingerprint (update-tracking.sh)
#   release-manifest.json     cert only: the manifest of the deployed tree
#                             (generate-manifest.sh) with main's deployed block kept;
#                             update-tracking.sh then stamps the environment into it.
# A rejected push (another workflow pushed to main meanwhile) fetches main again and
# writes the record anew on the new tip: update-tracking.sh re-derives the file from
# what is there, so nothing is lost. Tests: python/tests/test_release_tracking_commit.py.
#
# Env: COMMIT_TRACKING_ATTEMPTS (default 5), COMMIT_TRACKING_PAUSE (most seconds
# between attempts, default 5).

set -euo pipefail

USAGE="Usage: commit-tracking.sh <cert|prod> <DEPLOYED_SHA> <FINGERPRINT> [APPLIED_JSON]"
TARGET_ENV="${1:?$USAGE}"
DEPLOYED_SHA="${2:?$USAGE}"
FINGERPRINT="${3:?$USAGE}"
APPLIED_JSON="${4:-[]}"
ATTEMPTS="${COMMIT_TRACKING_ATTEMPTS:-5}"
PAUSE="${COMMIT_TRACKING_PAUSE:-5}"

case "$TARGET_ENV" in
  cert) LABEL=CERT ;;
  prod) LABEL=PROD ;;
  *) echo "$USAGE" >&2; exit 2 ;;
esac

DEPLOYED_TREE="$(pwd)"
SCRIPTS="$DEPLOYED_TREE/scripts"
TMP="$(mktemp -d)"
MAIN="$TMP/main"
cleanup() {
  git -C "$DEPLOYED_TREE" worktree remove --force "$MAIN" >/dev/null 2>&1 || true
  git -C "$DEPLOYED_TREE" worktree prune >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

if [ "$TARGET_ENV" = cert ]; then
  # Counted on the deployed tree; generate-manifest.sh names the commit by GITHUB_SHA.
  GITHUB_SHA="$DEPLOYED_SHA" bash "$SCRIPTS/generate-manifest.sh" "$FINGERPRINT"
  cp release-manifest.json "$TMP/deployed-manifest.json"
  git checkout -q -- release-manifest.json
fi

for attempt in $(seq 1 "$ATTEMPTS"); do
  git worktree remove --force "$MAIN" >/dev/null 2>&1 || true
  git fetch -q origin main
  git worktree add -q --detach "$MAIN" FETCH_HEAD
  (
    cd "$MAIN"
    if [ "$TARGET_ENV" = cert ]; then
      jq --slurpfile built "$TMP/deployed-manifest.json" '$built[0] + {deployed: .deployed}' \
        release-manifest.json >"$TMP/merged-manifest.json"
      mv "$TMP/merged-manifest.json" release-manifest.json
    fi
    bash "$SCRIPTS/update-tracking.sh" "$TARGET_ENV" "$DEPLOYED_SHA" "$FINGERPRINT" "$APPLIED_JSON" >/dev/null
    git add deployed_migrations.json release-manifest.json
    git commit -q -m "chore: update $LABEL tracking [skip ci]"
  )
  if git -C "$MAIN" push -q origin HEAD:main; then
    echo "Pushed on attempt $attempt"
    exit 0
  fi
  if [ "$attempt" -lt "$ATTEMPTS" ]; then
    echo "Push rejected (main moved) -- fetching main and writing the record again ($attempt/$ATTEMPTS)"
    sleep $((RANDOM % (PAUSE + 1)))
  fi
done

echo "::error::Failed to push $LABEL tracking update after $ATTEMPTS attempts" >&2
exit 1
