# Key references for Claude

Use references by authority. Do not substitute a historical document for the current owner.

| Question | Authoritative reference |
|---|---|
| How does the system work now? | [Developer handbook](../handbook/index.html) |
| Which page owns a changing implementation area? | [Documentation ownership map](../handbook/documentation-map.html) |
| What must be true? | [Governance](../governance/index.html), including specification, RTM and [formal rules](../rules/index.html) |
| Why was a durable choice made? | [ADR registry](../adr/index.html) |
| How is the repository organized? | [Codebase map](../handbook/reference/codebase-map.html) |
| Which workflows exist? | [Workflow catalog](../handbook/reference/workflow-catalog.html) |
| How do I run LOCAL safely? | [Local development](../handbook/operations/local-development.html) and [scripts/reset-dev.sh](../../scripts/reset-dev.sh) |
| How do releases and environments work? | [Environments and release](../handbook/operations/environments-and-release.html) |
| How do operators diagnose/recover? | [Operator runbooks](../handbook/operations/operator-runbooks.html) |
| Which validation and traceability rules apply? | [Test and traceability](../handbook/reference/test-and-traceability.html), [testing.md](testing.md), [scripts/check-coherence.sh](../../scripts/check-coherence.sh) and [scripts/check-spec-sync.sh](../../scripts/check-spec-sync.sh) |
| How must documentation be maintained? | [Documentation standard](../handbook/reference/documentation-standard.html) and [documenting.md](documenting.md) |
| Where is run/design evidence? | [Evidence catalog](../evidence/index.html) |
| Where is superseded history? | [Legacy archive](../archive/legacy-2026-07/index.html)—historical use only |

Credentials are never documentation. Do not read, quote or embed tokens from MCP configuration, environment files, git remotes or local settings. Use configured authentication surfaces without exposing their values.
