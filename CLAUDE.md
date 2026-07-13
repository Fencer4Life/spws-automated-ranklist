# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

SPWS Automated Ranklist System — automated ranking for the Polish Veterans Fencing Association across 30 sub-rankings (3 weapons × 2 genders × 5 age categories V0-V4). Three-tier deploy: LOCAL → CERT → PROD.

**Current-system source of truth:** [doc/handbook/index.html](doc/handbook/index.html) — business domain, product, architecture, subsystems, operations and source-linked reference.
**Normative requirements:** [doc/governance/index.html](doc/governance/index.html) — specification, RTM and formal rules.
**Decision rationale:** [doc/adr/index.html](doc/adr/index.html). Historical narratives are cataloged under [doc/archive/legacy-2026-07/](doc/archive/legacy-2026-07/) and must not be used to infer current behavior.

## Modules

- The files under `doc/claude/` are agent procedures and routing aids, not a second architecture reference. Current-system facts belong only in the handbook.
- [doc/claude/architecture.md](doc/claude/architecture.md) — route architecture questions into the canonical handbook and source evidence.
- [doc/claude/testing.md](doc/claude/testing.md) — commands, mandatory TDD workflow, after-change rule.
- [doc/claude/documenting.md](doc/claude/documenting.md) — scope-change pass, RTM check, ADR maintenance.
- [doc/claude/planning.md](doc/claude/planning.md) — planning gate, verify-before-claim, scenario walk-throughs, LOCAL parity rule, TDD strict order, ADR draft sign-off, doc completeness, CI/CD + Telegram operational hooks, per-event sign-off, plan file readability for future sessions.
- [doc/claude/conventions.md](doc/claude/conventions.md) — data-integrity hard rules, working style.
- [doc/claude/key-references.md](doc/claude/key-references.md) — authority-based index of current docs, governance, decisions, evidence and operational tools.
- [doc/claude/graph-analysis.md](doc/claude/graph-analysis.md) — graphify knowledge graph: consult it first for codebase analysis (`graphify query/explain/affected/path`), and run `scripts/refresh-graph.sh` before every commit.
