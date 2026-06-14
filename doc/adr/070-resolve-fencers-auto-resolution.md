# ADR-070: `ResolveFencers` auto-resolution (merged Stage-0 ⊕ Stage-6, runs early), no human review gate

**Status:** Proposed (design-only, 2026-06-14). Target architecture in
[ingestion_pipeline_NEW_design.md](../ingestion_pipeline_NEW_design.md) §5.1. **Not yet implemented.**
**Date:** 2026-06-14
**Relates to:** ADR-003 (identity by FK), ADR-010/056 (V-cat from birth year), ADR-020/038 (domestic
auto-create / international POL-only), ADR-064 (asymmetric gender filter), ADR-071 (dedup sweep),
ADR-073 (plugin architecture), ADR-074 (no-halt). **Amends** ADR-050 (review gate removed) and
ADR-056 (Stage-0 absorbed into this plugin).

## Context

The unified pipeline (ADR-050) split identity work across two stages — Stage-0 roster reconciliation
(ADR-056 rev 2026-06-13: high-precision create + band-midpoint BY reconcile) and a later Stage-6 fuzzy
matcher — and routed every uncertain match through a **human review gate** (draft tables +
`fn_commit_event_draft` triage). For a *fully automated* domestic pipeline this is two problems:

1. The two stages can disagree about a fencer's birth year — the matcher fuzzy-links before
   reconciliation has settled the roster, so a fuzzy tiebreak may rely on a BY that Stage-0 then changes.
2. The human gate blocks automation entirely; it was the single largest source of operator toil.

## Decision

Merge Stage-0 and Stage-6 into a **single plugin, `ResolveFencers`**, that owns *name → governed fencer*
and runs **first of the core**, before `DetectCombinedPool`/`SplitByAge`. It is the sole writer of
`tbl_fencer` during ingestion. Two internal phases (one plugin — all name→fencer logic in one place):

- **Phase A — settle the roster (exact, high precision):** post-fold equality match (ADR-003, ~0 false
  positives); on hit, reconcile a conflicting stored BY to the V-cat **band midpoint** (ADR-056).
- **Phase B — resolve the remainder (fuzzy, against the now-reconciled roster):** if
  `conf ≥ AUTO_LINK_THRESHOLD` and age-band + gender corroborate (ADR-064), link + alias-writeback
  (`fn_update_fencer_aliases`, exact next run); else **(domestic)** create a new fencer at band-midpoint
  BY (ADR-020); **(international, deferred §12)** exclude (ADR-038).

**No human review gate.** Every call is auto-decided by calibrated confidence; the result is committed
atomically (ADR-014/022) with no draft/triage step. Uncertainty **biases to the recoverable outcome**
(create-new, later deduped by ADR-071) over the unrecoverable one (a wrong link → corrupt FK, BR-9).
`ResolveFencers` declares `effects: master_data` and emits `master_data.changed`, which drives
self-healing recompute (ADR-072).

Because it precedes the structural steps, every downstream V-cat decision consumes the **governed** birth
year, not raw scrape markers — removing the "split on a wrong scraped BY → needs a human" failure mode and
making full automation defensible.

## Alternatives considered

- **Keep the review gate** (ADR-050). Rejected: incompatible with full automation.
- **Keep Stage-0 and Stage-6 separate.** Rejected: they share all name→fencer logic; separation is exactly
  what let them disagree on BY. One plugin, two phases, settles BY before any fuzzy tiebreak relies on it.
- **Bias to link-over-create.** Rejected: a wrong link is unrecoverable corruption; a duplicate is
  recoverable by the dedup sweep (ADR-071). Asymmetric safety mandates create-over-uncertain-link.

## Consequences

- One maintainable home for all identity logic; the *same* dedup/reconcile code serves both per-bracket
  ingest and the whole-roster `DEDUP_SWEEP` (ADR-071) — there is **no separate MDM subsystem**.
- Full automation: no operator triage on the domestic path.
- A calibrated `AUTO_LINK_THRESHOLD` (knob, design §11) bounds the false-link rate; duplicates are expected
  and swept.
- The draft tables + `fn_commit_event_draft` / `fn_discard_event_draft` / `fn_dry_run_event_draft` RPCs
  become dead and are removed (ADR-073).

## Tests (planned — design §10, RED first)

exact-link / fuzzy-link / create / reconcile-BY / two-phase BY settling / split-uses-governed-BY;
calibration regression bounding the false-link rate.
