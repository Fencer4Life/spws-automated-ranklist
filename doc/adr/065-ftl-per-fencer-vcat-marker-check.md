# ADR-065: FTL per-fencer V-cat marker check at the splitter

**Status:** Accepted (drafted 2026-05-08; renumbered 063 → 065 on 2026-05-10 to resolve conflict with the already-committed ADR-063 polish-plural-and-grupy-zbiorcze)
**Related:** ADR-049 (joint-pool split flag), ADR-056 (V-cat resolution by post-match fencer birth year — bracket-label-wins revision), ADR-057 (eventSchedule splitter)
**Phase:** 5 (operational rebuild)

## Context

ADR-056's 2026-05-03 revision established **"single-V-cat bracket label wins"** as the rule for past tournaments: when an FTL bracket name parses to a single V-cat (e.g. `Vet-50 Men's Épée` → V2), every fencer in that bracket is assigned to that V-cat regardless of their birth-year-derived V-cat. This preserves the organizer's placement decision for the season's ranklist.

The rule depends on a hidden assumption: **the bracket name accurately reflects the bracket's contents**. If the organizer dumps multiple V-cats into a single bracket but lazily labels it as one V-cat, the splitter takes that label at face value and the V-cat trigger (which intentionally bypasses BY-checking when `enum_source_age_category IS NOT NULL` per ADR-056) lets the wrong-V-cat rows through silently.

Phase 5 ingestion of `PPW2-2025-2026` on 2026-05-08 hit this case:

- FTL bracket `'SZPADA KOBIET 2 WETERANI'` parsed cleanly as `('EPEE', 'F', 'V2')`.
- Its 7 fencers actually spanned V0+V1+V2, with each fencer's actual V-cat encoded in their name string:
  - `"PĘCZEK (0) Sandra"` → V0
  - `"KAMIŃSKA   1 Gabriela"` → V1
  - `"WASILCZUK (2) Beata"` → V2
- The pipeline assigned all 7 to V2; 4 of them were also correctly present in the per-V-cat V0/V1 brackets (registered separately by the same organizer); ranklist contained KAMIŃSKA twice (V1 + V2).

The per-fencer markers are evidence that the organizer KNEW the bracket was a joint pool — they tagged each fencer manually because the bracket name couldn't disambiguate. Reading those markers preserves the organizer's intent (which ADR-056 says we should honour).

## Decision

**The FTL eventSchedule splitter inspects per-fencer name markers and downgrades misregistered brackets to joint-pool.**

Implementation in `python/pipeline/review_cli.py`:

1. **Marker extractor** `_extract_vcat_marker(fencer_name) -> int | None`:
   - Regex `\s+\(?([0-4])\)?\s+` matches a digit 0-4 surrounded by whitespace, optionally parenthesized.
   - Catches both Polish conventions: `"PĘCZEK (0) Sandra"` and `"KAMIŃSKA   1 Gabriela"`.
   - Returns `None` for clean names without markers.

2. **Bracket-vs-markers reconciler** `_bracket_marker_conflict(parsed, bracket_vcat)`:
   - When `bracket_vcat is None` (already joint-pool) → no conflict.
   - When no fencer in the bracket has a marker → no conflict (trust the bracket name; the organizer didn't bother encoding because there was no ambiguity).
   - When all marker-bearing fencers agree with `bracket_vcat` → no conflict (consistent).
   - When any marker-bearing fencer disagrees → **conflict**. The bracket is misregistered.

3. **Downgrade in `Fetcher.fetch_event_url_with_skips`**: when a conflict is detected for a single-V-cat bracket, set `category = None` before calling `_annotate_parsed`. This makes `parsed.category_hint = None`, which (per ADR-056's joint-pool clause) routes the bracket through the BY-derivation path — every fencer is assigned to her actual birth-year-derived V-cat.

The downgrade is logged to stderr with the marker distribution (e.g. `mislabeled as V2: V0=1 V1=3 V2=3 → downgrading to joint-pool`) so the operator can verify on the per-event staging summary.

## Alternatives considered

- **Strip markers from fencer names but keep bracket V-cat (no downgrade)**: would silently re-assign the wrong-V-cat fencers (KAMIŃSKA stays in V2 even though her marker says V1). Defeats the marker's purpose as evidence.
- **Halt and surface bracket misregistration to operator**: safer in principle but interrupts bulk runs for what is genuinely fixable data — the BY-derivation path produces the correct routing. The downgrade-and-log approach gives operators the same visibility (in the staging summary) without blocking ingestion.
- **Always-on BY enforcement at the trigger**: would invalidate ADR-056's deliberate "bracket label wins" rule for the legitimate cross-season case (ZAWROTNIAK V1 in 2023-24 vs V2 in 2024-25). Rejected — see ADR-056 revision.
- **Per-source override YAML to mark specific brackets as joint-pool**: scales poorly across hundreds of brackets and requires upfront knowledge of each misregistration. The marker-based check is automatic and source-driven.

## Consequences

**Positive**
- Misregistered FTL brackets are caught at staging time, before drafts commit.
- Each fencer is routed to her actual V-cat by BY-derivation when the organizer's per-fencer markers disagree with the bracket label — preserving organizer intent (the markers ARE the per-fencer placement decision).
- ADR-056's "bracket label wins" rule remains intact for clean per-V-cat brackets (most cases).
- No data corruption can land in `tbl_result` from this class of operator error.

**Negative / risks**
- Polish-specific marker convention. Other federations may use different formats (none seen yet in the rebuild scope).
- The check runs only for FTL eventSchedule paths. Other parsers (Engarde, FT XML, Ophardt, admin XLSX upload) carry their own V-cat assignment paths and don't benefit. Each parser needs its own equivalent guard if it can produce the same class of error.
- A bracket that legitimately mixes V-cats AND happens to have markers all matching its label (extremely unlikely) would not be flagged. Acceptable — that case isn't actually misregistration.

**Neutral**
- The ADR-056 trigger (`fn_assert_result_vcat`) is unchanged. The bypass for `enum_source_age_category IS NOT NULL` still load-bears for the legitimate cross-season carry-over case. We're tightening the producer, not the enforcer.

## Test scope

Plan IDs **P5.M1.1–P5.M1.11** in `python/tests/test_vcat_marker.py`:

- 5.M1.1 — `_extract_vcat_marker` parses `"(N)"` parenthesized markers.
- 5.M1.2 — parses bare-digit `" N "` markers.
- 5.M1.3 — returns `None` on clean fencer names.
- 5.M1.4 — handles empty / None / out-of-range digits.
- 5.M1.5 — handles hyphenated surnames (`SAMECKA - NACZYŃSKA 1 Martyna`).
- 5.M1.6 — `_bracket_marker_conflict`: bracket already joint-pool → no conflict signal.
- 5.M1.7 — bracket with no per-fencer markers → no conflict (trust label).
- 5.M1.8 — markers all consistent with bracket V-cat → no conflict.
- 5.M1.9 — bracket says V2 but markers span V0/V1/V2 → conflict (misregistration).
- 5.M1.10 — single outlier marker triggers conflict.
- 5.M1.11 — empty bracket → no conflict.

## Implementation

Files modified:

- `python/pipeline/review_cli.py` — added `_extract_vcat_marker`, `_bracket_marker_conflict`, wired into `Fetcher.fetch_event_url_with_skips`.
- `python/tests/test_vcat_marker.py` — new file, 11 unit tests.

No migration required. No schema change. Rolls forward only.
