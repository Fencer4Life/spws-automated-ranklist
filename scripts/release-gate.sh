#!/usr/bin/env bash
# ADR-094: skip Release's build/deploy chain when everything that changed
# since PROD last deployed is documentation. release.yml is triggered by
# `workflow_run`, whose payload has no `before` SHA, so this script derives
# the range itself and writes a single `deploy` boolean to GITHUB_OUTPUT.
#
# The range starts at the commit PROD last deployed, which deploy-prod records
# in deployed_migrations.json (.prod.last_sha), not at the previous CI run: a
# code change whose release never ran (red CI, or cancelled while waiting
# behind a PROD approval) stays in the range until it is deployed (ADR-094
# amendment 2026-10-24). PROD deploys after CERT, so its commit is the oldest.
#
# Fails OPEN by design: anything it cannot classify with confidence deploys.
# A missed skip costs a routine, low-risk release run; a wrong skip would
# silently leave a real change stuck on CERT/PROD.
#
# It also outputs the range it measured, base and head, for the notes job, and
# writes its verdict with the changed paths onto the Release run's Summary page
# (plan doc/plans/release-notes-on-every-release-run-2026-11-01.html, R2 A;
# ADR-094 amendment 2026-11-01). Neither changes a decision.
#
# Env (all overridable for tests; production values come from the workflow):
#   RELEASE_GATE_EVENT          github.event_name   (default: workflow_run)
#   RELEASE_GATE_HEAD_SHA       head of the range   (default: workflow_run.head_sha;
#                                                   for a manual start, HEAD)
#   RELEASE_GATE_BASE_SHA       base of the range   (default: .prod.last_sha of the tracking file)
#   RELEASE_GATE_TRACKING_FILE  the tracking file   (default: deployed_migrations.json)
#   GITHUB_OUTPUT               where to write deploy=true|false, base and head
#   GITHUB_STEP_SUMMARY         the run's Summary page (unset outside Actions: nothing written)
set -euo pipefail

event="${RELEASE_GATE_EVENT:-${GITHUB_EVENT_NAME:-workflow_run}}"
head_sha="${RELEASE_GATE_HEAD_SHA:-${GITHUB_EVENT_WORKFLOW_RUN_HEAD_SHA:-}}"
tracking="${RELEASE_GATE_TRACKING_FILE:-deployed_migrations.json}"
base_sha="${RELEASE_GATE_BASE_SHA:-}"
if [ -z "$base_sha" ] && [ -f "$tracking" ]; then
    base_sha="$(jq -r '.prod.last_sha // empty' "$tracking" 2>/dev/null || true)"
fi
# A manual start has no CI run: it deploys main as checked out here.
if [ -z "$head_sha" ] && [ "$event" != "workflow_run" ]; then
    head_sha="$(git rev-parse HEAD 2>/dev/null || true)"
fi
{
    echo "base=$base_sha"
    echo "head=$head_sha"
} >>"$GITHUB_OUTPUT"

# deploy <true|false> <log line> <sentence for the Summary page> [paths]
deploy() {
    echo "deploy=$1" >>"$GITHUB_OUTPUT"
    echo "$2"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
        local heading="deploys"
        [ "$1" = true ] || heading="nothing to deploy"
        {
            printf '### Release gate: %s\n\n<p>%s</p>\n\n' "$heading" "$3"
            if [ -n "${4:-}" ]; then
                printf '<details><summary>The %s paths</summary>\n\n```\n%s\n```\n\n</details>\n\n' \
                    "$(grep -c . <<<"$4")" "$4"
            fi
        } >>"$GITHUB_STEP_SUMMARY"
    fi
}

short() { printf '<code>%s</code>' "${1:0:8}"; }

# A manual dispatch is an explicit operator request — never second-guess it.
if [ "$event" != "workflow_run" ]; then
    deploy true "release-gate: event '$event' is not workflow_run — deploying unconditionally" \
        "Started by hand, so the gate does not judge the paths: a manual start always deploys (ADR-094)."
    exit 0
fi

if [ -z "$base_sha" ] || [ -z "$head_sha" ]; then
    deploy true "release-gate: base or head SHA missing — deploying (fail open)" \
        "The commit PROD last deployed or this run's commit is not known, so the gate deploys: it fails open (ADR-094)."
    exit 0
fi

if ! git cat-file -e "${base_sha}^{commit}" 2>/dev/null; then
    deploy true "release-gate: base commit $base_sha not resolvable — deploying (fail open)" \
        "The commit PROD last deployed, $(short "$base_sha"), is not in this history, so the gate deploys: it fails open (ADR-094)."
    exit 0
fi

if ! git merge-base --is-ancestor "$base_sha" "$head_sha" 2>/dev/null; then
    deploy true "release-gate: base commit $base_sha is not an ancestor of $head_sha — deploying (fail open)" \
        "The commit PROD last deployed, $(short "$base_sha"), is not an ancestor of $(short "$head_sha"), so the gate deploys: it fails open (ADR-094)."
    exit 0
fi

if [ "$base_sha" = "$head_sha" ]; then
    deploy true "release-gate: base equals head, no diff evidence — deploying (fail open)" \
        "PROD already runs $(short "$head_sha"); with no change to judge, the gate deploys it again: it fails open (ADR-094)."
    exit 0
fi

changed="$(git diff --name-only "$base_sha" "$head_sha")"

if [ -z "$changed" ]; then
    deploy true "release-gate: empty diff — deploying (fail open)" \
        "No file differs between $(short "$base_sha") and $(short "$head_sha"), so the gate deploys: it fails open (ADR-094)."
    exit 0
fi

# Documentation-only prefixes/files, plus the two root-level tracking files
# the Release workflow's own build/deploy-cert/deploy-prod jobs commit after
# every run (deployed_migrations.json, release-manifest.json). Both are pure
# CI-generated bookkeeping with no code or schema effect, but they live at
# the repo root rather than under doc/ — so before this exemption, any one
# of them landing inside a later diff range (e.g. from an unrelated Release
# run shortly before a genuinely docs-only push) silently defeated this
# gate's whole purpose (observed 2026-09-13). The .claude/ and .agents/
# directories hold Claude's and Codex's skills and settings, which nothing
# builds or deploys (ADR-094 amendment 2026-10-31); only the directories, so a
# root file named like them still deploys. Everything else — including
# the one frontend path that IS published (frontend/public/*.html, e.g. the
# scoring annex) — still deploys.
non_deployable_pattern='^(doc/|\.claude/|\.agents/|CLAUDE\.md$|AGENTS?\.md$|README\.md$|deployed_migrations\.json$|release-manifest\.json$)'

deployable="$(grep -Ev "$non_deployable_pattern" <<<"$changed" || true)"
changed_count="$(grep -c . <<<"$changed")"

if [ -z "$deployable" ]; then
    deploy false "release-gate: every changed path is documentation-only — skipping build/deploy"$'\n'"$changed" \
        "Every one of the $changed_count paths changed since PROD last deployed $(short "$base_sha") is documentation, agent tooling or a tracking file (ADR-094). Nothing is built or deployed; CERT, PROD and Pages stay at $(short "$base_sha")." \
        "$changed"
    exit 0
fi

deploy true "release-gate: at least one deployable path changed — deploying"$'\n'"$deployable" \
    "$changed_count paths changed since PROD last deployed $(short "$base_sha"); $(grep -c . <<<"$deployable") of them are not documentation, agent tooling or tracking files, so the run builds and deploys (ADR-094)." \
    "$deployable"
