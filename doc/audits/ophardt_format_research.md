# Ophardt format research — Phase 1 spike (2026-05-01)

Spike to decide whether Ophardt (`fencingworldwide.com`, the public results face of Ophardt Team Sportevent) belongs in Phase 1 of the rebuild ([doc/plans/rebuild/p1-ir-parsers.md](../plans/rebuild/p1-ir-parsers.md)) or defers to Phase 1.5.

## TL;DR — Verdict

**In-scope for Phase 1.** Ophardt is server-rendered HTML over jQuery + Bootstrap. Every datum the IR contract needs (event metadata, tournament breakdown, ranked results, stable athlete ID, country) is present in the initial payload of normal `requests.get(...)` calls. No SPA hydration, no JS-only data, no Playwright dependency.

The only field the IR cares about that Ophardt does **not** expose is `birth_year` — but Ophardt's globally stable athlete ID (`/athlete/{id}/`) is a stronger identity-resolution anchor than birth year would be, so this is a non-issue.

## Sample probe (used for this spike)

Event-level URL (provided by user):

```
https://www.fencingworldwide.com/en/30657-2024/tournament/
```

Resolves to: *EVF Circuit Memoriam Max Geuter*, München (GER), 07–08.12.2024 — 16 individual veteran tournaments across Foil/Sabre × M/W × O40/O50/O60/O70.

## URL anatomy

| Level | Pattern | Example | What's there |
|---|---|---|---|
| Event | `/{lang}/{eventId}-{year}/tournament/` | `/en/30657-2024/tournament/` | Event title, host city/country, date span, list of sub-tournaments grouped by age cat × weapon |
| Tournament root | `/{lang}/{tournamentId}-{year}/global/` | `/en/903540-2024/global/` | Breadcrumb (weapon, gender, V-cat, individual/team), sub-page nav |
| Tournament results | `/{lang}/{tournamentId}-{year}/results/` | `/en/903540-2024/results/` | Final ranked table — **the primary scrape target** |
| Tournament participants | `/{lang}/{tournamentId}-{year}/participants/` | `/en/903540-2024/participants/` | Starter list with FIE/EVF rating |
| Tournament pools | `/{lang}/{tournamentId}-{year}/pools/{round}` | `/en/903540-2024/pools/1` | Preliminaries (not needed for IR) |
| Tournament DE | `/{lang}/{tournamentId}-{year}/direct/{round}` | `/en/903540-2024/direct/2` | Direct elimination tableau (not needed for IR) |
| Athlete profile | `/athlete/{athleteId}/` | `/athlete/2137/` | Profile page; **stable global ID** for identity resolution |

`{lang}` is `en`/`de`/`fr`. Affects nav and a few labels but not the breadcrumb domain terms (see Locale handling).

## Server-rendered evidence

| Probe | Status | Size | Initial payload contains |
|---|---|---|---|
| `/en/30657-2024/tournament/` | 200 | 21 KB | Full event title, all sub-tournaments listed, dates, host country |
| `/en/903540-2024/global/` | 200 | 18 KB | Full breadcrumb (Florett / Herren / V50 / Einzel / München (GER) / December 8, 2024) |
| `/en/903540-2024/results/` | 200 | 25 KB | Complete `<table class="...startlist">` with all rankings, ties, country flags, athlete IDs |
| `/en/903540-2024/participants/` | 200 | (similar) | Complete starter list with country, athlete ID, rating |
| `/athlete/2137/` | 200 | 200 KB | Full bio page; **no birth year, no DOB** in any common keyword |

Stack indicators in `<head>`: `bootstrap-5.3.0`, jQuery 3.6.4. No React/Vue/Angular hydration markers. No `data-react-root`, no `<noscript>` warnings, no empty container shells.

## Sample results-table HTML

```html
<table class="table table-striped table-full table-hover startlist">
  <thead>
    <tr><th>&#160;</th><th>Nation</th><th>Name</th><th>&#160;</th></tr>
  </thead>
  <tbody>
    <tr>
      <td>1.</td>
      <td class="nation"><img class="flag-small" src="/img/flags/ita.svg"/> ITA</td>
      <td class="name">
        <a href="/en/903540-2024/participant/1780"><i class="fa fa-eye"></i></a>
        <a href="/athlete/1780/" target="_blank">PESCE Filippo</a>
      </td>
      <td width="100"></td>
    </tr>
    <tr>
      <td>T3.</td>
      <td class="nation"><img class="flag-small" src="/img/flags/isr.svg"/> ISR</td>
      <td class="name">
        <a href="/en/903540-2024/participant/464693"><i class="fa fa-eye"></i></a>
        <a href="/athlete/464693/" target="_blank">HAYAT Konstantin</a>
      </td>
      <td width="100"></td>
    </tr>
  </tbody>
</table>
```

Tie marker is `T3.` (T-prefix). Place is `<td>{n}.</td>`, strip the trailing dot. Country is the trailing 3-letter ISO code in `td.nation` (also encoded in the flag image filename — secondary signal). Athlete name is the link text inside the second `<a>` of `td.name`. Stable ID is the integer in `/athlete/{id}/`.

## IR field mapping

For `ParsedTournament`:

| IR field | Source | Notes |
|---|---|---|
| `parsed_date` | Tournament breadcrumb (e.g. "December 8, 2024") **or** event card (`07.12. - 08.12.`) — prefer breadcrumb (per-tournament, not per-event) | English-locale long-form; parse with `%B %d, %Y` |
| `weapon` | Breadcrumb position 3 (Florett/Florett/Sabre/Säbel/Degen/Épée) | German labels even on `/en/` — locale-mixed |
| `gender` | Breadcrumb position 4 (Herren/Damen) | German labels even on `/en/` |
| `category_hint` | Breadcrumb position 5 (V40/V50/V60/V70) **or** parent event listing (`Foil Men's O50`) | Use the URL-derived hint (matches Ophardt's `O{n}` ↔ SPWS `V{n−30/10}` mapping: O30→V0, O40→V1, O50→V2, O60→V3, O70→V4) |
| `organizer_hint` | Constant `"FIE"` for Ophardt parser | Veterans events under FIE umbrella; downstream may reclassify based on title (e.g. EVF Circuit) |
| `source_kind` | New enum value `SourceKind.OPHARDT_HTML` | Add to `python/pipeline/ir.py` |
| `source_url` | Tournament results URL (`.../results/`) | What admin pasted |
| `source_artifact_path` | None | No file artifact; live HTML |
| `raw_pool_size` | `len(<tbody><tr>)` of results table | Or read from participants page (more authoritative) |

For `ParsedResult`:

| IR field | Source | Notes |
|---|---|---|
| `fencer_name` | `<a href="/athlete/{id}/">…</a>` link text | Format `SURNAME Given` (uppercase surname pattern) — same as Engarde, splitter logic reusable |
| `fencer_country` | `<td class="nation">` trailing 3-letter ISO | Cross-check against flag SVG filename for robustness |
| `birth_year` | **None** — not exposed | See Identity-resolution section below |
| `birth_date` | **None** — not exposed | |
| `place` | `<td>{n}.</td>` (strip trailing dot, strip leading `T` for ties) | Ties keep equal place number per FIE convention |
| `raw_age_marker` | None at result level | Tournament-level `category_hint` is authoritative |
| `source_vcat_hint` | Mirrors `category_hint` | |
| `bool_excluded` | Always `False` | Ophardt has no excluded-flag concept |
| `source_row_id` | Ophardt athlete ID (e.g. `"ophardt:1780"`) | Globally stable across tournaments |

## Locale handling — implications for R012

Even when the URL prefix is `/en/`, the breadcrumb renders weapon/gender/category in German (Florett, Herren, V50, Einzel). This is the same locale-mixed behavior that R012 already covers for Engarde HU. Two consequences:

1. The Ophardt parser must use a locale-agnostic dictionary (DE/EN/FR weapon and gender labels). Reuse the Engarde lookup tables.
2. Don't trust `lang=` URL prefix as a normalization promise. Always parse the actual rendered tokens.

A safer alternative for some fields: scrape the **German** URL (`/de/...`) deliberately so the locale is explicit, since the German labels are the canonical ones in the markup anyway. Decision deferred — both approaches work; pick during parser implementation.

## Identity-resolution implications

Ophardt does not expose birth year or DOB on the public results, participant, or athlete pages. For SPWS this would normally be a problem (V-cat scoring needs DOB validation), but two facts collapse the risk:

1. **Tournament-level `category_hint` is authoritative.** SPWS V-cat is assigned per tournament from the URL/breadcrumb, not per fencer from DOB.
2. **Stable Ophardt athlete ID** (`/athlete/{id}/`) is a *stronger* identity signal than birth year would be. A repeated ID across tournaments is a 100% match — no fuzzy matching needed. The first time an Ophardt ID is seen, the matcher falls back to (name, country) fuzzy + manual review; once confirmed, the ID becomes a stable foreign key (R005-style ref-table candidate).

Recommended (Phase 1): IR carries `source_row_id="ophardt:{athleteId}"`. Phase 2/3 admin review treats first-seen Ophardt IDs as low-confidence (require human confirm). Phase 6+ promotes confirmed mappings to `tbl_fencer.txt_external_id_ophardt` (or a side table) so subsequent runs auto-link.

## Edge cases caught during the spike

- **Ties:** `T3.` prefix means tied rank. Two T3 rows mean both got bronze; the next row is `5.` (no `4.`).
- **Multi-day events:** Sub-tournaments under one event can span multiple dates (this Munich event spans 07–08.12). Do not infer tournament date from event range — use tournament breadcrumb date.
- **Team events:** Out of MVP scope, but note: dropdown items use `fa-person-simple` icon for individual; team events would use a different icon. Filter on this if a team event ever sneaks in.
- **`O30` not seen in this event** but the SPWS↔Ophardt mapping table reserves the slot for V0 fencers (30+). Verify on a second event before locking the parser if any V0 sample exists.

## Recommendation for the master plan

| Option | Effort | Recommendation |
|---|---|---|
| **A. In-scope for Phase 1** — write `python/scrapers/ophardt.py` alongside the 7 parser refactors, total 8 parsers in Phase 1 | +0.5 day on top of Phase 1 (HTML structure is simpler than EVF JSON or FTL XML) | **Recommended.** Low marginal cost; same IR contract; no new heavy dep. |
| B. Defer to Phase 1.5 | Same effort, just later | Only sensible if Phase 1 is already feeling overloaded. |
| C. Out of scope (MVP) | 0 | Reject — Ophardt covers EVF Circuit + several FIE Veterans events SPWS scores. |

Plan-table impact if option A is taken: Phase 1 deliverables grow by one file (`python/scrapers/ophardt.py`), one fixture set (`python/tests/fixtures/ophardt/`), and one contract test row. Master plan summary stays accurate ("conform all parsers to IR"). Phase 1.5 placeholder can be deleted.

## Open questions for the user

1. **Promote to Option A** (Ophardt enters Phase 1) or hold at Option B (Phase 1.5)?
2. **Locale strategy:** prefer `/en/` URLs (current data has German breadcrumbs anyway) or `/de/` URLs (canonical labels) for the parser's input? — defer until parser implementation.
3. **Athlete-ID promotion**: Phase 1 carries `source_row_id`. Add `tbl_fencer.txt_external_id_ophardt` column in Phase 2 schema, or wait until Phase 6 when ref-table patterns harden? — defer; not blocking Phase 1.
