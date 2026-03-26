# ADR-007: Shadow DOM (Implemented M8)

**Status:** Implemented (M8, 2026-03-26)
**Date:** 2025-03-01 (M6) · **Resolved:** 2026-03-26 (M8)

## Context

The Web Component is designed to be embedded in a WordPress site via `<script>` tag. Shadow DOM encapsulation would prevent host page CSS from bleeding into the ranklist — a critical requirement for production.

## Decision

Defer Shadow DOM (`customElement: true` compiler mode) to the MVP phase. The POC uses direct Svelte mount without Shadow DOM.

## Rationale

Svelte's `customElement: true` compiler option is incompatible with `@testing-library/svelte`, which uses the Svelte 4 `new Component()` API (enabled via `compatibility.componentApi: 4`). Enabling custom element mode breaks all 28+ vitest unit tests.

## Planned Resolution (MVP)

For MVP, build the component as a proper `<spws-ranklist>` custom element with isolated styles. Unit tests for the custom element build will use a separate test harness or Playwright E2E tests instead of `@testing-library/svelte`.

## Resolution (M8)

Implemented in T8.7 via dual-build strategy:
- **Dev/Test** (`vite.config.ts`): `compatibility.componentApi: 4` — `@testing-library/svelte` works for 97 vitest tests
- **Production CE** (`vite.config.ce.ts`): `customElement: true` — outputs bundle registering `<spws-ranklist>` and `<spws-calendar>` with Shadow DOM
- **Playwright E2E** (`e2e/shadow-dom.spec.ts`): 7 assertions verify Shadow DOM isolation, CE registration, and host CSS leak prevention

## Consequences

- POC: component styles may conflict with host page CSS — acceptable for dev/demo environments
- POC: no `<spws-ranklist>` custom element tag — component is mounted via Svelte's `mount()` API
- All unit tests work with `@testing-library/svelte` during POC
- ~~MVP must resolve this before WordPress deployment~~ **Resolved in M8**
- Both `<spws-ranklist>` and `<spws-calendar>` now ship as custom elements with Shadow DOM isolation (NFR-13 covered, test IDs 8.55–8.61)
