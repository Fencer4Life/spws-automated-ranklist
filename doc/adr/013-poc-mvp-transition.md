# ADR-013: POC-to-MVP Transition

**Status:** Accepted
**Date:** 2026-03-25 (M6→M8)

## Context

The POC (M0-M6) validated all four pillars of the system:

1. **Core Math** — Scoring engine matches reference Excel within 0.01 tolerance (M2, 24 pgTAP + 7 pytest).
2. **Scraping Viability** — Three platforms operational: FTL, Engarde, 4Fence (M3, 31 pytest).
3. **Admin Workflow** — Season setup, scoring config, identity resolution tested end-to-end (M1-M4).
4. **UI Portability** — Web Component with PPW/Kadra toggle, drilldown, ODS export, i18n (M6, 28 vitest).

M7 (Ingestion Pipeline) was the final POC milestone. Its individual components (scrapers, matcher, scoring engine) are all implemented and tested, but the orchestration pipeline (`ingest.yml`), admin CRUD UI, and identity resolution admin UI were not yet wired together.

The project needed to decide: complete M7 within POC scope (single category), or transition to MVP (all 30 categories) and build the pipeline alongside the broader admin UI.

## Decision

Declare POC complete (M0-M6). Transition to MVP with two milestones:

- **M8:** Multi-Category Data + Calendar UI + Schema Extensions
- **M9:** Ingestion Pipeline + Admin CRUD + Identity Resolution Admin

M7's orchestration pipeline is absorbed into M9. The M7 test plan (7.1-7.9) carries forward to M9 with expanded scope for multi-category support.

Milestone numbering continues from POC (M8, M9) rather than restarting at M1 to preserve traceability — all existing test IDs, FR references, and ADR cross-references remain valid.

## Alternatives Considered

1. **Complete M7 in POC before MVP** — Rejected. The ingestion pipeline needs the admin CRUD UI (season/event/tournament management) to be useful in production. Building the pipeline for a single category, then rebuilding for 30 categories, would be wasted effort.

2. **Start fresh MVP plan (M1-M2)** — Rejected. Restarting numbering would break traceability. Existing test IDs (1.1-6.20), FR references (FR-01 to FR-42), and ADR cross-references all use the current numbering scheme.

## Consequences

- POC Development Plan (`POC_development_plan.md`) is frozen — M6 marked COMPLETED, M7 marked DEFERRED
- New `MVP_development_plan.md` created for M8-M9
- Project Specification §6.1 (POC) marked COMPLETED, §6.2 (MVP) rewritten with agreed scope
- RTM extended with FR-43 to FR-52 (all Planned status)
- 236 existing test assertions (117 pgTAP + 91 pytest + 28 vitest) provide the foundation for MVP development
- POC Known Test Gaps (FR-10, FR-14, FR-23, FR-40, NFR-10, NFR-13) carry forward to MVP
