#!/usr/bin/env bash
# release-section.sh — write what a deploy job deployed onto the Release run's Summary page.
#
# Usage:  scripts/release-section.sh <cert|prod>
#
# deploy-cert and deploy-prod run it as the step just before their Telegram alert, with
# `if: always()`, so a failed deploy is reported too: the commit, the migrations applied
# or none, the fingerprint check, the Edge Function, the security posture, the record on
# main, or the first step that failed. It only formats the values release.yml passes in
# env: and never fails the job, because the alert after it would then name the deploy as
# what failed. Outside Actions (no GITHUB_STEP_SUMMARY) it prints to stdout.
#
# Env: DEPLOYED_SHA, FINGERPRINT, HAS_NEW_MIGRATIONS (true|false), NEW_MIGRATIONS (JSON
# array), and each step's outcome: OUTCOME_CHECK, OUTCOME_APPLY, OUTCOME_VERIFY,
# OUTCOME_FUNCTIONS, OUTCOME_POSTURE, OUTCOME_RECORD; GITHUB_REPOSITORY for the link.
#
# Plan: doc/plans/release-notes-on-every-release-run-2026-11-01.html (R1 A).
# Tests: python/tests/test_release_notes.py RELNOTES.11.

set -uo pipefail

case "${1:-}" in
  cert) LABEL=CERT ;;
  prod) LABEL=PROD ;;
  *) echo "Usage: release-section.sh <cert|prod>" >&2; exit 2 ;;
esac

out="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
sha="${DEPLOYED_SHA:-}"
fingerprint="${FINGERPRINT:-}"
commit="<code>${sha:0:8}</code>"
if [ -n "${GITHUB_REPOSITORY:-}" ] && [ -n "$sha" ]; then
  commit="<a href=\"https://github.com/${GITHUB_REPOSITORY}/commit/${sha}\">${commit}</a>"
fi

# The first step that did not finish, in the order the job runs them.
stopped=""
stopped_how=""
for step in "CHECK:checking for pending migrations" \
            "APPLY:applying the migrations" \
            "VERIFY:verifying the schema fingerprint" \
            "FUNCTIONS:deploying the Edge Function" \
            "POSTURE:verifying the security posture" \
            "RECORD:recording the deploy on main"; do
  var="OUTCOME_${step%%:*}"
  case "${!var:-}" in
    failure) stopped="${step#*:}"; stopped_how="failed"; break ;;
    cancelled) stopped="${step#*:}"; stopped_how="was cancelled"; break ;;
  esac
done

{
  printf '### %s\n\n' "$LABEL"
  if [ -n "$stopped" ]; then
    printf '<p><b>%s</b> deploy %s at: %s, for %s.' "$LABEL" "$stopped_how" "$stopped" "$commit"
    [ "$LABEL" = CERT ] && printf ' PROD was not deployed.'
    printf '</p>\n\n'
  else
    if [ "${HAS_NEW_MIGRATIONS:-}" = true ]; then
      count="$(jq -r 'length' <<<"${NEW_MIGRATIONS:-[]}" 2>/dev/null || echo "?")"
      names="$(jq -r 'map("<code>" + . + "</code>") | join(", ")' <<<"${NEW_MIGRATIONS:-[]}" 2>/dev/null \
        || printf '<code>%s</code>' "${NEW_MIGRATIONS:-}")"
      noun=migrations
      [ "$count" = 1 ] && noun=migration
      migrations="$count $noun applied: $names"
    else
      migrations="No new migration"
    fi
    printf '<p><b>%s</b> runs %s. %s; schema fingerprint <code>%s…</code> matches the build. ' \
      "$LABEL" "$commit" "$migrations" "${fingerprint:0:8}"
    printf 'Edge Function <code>dispatch-workflow</code> deployed. Security posture verified. Recorded on main.</p>\n\n'
    if [ "$LABEL" = CERT ]; then
      printf '<p><sub>PROD waits for approval in the production environment; its section appears when deploy-prod has run.</sub></p>\n\n'
    fi
  fi
} >>"$out"

exit 0
