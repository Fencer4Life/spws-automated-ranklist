# ADR-062: Skip non-SPWS bracket names at FTL event-schedule discovery

**Status:** Accepted (2026-05-03)
**Related:** ADR-050 (unified ingestion pipeline), ADR-057 (pool-round structural detection)
**Phase:** 5 (operational rebuild)

## Context

FTL event-schedule URLs sometimes list brackets from a *different* competition held back-to-back at the same venue. Discovered on PPW4-2024-2025: the "Akademickie Mistrzostwa Warszawy i Mazowsza" (Academic Championships of Warsaw and Mazovia) shared the FTL schedule page `E77EA15E4ACA4A23B1539C95B34E60EB` with PPW4. Two of its brackets — szabla mężczyzn (men's sabre) and szabla kobiety (women's sabre) — survived the existing skip filters and were ingested as if they were PPW4 sub-tournaments:

- **Men's bracket** had 18 fencers with V-cat markers `(0)/(1)/(2)`. `s7_split_by_vcat` treated it as a joint pool and emitted V0/V1/V2 PPW4 drafts.
- The consolidator merged those drafts with the *real* PPW4 SABRE-M brackets by `txt_code`.
- 5 fencers who competed in BOTH events (KOŃCZYŁO V2, MIKOŁAJCZUK V0, REDZIŃSKI V0, PRZYSTAJKO V1, TECŁAW V1) ended up with two `tbl_result_draft` rows sharing `(id_fencer, id_tournament_draft)`.
- `uq_result_fencer_tournament` blocked the commit. Several days lost diagnosing the wrong layer (suspected pool/DE merge, then consolidator) before realizing the bug was at *bracket discovery* — the pipeline had no way to know "this bracket isn't ours".

The women's AKADEMICKIE bracket was halted by ADR-057's gender-mix structural check (8M/2F majority/minority anomaly), but only by accident — pure luck of how it matched against the master fencer table. The men's bracket was all-male, so ADR-057 didn't fire.

ADR-057 introduced structural pool-round detection (post-matcher gender mix). That helps when a bracket is genuinely a pool round, but a guest event held by a different organization is not a pool round — it's a real tournament, just not OUR tournament. We need a complementary filter at *discovery* time.

## Decision

**Add a third filter to `parse_event_schedule` (alongside `MIKST_PATTERN` and `SKIP_PATTERNS`)** requiring the bracket name's first significant token to match `SPWS_BRACKET_FIRST_TOKEN`. Vocabulary covers:

- Polish weapons: `Szpada` / `Floret` / `Szabla`
- English weapons: `Epee` / `Épée` / `Foil` / `Sabre` / `Saber`
- Genders: `Men's` / `Women's` / `Men` / `Women` / `Mens` / `Womens` / `kobiet[ay]` / `mężczyzn[iy]`
- V-cat / age / format markers: `Vet` / `Veteran[iy]` / `Senior` / `Mixed` / `Mikst` / `Cat[egory]` / `Kategori[aę]`

Names that don't match are added to the `skipped` list with reason `"guest event (non-SPWS bracket name)"` and surfaced in the per-event staging `.md`.

## Alternatives considered

- **Pure denylist regex** (`Akademickie`, `Mistrzostwa Polski Senior`, etc.). Brittle as new guest events emerge — whack-a-mole.
- **Operator-driven YAML override** (`bracket_skip:` per event). Tedious; requires the operator to know about the guest event before ingesting.
- **Compare bracket fencer-set against a known SPWS participant list.** No reliable participant list exists pre-ingest.
- **Detect "competition-name structure"** via dash-separated guest-event prefix. Fragile — the SPWS bracket `"Szpada kobiet i mężczyzn - grupy"` also has a dash.
- **Allowlist at first-token level** (chosen). Minimal filter, declarative, reusable across past + future events, easy to widen by adding tokens to the regex if SPWS adopts new naming conventions.

## Consequences

**Positive**
- Closes a class of bug whose only signal was a downstream uniqueness violation. Self-explanatory: `"guest event"` reason in staging md tells the operator exactly why a bracket got skipped.
- Discovery-time filter is the cheapest possible layer; no downstream stage has to reason about cross-event ambiguity.
- Composes cleanly with ADR-057: name-based filters skip *obvious* non-SPWS brackets at discovery; structural detection catches what slips through.

**Negative / risks**
- First-token vocabulary needs maintenance if SPWS adopts new naming conventions. The 5.21.x test suite locks in the current vocabulary; adding a new prefix requires both code + test update.
- Per-event staging md cosmetic: guest-event skips currently render under the existing **"Pool rounds detected"** header (they get the same `skipped` data shape). Future polish could split the section into "Pool rounds" + "Guest events skipped". Low priority — operator visibility is unaffected.

**Neutral**
- No retroactive effect on past committed events. Re-ingesting an event with this filter will produce fewer brackets if it previously included guest-event sub-tournaments; that's the desired behaviour but worth noting before bulk re-runs.

## Implementation

- [python/tools/scrape_ftl_event_urls.py](../../python/tools/scrape_ftl_event_urls.py) — `SPWS_BRACKET_FIRST_TOKEN` regex + filter in `parse_event_schedule` after `MIKST_PATTERN` and `SKIP_PATTERNS`. Skipped entries carry reason `"guest event (non-SPWS bracket name)"`.
- [python/tests/test_scrapers.py](../../python/tests/test_scrapers.py) `TestFTLEventSchedule` — plan tests 5.21.1–5.21.4.

## Test scope (TDD)

- pytest 5.21.1 — Polish AKADEMICKIE-style guest event ("Akademickie Mistrzostwa Warszawy i Mazowsza - szabla mężczyzn") skipped
- pytest 5.21.2 — Polish PPW-conventional bracket "Szpada kobiet i mężczyzn - grupy" kept (regression guard, weapon-first with dash)
- pytest 5.21.3 — skipped guest-event entry carries informative reason text mentioning "guest" or "non-SPWS"
- pytest 5.21.4 — English-language SPWS brackets ("Men's Sabre Category 3 and 4", "Women's Foil Category 1 and 2") kept (regression guard for gender-first names)
