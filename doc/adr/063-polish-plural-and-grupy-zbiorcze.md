# ADR-063: Polish-plural-case + GRUPY ZBIORCZE pool-round recognition in FTL bracket parsing

**Status:** Accepted (2026-05-03)
**Related:** ADR-050 (unified ingestion pipeline), ADR-057 (pool-round structural detection), ADR-062 (SPWS bracket-name filter)
**Phase:** 5 (operational rebuild)

## Context

PPW5-2024-2025 ingestion silently dropped 14 of 26 brackets at the FTL splitter ("unparseable bracket name") because the organizer used a different — but equally valid — Polish-grammar convention than PPW1-PPW4:

1. **Plural case for "men":** PPW5 used the *nominative plural* `MĘŻCZYŹNI` (with `Ź` — Z-acute). The existing `GENDER_MALE` regex `MĘŻCZYZN[I]?` only matched the *genitive plural* root `MĘŻCZYZN` (with plain `Z`) used in `kategoria N` constructs by PPW1-PPW4 organizers.
2. **Pool-round naming:** PPW5 named the preliminary all-fencer pools `GRUPY ZBIORCZE` (Polish: "collective groups") rather than `MIKST` or `Mixed`. They aren't tournaments — they only seed the per-V-cat brackets — but were neither in `MIKST_PATTERN` nor recognised structurally because the bracket name lacks gender words and `parse_tournament_name` returns `None`, falling into the generic "unparseable" bucket.

Both forms are correct organizer-dependent Polish. Our parser was tightly typed against one specific convention.

## Decision

- **Widen `GENDER_MALE`** from `MĘŻCZYZN[I]?` to `MĘŻCZY[ZŹ]N[IY]?` — accepts both genitive (Z) and nominative (Ź) roots, optional plural suffix `I`/`Y`.
- **Extend `MIKST_PATTERN`** with `\bGRUPY\s+ZBIORCZE\b` so these brackets get the existing pool-round skip path with reason `"Mixed/MIKST (pool round)"`.
- **Lock the original genitive form via regression test 5.22.2b** so future regex tweaks don't accidentally drop PPW1-PPW4 grammar.

## Alternatives considered

- **Per-event YAML override.** Reactive; new organizer convention = new override. Doesn't scale.
- **Drop strict gender-name matching and infer gender from fencer roster.** Bigger change; weakens parser confidence everywhere; defers gender resolution to a stage that can't halt early.
- **Widen the regex** (chosen). Minimal, declarative, locked by tests, easy to extend if SPWS adopts further variants.

## Consequences

**Positive:** PPW5-class events ingest fully (14 → 0 unparseable brackets). Future bracket names using either Polish-plural form parse cleanly. `GRUPY ZBIORCZE` brackets now categorized as pool rounds in the staging md instead of `unparseable bracket name`.

**Negative / risks:** Vocabulary maintenance burden grows if SPWS adopts further organizer-specific variants. 5.22.x test suite locks in the current accepted forms — adding new ones requires both code + test update.

**Neutral:** `MIKST_PATTERN` is now a small mixed-language enum (Polish + English). Acceptable; the regex is still trivially readable.

## Implementation

- [python/tools/scrape_ftl_event_urls.py](../../python/tools/scrape_ftl_event_urls.py) — `GENDER_MALE` and `MIKST_PATTERN` regex updates with inline comments documenting the grammatical reasoning.
- [python/tests/test_scrapers.py](../../python/tests/test_scrapers.py) — `TestFTLEventSchedule` plan tests 5.22.1 / 5.22.2 / 5.22.2b / 5.22.3.

## Test scope (TDD)

- pytest 5.22.1 — `parse_tournament_name("SZABLA MĘŻCZYŹNI V0")` → `(SABRE, M, V0)`
- pytest 5.22.2 — `parse_tournament_name("FLORET MĘŻCZYŹNI V3")` → `(FOIL, M, V3)`
- pytest 5.22.2b — regression guard: original `"SZPADA MĘŻCZYZN kategoria 2"` (genitive) → `(EPEE, M, V2)` still parses
- pytest 5.22.3 — `parse_event_schedule` skips `GRUPY ZBIORCZE` brackets as pool rounds; real `MĘŻCZYŹNI V0` bracket alongside is kept

## Amendment (2026-06-03) — no-gender `kat. N` brackets default to `M` (ADR-34 parity)

`parse_tournament_name` previously returned `None` for a weapon-bearing bracket
with **no gender keyword** (the FT `Sexe="X"` case, e.g. Polish `Szabla kat. 4` /
`Szabla kat. 0`). The URL discovery path therefore silently dropped the PPW5 V0/V4
men's-sabre brackets that the XML ingest path keeps (the XML path defaults gender
to `M` per ADR-34 and lets `fn_effective_gender` reassign any women at query time).
Fix: when weapon + category are present but no gender keyword matches, default
gender to `M` — making URL ingest byte-identical to XML ingest for PPW4/PPW5.
Guest-event names are still filtered upstream by `SPWS_BRACKET_FIRST_TOKEN`.
Test: pytest 3.15g2 (`test_scrapers.py::TestFTLEventSchedule::test_parse_tournament_name_polish_kat_no_gender_defaults_male`).
