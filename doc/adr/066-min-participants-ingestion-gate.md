# ADR-066: Min-participants threshold gates ingestion, not scoring

**Status:** Accepted (drafted 2026-05-10)
**Related:** ADR-018 (Rolling Score), ADR-046 (PEW weapon-letter suffix — naming-shape sibling), ADR-050 (unified ingestion pipeline), ADR-052 (URL→data validation)
**Phase:** 5 (operational rebuild)

## Context

`tbl_scoring_config.int_min_participants_ppw` (default 1) and `int_min_participants_evf` (default 5) have existed since the initial schema, surfaced through `fn_export_scoring_config` / `fn_import_scoring_config` and the admin UI's scoring-config editor. **No code consumed them.** They were declared-but-dead knobs.

The dead-knob status hit reality during Phase 5 active-season rebuild on 2026-05-10:

- FTL eventSchedule for `PPW2-2025-2026` listed 7 FOIL brackets, 6 of which had `1 competitor` (a single registrant, no actual fencing).
- FTL's `/events/results/data/<UUID>` JSON returns `place: null` for those brackets — no rounds were played, no ranking computed.
- `python/scrapers/ftl.py:parse_ftl_json` dropped every entry with unparseable place. Result: `n_results = 0` per bracket.
- The orchestrator's hardcoded `if n_results == 0: skip` then silently dropped the bracket entirely.

Per SPWS rules (operator confirmation 2026-05-10), **the lone competitor in a 1-competitor bracket DOES earn ranklist points** by walkover. Scoring engine (`fn_calc_tournament_scores`) already handles `v_n=1` correctly: place_pts = `int_mp_value` = 50, no DE bonus, gold podium = `3*1^(1/3) = 3` → ~9 final points. The bug was purely at ingestion: brackets never made it to the DB so the scoring engine never saw them.

The user requested the inclusion threshold be **driven by `int_min_participants_ppw`** so that a future config change (e.g. `=2` to exclude 1-competitor brackets) takes effect without code changes. This is the explicit decision to make the dead config knob load-bearing.

## Decision

**Tournaments with `n_competitors < threshold` are skipped at ingestion**, where `threshold` is `tbl_scoring_config.int_min_participants_{ppw,evf}` resolved per the event's `id_season` and per the tournament type. Strict less-than semantics:

| Config value | Behaviour |
|---|---|
| `1` (default) | All brackets included; walkover (single-competitor) brackets count |
| `2` | 1-competitor brackets dropped; ≥2 included |
| `5` (EVF default) | <5-competitor brackets dropped |

Type → column routing:

| Tournament type | Threshold column |
|---|---|
| PPW, MPW, PSW (domestic SPWS) | `int_min_participants_ppw` |
| PEW, MEW, MSW (international classification) | `int_min_participants_evf` |
| IMEW → MEW; DMEW → MPW; IMSW → MSW | (alternation pairs follow their non-prefixed sibling) |

Skipped brackets generate **NO** `tbl_tournament` row, **NO** `tbl_result` row, **NO** scoring side-effect. They appear in the per-event staging summary's *"Skipped — below min-participants threshold"* section with bracket name, weapon, gender, V-cat, n, threshold (in the reason string), and source URL — so the operator can verify the threshold is set correctly before sign-off.

### Walkover semantics in the FTL parser

A prerequisite for `threshold=1` to do the right thing: the FTL parser must actually emit a result row for a 1-competitor bracket. The FTL JSON `place: null` shape is interpreted as **walkover (place=1)** when (and only when) there is exactly one non-`excluded` entry. Multi-entry-with-all-null-places stays as today (truly unranked data, drop them). This rule lives in `parse_ftl_json` and `parse_ftl_with_marker` (`python/scrapers/ftl.py`).

### Implementation surface

1. **`python/scrapers/ftl.py`** — walkover patch in both `parse_ftl_json` and `parse_ftl_with_marker`.
2. **`python/pipeline/db_connector.py`** — three new functions:
   - `get_min_participants(db, id_season, tourn_type) -> int` — reads the column, defaults to 1 on missing config / unknown type.
   - `derive_tourn_type_from_event_code(event_code) -> str | None` — maps event txt_code prefix to a tournament-type token.
   - `gate_below_min_participants(db, id_season, tourn_type, n_results) -> (bool, str | None)` — returns `(True, "BELOW_MIN_PARTICIPANTS (n=X, min=Y)")` when below threshold, else `(False, None)`.
3. **`python/tools/recreate_active_season_2025_2026.py`** + **`python/tools/phase5_runner.py`** — replace the hardcoded `if n_results == 0:` skip with `gate_below_min_participants(...)`. Both runners reuse the same helper.
4. **`python/tools/phase5_runner.py:_multi_summary_md`** — adds the *"Skipped — below min-participants threshold"* section to the per-event .md output when at least one bracket was dropped by the gate.

## Alternatives considered

- **Apply the threshold at scoring time** (filter inside `fn_calc_tournament_scores`): Below-threshold tournaments would still get `tbl_tournament` + `tbl_result` rows. Rejected — drilldown views would show "zero-score" tournaments, polluting the UI, and the audit trail would suggest the tournament happened when it deliberately doesn't count.
- **Threshold per tournament type column** (`int_min_participants_pew`, `_mew`, etc.): finer-grained but five times the schema surface and matching frontend churn. The current 2-column shape (domestic + international) covers all 6 active types with the same routing rule as the multiplier columns.
- **Drop walkover semantics, require explicit place=1**: would dispatch to operator each time FTL emits a null-place bracket, defeating bulk ingestion. The walkover rule is unambiguous (n=1 ⇒ place=1) and the gate then decides whether to count it.
- **Hardcode `< 1` (drop only n=0 brackets)**: would solve today's bug but lock in the current "include everything" policy. Future seasons could not raise the threshold without code edits.

## Consequences

### Backwards-compatible

- Existing seasons all have `int_min_participants_ppw = 1` and `int_min_participants_evf = 5`. The gate's first activation drops nothing that wasn't already being dropped (FTL parser walkover patch is what restores the 1-competitor brackets — gate just keeps the door open).
- Existing scoring is untouched: `fn_calc_tournament_scores` already computes correctly for `v_n=1`.

### Operationally visible

- Per-event staging summaries gain a new section when brackets are skipped. Operator now sees `(bracket name, weapon, gender, V-cat, n, threshold, URL)` for every drop.
- Cron / daily orchestrator runs use the same gate.

### Schema unchanged

- No DDL change. Columns and view exposure already existed since `20250301000001_enums_tables_indexes.sql`.

### Re-ingestion required for active-season PPW2

- The active-season PPW2-2025-2026 had 6 FOIL + 2 SABRE single-competitor brackets dropped pre-ADR-066. After the walkover patch + gate, re-running the orchestrator restores them. This is operational, not destructive — the orchestrator is idempotent against the cleared draft tables.

## Tests

### pytest

- `test_ftl_walkover.py` (5.M3.1–5.M3.7): walkover semantics in both `parse_ftl_json` and `parse_ftl_with_marker`.
- `test_min_participants_helper.py` (5.M4.1–5.M6.7): helpers + gate + event-code type derivation.
- `test_min_participants_summary.py` (5.M7.1–5.M7.3): staging-summary section rendering.

### pgTAP

- `42_min_participants_threshold.sql` (5.M8.1–5.M8.4): schema invariants + JSONB round-trip via `fn_export_scoring_config`.

## Originating ADR / Rule

- Rule: `doc/rules/R013.md` — min-participant ingestion gate.
