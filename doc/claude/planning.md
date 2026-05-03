# Planning rules (Claude session guidance for SPWS Ranklist work)

This file canonicalises the planning discipline. Any session asked to plan a
feature, architectural change, or operational extension MUST follow these
rules. They supersede defaults.

## 1. Planning gate — always before any plan

1. Read [doc/Project Specification. SPWS Automated Ranklist System.md](../Project%20Specification.%20SPWS%20Automated%20Ranklist%20System.md) §3 RTM to identify in-scope FRs.
2. Read the relevant UC acceptance criteria in spec §3.
3. Cross-check approved mockups in [doc/mockups/](../mockups/).
4. Write acceptance tests in the plan FIRST — every FR needs ≥1 plan-test-ID
   before implementation starts.

## 2. Verify before claim — never confabulate

When the plan describes how an existing system works:
- Read the actual files. Quote line numbers.
- Fetch external API docs (WebFetch) before claiming behaviour.
- Trace execution paths through real code.
- If you cannot verify, say so — do not pretend.
- Specifically banned: hallucinating file paths, function names, fields, env
  vars, workflow names, table columns. The user has caught these. Never again.

## 3. Walk-through user scenarios for any architectural change

- Pick a concrete user scenario (e.g. "Event A arrives by email in June on CERT").
- Walk through it step-by-step, surface-by-surface.
- Cover happy path AND adjacent paths (cross-event cascade, partial failure,
  concurrent operator action).
- This catches gaps the abstract design hides.

## 4. LOCAL parity is sacred

When proposing new infrastructure (Storage, workflows, edge functions):
- Identify what LOCAL operators do TODAY in the same flow.
- The new infra MUST NOT change today's LOCAL behaviour.
- Gate new behaviour to CERT/PROD via env switches and CLI defaults.
- Operator's in-progress work on LOCAL must not be disrupted.
- "It only works on CERT" is unacceptable when LOCAL is in active use.

## 5. TDD strict order — RED before GREEN, no exceptions

1. Write acceptance test assertions in the plan FIRST.
2. Write test code with plan-test-ID comments (`// 5.4`, `-- 5.10`,
   docstring `5.7`).
3. Run tests → confirm RED. If a test passes pre-implementation, REWRITE it.
4. Write implementation code (minimum to flip GREEN).
5. Run tests → confirm GREEN.
6. Refactor with tests staying green.

Quality gates:
- Every test ID lands in RTM before code lands.
- All three suites green (pgTAP + pytest + vitest) before any smoke test.
- No skipped tests introduced.
- No test passes before its implementation lands.
- Implementation diff = minimum to flip the test surface.

## 6. ADRs — propose, sign off, then disk

Trigger check: Tradeoff, alternative, deferral, or new pattern? → ADR required.

Process:
1. Conflict scan: check ADR registry in spec Appendix C; supersede conflicts.
2. Draft the ADR in the plan file: Context, Decision, Alternatives,
   Consequences, Status: Proposed.
3. Wait for explicit user sign-off as a draft.
4. THEN write [doc/adr/](../adr/)`NNN-slug.md`.
5. Update spec Appendix C registry. NEVER put the ADR registry in RTM —
   registry lives ONLY in spec Appendix C.
6. Cross-reference in [doc/development_history.md](../development_history.md).

## 7. Documentation completeness — every shipped feature

Required artefacts:
- ADR(s) in [doc/adr/](../adr/)
- ADR registry rows in spec Appendix C
- FR rows in spec §3 RTM with `Covered` status
- Test count updates in spec Appendix B + [doc/claude/testing.md](testing.md)
- [doc/development_history.md](../development_history.md) close-out section
- MEMORY entry under `~/.claude/projects/.../memory/`
- [doc/cicd-operations-manual.md](../cicd-operations-manual.md) updates for any new workflow / env var
  / runbook step

## 8. Operational hooks — CI/CD and Telegram

When the plan touches:
- A new GH workflow → add to [doc/cicd-operations-manual.md](../cicd-operations-manual.md) AND to the
  `dispatch-workflow` edge-fn allowlist if UI-triggerable.
- A new env var or secret → add to ops manual secrets matrix.
- A new Telegram-fired event → update GAS `/help` command in
  [scripts/gas_email_ingestion.js](../../scripts/gas_email_ingestion.js).
- A new operator command → add Telegram command case in GAS + document in
  `/help`.

## 9. Plan file readability for future sessions

Every plan file should be:
- Standalone — readable cold by a fresh session with no prior context.
- TOC / read-order at top.
- Scenario walk-throughs explicit.
- File paths absolute or repo-relative; quoted exactly.
- Function/migration names quoted exactly.
- Plan-test-IDs assigned, never renumbered.
- Locked decisions explicit (vs open questions).
- LOCAL vs CERT parity matrix included.
- Definition of done explicit and binary.

## 10. Per-event sign-off (operational)

During multi-event ingestion (Phase 5 historical re-ingest, season ingest):
- NEVER advance to event N+1 without explicit user "OK" on event N.
- Show the verdict, wait for sign-off, then commit.
- The user has stated this rule explicitly: "don't you dare to move to the
  second event before I say SO".

## 11. User calls the shots

- Diagnose, propose, STOP. Do not chain steps without per-step authorisation.
- The user makes all domain-rule decisions; ask them, do not assume.
- Architectural / technical decisions are delegated to the assistant — but
  every such decision must be JUSTIFIED + COMMUNICATED + ELABORATED, not
  just announced.
- Enumerate domain assumptions for validation BEFORE any architecting.

## 12. Never use shorthand layer/phase names

Always use the full title + full plan name. "Layer 6 / Phase 4" alone is
meaningless to the user — they manage many parallel workstreams.

## 13. UI debug, never console

Surface diagnostics in the UI (error banner / inline form), never push
DevTools / console.log on the user. They do not want to open browser
DevTools to read what went wrong.

## 14. Reset DB only via the script

Never run bare `supabase db reset`. Always [./scripts/reset-dev.sh](../../scripts/reset-dev.sh)
(it recreates the admin user too).

## 15. Validate URL→data match on every write

When writing URL-bearing rows: scrape the URL, compare date/name/weapon/
category to the row, REJECT on mismatch. Plus pgTAP/pytest coverage.

## 16. Forbidden file reads

XLSX/XLSM/XLS files are off-limits unless the user names the specific file
and authorises that specific read.
