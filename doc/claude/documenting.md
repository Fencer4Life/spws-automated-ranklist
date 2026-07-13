# Documenting

Documentation steps are mandatory before marking any task complete. Human-facing project documents and plans use `.html`; fixed-name framework guidance such as this file is an exception.

## Documentation authority

- [Current handbook](../handbook/index.html) — present-tense domain, product, architecture, subsystem and operations truth.
- [Documentation map](../handbook/documentation-map.html) — canonical page ownership and implementation review triggers.
- [Governance](../governance/index.html) — specification, RTM and formal business rules.
- [ADR registry](../adr/index.html) — durable decision rationale.
- [Evidence catalog](../evidence/index.html) — point-in-time run, audit and design artifacts.
- [Legacy archive](../archive/legacy-2026-07/index.html) — superseded narratives; never use as current truth.

## Documentation coherence gate

Every development plan must include the exact checkbox block from the [documentation standard](../handbook/reference/documentation-standard.html). Before completion:

1. Classify domain, product, architecture, operations, configuration and reference impact.
2. Name affected canonical HTML pages, or justify `none` with inspected sources.
3. Update pages in present tense, including implementation maps and `last-verified`.
4. Update ADRs, governance records and operational material when their contracts change.
5. Archive superseded prose instead of appending implementation history to current pages.
6. Run `python scripts/check_docs.py --changed-from <base>` and resolve errors; ownership findings begin as warnings.

## Scope and traceability changes

When an FR or NFR is added, removed or modified, walk this chain before code:

1. specification scope and acceptance criteria;
2. RTM status and test references;
3. plan test IDs;
4. test code comments and assertions;
5. documented coverage gaps and test totals;
6. affected handbook pages and formal rules.

Traceability remains **FR/NFR ↔ RTM ↔ plan test ID ↔ test code**. The handbook explains the behavior; it does not duplicate the matrix.

## ADR maintenance

Create or supersede an ADR for a tradeoff, alternative, deferral, changed established pattern or future architectural constraint. Draft it in the HTML development plan, obtain approval, then add the retained `doc/adr/NNN-slug.md` source and generate its `.html` representation with `python scripts/render_adrs.py`. Update the specification ADR registry and link the decision from affected handbook pages.

## Diagrams

Use accessible HTML/CSS diagrams for human-facing HTML pages. Retained Markdown sources may use fenced Mermaid when the renderer supports and validates it.
