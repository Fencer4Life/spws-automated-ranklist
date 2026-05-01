# Full Data Import Plan: 30 Categories x 3 Seasons

## Context

The SPWS ranking system needs production-quality data across **all 30 sub-rankings** (3 weapons x 2 genders x 5 age categories) for **3 seasons** to upload to CERT for community validation.

| Season | Current State | Target |
|---|---|---|
| SPWS-2023-2024 | V2 M Epee only | All 30 categories from 60 Excel files |
| SPWS-2024-2025 | All 30 from older snapshot (missing PP4/PP5) | Regenerate all 30 from newer Excel files |
| SPWS-2025-2026 | V2 M Epee only | All 30 (PP1 scrape + PP2 scrape + PP4 XML; PP3 LOST) |

## Architecture: Staging Spreadsheet

A `.ods` spreadsheet serves as the **human-editable staging layer** between raw source files and SQL seed scripts. The user curates metadata; results go directly from sources to SQL.

```
Source files (Excel / XML / FTL scrape)
    ↓  [Python: parse → populate spreadsheet + generate results SQL]
Staging Spreadsheet (.ods) — user reviews & improves metadata
    ↓  [Python: read spreadsheet → generate metadata SQL]
    +  Results SQL (generated directly from sources, user spot-checks)
    ↓
Combined SQL seed scripts → supabase db reset → CERT upload
```

### Spreadsheet Structure — 5 tabs

### Cell protection & color coding

All tabs use sheet protection (blank password — user can unlock if needed).

| Color | Meaning | Editable? |
|---|---|---|
| **White (no bg)** | User-curated columns | Yes |
| **Light gray** (#E0E0E0) | All non-editable cells (formulas, locked data) | No (locked) |
| **Dark navy** (#2C3E50) | Header row — inverse (white bold text) | No (locked) |
| **Light green** (#C6EFCE) | Coverage tab — data exists | No (locked) |

Additional features: frozen header rows, autofilter dropdowns on all tabs.

#### 1. Seasons (editable)
Season definitions + scoring config + import tracking log.

| Column | Description |
|---|---|
| season_code | e.g., `SPWS-2023-2024` |
| dt_start, dt_end | Season boundaries |
| bool_active | Only one TRUE |
| ppw_best_count | Best K domestic rounds (4) |
| ppw_total_rounds | Total domestic rounds (8 for 2023-24, 5 for 2024-25+) |
| mpw_multiplier | National championship multiplier |
| pew_best_count | Best J international events |
| mew_multiplier, msw_multiplier | Championship multipliers |
| import_log | Free-text notes: decisions, known gaps, iteration history |

#### 2. Fencers (editable)
Master fencer list with identity resolution tracking.

**Tunable matching parameters** (in the tab header, above the data rows):

| Parameter | Default | Effect |
|---|---|---|
| `auto_match_threshold` | 90 | Score ≥ this → CONFIRMED |
| `pending_threshold` | 50 | Score ≥ this → FUZZY_{score} |
| `use_diacritic_folding` | TRUE | Fold ą→a, ł→l, etc. before comparing |
| `use_token_set_ratio` | TRUE | Use max(token_sort, token_set) instead of token_sort only |

**Iteration workflow:** User changes thresholds → re-runs `populate` → checks CONFIRMED vs FUZZY vs NEW counts → adjusts → repeats until satisfied.

**Data columns:**

| Column | Description |
|---|---|
| id | Auto-assigned (matches seed_tbl_fencer.sql row order) |
| surname, first_name | Canonical name |
| birth_year | Year of birth (critical for age category assignment) |
| **birth_year_source** | `EXACT` (from XML DOB), `ESTIMATED` (from age cat), `USER` (manually set) |
| club | Current club affiliation |
| nationality | Default 'PL' |
| **match_status** | `CONFIRMED` (exact/alias match), `FUZZY_85` (score), `NEW` (created from unmatched domestic name), `AMBIGUOUS` (multiple potential matches) |
| source_note | Where this fencer was first discovered |

Alias columns deferred — will be added later if needed.

User actions: fix names, correct birth years, resolve AMBIGUOUS/FUZZY entries.

#### 3. Events (editable)
Parent events — one row per event per season.

| Column | Color | Description |
|---|---|---|
| **event_code** | gray (locked) | Auto-derived: `=CONCAT(event_prefix, "-", season_code)` |
| event_prefix | white | Editable building block, e.g., `PP1`, `PEW3`, `GP7` |
| name | white | Canonical event name |
| season_code | white | FK to Seasons tab |
| organizer | white | SPWS / EVF / FIE |
| location, country | white | Venue info |
| dt_start, dt_end | white | Auto-populated from Excel, user can override |
| status | white | COMPLETED / SCHEDULED / CANCELLED |
| url_event, url_invitation | white | Links |
| entry_fee, currency | white | Optional |
| **discrepancy_note** | white | Auto-filled if Excel files disagree on name/location/date |

User actions: fix event names, add missing URLs, correct dates/locations.

#### 4. Tournaments (editable)
Per-category tournament entries — the core data curation tab.

| Column | Color | Description |
|---|---|---|
| **tournament_code** | gray (locked) | Auto-derived: `=CONCAT(event_prefix, "-", age_cat, "-", gender, "-", weapon, "-", season_code)` |
| **event_code** | gray (locked) | Auto-derived: `=CONCAT(event_prefix, "-", season_code)` — FK to Events tab |
| event_prefix | white | Building block, e.g., `PP1`, `PEW3` |
| season_code | white | Season reference |
| weapon | white | EPEE / FOIL / SABRE |
| gender | white | M / F |
| age_cat | white | V0 / V1 / V2 / V3 / V4 |
| type | white | PPW / MPW / PEW / MEW / PSW |
| dt_tournament | white | Date (auto-populated, overridable) |
| **participant_count** | white | Re-counted after category split (not combined N) |
| result_url | white | FTL/Engarde/4Fence URL for scraping |
| **source_file** | white | Path to Excel sheet or XML file |
| **original_source** | white | For split categories: ref to combined source (e.g., `VABCME_2026-11.xml`) |
| **import_status** | white | `PLANNED` / `NEEDS_URL` / `SCRAPED` / `SPLIT` / `SCORED` / `LOST` / `EMPTY` |
| notes | white | Free text |

User actions: add scrape URLs, mark LOST/EMPTY, correct participant counts.

**Combined category splitting:** When PP4 ran V0+V1 together (10 fencers), populate creates TWO rows:
- `PP4-V0-M-EPEE-2025-2026` with `participant_count` = count of V0 fencers, `original_source` = `VABCME_2026-11.xml`
- `PP4-V1-M-EPEE-2025-2026` with `participant_count` = count of V1 fencers, `original_source` = `VABCME_2026-11.xml`
- Results re-ranked within each split category (place 1..N per split, N = split count)

#### 5. Coverage (read-only, auto-generated)
Gap matrix grouped by season. Rows = events, columns = 30 categories.

| Cell Value | Meaning |
|---|---|
| Number (e.g., `10`) | Participant count — data imported |
| `?` | Not yet imported |
| `LOST` | Data unrecoverable |
| `0` or `EMPTY` | Event held but zero participants in this category |
| `-` | Event doesn't exist for this season |

Regenerated each time `populate` or `export` runs.

### What stays OUTSIDE the spreadsheet
- **tbl_result rows** — generated directly from Excel/XML/scraper sources into SQL files
- User reviews result SQL files for sanity (spot-check top placements)

### Regeneration requirement
All existing seed data — including the current 2025-2026 V2 M Epee seed — will be regenerated through the staging spreadsheet workflow. No existing seed file is assumed correct.

---

## Fuzzy Matching Strategy

### Current state: two incompatible systems
1. **`generate_season_seed.py`** — binary threshold-80 match/no-match using `token_sort_ratio`
2. **`python/matcher/fuzzy_match.py`** — 3-tier (AUTO≥95, PENDING≥50, UNMATCHED<50) with age-category disambiguation

**Decision:** Unify on the proper matcher (`fuzzy_match.py`), enhanced with two new capabilities.

### Enhancements to `fuzzy_match.py`

#### 1. Diacritic folding in `normalize_name()`
Add `unicodedata.normalize('NFD')` + strip combining marks before comparison.
- `ŁUCZAK` → `LUCZAK`, `BARAŃSKI` → `BARANSKI`, `KOŃCZYŁO` → `KONCZYLO`
- Eliminates a whole class of aliases (Polish ↔ ASCII from international sources)
- Controlled by `use_diacritic_folding` parameter (default: TRUE)

#### 2. Token set ratio as secondary scorer
Add `fuzz.token_set_ratio` and take `max(token_sort_ratio, token_set_ratio)`.
- Handles name subsets: `SPŁAWA-NEYMAN MACIEJ` vs `NEYMAN MACIEJ` → ~95 (was ~75)
- Handles extra words: `CIUFFREDA Luigi Salvatore` vs `CIUFFREDA Luigi` → high score
- Controlled by `use_token_set_ratio` parameter (default: TRUE)

#### 3. Alias matching remains exact (case-insensitive, diacritic-folded)
Aliases always return score 100. No fuzzy alias matching.

### Threshold classification for staging spreadsheet

| Score | Status | Action |
|---|---|---|
| ≥ `auto_match_threshold` (default 90) | `CONFIRMED` | Auto-linked, no alias needed |
| ≥ `pending_threshold` (default 50) | `FUZZY_{score}` | Visible in spreadsheet Fencers tab for user review |
| < 50, domestic (PPW/MPW) | `NEW` | Auto-created in Fencers tab with estimated birth year |
| < 50, international (PEW/MEW) | skipped | Not added to Fencers tab |

### Tunable parameters
Matching parameters are stored in the **Fencers tab header** (see §2 above). The `populate` command reads them before running matches.

### Why start at 90 (not 95)
- With diacritic folding, most real Polish name matches jump from ~85 → 100
- Single-letter typos (`KOWALSKY` vs `KOWALSKI`) score ~95 → auto-matched at 90
- False-positive risk is low: `KOWALSKI Jan` vs `KOWALSKA Anna` scores ~75 → stays in FUZZY
- User can tighten to 95 or loosen to 85 after seeing results

---

## Phase 0: Staging Spreadsheet Setup

### T0.1 — Install ODS dependency

```bash
pip install odfpy
```

Add `odfpy` to requirements.

### T0.2 — Enhance fuzzy matcher

**Modify:** `python/matcher/fuzzy_match.py`

1. Add diacritic folding to `normalize_name()` (behind `use_diacritic_folding` flag)
2. Add `token_set_ratio` secondary scorer (behind `use_token_set_ratio` flag)
3. Make thresholds configurable via parameters (not hardcoded constants)
4. Add tests for diacritic folding and token_set_ratio edge cases

### T0.3 — Create spreadsheet generator (CURRENT TASK — mock mode)

**New files:**
- `python/tools/staging_spreadsheet.py` — CLI tool with mock/populate/export subcommands
- `python/tests/test_staging_spreadsheet.py` — 15 test assertions (IDs 9.101–9.115)

Three modes (only **mock** implemented now):
- **`mock`** — Generate `doc/staging_data_mock.ods` with 3-5 realistic sample rows per tab, color coding, cell protection, and formulas. User reviews in LibreOffice, gives feedback. Mock is deleted before real data work begins.
- **`populate`** — (future) Read all source data (Excel/XML) → write `doc/staging_data.ods` with extracted metadata
- **`export`** — (future) Read user-curated spreadsheet → generate SQL seed files

#### CLI Interface

```
python python/tools/staging_spreadsheet.py mock [--output PATH]
python python/tools/staging_spreadsheet.py populate --input PATH [--output PATH]  # future
python python/tools/staging_spreadsheet.py export --input PATH                     # future
```

Default mock output: `doc/staging_data_mock.ods`

#### odfpy API Patterns

```python
from odf.opendocument import OpenDocumentSpreadsheet
from odf.table import Table, TableRow, TableCell, TableColumn
from odf.text import P
from odf.style import Style, TableCellProperties, TableColumnProperties, TextProperties
```

| Operation | API |
|---|---|
| Background color | `TableCellProperties(backgroundcolor='#D6EAF8')` |
| Cell lock (protected) | `TableCellProperties(cellprotect='protected')` |
| Cell unlock (editable) | `TableCellProperties(cellprotect='none')` |
| Sheet protection | `Table(name='Seasons', protected='true', protectionkey='')` |
| Formula cell | `TableCell(formula='of:=CONCAT([.B2];"-";[.D2])')` |
| Column width | `TableColumnProperties(columnwidth='3cm')` |

Formula syntax: ODF `of:=` prefix, semicolon separators, `[.A1]` cell refs.

#### Code Structure

```
staging_spreadsheet.py
├── CONSTANTS (column definitions, mock data, color maps)
├── _create_styles(doc) → {"header", "white", "gray", "blue"}
│   - header: bold, no bg
│   - white: cellprotect="none" (editable)
│   - gray: bg=#E0E0E0, cellprotect="protected" (locked)
│   - blue: bg=#D6EAF8, cellprotect="none" (editable, pre-filled)
├── _add_cell(row, value, style, valuetype, formula) — helper
├── _build_seasons_tab(doc, styles, data) → Table
├── _build_fencers_tab(doc, styles, data, params) → Table
├── _build_events_tab(doc, styles, data) → Table  (formulas for event_code)
├── _build_tournaments_tab(doc, styles, data) → Table  (formulas for codes)
├── _build_coverage_tab(doc, styles, events, tournaments) → Table
├── mock_mode(output_path) — orchestrator
├── main() — argparse subcommands
```

Tab builders accept data as parameter (mock passes constants; future populate passes DB results).

#### Formula Specification

**Events tab — event_code (col A):**
`of:=CONCAT([.B{r}];"-";[.D{r}])` (event_prefix + season_code) → `PP1-SPWS-2024-2025`

**Tournaments tab — tournament_code (col A):**
`of:=CONCAT([.C{r}];"-";[.G{r}];"-";[.F{r}];"-";[.E{r}];"-";[.D{r}])`
(event_prefix + age_cat + gender + weapon + season_code) → `PP1-V2-M-EPEE-SPWS-2024-2025`

**Tournaments tab — event_code (col B):**
`of:=CONCAT([.C{r}];"-";[.D{r}])` → `PP1-SPWS-2024-2025`

#### Mock Data

**3 Seasons:** SPWS-2023-2024, SPWS-2024-2025, SPWS-2025-2026
**5 Fencers** (Polish diacritics): KOWALSKI Jan, NOWAKOWSKA-WIŚNIEWSKA Anna, BŁAŻEJEWSKI Krzysztof, DĄBROWSKI Łukasz, ZIĘBA Małgorzata
**~10 Events** (3-5 per season): PP1, PP2, MPW, PEW1, GP1, GP2, etc.
**5 Tournaments** (varied weapon/gender/age_cat combos)
**Coverage:** Sample gap matrix with numbers, `?`, `LOST`, `-`

#### Test Plan (IDs 9.101–9.115)

Tests use `subprocess.run` + `odf.opendocument.load()` via shared `@pytest.fixture(scope="module")`.

| ID | Test | Assertion |
|---|---|---|
| 9.101 | `test_mock_creates_ods_file` | CLI exits 0, file exists |
| 9.102 | `test_mock_has_five_tabs` | 5 Tables: Seasons, Fencers, Events, Tournaments, Coverage |
| 9.103 | `test_seasons_tab_columns` | Header row has 11 columns matching spec |
| 9.104 | `test_seasons_tab_data_rows` | 3 data rows (one per season) |
| 9.105 | `test_fencers_tab_header_area` | Rows 0-3 have matching parameter labels + default values |
| 9.106 | `test_fencers_tab_columns` | Data header row has 11 columns matching spec |
| 9.107 | `test_fencers_tab_data_rows` | 5 data rows, at least one has Polish diacritics |
| 9.108 | `test_events_tab_columns` | Header has 13 columns matching spec |
| 9.109 | `test_events_tab_formula_columns` | event_code cells have `formula` attr with `of:=CONCAT` |
| 9.110 | `test_tournaments_tab_columns` | Header has 15 columns matching spec |
| 9.111 | `test_tournaments_tab_formula_columns` | tournament_code + event_code have formula attrs |
| 9.112 | `test_coverage_tab_exists` | Coverage tab exists with category column headers |
| 9.113 | `test_color_coding_gray_cells` | Formula cells have bg=#e0e0e0 |
| 9.114 | `test_color_coding_blue_cells` | Auto-populated cells have bg=#d6eaf8 |
| 9.115 | `test_sheet_protection` | All 5 Tables have `protected='true'` |

#### TDD Execution Order

1. Write tests → `python/tests/test_staging_spreadsheet.py` (15 assertions)
2. Run tests → RED (ImportError / FileNotFoundError)
3. Write implementation → `python/tools/staging_spreadsheet.py`
4. Run tests → GREEN (all 15 pass)
5. Run full suite → no regressions
6. User reviews `doc/staging_data_mock.ods` in LibreOffice

### T0.4 — Create result importer

**New file:** `python/tools/import_results.py`

Reads the Tournaments tab from the staging spreadsheet, then for each tournament:
- If `source_file` points to an Excel sheet → use `generate_season_seed.py` extraction logic
- If `source_file` points to an XML file → use XML parser logic
- If `result_url` is a FTL/Engarde/4Fence URL → use existing scrapers
- If `import_status` = LOST → skip, add SQL comment

Outputs result INSERT statements appended to the per-category SQL file.

---

## Phase 1: Source Data Extraction

### T1.1 — Extract metadata from 2023-2024 Excel files (60 files)

Read all 60 Excel files in `doc/external_files/Sezon 2023 - 2024/`:
- Sheet names: GP1-GP8, MPW, PEW1-PEW12, VFC, IMEW, KlasyfikacjaGP
- Extract: location (C2), date (C3), participant count (H2), result URL (C2 hyperlink)
- Populate Events + Tournaments tabs for season SPWS-2023-2024

**File naming convention:**
| Pattern | Male | Female |
|---|---|---|
| Epee | `SZPADA-{N}-2023-2024.xlsx` | `SZPADA-K{N}-2023-2024.xlsx` |
| Foil | `FLORET-{N}-2023-2024.xlsx` | `FLORET-K{N}-2023-2024.xlsx` |
| Sabre | `SZABLA-{N}-2023-2024.xlsx` | `SZABLA-K{N}-2023-2024.xlsx` |

Where N=0→V0, N=1→V1, N=2→V2, N=3→V3, N=4→V4

**Sheet → tournament type mapping (2023-2024):**
```
GP1-GP8 → PPW (8 domestic rounds, best 4 of 8)
MPW → MPW
PEW1-PEW12 → PEW
VFC → PEW (EVF-organized)
IMEW → MEW
```

### T1.2 — Extract metadata from 2024-2025 Excel files (60 files)

Same structure as T1.1 but from `doc/external_files/Sezon 2024 - 2025/`:
- Sheet names: PP1-PP5, MPW, PEW1-PEW7, PS, IMEW
- These are NEWER than `reference/SZPADA-2-2024-2025.xlsx` (which was missing PP4/PP5)

**Sheet → tournament type mapping (2024-2025):**
```
PP1-PP5 → PPW (5 domestic rounds, best 4 of 5)
MPW → MPW
PEW1-PEW7 → PEW
PS → PSW
IMEW → MEW
```

### T1.3 — Extract metadata from 2025-2026 XML files

Parse 17 XML files in `doc/external_files/Sezon_2025-2026/Attachments-Fw_ wyniki Gdańsk/`:
- Extract fencer data: Nom, Prenom, DateNaissance, Sexe, Nation, Club, Classement
- Map XML file → SPWS category using AltName field:
  - `VABCME` → v0+v1 Male Epee (combined)
  - `V40ME` → v2 Male Epee
  - `V50ME` → v3 Male Epee
  - `V60ME` → v4 Male Epee
  - etc.
- For combined categories: split fencers using birth year → age category
- For missing DOB: cross-reference master list, fall back to lowest category

**PP1 + PP2:** Need FTL scrape URLs (user to provide in Tournaments tab)
**PP3:** Marked as LOST in Tournaments tab

### T1.4 — Extract & augment fencer master list

Build comprehensive Fencers tab from all sources:
1. Start with existing 270 fencers from `seed_tbl_fencer.sql`
2. Add unmatched domestic (PPW/MPW) fencers from all Excel files
3. Enrich birth years from XML `DateNaissance` fields
4. Add foreign fencers who participated in PPW tournaments
5. Add `source_note` column tracking where each fencer was discovered

---

## Phase 2: User Curation Cycle

**Handoff to user.** The populated `doc/staging_data.ods` contains:
- ~300+ fencers (270 existing + newly discovered)
- ~40-60 events across 3 seasons
- ~500+ tournament entries (30 cats × ~15-20 events per season)
- Coverage matrix showing gaps

**User actions:**
1. Review & correct fencer names, birth years, club affiliations
2. Fix event names, locations, dates
3. Add missing FTL URLs for PP1/PP2 2025-2026 in Tournaments tab
4. Mark unrecoverable tournaments as LOST
5. Validate Coverage matrix — identify remaining gaps

**This cycle can repeat:** user edits → re-export → spot-check SQL → user edits again.

---

## Phase 3: SQL Generation

### T3.1 — Export metadata SQL from spreadsheet

Run `staging_spreadsheet.py export`:
- `supabase/seed.sql` — season + organizer INSERTs
- `supabase/seed_tbl_fencer.sql` — augmented fencer list
- Event + tournament header INSERTs into per-category SQL files

### T3.2 — Generate result SQL from sources

Run `import_results.py` for each tournament in the spreadsheet:
- Excel source → extract results using existing `generate_season_seed.py` logic
- XML source → parse FencingTime XML
- FTL URL → scrape using `python/scrapers/ftl.py`
- Append `fn_calc_tournament_scores()` call per tournament
- Output: `supabase/data/{season}/{cat}.sql` files with results

### T3.3 — Season scoring configs

Generate `season_config.sql` per season:
- **2023-2024:** `int_ppw_total_rounds=8`, `int_ppw_best_count=4` + MPW always
- **2024-2025:** `int_ppw_total_rounds=5`, `int_ppw_best_count=4` (existing)
- **2025-2026:** `int_ppw_total_rounds=5`, `int_ppw_best_count=4` (existing)

### T3.4 — Build CERT upload script

**New file:** `scripts/build_cert_seed.sh`

Concatenates all SQL in correct dependency order with transaction wrapper.

---

## Phase 4: Validation

### T4.1 — Cross-validate rankings against Excel

Compare computed `fn_ranking_ppw` output vs Excel "Ranking/KlasyfikacjaGP" sheets (top-10 per category).

### T4.2 — Data completeness report

Verify: all 30 categories × 3 seasons have data, no NULL fencer refs, participant counts match.

### T4.3 — Unmatched fencer report

List all names that failed fuzzy matching, grouped by domestic (action needed) vs international (expected).

---

## Execution Order

```
T0.1 → T0.2 → T0.3 → T0.4                   (deps + matcher + spreadsheet + importer)
    → T1.1 + T1.2 + T1.3 + T1.4             (extract all sources → populate spreadsheet)
    → T2 USER CURATION CYCLE                  (user reviews, tunes thresholds, adds aliases)
    → T3.1 → T3.2 → T3.3 → T3.4             (export SQL)
    → T4.1 → T4.2 → T4.3                     (validate)
    → repeat T2-T4 as needed (re-populate to re-match with new thresholds)
```

## Critical Files

| File | Action |
|---|---|
| `python/matcher/fuzzy_match.py` | ENHANCE — diacritic folding + token_set_ratio + configurable thresholds |
| `python/tools/staging_spreadsheet.py` | NEW — populate + export ODS staging spreadsheet |
| `python/tools/import_results.py` | NEW — result extraction from all source types |
| `python/tools/parse_fencingtime_xml.py` | NEW — FencingTime XML parser |
| `python/tools/generate_season_seed.py` | RETIRED — replaced by staging_spreadsheet.py + import_results.py |
| `doc/staging_data.ods` | NEW — the staging spreadsheet (user-curated) |
| `supabase/seed_tbl_fencer.sql` | Regenerated from spreadsheet Fencers tab |
| `supabase/data/{2023_24,2024_25,2025_26}/*.sql` | Generated from spreadsheet + result sources |
| `scripts/build_cert_seed.sh` | NEW — CERT upload consolidation |

## Resolved Questions

1. **2023-2024 scoring:** Best 4 of 8 GP rounds + MPW always
2. **2025-2026 PP1-PP3:** Scrape PP1 + PP2 from FTL. PP3 LOST.
3. **VFC sheet:** PEW type (EVF-organized)
4. **Foreign fencers:** Add to master list only if they participate in domestic PPW events
5. **Missing DOB:** Cross-reference first, fall back to lowest age category
6. **Spreadsheet format:** .ods (LibreOffice native, Python macros possible)
7. **Results in spreadsheet:** No — results go directly from sources to SQL; user spot-checks SQL files

## Verification

```bash
# After each export cycle:
supabase db reset
supabase test db
source .venv/bin/activate && python -m pytest python/tests/ -v
cd frontend && npm test

# Spot-check rankings
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
  SELECT * FROM fn_ranking_ppw(
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025'),
    'EPEE', 'M', 'V2'
  ) LIMIT 10;
"
```

## Estimated Scale

- 1 staging spreadsheet (.ods) with ~5 tabs, ~600+ rows total
- ~90 result SQL files (30 per season)
- ~30,000+ SQL lines total
- ~300-500 fencers in augmented master list
- ~3,000+ tournament result rows across all seasons
