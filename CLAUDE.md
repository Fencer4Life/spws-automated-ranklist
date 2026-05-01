# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

SPWS Automated Ranklist System — automated ranking for the Polish Veterans Fencing Association across 30 sub-rankings (3 weapons × 2 genders × 5 age categories V0-V4). Three-tier deploy: LOCAL → CERT → PROD.

**Single source of truth:** [doc/Project Specification. SPWS Automated Ranklist System.md](doc/Project%20Specification.%20SPWS%20Automated%20Ranklist%20System.md) — FRs, RTM, ADR registry, test baseline.
**Development history:** [doc/development_history.md](doc/development_history.md) — chronological POC/MVP/Go-to-PROD archive (archived plans in [doc/archive/](doc/archive/) are superseded; do not consult for planning).

## Modules

- [doc/claude/architecture.md](doc/claude/architecture.md) — data flow, database, Python, frontend dual-build, CI/CD.
- [doc/claude/testing.md](doc/claude/testing.md) — commands, mandatory TDD workflow, after-change rule.
- [doc/claude/documenting.md](doc/claude/documenting.md) — scope-change pass, RTM check, ADR maintenance.
- [doc/claude/conventions.md](doc/claude/conventions.md) — data-integrity hard rules, working style.
- [doc/claude/key-references.md](doc/claude/key-references.md) — index of spec, ADRs, scripts, MCP/PAT.
