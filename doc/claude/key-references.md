# Key references

| File | Purpose |
|---|---|
| [doc/Project Specification. SPWS Automated Ranklist System.md](../Project%20Specification.%20SPWS%20Automated%20Ranklist%20System.md) | FRs, RTM, ADR registry, test baseline |
| [doc/development_history.md](../development_history.md) | Chronological archive of POC/MVP/Go-to-PROD |
| [doc/adr/](../adr/) | 49 ADRs |
| [doc/cicd-operations-manual.md](../cicd-operations-manual.md) | Deployment + release pipeline |
| [scripts/reset-dev.sh](../../scripts/reset-dev.sh) | Local DB reset (recreates admin@spws.local) |
| [scripts/check-coherence.sh](../../scripts/check-coherence.sh) | Four CI gates: version sync, ADR count, pgTAP plan sum, migration↔spec |
| [.github/copilot-instructions.md](../../.github/copilot-instructions.md) | GitHub MCP server is the path for GitHub API ops; PAT is in `.vscode/mcp.json` |
| [doc/claude/architecture.md](architecture.md) | Data flow, DB, Python, frontend, CI/CD |
| [doc/claude/testing.md](testing.md) | Commands, TDD workflow, test ID traceability |
| [doc/claude/documenting.md](documenting.md) | Scope-change pass, RTM check, ADR workflow |
| [doc/claude/conventions.md](conventions.md) | Documentation rules, data-integrity hard rules, working style |
| [doc/requirements-traceability-matrix.md](../requirements-traceability-matrix.md) | Externalized RTM (FRs + NFRs + Coverage Summary) — Phase 0.5 |
| [doc/backlog/superfive-phase-3.md](../backlog/superfive-phase-3.md) | SuperFive Phase 3 backlog (extracted from spec §9.8 + Appendix B) |
| [scripts/check-spec-sync.sh](../../scripts/check-spec-sync.sh) | Phase 0.5 spec-sync invariants (5 gates) |
| /Users/aleks/.claude/plans/now-we-have-a-precious-wren.md | Active rebuild plan (REBUILD-ACTIVE through Phase 6) |
| [doc/plans/rebuild/](../plans/rebuild/) | Per-phase rebuild subplans (p0-0, p0, p1..p7) |
| [doc/rules/](../rules/) | Rules registry (R001-R012, Pandoc-built HTML) — REBUILD-ACTIVE |
| [doc/overrides/](../overrides/) | Per-event override YAML files — REBUILD-ACTIVE |
| [scripts/load-cert-ref.sh](../../scripts/load-cert-ref.sh) | Loads PROD seed into cert_ref schema — REBUILD-ACTIVE |
| [python/matcher/config.yaml](../../python/matcher/config.yaml) | Matcher thresholds + Polish normalizations + nicknames (single tuning surface) |
