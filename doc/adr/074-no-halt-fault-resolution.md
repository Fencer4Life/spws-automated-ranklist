# ADR-074: No hard halt — declarative fault resolution + last-resort escalation

**Status:** Proposed (design-only, 2026-06-14). Target architecture in
[ingestion_pipeline_NEW_design.md](../ingestion_pipeline_NEW_design.md) §2 / §5.2. **Not yet implemented.**
**Date:** 2026-06-14
**Relates to:** **reverses** the halt-by-exception model of ADR-050 / ADR-057 / ADR-067; **amends**
ADR-038 (V0), ADR-066 (min-participants), ADR-069 (participant-count "HALT gate"); ADR-073 (orchestrator),
ADR-059 (Telegram), ADR-072 (self-healing).

## Context

The pipeline was built on **halt-by-exception**: a gate that hit a problem raised `Halt` and the run
stopped, awaiting a human. ADR-066 (below-min), ADR-069 (count mismatch — literally titled "HALT gate"),
ADR-057 / ADR-067 (pool-round / invalid IR) and the V0-on-international rule (ADR-038) all hard-stop. For a
*fully automated* pipeline this is fatal: any single bad bracket halts the whole event and demands an
operator. Full automation requires the run to **always reach a committed, consistent state**.

## Decision

**No domain problem ever hard-halts.** A gate/transform that hits one calls `ctx.fault(kind, detail)`; the
orchestrator does **not** stop. Resolution is governed by an explicit, declarative **`REMEDIATIONBOOK`**
(`dict[FaultKind → Remediation]`, a sibling of the RuleBook — error policy is business logic, kept out of
hidden `if`s inside plugins). Each `Remediation` carries an **inline deterministic fix** applied in-pass
(`drop_bracket`, `skip_bracket`, `accept_parsed`, `keep_combined`, `skip_artifact`) so the flow runs on to
`Commit`, plus an **escalation policy** (`NEVER` / `ON_LOSS` / `ALWAYS`).

A dedicated **`Escalate`** plugin (the "error plugin"; Mutator, `effects: external`) runs **last**, inside
`POST_COMMIT`'s `Notify`, *after* the event is already committed in its best automatically-resolved state.
It sends a Telegram message **only** for `ALWAYS` faults, or `ON_LOSS` when the inline fix dropped data. It
is **informational and asks for a human decision — it never blocks**. Only a genuine infra `Abort` (e.g.
DB down) stops a run, and it is retried, never gated.

Three "hard" rules are **reframed, not weakened**:

- **V0-on-international (ADR-038, R005b):** hard *exclusion* of the V0 row — the invariant (no V0 in an
  international ranking) is preserved — not a hard *halt*; the rest commits, `Escalate=ALWAYS`.
  (International is deferred — design §12 — so this is documented, not yet active.)
- **Below-min bracket (ADR-066):** auto-**drop** the bracket (it isn't a rankable tournament), commit the
  rest, `Escalate=ON_LOSS`.
- **Participant-count mismatch (ADR-069):** the post-commit validator becomes a **fault**
  (`accept_parsed` + `Escalate=ALWAYS`), not a halt — it flags loudly but never blocks.

Problems that need a *different flow* (a master-data correction → re-derive an event) are **not** faults —
they travel the Mutator→signal→Reactor self-healing seam (ADR-072). Faults fix the *current* run inline;
self-healing fixes *other* events asynchronously. Together: full automation, no gate.

## Alternatives considered

- **Keep halt-by-exception with auto-retry.** Rejected: retrying a deterministic data problem (below-min)
  loops forever — the problem needs a *decision* (drop), and that decision can be encoded.
- **Hidden auto-resolution inside each gate.** Rejected: spreads error policy across plugins. The
  `REMEDIATIONBOOK` keeps it in one inspectable place (mirrors the RuleBook).
- **Telegram as a gate (block until the operator replies).** Rejected: that *is* a human gate. Escalation
  is post-commit and informational; the system keeps running on its best automatic resolution.

## Consequences

- The domestic pipeline always runs to a committed, notified state; no operator is ever in the critical
  path.
- ADR-069's `PARTICIPANT_COUNT_MISMATCH` halt and the splitter / pool-round / invalid-IR halts become
  faults; `HaltReason` is retired in favour of `FaultKind` + a narrow `Abort`.
- Telegram volume is bounded by escalation policy, not one message per problem.
- Data loss (a dropped bracket) is always surfaced (`ON_LOSS`), so a *silent* drop is impossible.

## Tests (planned — design §10, RED first)

below-min → drop + continue → commit; count-mismatch → accept + escalate; flow reaches `Commit` despite a
fault; `Escalate` fires only per policy; infra `Abort` is retried, not gated.
