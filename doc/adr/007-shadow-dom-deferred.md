# ADR-007: Shadow DOM Deferred to MVP

**Status:** Accepted
**Date:** 2025-03-01 (M6)

## Context

The Web Component is designed to be embedded in a WordPress site via `<script>` tag. Shadow DOM encapsulation would prevent host page CSS from bleeding into the ranklist — a critical requirement for production.

## Decision

Defer Shadow DOM (`customElement: true` compiler mode) to the MVP phase. The POC uses direct Svelte mount without Shadow DOM.

## Rationale

Svelte's `customElement: true` compiler option is incompatible with `@testing-library/svelte`, which uses the Svelte 4 `new Component()` API (enabled via `compatibility.componentApi: 4`). Enabling custom element mode breaks all 28+ vitest unit tests.

## Planned Resolution (MVP)

For MVP, build the component as a proper `<spws-ranklist>` custom element with isolated styles. Unit tests for the custom element build will use a separate test harness or Playwright E2E tests instead of `@testing-library/svelte`.

## Consequences

- POC: component styles may conflict with host page CSS — acceptable for dev/demo environments
- POC: no `<spws-ranklist>` custom element tag — component is mounted via Svelte's `mount()` API
- All unit tests work with `@testing-library/svelte` during POC
- MVP must resolve this before WordPress deployment
