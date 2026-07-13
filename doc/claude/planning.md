# Planning rules (Claude session guidance for SPWS Ranklist work)

This file canonicalises the planning discipline. Any session asked to plan a
feature, architectural change, or operational extension MUST follow these
rules. They supersede defaults.

Every human-facing plan is a standalone `.html` file using the repository's approved Editorial template and includes the exact documentation coherence gate from [the documentation standard](../handbook/reference/documentation-standard.html).

## 1. Planning gate — always before any plan

1. Open [governance](../governance/index.html), then read the relevant rows in the requirements traceability matrix to identify in-scope FRs/NFRs.
2. Read the relevant use-case acceptance criteria in the specification.
3. Cross-check approved mockups in [doc/mockups/](../mockups/).
4. Use the [documentation map](../handbook/documentation-map.html) to name current pages affected by the proposed change.
5. Write acceptance tests in the plan FIRST — every FR needs ≥1 plan-test-ID
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
6. Link the decision from affected current handbook pages; preserve implementation evidence in the plan rather than appending to development history.

## 7. Documentation completeness — every shipped feature

Required artefacts:
- ADR(s) in [doc/adr/](../adr/)
- ADR registry rows in spec Appendix C
- FR rows in spec §3 RTM with `Covered` status
- Test count updates in spec Appendix D + [doc/claude/testing.md](testing.md) — **see rule 7a below; this is a CI-enforced hard gate**
- Documentation coherence gate completed using [the canonical standard](../handbook/reference/documentation-standard.html)
- Affected pages in [doc/handbook/](../handbook/) updated in present tense, with ownership-map review
- ADR links and governance records updated when applicable
- [workflow catalog](../handbook/reference/workflow-catalog.html), [environment/release guide](../handbook/operations/environments-and-release.html) and [operator runbooks](../handbook/operations/operator-runbooks.html) updated for workflow, environment or operator changes
- Superseded narratives archived; no implementation diary appended to current pages

## 7a. CI coherence gates — NEVER forget to update these (hard CI fail otherwise)

The CI runs [scripts/check-coherence.sh](../../scripts/check-coherence.sh) which has FOUR
gates — three are hard fails, one a warning:

| Gate | Check | Hard fail? | What to update when adding code |
|------|-------|-----------|---------------------------------|
| 1 | `pyproject.toml` version == `frontend/package.json` version | YES | Bump both together when releasing. |
| 2 | ADR file count in `doc/adr/` == ADR rows matching `\| [ADR-0` in spec Appendix C | YES | **Every new `doc/adr/NNN-*.md` file MUST have a matching row in spec Appendix C. Every superseded ADR keeps its row.** |
| 3 | Sum of `SELECT plan(N)` across `supabase/tests/*.sql` == `pgTAP total: N assertions` line in spec Appendix D | YES | **Every new pgTAP `plan(N)` MUST be added into the documented total. Update the `pgTAP total: N assertions` line in spec Appendix D and the per-suite Count column in the table below it.** |
| 4 | New migration in `supabase/migrations/` accompanied by spec/ADR change | warning | Land docs alongside migrations. |

**Workflow before pushing**:

1. After adding/changing pgTAP tests: re-run `bash scripts/check-coherence.sh`.
   If Gate 3 fails, update the `pgTAP total: N assertions` line in spec
   Appendix D until it matches.
2. After adding/superseding an ADR: confirm the file in `doc/adr/` and the
   row in spec Appendix C are both present. Re-run coherence.
3. After bumping a version: bump both `pyproject.toml` and
   `frontend/package.json`. Re-run coherence.
4. **The user has been burned by Gate 3 failures more than once. Run
   coherence locally before every push that touches tests, ADRs, or version.**

`scripts/check-coherence.sh` exits 0 on PASS, 1 on any hard-fail. CI invokes
it as a required check on `main`, so a failed gate blocks the merge / push.

This is rule SEVEN-A on purpose — it's the most-forgotten gate in the
documentation suite, and the user explicitly asked it be canonicalised
"so you don't forget EVER".

## 8. Operational hooks — CI/CD and Telegram

When the plan touches:
- A new GH workflow → add to the [workflow catalog](../handbook/reference/workflow-catalog.html) and [operator runbooks](../handbook/operations/operator-runbooks.html) AND to the
  `dispatch-workflow` edge-fn allowlist if UI-triggerable.
- A new env var or secret → add to the environment/release reference without recording the secret value.
- A new Telegram-fired event → update GAS `/help` command in
  [scripts/gas_email_ingestion.js](../../scripts/gas_email_ingestion.js).
- A new operator command → add Telegram command case in GAS + document in
  `/help`.

## 9. Plan file readability for future sessions

Every plan file should be:
- HTML — standalone, responsive and based on the approved Editorial template.
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
