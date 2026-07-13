# Architecture routing for Claude

This file is an agent routing aid. It must not duplicate or independently summarize the running architecture.

## Canonical current-system pages

1. [System context](../handbook/architecture/system-context.html) — actors, external systems and trust boundaries.
2. [Containers and data](../handbook/architecture/containers-and-data.html) — Svelte, Python, Supabase, automation and data ownership.
3. [End-to-end flows](../handbook/architecture/end-to-end-flows.html) — browse, registration, ingestion, recompute, EVF and promotion sequences.
4. [Subsystem pages](../handbook/index.html#topics) — boundaries, invariants, implementation maps, operations and tests.
5. [Workflow catalog](../handbook/reference/workflow-catalog.html) — current GitHub Actions inventory.

For rationale, use the [ADR registry](../adr/index.html). For normative requirements, use [governance](../governance/index.html). Never infer current architecture from development history, completed plans, legacy ingestion designs or point-in-time evidence.

## Analysis procedure

1. Query Graphify and use the relevant language tooling as required by `pre-analysis-check`.
2. Identify the owning handbook page through the [documentation map](../handbook/documentation-map.html).
3. Verify claims against current source, migrations, workflows and tests.
4. Treat a disagreement between implementation and handbook as drift requiring an explicit decision—not permission to silently prefer either side.
5. If implementation changes, update the owning handbook page in present tense and complete the [documentation coherence gate](../handbook/reference/documentation-standard.html#plan-gate).
