# ADR-064: Asymmetric gender filter at matcher time (domestic events only)

**Status:** Accepted (implemented 2026-05-10)
**Date:** 2026-05-10
**Source:** ADR-034 (parent rule), feedback_spws_includes_everyone.md, Phase 5 PPW3-2025-2026 halt incident.

## Context

ADR-034 codifies cross-gender scoring rules but defers enforcement to ranking-query time via `fn_effective_gender`. Specifically: **"Man in women's tournament — Points never count for any ranklist. Dropped entirely, no exceptions."**

The ingest-time matcher (`find_best_match`) was gender-blind: it scored name-distance only, with no `enum_gender` awareness. International women guests whose surnames share stems with Polish male fencers (e.g. BLR/LTU/CRC women in PPW3-2025-2026 Women's Épée vs. Polish male V-category epeeists) got wrong-matched onto male `tbl_fencer` rows. That produces a structural artifact at `s7_pool_round_check` (3M/8F mix → "looks like pool round") which halts the bracket, blocks the draft write, and removes the bracket from FencerAliasManager UI reach (no draft rows → no pending pairs derivable from `tbl_result_draft`).

The federation rule, confirmed 2026-05-10:

- **Men cannot legitimately appear in women's tournaments anywhere — no exceptions.**
- **Women may rarely appear in men's tournaments** when no women's bracket exists at the event for that weapon/category.

This is asymmetric. ADR-034 already encodes the asymmetry at scoring time. ADR-064 pulls the same asymmetric rule forward into the matcher for domestic events.

## Decision

At s6 identity resolution time, apply a **one-sided** gender filter to the matcher's candidate list, scoped to **SPWS-organized domestic events only** (`tournament_type ∈ {PPW, MPW}` — GP events are encoded as PPW):

- **When `parsed.gender == 'F'`:** the matcher drops any `tbl_fencer` row with `enum_gender = 'M'` from the candidate set before name-distance scoring. F and NULL-gender rows remain eligible. If no eligible candidate remains, the FTL row falls through to NEW_FENCER → auto-created with `enum_gender = 'F'` (inherited from bracket).
- **When `parsed.gender == 'M'`:** no filter. Current behavior preserved end-to-end. ADR-034's `fn_effective_gender` redirects legitimate F-in-M results at ranking time as designed.
- **When `parsed.gender` is `None`:** no filter. Compound brackets handled by ADR-056 V-cat split do not yet have a gender at s6; safe default is current behavior.
- **For non-domestic events (PEW/MEW/MSW/EVF):** no filter. International intake follows `feedback_international_no_pending.md` (AUTO_MATCHED-only); this ADR's federation rule applies to SPWS domestic events only.

### Implementation surface

- `python/matcher/fuzzy_match.py` — `find_best_match` gains `bracket_gender: str | None = None`. When `'F'`, filters `fencer_db` to drop rows with `enum_gender == 'M'` before scoring.
- `python/matcher/pipeline.py` — `resolve_tournament_results` gains `bracket_gender: str | None = None`. Forwards to `find_best_match` only when `is_domestic`. `auto_create_fencer` gains `gender_default: str | None = None`; the NEW_FENCER auto-create path passes the bracket's gender.
- `python/pipeline/stages.py` — `s6_resolve_identity` reads `ctx.parsed.gender` and threads it to all `find_best_match` call sites, gated on `_is_domestic(ctx.event)`.
- `python/pipeline/orchestrator.py` — legacy `_process_category` path mirrors the change.
- `python/pipeline/db_connector.py` — `fetch_fencer_db` selects `enum_gender` so the filter has data to work with.

## Alternatives considered

1. **Per-fencer name-inferred gender filter** — rejected: requires a Polish surname dictionary, first-name dictionary, and a fallback heuristic for international names. The very rows that surface this bug are the murkiest names; the heuristic is least reliable exactly where it's most needed. Bracket-level asymmetric filter sidesteps the inference problem entirely.
2. **Pre-create international guest rows from orchestrator side** — rejected as a structural fix: duplicates responsibility (the matcher already owns a NEW_FENCER fallback) and only moves the gender-inference problem one layer up.
3. **Skip via override YAML** — rejected: defers the problem; SPWS quality is non-negotiable per `project_evf_predominance.md` since errors propagate forever.
4. **Symmetric filter (bracket=F drops M *and* bracket=M drops F)** — rejected: would block legitimate ADR-034 women-in-men's-bracket scoring (the PPW5 case).
5. **Extend ADR-034 to ingest time symmetrically** — rejected: ADR-034 already filters at scoring time. The problem is that `s7_pool_round_check` halts the bracket *before* scoring is reachable. The fix has to land at s6, not at scoring.

## Consequences

- **PPW3-2025-2026 Women's Épée unblocks:** wrong-matched international women fall through to NEW_FENCER with bracket-inherited `enum_gender='F'`; s7 sees clean 11F; draft writes; remaining alias work flows through the UI normally.
- **Future SPWS domestic events with international women guests** no longer halt at s7 due to matcher mis-routing. The class of bug is eliminated, not just one instance.
- **ADR-034 untouched:** women-in-men's-bracket case (PPW5 example) still resolves correctly because no filter applies when bracket=M. The F fencer matches her F row, `fn_effective_gender` redirects her points at ranking time.
- **NEW_FENCER fallback semantics:** when the matcher rejects all M candidates, the FTL row gets a fresh F fencer row. This is consistent with `feedback_spws_includes_everyone.md` (every domestic participant enters the ranklist; international guests get full rows).
- **Risk — an unintended new row:** a real Polish woman who shares a surname with a Polish man *and* has no F row in `tbl_fencer` yet will get a fresh F row instead of being false-matched to the M row. This is the desired outcome (no false cross-gender match), and the operator can merge via the FencerAliasManager UI if a duplicate later surfaces.
- **Performance:** filter is a list comprehension on already-loaded `fencer_db`, no extra queries.

## Related ADRs

- **ADR-034** (Cross-Gender Tournament Scoring) — parent rule; this ADR enforces the M-in-F prohibition at ingest time, complementing ADR-034's F-in-M scoring redirect at ranking time.
- **ADR-038** (EVF intake Polish-only) — clarifies the domestic/international intake split. This ADR deliberately excludes EVF/PEW/MEW/MSW because international intake has its own rule.
- **ADR-003** (Identity by FK) — fencer identity is still tracked by FK; this ADR adds a gender-eligibility constraint to the candidate set, not a name-resolution change.
- **ADR-056** (post-match V-cat assignment) — same s6/s7 stage neighborhood; this ADR refines s6 candidate selection without changing V-cat split logic.
- **ADR-063** (FTL per-fencer V-cat marker check) — orthogonal Phase 5 fix in the same s7 neighborhood (V-cat marker check vs. gender filter); both reduce false halts.

## Tests

`python/tests/test_matcher_gender_filter.py` — plan test IDs **4.61–4.72**:

| ID | Scenario | Expected |
|---|---|---|
| 4.61 | F bracket + only-M candidate | UNMATCHED (filter rejects M) |
| 4.62 | F bracket + F candidate | matches F |
| 4.63 | F bracket + mixed F+M | matches F (M filtered) |
| 4.64 | F bracket + NULL-gender | matches NULL (eligible) |
| 4.65 | M bracket + F-only (PPW5-style) | matches F (no filter) |
| 4.66 | M bracket + mixed | matches best by name (no filter) |
| 4.67 | PEW + F bracket | filter bypassed (international) |
| 4.68 | MEW + F bracket | filter bypassed (international) |
| 4.69 | MSW + F bracket | filter bypassed (international) |
| 4.70 | bracket_gender=None | no filter (back-compat) |
| 4.71 | PPW + F + UNMATCHED | NEW_FENCER w/ enum_gender='F' |
| 4.72 | auto_create_fencer(gender_default='F') | dict has enum_gender='F' |
