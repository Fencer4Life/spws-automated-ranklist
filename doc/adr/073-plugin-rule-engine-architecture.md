# ADR-073: Plugin + rule-engine ingestion architecture

**Status:** Accepted (implemented 2026-06-15, NEW pipeline build M1–M5). Design in
[archive/legacy-2026-07/ingestion_pipeline_NEW_design.md](../archive/legacy-2026-07/ingestion_pipeline_NEW_design.md) §3–§7. **Implemented** — see [development_history](../archive/legacy-2026-07/development_history.md).
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

## Amendment (N14, 2026-06-18) — the Commit plugin persists `tbl_tournament.url_results`

**Context.** The fencer Drilldown links each result to its official results page from
`tbl_tournament.url_results` (via `vw_score`). Populating it relied on the admin pressing the event-level
"populate from event URL" button, which dispatches `populate_tournament_urls.py` through a GitHub Actions
`workflow_dispatch` — flaky (returns a 502 when the dispatch is rejected) and a separate manual step. But the
from-URL ingest **already** holds each committed tournament's results-page URL (`parsed.source_url`, set per
round by the ADR-076 keep-rule), so the link can be written inline at commit with no extra fetch.

**Decision.** The **`Commit` plugin** (the sole writer of `tbl_tournament`) passes the parsed source URL into
`fn_find_or_create_tournament` via a new trailing arg `p_url_results TEXT DEFAULT NULL`
(migration `20260619000001`, which drops the prior 7-arg overload before recreating so 6-arg calls stay
unambiguous). Population is **gated on viewable WEB source kinds** —
`_WEB_SOURCE_KINDS = {FTL, ENGARDE, FOURFENCE, DARTAGNAN, OPHARDT_HTML}` + an `http(s)` `source_url`:
- a non-NULL URL **sets/overwrites** `url_results` (re-ingest refreshes to the page actually ingested);
- `FENCINGTIME_XML` / `EVF_API` / `FILE_IMPORT` and non-http source_urls pass **NULL → preserve** the existing
  value (the EVF API URL is a JSON endpoint, not a page; `url_event` and admin-entered URLs are never wiped).

Reuses the ADR-076 `source_decisions` category→source-URL map (also surfaced in the staging report's Committed
section + a `Tournament URLs populated: N/M` summary) and brings the **ADR-068** `populate_tournament_urls`
behaviour inline. The standalone button/tool remains as a manual fallback. Validation is inherent: the URL
written is the exact page the results were just parsed from. Tests (RED first): pgTAP
`46_tournament_url_on_ingest.sql` (46.1–46.5: insert/overwrite/preserve + `vw_score` exposure); pytest
`test_url_results_on_ingest.py` (N14.4 connector forward, N14.5 gate matrix, N14.6 from-URL provenance,
N14.8 staging mention).

**NOT DONE (deferred):** the standalone "populate from event URL" (⬇) button — `populate_tournament_urls.py` —
does **not** support **Ophardt** (`fencingworldwide.com`): its event-index page has no parser/fixture and there
are 0 Ophardt domestic events, so a tested discovery branch could not be written. The button raises a clear
`NotImplementedError` for Ophardt URLs, and the staging report adds an *Ophardt — populate button NOT DONE*
warning. This is button-only: Ophardt `url_results` **is** populated during full ingestion (the `OPHARDT_HTML`
gate). Other platforms (FTL/Engarde/4fence/Dartagnan) work in the button as before.

Cross-references: **ADR-076** (keep-rule + source decisions), **ADR-068** (FTL session / populate tool).
