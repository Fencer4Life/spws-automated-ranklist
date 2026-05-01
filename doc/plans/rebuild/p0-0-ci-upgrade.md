# Phase 0.0 — CI Node 24 Upgrade (Task 0.0a)

**Status:** ✅ DONE — committed `6047a0b` (`ci: bump actions/checkout@v5, setup-python@v6, setup-node@v5`).

This subplan documents the bump for traceability. No further work is required.

## Trigger

GitHub Actions deprecation:
- Node 20 forced to Node 24 on **2026-06-02**
- Node 20 removed from runners on **2026-09-16**

The bump landed before the LOCAL DB rebuild kicks off so CI keeps working through the rebuild lifetime.

## Bumps applied

| From | To | Touch count |
|---|---|---|
| `actions/checkout@v4` | `@v5` | 14 lines |
| `actions/setup-python@v5` | `@v6` | 7 lines |
| `actions/setup-node@v4` | `@v5` | 2 lines |

**Total:** 23 line edits across 8 workflow files.

## Files modified

All under [.github/workflows/](../../../.github/workflows/):

- `ci.yml`
- `release.yml`
- `evf-sync.yml`
- `populate-urls.yml`
- `ingest.yml`
- `scrape-tournament.yml`
- `export-seed.yml`
- `promote.yml`

## Verification

- ✅ CI green on push of `6047a0b`
- ✅ Deprecation warning gone from GH Actions log
- ✅ All 8 workflow files reflect the new versions (verified via `grep "actions/(checkout|setup-python|setup-node)@" .github/workflows/*.yml`)

## Risk gate

Met: CI green after the bump.

## Cross-references

- Master plan: [now-we-have-a-precious-wren.md](/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md)
- Sibling: [p0-prep.md](p0-prep.md) — schema prep + cert_ref + rules framework + matcher config + Claude module edits (Phase 0)
