# ADR-052: URL→data validation enforcement at Stage 7

**Status:** Accepted
**Date:** 2026-05-02
**Relates to:** ADR-029 (tournament URL auto-population — amended), ADR-046 (PEW weapon-letter suffix — interacts with weapon-mismatch handling), ADR-049 (joint-pool split flag — combined-pool detection), ADR-050 (unified ingestion pipeline — Stage 7 belongs to the 11-stage flow), ADR-053 (EVF parity gate — Stage 7 runs at commit; parity at post-commit)

## Context

Admin-managed URLs (`tbl_event.url_results` and `tbl_tournament.url_results`) are hand-entered for vendor systems (Fencingtimelive, Engarde, Ophardt, etc.). When the operator pastes a wrong URL — or pastes the right URL into the wrong event row — the ingestion pipeline silently associates wrong results with the event. Memory rule [feedback_validate_url_writes.md](/Users/aleks/.claude/projects/-Users-aleks-coding-SPWSranklist/memory/feedback_validate_url_writes.md) documents that this has caused real data corruption.

The agreed remediation: scrape the URL, compare metadata to the event row, REJECT on mismatch. Stage 7 of the unified pipeline is where this comparison runs.

Open architectural questions answered by this ADR:

- Which fields are validated.
- The halt-vs-warn boundary per field.
- How to handle vendors with sparse metadata (some sources expose only date + weapon).
- How to handle combined-pool sources (one URL legitimately covers V1+V2+V3+V4).
- How the cert_ref backup-source path (`[5]` in review CLI) fits.
- How the EVF API source path (`[4]`) is validated (Stage 7 vs ADR-053's parity gate).
- How PEW events' weapon-letter suffix evolution (ADR-046) interacts with weapon-mismatch.

## Decision

### Strategy — opportunistic validation

Each scraper extracts as much metadata as it can from a given URL. Stage 7 walks the field list, **comparing only fields the scraper actually returned**. Missing fields are skipped — not failures. As scrapers improve (or vendors expose more metadata), validation tightens automatically without an ADR change.

### Field list and per-field behavior

Seven fields total. Six halt, one warns.

| Field | Behavior | Notes |
|---|---|---|
| Date | Halt | ±1 day tolerance for vendors reporting end-date of multi-day events |
| Weapon | **Halt for non-PEW; flag-for-rename for PEW** | See ADR-046 interaction below |
| Gender | Halt | Exact match; mixed-gender event halts unless override forces |
| Age category | Halt; skipped when source is combined-pool | Combined-pool flag from `bool_joint_pool_split` (ADR-049) |
| Country | Halt | Normalize to ISO-3 before compare |
| City | Halt | Normalize via alias YAML (case-fold, ASCII-fold, alias map); operator can extend YAML |
| Name | Warn only | Vendor naming too inconsistent for halt; finding lands in diff |

### Source path × Stage 7 behavior matrix

| Source path | Stage 7 behavior |
|---|---|
| `[1]` Recorded URL | Full six-field validation; halt on mismatch |
| `[2]` Paste URL | Full six-field validation; halt on mismatch |
| `[3]` Paste XML path | Full six-field validation; halt on mismatch |
| `[4]` EVF API | Full six-field validation; halt on mismatch (complementary to parity gate at post-commit) |
| `[5]` cert_ref placements | Stage 7 **skipped entirely** — no URL to validate; cert_ref is internal trusted data |

### PEW weapon-letter exception (ADR-046 interaction)

PEW events evolve their `txt_code` to reflect ingested weapon coverage (e.g., `PEW3fs` → `PEW3efs` when épée gets added later). A weapon "mismatch" between URL and event row for PEW codes is therefore not necessarily an error — it can be a legitimate addition.

Stage 7 logic for weapon validation:
- If `tbl_event.txt_code` does not start with `PEW` → halt on weapon mismatch.
- If `tbl_event.txt_code` starts with `PEW` and the URL's weapon is not in the current letter suffix → **do not halt**. Instead, flag the event with a "PEW cascade pending" annotation. Stage 8b (added by ADR-050 amendment) reads this flag at commit and runs `fn_pew_weapon_letters` cascade-rename.

### Combined-pool category handling (ADR-049 interaction)

When a URL legitimately covers multiple age categories in one combined-pool result page, the URL's metadata cannot be expected to match the event row's single age category. Stage 7 detects combined-pool from the source's reported metadata (or the operator's `bool_joint_pool_split` flag on the event row) and skips the age-category compare.

The splitter at Stage 4 then handles per-category separation; each split bucket maps to its own event row downstream.

### City alias normalization

New artifact: `python/pipeline/city_aliases.yaml`. Maintained as a flat YAML file in version control. Format:

```yaml
Warszawa: [Warsaw, Warschau, Varsovie, Varšava]
Kraków: [Krakow, Cracow, Krakau]
Wrocław: [Wroclaw, Breslau]
Poznań: [Poznan, Posen]
München: [Munich, Munchen, Monachium]
```

Comparison process:
1. Case-fold both sides.
2. ASCII-fold (strip diacritics).
3. Apply alias map: any alias → canonical.
4. Strict equal.

Mismatch after normalization → halt. Operator escape hatch: add the new alias to the YAML (1-line PR) or use the override YAML's city field for one-off events.

### Override YAML escape hatch

The Phase 3 override YAML schema (`doc/overrides/<event_code>.yaml`) gains city as a forced-override surface alongside identity/splitter/URL/match-method/joint-pool. Total 6 surfaces.

```yaml
url_overrides:
  city: Wrocław   # force-skip Stage 7 city check
  date: 2026-03-29   # force date if scraper misreports
  ...
```

### Halt diagnostic output

When Stage 7 halts, the operator must see exactly which field mismatched and what both sides saw. Halt produces:

- Telegram notification: `🚨 {event_code} ingestion halted - field mismatch: {field}` with both values.
- `doc/staging/<event_code>.diff.md` is written with a Stage 7 section showing the comparison.
- Pipeline does not proceed to Stage 8; nothing written to draft tables.

## Alternatives considered

### Alt 1 — Strict 4-field validation (date + weapon + gender + age category, no city/country)

Rejected. User experience with paste-wrong-URL errors includes cases where the wrong URL has the same date/weapon/gender/category but a different city/country (e.g., two events on the same weekend in different cities). Without city/country halt, those slip through.

### Alt 2 — Halt on name mismatch with fuzzy comparison

Rejected. Vendor naming is too inconsistent — "European Championships Veterans 2026", "EVF Vets EC 2026", "EC Vet 2026 Foil M V2" all describe the same event. Fuzzy matching would either be too strict (constant false-halts) or too loose (catches nothing). Warn-only via diff is sufficient signal for the operator.

### Alt 3 — City as warn-only (defer halt until alias table mature)

Rejected. User explicitly chose halt for city, accepting the alias-table maintenance burden as a Phase 4 deliverable. Without halt, "Budapest" vs "Kraków" mismatches would silently pass — the exact error class halt is meant to catch.

### Alt 4 — Halt only on fields the source claims to be authoritative for

Rejected as too complex. Different vendors have different authoritativeness on different fields. Opportunistic validation (compare what's available) sidesteps the question — every field the vendor reports is treated as if the vendor stands behind it.

### Alt 5 — DB-level required-fields constraint (force vendors to expose all 6 fields)

Rejected. We don't control vendors. Some vendors only expose date + weapon; that's reality. Treating their sparse output as a halt would block legitimate ingestion. Opportunistic validation is the only realistic path.

## Consequences

### New artifacts

- `python/pipeline/url_validation.py` — Stage 7 implementation. Single function `validate_metadata(event_row, scraped_metadata) -> ValidationResult` used by all source paths except cert_ref.
- `python/pipeline/city_aliases.yaml` — alias map seeded with PL/EU veteran-fencing locales.
- `python/pipeline/country_iso.yaml` (or hardcoded dict) — country-code ISO-3 normalization (POL ↔ PL ↔ Poland → POL).

### Existing code touched

- `python/pipeline/stages.py` — Stage 7 logic dispatches to `url_validation.validate_metadata`. Cert_ref path bypasses.
- `python/pipeline/overrides.py` — accepts `url_overrides.city` as a 6th surface.
- `python/pipeline/notifications.py` — Stage 7 halt template added.

### Test coverage

- pgTAP — n/a (logic is Python; DB invariants are unrelated).
- pytest — `url_validation` per-field tests (halt, warn, skip on missing, alias normalize, ISO normalize, PEW exception, combined-pool skip).
- vitest — n/a (UI doesn't call Stage 7 directly).

### Schema changes

None. All validation is in Python; no new columns or constraints.

### Operator workflow

When Stage 7 halts:
1. Operator reads Telegram notification + `doc/staging/<event_code>.diff.md`.
2. Decides: fix the URL (if pasted wrong), fix the event row (if metadata is wrong), extend `city_aliases.yaml` (if a new alias is needed), or use override YAML (one-off forced override).
3. Re-runs the pipeline.

## Out of scope

- **Fuzzy tournament-name matching as a halt.** Warn-only is the locked decision; fuzzy halt is too noisy.
- **Validating internal consistency of vendor data.** Stage 7 validates URL metadata vs event row only. Inconsistencies *within* the vendor data (e.g., contradictory placement claims) are caught at later stages or by parity gate.
- **Org-level validation.** `txt_organizer` is not validated against URL — most vendors don't expose organizer reliably. Organizer is set on event-row creation and trusted thereafter.
- **Year-of-license or other fencer-level metadata.** Stage 7 is event-level only. Fencer-level metadata is verified at Stage 6 (identity resolution).
- **Automatic alias-YAML extension on first halt.** Operator must manually add new city aliases. Auto-extension would risk false positives masking real errors.
