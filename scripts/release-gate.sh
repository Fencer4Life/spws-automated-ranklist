#!/usr/bin/env bash
# ADR-094: skip Release's build/deploy chain when a CI run carried
# documentation only. release.yml is triggered by `workflow_run`, whose
# payload has no `before` SHA (unlike `push`, which ci.yml reads for
# check_docs.py), so this script derives the range itself and writes a
# single `deploy` boolean to GITHUB_OUTPUT.
#
# Fails OPEN by design: anything it cannot classify with confidence deploys.
# A missed skip costs a routine, low-risk release run; a wrong skip would
# silently leave a real change stuck on CERT/PROD.
#
# Env (all overridable for tests; production values come from the workflow):
#   RELEASE_GATE_EVENT      github.event_name          (default: workflow_run)
#   RELEASE_GATE_BASE_SHA   base of the range to diff  (default: workflow_run.before)
#   RELEASE_GATE_HEAD_SHA   head of the range to diff  (default: workflow_run.head_sha)
#   GITHUB_OUTPUT           where to write deploy=true|false
set -euo pipefail

event="${RELEASE_GATE_EVENT:-${GITHUB_EVENT_NAME:-workflow_run}}"
base_sha="${RELEASE_GATE_BASE_SHA:-${GITHUB_EVENT_WORKFLOW_RUN_BEFORE:-}}"
head_sha="${RELEASE_GATE_HEAD_SHA:-${GITHUB_EVENT_WORKFLOW_RUN_HEAD_SHA:-}}"

deploy() {
    echo "deploy=$1" >>"$GITHUB_OUTPUT"
    echo "$2"
}

# A manual dispatch is an explicit operator request — never second-guess it.
if [ "$event" != "workflow_run" ]; then
    deploy true "release-gate: event '$event' is not workflow_run — deploying unconditionally"
    exit 0
fi

if [ -z "$base_sha" ] || [ -z "$head_sha" ]; then
    deploy true "release-gate: base or head SHA missing — deploying (fail open)"
    exit 0
fi

if ! git cat-file -e "${base_sha}^{commit}" 2>/dev/null; then
    deploy true "release-gate: base commit $base_sha not resolvable — deploying (fail open)"
    exit 0
fi

if [ "$base_sha" = "$head_sha" ]; then
    deploy true "release-gate: base equals head, no diff evidence — deploying (fail open)"
    exit 0
fi

changed="$(git diff --name-only "$base_sha" "$head_sha")"

if [ -z "$changed" ]; then
    deploy true "release-gate: empty diff — deploying (fail open)"
    exit 0
fi

# Documentation-only prefixes/files. Everything else — including the one
# frontend path that IS published (frontend/public/*.html, e.g. the scoring
# annex) — deploys.
non_deployable_pattern='^(doc/|CLAUDE\.md$|AGENTS?\.md$|README\.md$)'

deployable="$(grep -Ev "$non_deployable_pattern" <<<"$changed" || true)"

if [ -z "$deployable" ]; then
    deploy false "release-gate: every changed path is documentation-only — skipping build/deploy"$'\n'"$changed"
    exit 0
fi

deploy true "release-gate: at least one deployable path changed — deploying"$'\n'"$deployable"
