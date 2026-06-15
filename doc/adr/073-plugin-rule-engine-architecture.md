# ADR-073: Plugin + rule-engine ingestion architecture

**Status:** Accepted (implemented 2026-06-15, NEW pipeline build M1–M5). Design in
[ingestion_pipeline_NEW_design.md](../ingestion_pipeline_NEW_design.md) §3–§7. **Implemented** — see [development_history](../development_history.md).
**Date:** 2026-06-14
**Relates to:** **amends** ADR-050 (the stage-monolith becomes plugins; draft tables removed); ADR-006
(JSONB rules — precedent for an optional `tbl_flow_rule`); ADR-055 (provenance middleware); hosts the
plugins/flows of ADR-070 / ADR-071 / ADR-072 / ADR-074.

## Context

ADR-050's unified pipeline is a fixed linear sequence of stages with branching `if`s inside stages
(organizer / domestic / international forks, halt logic). Adding a scenario means editing orchestration
code, and business branches are hidden inside stage functions. A fully automated, self-healing pipeline
has *several* scenarios — ingest, recompute, dedup, post-commit — that share most steps; the linear
monolith cannot express that without duplication.

## Decision

Restructure into **three one-directional layers**:

1. **RuleBook + RuleEngine (plan time).** A `Rule` is a named `Flow` = an ordered tuple of `Step`s; the
   `RuleBook` is `dict[Flow → Rule]`. `RuleEngine.plan(FlowParams)` looks up the flow, prunes steps by a
   plan-time `when` predicate, and produces an immutable, **DAG-validated** `ExecutionPlan`
   (`reads ⊆ earlier writes`, so mis-ordering fails before any row is touched). Sequencing is
   **declarative and inspectable before execution** (`plan.describe()`).
2. **Orchestrator (run time).** Generic, domain-ignorant: for each plugin, `applies(ctx)?` →
   middleware-wrapped `run`. **One direction only** — a plugin never calls another plugin or the
   orchestrator.
3. **Plugins (logic).** Each implements the `IngestPlugin` contract (`reads` / `writes` / `effects` +
   `applies` + `run`), one concern each, all I/O via injected `Services`. Five **kinds**:
   **Source · Gate · Transform · Mutator · Reactor**. Mutators emit **signals**; **Reactors** observe a
   signal → emit a **Flow** — the only mechanism that closes loops, with **no back-edges** in the forward
   pipeline.

Cross-cutting concerns (timing, structured log, provenance ADR-055, escalation ADR-074) are **middleware**
wrapping every `run`, keeping plugins pure. The `RuleBook` ships **code-defined**; an optional
`tbl_flow_rule` (ADR-006 JSONB precedent) is a future knob for deploy-free flow changes.

## Alternatives considered

- **Keep the linear stage pipeline (ADR-050).** Rejected: cannot express multiple flows sharing steps
  without copy-paste; hides business branches inside code.
- **A workflow engine / DAG library (Airflow, Prefect, Dagster).** Rejected: heavyweight for an in-process
  pipeline; we need a tiny, testable, inspectable planner — not a scheduler or a service.
- **Plugins calling plugins (free-form DAG).** Rejected: re-introduces hidden coupling. The
  Mutator→signal→Reactor seam gives event-driven composition without back-edges.

## Consequences

- **Adding a scenario = adding a `Rule`** (and maybe a plugin), with no change to the orchestrator or
  existing plugins — this is exactly what lets the domestic pipeline ship as 4 flows and defer the
  international flows (design §12) at zero cost.
- Sequence is unit-testable on its own ("flow X with params Y ⇒ plugins Z").
- Write-discipline (`writes` only) + effects-honesty make recompute / re-ingest safely re-runnable.
- The draft tables + `DRY_RUN` RPCs from ADR-050 are removed (no review gate to stage for — ADR-070).
- New layout: `python/pipeline/core/` (contract, orchestrator), `engine/` (rulebook, rule_engine, flows),
  `plugins/`, `middleware/`, `run.py`.

## Tests (implemented — design §10, RED first)

planner resolves flow → sequence (incl. `ResolveFencers` before `SplitByAge`); DAG-validation rejects
mis-order; orchestrator skip / fault / trace; **parity gate** — wrapped legacy stages produce
byte-identical output on the same inputs.
