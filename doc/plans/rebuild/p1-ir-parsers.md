# Phase 1 — IR + 8 parsers (7 existing + Ophardt) (M) ✅ DONE 2026-05-01

**Prerequisites:** Phase 0 ([p0-prep.md](p0-prep.md)) — schema, cert_ref, rules, matcher config, Claude modules aligned. ✅ shipped.

**Status:** All deliverables shipped on `main`. pgTAP 404 → 427, pytest 354 → 402, vitest unchanged at 332. See `git log --oneline` for the 6 incremental commits (4409f95 → 6a8c3e4 → 7921a10 → 043ac7c → 713dc71 → f0ade4d → final Ophardt + registry).

## Goal

Stand up a normalized intermediate representation (IR). Conform all 7 existing parsers to it. Add Ophardt as the 8th parser — spike confirmed server-rendered HTML, no Playwright dep needed (see [doc/audits/ophardt_format_research.md](../../audits/ophardt_format_research.md)).

## IR contract

```python
@dataclass
class ParsedResult:
    fencer_name: str
    fencer_country: str | None
    birth_year: int | None
    birth_date: date | None
    place: int
    raw_age_marker: str | None       # "v0v1" / individual age cell
    source_vcat_hint: str | None     # e.g. EVF categoryId-derived V-cat
    bool_excluded: bool              # FTL excluded flag etc.
    source_row_id: str

@dataclass
class ParsedTournament:
    parsed_date: date                # normalized at parse time
    weapon: str
    gender: str
    season_end_year: int             # injected; required for splitter
    organizer_hint: str              # SPWS | EVF | FIE
    source_kind: SourceKind
    source_url: str | None
    source_artifact_path: str | None
    raw_pool_size: int | None
    category_hint: str | None        # tournament-level hint (EVF API: authoritative)
    results: list[ParsedResult]
```

`MatchResult` gains `alternatives: list[Candidate]` so the diff can render *all* candidates for ambiguous multi-fencer cases.

## Deliverables

- ✅ **Traceability schema** (ADR-055) — migration `supabase/migrations/20260501000003_phase1_ingest_traceability.sql`:
  - `enum_parser_kind` Postgres enum (mirrors Python `SourceKind` from `python/pipeline/ir.py`)
  - Stamp columns on `tbl_event` + `tbl_tournament`: `enum_parser_kind`, `dt_last_scraped`, `txt_source_url_used`
  - Two history tables (`tbl_event_ingest_history`, `tbl_tournament_ingest_history`) with FK CASCADE, UNIQUE on (parent, run_id), cap-of-6 BEFORE INSERT triggers
  - pgTAP suite `supabase/tests/26_ingest_traceability.sql` (23 assertions)
- ✅ New file: `python/pipeline/ir.py` — `ParsedTournament`, `ParsedResult`, `SourceKind` enum (8 values incl. `OPHARDT_HTML`); cross-language sync test (`test_ir.py::test_source_kind_matches_postgres_enum`) catches drift between Python and Postgres at runtime.
- ✅ New file: `python/scrapers/ophardt.py` — Ophardt parser (server-rendered HTML, BeautifulSoup, no JS runtime).
- ✅ Parser registry in `python/scrapers/__init__.py` (`PARSERS` dict) covering all 8 sources.
- ✅ Each parser conforms to the IR via a `parse_*()` factory:
  - `fencingtime_xml.parse(bytes)` → ParsedTournament (native Tireur.ID)
  - `ftl.parse_json(data)` and `ftl.parse_csv(text)` (native FTL `id` field for JSON; synthetic for CSV)
  - `engarde.parse_html(html)` (synthetic, locale-agnostic)
  - `fourfence.parse_html(html)` (synthetic; country=None per source quirk)
  - `dartagnan.parse_rankings(html)` (synthetic, country from flag-img-src)
  - `evf_results.parse_results(raw, weapon=…, gender=…, category_hint=…, parsed_date=…)` (pure function — no client lifecycle)
  - `file_import.parse(bytes, filename)` (CSV/XLSX/JSON dispatcher)
  - `ophardt.parse_results(html)` (native `/athlete/{id}/`)
- ✅ pytest contract tests in `python/tests/test_ir_contracts.py` — 41 assertions covering all 8 parsers + parser registry.
- ✅ Test fixtures: Engarde HU at `python/tests/fixtures/engarde/clasfinal_hunfencing.html` (existing); Ophardt at `python/tests/fixtures/ophardt/results_903540-2024_munich_foil_men_v2.html` (Munich 2024 EVF Circuit, Foil Men's O50 → V2).

## Sources (8 total)

| Source | File | Change required |
|---|---|---|
| FencingTime XML | [python/scrapers/fencingtime_xml.py](../../../python/scrapers/fencingtime_xml.py) | Refactor to emit IR; combined-pool detection moves to Stage 3 |
| FTL | [python/scrapers/ftl.py](../../../python/scrapers/ftl.py) | Refactor to emit IR; preserve excluded-flag |
| Engarde | [python/scrapers/engarde.py](../../../python/scrapers/engarde.py) | Refactor to emit IR; existing parser locale-agnostic. Add HU fixture. |
| 4Fence | [python/scrapers/fourfence.py](../../../python/scrapers/fourfence.py) | Refactor to emit IR |
| Dartagnan | [python/scrapers/dartagnan.py](../../../python/scrapers/dartagnan.py) | Refactor to emit IR |
| EVF API | [python/scrapers/evf_results.py](../../../python/scrapers/evf_results.py) | Refactor to emit IR; harden CATEGORY_MAP missing-key path (must error, not return None) |
| CSV/XLSX/JSON | [python/scrapers/file_import.py](../../../python/scrapers/file_import.py) | Wire to orchestrator (currently orphaned) |
| Ophardt (NEW) | `python/scrapers/ophardt.py` (to create) | Server-rendered HTML on `fencingworldwide.com`; results table at `/{lang}/{tournamentId}-{year}/results/`; emits IR with stable `source_row_id="ophardt:{athleteId}"`; locale-mixed breadcrumb (German labels on `/en/` URLs) — reuse Engarde lookup tables. Birth year not exposed; rely on event-level `category_hint` + Ophardt athlete ID for identity. Spike: [doc/audits/ophardt_format_research.md](../../audits/ophardt_format_research.md). |

## Risk gate (all met 2026-05-01)

- ✅ All existing pytest scraper tests still pass (legacy `parse_ftl_json` / `parse_engarde_html` / etc. untouched).
- ✅ New contract tests pass: each of the 8 parsers → schema-valid `ParsedTournament` (41/41 in `test_ir_contracts.py`).
- ✅ Ophardt parser produces a valid `ParsedTournament` from the captured Munich fixture.
- ✅ Traceability migration applied; `supabase/tests/26_ingest_traceability.sql` green (23/23).
- ✅ Cross-language enum sync test (`test_ir.py::test_source_kind_matches_postgres_enum`) green — Python `SourceKind` exactly matches Postgres `enum_parser_kind`.

## Cross-references

- Master plan: [now-we-have-a-precious-wren.md](/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md)
- Predecessor: [p0-prep.md](p0-prep.md)
- Successor: [p2-drafts.md](p2-drafts.md) — Draft tables + dry-run loop (consumes IR)
- Implements R012 (Engarde multilingual handling)
