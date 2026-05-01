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
