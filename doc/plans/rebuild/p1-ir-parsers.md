# Phase 1 — IR + 7 existing parsers (M)

**Prerequisites:** Phase 0 ([p0-prep.md](p0-prep.md)) — schema, cert_ref, rules, matcher config, Claude modules aligned.

## Goal

Stand up a normalized intermediate representation (IR). Conform all 7 existing parsers to it. Decide whether Ophardt belongs in this rebuild or defers to Phase 1.5.

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

- New file: `python/pipeline/ir.py` — `ParsedTournament`, `ParsedResult`, `SourceKind` enum.
- Parser registry in `python/scrapers/__init__.py`.
- Each existing parser conforms to the IR via `parse(...) → ParsedTournament` factory.
- pytest contract tests: each parser produces a schema-valid `ParsedTournament`.
- Engarde HU test fixture added to `python/tests/fixtures/engarde/hu/`.

## Sources to refactor (7 existing)

| Source | File | Change required |
|---|---|---|
| FencingTime XML | [python/scrapers/fencingtime_xml.py](../../../python/scrapers/fencingtime_xml.py) | Refactor to emit IR; combined-pool detection moves to Stage 3 |
| FTL | [python/scrapers/ftl.py](../../../python/scrapers/ftl.py) | Refactor to emit IR; preserve excluded-flag |
| Engarde | [python/scrapers/engarde.py](../../../python/scrapers/engarde.py) | Refactor to emit IR; existing parser locale-agnostic. Add HU fixture. |
| 4Fence | [python/scrapers/fourfence.py](../../../python/scrapers/fourfence.py) | Refactor to emit IR |
| Dartagnan | [python/scrapers/dartagnan.py](../../../python/scrapers/dartagnan.py) | Refactor to emit IR |
| EVF API | [python/scrapers/evf_results.py](../../../python/scrapers/evf_results.py) | Refactor to emit IR; harden CATEGORY_MAP missing-key path (must error, not return None) |
| CSV/XLSX/JSON | [python/scrapers/file_import.py](../../../python/scrapers/file_import.py) | Wire to orchestrator (currently orphaned) |

## Ophardt research spike (manual fetch + writeup)

- Output: `doc/audits/ophardt_format_research.md`
- Decision criteria:
  - HTML-server-rendered → in-scope, write parser this phase or 1.5
  - SPA / Playwright-only → defer to Phase 1.5 or out-of-scope (heavy dep)
- File `python/scrapers/ophardt.py` is created **only if** the research outcome is favorable.

## Risk gate

- All existing pytest scraper tests pass.
- New contract tests pass (each parser → schema-valid `ParsedTournament`).
- Ophardt decision documented in `doc/audits/ophardt_format_research.md`.

## Cross-references

- Master plan: [now-we-have-a-precious-wren.md](/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md)
- Predecessor: [p0-prep.md](p0-prep.md)
- Successor: [p2-drafts.md](p2-drafts.md) — Draft tables + dry-run loop (consumes IR)
- Implements R012 (Engarde multilingual handling)
