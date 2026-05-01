# Documenting

Documentation steps are mandatory before marking any task complete.

## Single source of truth

- [doc/Project Specification. SPWS Automated Ranklist System.md](../Project%20Specification.%20SPWS%20Automated%20Ranklist%20System.md) — FRs, RTM, ADR registry, test baseline.
- [doc/development_history.md](../development_history.md) — chronological POC/MVP/Go-to-PROD archive. Active plan files in [doc/](../) are archived; do not consult for planning.

## Scope-change pass

When **any** FR is added, removed, or modified, walk the full chain — in order — before writing code:

1. **Scope sections** — update relevant scope/deliverables documentation
2. **RTM** — mark affected FR/NFR rows as added/dropped/modified
3. **Plan test IDs** — identify affected plan test numbers; update milestone test tables
4. **Test code** — locate via plan test ID comments (`// 6.5`, `-- 2.19`, docstring `4.25`); remove or update assertions
5. **Known test gaps** — update if coverage changes

Traceability chain: **FR/NFR (spec) ↔ RTM ↔ plan test ID (milestone table) ↔ test code (comment).**

## RTM post-implementation check

Before marking any task complete, verify:

1. Every new test assertion is referenced by an FR/NFR in the RTM Tests column
2. If test IDs changed, RTM Tests column updated accordingly
3. Every new test is listed in the correct milestone test table
4. Implementation-notes pgTAP total matches `plan(N)` sum across all test files
5. FR/NFR Status column reflects actual coverage (Covered / Partial / Gap)

## ADR maintenance

An ADR is required when a change involves any of:

- choosing between alternatives
- deferring functionality
- changing an established pattern
- constraining future architecture

Workflow:

1. **Trigger check** — does this change match one of the four triggers? → ADR required
2. **Conflict scan** — scan the registry in auto-memory `MEMORY.md`; if the new ADR contradicts/supersedes an existing one, update the old ADR (Status: Superseded by …) **first**
3. **Create ADR file** — `doc/adr/NNN-slug.md` with Context · Decision · Alternatives · Consequences · Status
4. **Update Appendix C** in the spec
5. **Cross-reference** in the development plan implementation notes

## Diagrams

Always use ` ```mermaid ` fenced code blocks. No inline Mermaid, no other diagram formats.
