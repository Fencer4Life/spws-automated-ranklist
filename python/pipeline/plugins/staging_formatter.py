"""StagingFormatter — the terminal shaper of the staging report (ADR-075).

Option B: every plugin serializes its own fragment to the `report` channel as it
runs; this ONE plugin shapes the accumulated fragments into the per-event files:

  - `doc/staging/<EVENT>.<ts>.md`       — the **automation report** (G9 framing):
    the gaps the fully-automated pipeline detected that may need admin intervention
    (the pipeline already committed — ADR-074, no sign-off, no gate).
  - `doc/staging/<EVENT>.<ts>.diff.md`  — the 3-way diff (Source/CERT/New LOCAL).

Richness parity with the OLD pipeline's `.md` is reached by (a) **reusing the OLD
pure DB-reader helpers** (`_fetch_event_meta`, `_live_tournament_rows`,
`_check_pool_round_count`, `_classify_alias_pair`) for live/reference data, and
(b) iterating **per bracket** (each `report` in `_bracket_reports` is one bracket)
so bracket context attaches to matches/faults/counts. The legacy pctx is NOT used.

It is the ONLY plugin that touches the filesystem, runs at EVENT scope only (the
CLI seeds `_bracket_reports`), and is informational/post-commit.
"""
from __future__ import annotations

from datetime import datetime, timezone
from types import SimpleNamespace

from python.pipeline.core.contract import Context, PluginKind, Services
from python.pipeline.plugins.base import BasePlugin

# Reused OLD pure helpers (DB-read / pure — no pctx). Imported at call sites in
# tests via this module's namespace, so they are referenced as module globals.
from python.tools.phase5_runner import (  # noqa: E402
    _check_pool_round_count,
    _classify_alias_pair,
    _fetch_event_meta,
    _live_tournament_rows,
)


class Section:
    SOURCE = "SOURCE"
    EVENT = "EVENT"
    IDENTITY = "IDENTITY"
    STRUCTURE = "STRUCTURE"
    VALIDATION = "VALIDATION"
    COMMIT = "COMMIT"
    REACTION = "REACTION"


ADMIN_URL = "http://localhost:5173/?admin=1"


def _utc_stamp() -> str:
    """Sortable, colon-free UTC stamp: YYYYMMDD-HHMMSSZ (lexical == chronological)."""
    return datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%SZ")


def _norm(s) -> str:
    return (s or "").strip().casefold()


# ---------------------------------------------------------------------------
# Per-bracket model — each report in `_bracket_reports` is ONE bracket.
# ---------------------------------------------------------------------------

def _bracket_model(report) -> dict:
    src, ident = {}, {}
    pool_round, count = None, None
    committed = None
    for f in report:
        p = f.payload
        if f.section == Section.SOURCE:
            src = p
        elif f.section == Section.IDENTITY:
            ident = p
        elif f.section == Section.COMMIT:
            committed = p
        elif f.section == Section.VALIDATION:
            if p.get("check") == "pool_round" and p.get("is_pool_round"):
                pool_round = p
            elif p.get("check") == "count":
                count = p
    weapon = src.get("weapon") or "?"
    gender = src.get("gender") or "?"
    category = src.get("category_hint") or "COMB"
    return {
        "label": f"{weapon}/{gender}/{category}",
        "weapon": weapon, "gender": gender, "category": category,
        "matches": ident.get("matches", []),
        "created": ident.get("created", []),
        "reconciled": ident.get("reconciled", []),
        "conflicts": ident.get("conflicts", []),
        "alias_writebacks": ident.get("alias_writebacks", []),
        "committed": committed, "pool_round": pool_round, "count": count,
    }


# ---------------------------------------------------------------------------
# Section renderers — each takes the assembled model and returns markdown.
# ---------------------------------------------------------------------------

def _render_header(m) -> str:
    full = (m["event_meta"] or {}).get("_full_row") or {}
    lines = ["| Field | Value |", "|---|---|"]
    for k in sorted(full.keys()):
        v = full[k]
        if v is None or v == "" or v == []:
            continue
        lines.append(f"| `{k}` | {v} |")
    urls = (m["event_meta"] or {}).get("urls") or []
    if urls:
        lines += ["", f"**Source URL slots ({len(urls)}):**", ""]
        for slot, url in urls:
            lines.append(f"- slot {slot}: {url}")
    return "\n".join(lines) if len(lines) > 2 else "_No event metadata._"


def _render_automation_gaps(m) -> str:
    """G8 — the centerpiece: everything that may need admin intervention."""
    gaps: list[str] = []
    pr = m["pool_rounds"]
    if pr:
        gaps.append(f"- **{len(pr)} bracket(s) omitted as pool-rounds** — see *Brackets present "
                    f"but omitted*: {', '.join(b.get('name') or b['weapon'] for b in pr)}")
    if m["schedule_skips"]:
        gaps.append(f"- **{len(m['schedule_skips'])} schedule-level skip(s)** "
                    f"(present on the event page, never ingested).")
    dups = [c for c in m["created"] if c.get("near_miss") and (c["near_miss"].get("name"))]
    if dups:
        gaps.append(f"- **{len(dups)} newly-created fencer(s) have a close existing match** "
                    f"(possible duplicate / missed link — see *New fencers created*).")
    if m["null_by"]:
        gaps.append(f"- **{len(m['null_by'])} fencer(s) with NULL birth year** — V-cat undefined "
                    f"(see *Fencer matching*).")
    if m["estimated_by"]:
        gaps.append(f"- **{len(m['estimated_by'])} fencer(s) with an estimated birth year** "
                    f"— V-cat may be wrong.")
    bad_aliases = [v for v in m["alias_verdicts"] if v["verdict"] == "❌"]
    if bad_aliases:
        gaps.append(f"- **{len(bad_aliases)} suspected wrong alias link(s)** "
                    f"(different person? — see *Fencer matching → alias verdicts*).")
    below = [b for b in m["brackets"] if (b.get("count") or {}).get("below_min")]
    if below:
        gaps.append(f"- **{len(below)} bracket(s) below the minimum participant count** (dropped).")
    mism = [b for b in m["brackets"] if (b.get("count") or {}).get("count_mismatch")]
    if mism:
        gaps.append(f"- **{len(mism)} bracket(s) with a URL↔data count mismatch** (accepted, flag).")
    if not gaps:
        return "_No automation gaps detected — nothing needs admin attention._"
    return ("These items the automation could not fully resolve. The event is **already committed**; "
            "fix any that matter in the admin UI and recompute self-heals.\n\n" + "\n".join(gaps))


def _render_created(m) -> str:
    created = m["created"]
    if not created:
        return "_No new fencers created._"
    lines = ["| Name | Nat | V-cat | calc BY | flag | source | closest existing (why not linked) |",
             "|---|---|---|---|---|---|---|"]
    for c in created:
        by = c.get("birth_year")
        flag = "🔴 missing" if by is None else ("🟡 estimated" if c.get("estimated") else "confirmed")
        nm = c.get("near_miss") or {}
        near = (f"{nm.get('name')} (#{nm.get('id_fencer')}, conf {nm.get('confidence')})"
                if nm.get("name") else "_(no close match)_")
        lines.append(f"| {c.get('scraped_name', '?')} | {c.get('nationality', '?')} "
                     f"| {c.get('vcat') or '—'} | {by if by is not None else '—'} | {flag} "
                     f"| FTL | {near} |")
    return "\n".join(lines)


def _render_reconciled(m) -> str:
    rec = m["reconciled"]
    if not rec and not m["conflicts"]:
        return "_No birth-year reconciliations._"
    lines: list[str] = []
    if rec:
        lines += ["| Fencer | BY | BY status | status reason |", "|---|---:|---|---|"]
        for r in rec:
            reason = (f"conflicted with V-cat {r.get('vcat')} (old BY {r.get('old_birth_year')}) "
                      f"→ reconciled to band midpoint")
            if r.get("was_confirmed"):
                reason += "; ⚠ was CONFIRMED → downgraded to estimated"
            lines.append(f"| {r.get('scraped_name', '?')} (#{r.get('id_fencer')}) "
                         f"| {r.get('new_birth_year')} | estimated | {reason} |")
    for c in m["conflicts"]:
        lines.append(f"- ⚠ conflict: {c.get('scraped_name')} (#{c.get('id_fencer')}) "
                     f"{c.get('first_vcat')} vs {c.get('second_vcat')}")
    return "\n".join(lines)


def _render_matching(m) -> str:
    matches = m["matches_flat"]  # list of (match_dict, bracket_label)
    if not matches:
        return "_No matches._"
    by_id = m["fencer_by_id"]

    # By method
    by_method: dict[str, int] = {}
    for mm, _ in matches:
        by_method[mm.get("method", "?")] = by_method.get(mm.get("method", "?"), 0) + 1
    total = sum(1 for mm, _ in matches if mm.get("id_fencer") is not None)
    lines = [f"- **Total matches with id_fencer:** {total}", "", "### By method", "",
             "| Method | Count |", "|---|---:|"]
    for k in sorted(by_method):
        lines.append(f"| `{k}` | {by_method[k]} |")

    # Name resolution paths
    alias_new = len(m["alias_writebacks"])
    alias_existing = 0
    for mm, _ in matches:
        f = by_id.get(mm.get("id_fencer"))
        if not f:
            continue
        aliases = [_norm(a) for a in (f.get("json_name_aliases") or [])]
        if _norm(mm.get("scraped_name")) in aliases:
            alias_existing += 1
    canonical = max(total - alias_new - alias_existing, 0)
    lines += ["", "### Name resolution", "", "| Path | Count |", "|---|---:|",
              f"| ✅ matched via canonical name | {canonical} |",
              f"| 🔗 matched via existing alias | {alias_existing} |",
              f"| 🆕 new alias would be added | {alias_new} |"]

    # Alias verdicts
    if m["alias_verdicts"]:
        lines += ["", "**Alias verdicts:**", "",
                  "| Verdict | Scraped | Resolved canonical | Reason |", "|---|---|---|---|"]
        for v in m["alias_verdicts"]:
            lines.append(f"| {v['verdict']} | `{v['scraped']}` | {v['canonical']} | {v['reason']} |")

    # Birth-year quality
    confirmed = est = missing = 0
    for mm, _ in matches:
        if mm.get("id_fencer") is None:
            continue
        f = by_id.get(mm.get("id_fencer")) or {}
        if f.get("int_birth_year") is None and mm.get("governed_birth_year") is None:
            missing += 1
        elif f.get("bool_birth_year_estimated"):
            est += 1
        else:
            confirmed += 1
    lines += ["", "### Birth-year quality", "", "| Path | Count |", "|---|---:|",
              f"| ✅ known + confirmed | {confirmed} |",
              f"| 🟡 estimated | {est} |",
              f"| 🚨 MISSING (NULL) — V-cat undefined | {missing} |"]

    if m["null_by"]:
        lines += ["", "**🚨 Fencers with NULL birth year:**", "",
                  "| Fencer | id_fencer | Bracket | Place |", "|---|---:|---|---:|"]
        for r in m["null_by"]:
            lines.append(f"| {r['name']} | {r['id_fencer']} | {r['bracket']} | {r['place']} |")
    if m["estimated_by"]:
        lines += ["", "**🟡 Fencers with estimated birth year:**", "",
                  "| Fencer | Estimated BY | Bracket | Place |", "|---|---:|---|---:|"]
        for r in m["estimated_by"]:
            lines.append(f"| {r['name']} | {r['by']} | {r['bracket']} | {r['place']} |")
    return "\n".join(lines)


def _render_committed(m) -> str:
    rows = m["live_rows"]
    if not rows:
        return "_No committed tournaments found._"
    total_results = sum(r.get("int_participant_count") or 0 for r in rows)
    lines = [f"**{len(rows)} tournaments, {total_results} results.**", "",
             "| Code | V-cat | Wpn | Gen | Date | Joint | Results | Source URL |",
             "|---|---|---|---|---|---|---:|---|"]
    for r in rows:
        joint = "✓" if r.get("bool_joint_pool_split") else ""
        url = r.get("url_results") or r.get("txt_source_url_used") or ""
        lines.append(f"| `{r.get('txt_code', '?')}` | {r.get('enum_age_category', '?')} "
                     f"| {r.get('enum_weapon', '?')} | {r.get('enum_gender', '?')} "
                     f"| {r.get('dt_tournament', '?')} | {joint} "
                     f"| {r.get('int_participant_count', '?')} | {url} |")
    return "\n".join(lines)


def _render_omitted(m) -> str:
    """G3 — brackets present on the event page but NOT ingested as tournaments."""
    rows = []
    for b in m["pool_rounds"]:
        rows.append((b.get("weapon", "?"), b.get("name") or "?",
                     b.get("reason") or "pool round", b.get("url") or ""))
    for s in m["schedule_skips"]:
        rows.append((s.get("weapon", "?"), s.get("name", "?"),
                     s.get("reason", "skip"), s.get("url", "")))
    if not rows:
        return "_No brackets omitted — every discovered bracket was ingested._"
    lines = ["These brackets were **present but omitted from processing** (not scored as tournaments):",
             "", "| Weapon | Bracket name | Reason | URL |", "|---|---|---|---|"]
    for w, name, reason, url in rows:
        lines.append(f"| {w} | {name} | {reason} | {url} |")
    # Misclassification guard (conditional ⚠ only — no standing table).
    for warn in _check_pool_round_count(m["pool_rounds"]):
        lines += ["", f"> {warn}"]
    return "\n".join(lines)


def _render_parse_status(m) -> str:
    """G7 — tally over the brackets + per-affected skip/exception reasons."""
    clean = skipped = empty = exception = 0
    reasons: list[str] = []
    for b in m["brackets"]:
        committed = b.get("committed")
        pr = b.get("pool_round")
        cnt = b.get("count") or {}
        label = b["label"]
        if pr:
            skipped += 1
            reasons.append(f"- ⊘ {label}: pool round — {pr.get('reason')}")
        elif committed and committed.get("skipped"):
            skipped += 1
            reasons.append(f"- ⊘ {label}: dropped {committed.get('dropped')}")
        elif cnt.get("below_min"):
            skipped += 1
            reasons.append(f"- ⊘ {label}: below minimum participants")
        elif committed and (committed.get("tournaments") or committed.get("persisted")):
            clean += 1
        elif not b["matches"]:
            empty += 1
        else:
            exception += 1
            reasons.append(f"- 🔥 {label}: did not reach Commit (no committed outcome recorded)")
    lines = [f"- ✅ clean (committed): **{clean}**",
             f"- ⊘ skipped / faulted: **{skipped}**",
             f"- ⊝ empty (no fencers): **{empty}**",
             f"- 🔥 exception (no commit): **{exception}**"]
    if reasons:
        lines += ["", "**Reasons:**", *reasons]
    return "\n".join(lines)


def _render_footer(m) -> str:
    return (f"_Automation report (ADR-075). The pipeline has **already committed** — full automation, "
            f"no sign-off. Review the **Detected automation gaps** above; correct any that matter in the "
            f"admin UI ({ADMIN_URL}) and recompute self-heals._")


# The TEMPLATE — ordered (heading, renderer). Gaps summary up top (G8/G9 framing),
# then the detailed sections. No sign-off (G9).
STAGING_TEMPLATE = [
    ("## Event", _render_header),
    ("## Detected automation gaps", _render_automation_gaps),
    ("## New fencers created", _render_created),
    ("## Birth-year reconciliations", _render_reconciled),
    ("## Fencer matching", _render_matching),
    ("## Committed tournaments", _render_committed),
    ("## Brackets present but omitted from processing", _render_omitted),
    ("## Bracket parse status", _render_parse_status),
    ("", _render_footer),
]


def _assemble(event_code, db, bracket_reports, schedule_skips) -> dict:
    brackets = [_bracket_model(r) for r in bracket_reports]

    matches_flat = [(mm, b["label"]) for b in brackets for mm in b["matches"]]
    created = [c for b in brackets for c in b["created"]]
    reconciled = [r for b in brackets for r in b["reconciled"]]
    conflicts = [c for b in brackets for c in b["conflicts"]]
    alias_writebacks = [a for b in brackets for a in b["alias_writebacks"]]
    pool_rounds = [b["pool_round"] for b in brackets if b["pool_round"]]

    fencer_by_id = {}
    try:
        for f in (db.fetch_fencer_db() if db is not None else []) or []:
            fencer_by_id[f["id_fencer"]] = f
    except Exception:
        pass

    # Alias verdicts (reuse the OLD pure classifier).
    alias_verdicts = []
    for a in alias_writebacks:
        verdict, reason = _classify_alias_pair(a.get("scraped") or "", a.get("canonical") or "")
        alias_verdicts.append({"verdict": verdict, "reason": reason,
                               "scraped": a.get("scraped"), "canonical": a.get("canonical")})

    # NULL-BY / estimated-BY — deduped by id_fencer, first bracket+place kept.
    null_by, estimated_by = [], []
    seen_null, seen_est = set(), set()
    for mm, label in matches_flat:
        fid = mm.get("id_fencer")
        if fid is None:
            continue
        f = fencer_by_id.get(fid) or {}
        by = f.get("int_birth_year")
        if by is None and mm.get("governed_birth_year") is None:
            if fid not in seen_null:
                seen_null.add(fid)
                null_by.append({"name": mm.get("scraped_name"), "id_fencer": fid,
                                "bracket": label, "place": mm.get("place")})
        elif f.get("bool_birth_year_estimated"):
            if fid not in seen_est:
                seen_est.add(fid)
                estimated_by.append({"name": mm.get("scraped_name"),
                                     "by": by if by is not None else mm.get("governed_birth_year"),
                                     "bracket": label, "place": mm.get("place")})

    try:
        event_meta = _fetch_event_meta(db, event_code) if db is not None else {}
    except Exception:
        event_meta = {}
    try:
        live_rows = _live_tournament_rows(db, event_code) if db is not None else []
    except Exception:
        live_rows = []

    return {
        "brackets": brackets, "matches_flat": matches_flat, "created": created,
        "reconciled": reconciled, "conflicts": conflicts,
        "alias_writebacks": alias_writebacks, "alias_verdicts": alias_verdicts,
        "pool_rounds": pool_rounds, "schedule_skips": schedule_skips or [],
        "fencer_by_id": fencer_by_id, "null_by": null_by, "estimated_by": estimated_by,
        "event_meta": event_meta, "live_rows": live_rows,
    }


def render_staging_md(event_code, db, bracket_reports, schedule_skips, stamp) -> str:
    m = _assemble(event_code, db, bracket_reports, schedule_skips)
    lines = [f"# Automation report — {event_code}", "", f"_Generated {stamp} (UTC)_", ""]
    for heading, renderer in STAGING_TEMPLATE:
        if heading:
            lines += [heading, ""]
        lines += [renderer(m), ""]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# The plugin
# ---------------------------------------------------------------------------

class StagingFormatter(BasePlugin):
    name = "StagingFormatter"
    kind = PluginKind.MUTATOR
    reads = frozenset({"event"})
    effects = frozenset({"docs"})

    def applies(self, ctx: Context) -> bool:
        return ctx.get("_bracket_reports") is not None

    def run(self, ctx: Context, svc: Services) -> None:
        reports = ctx.get("_bracket_reports") or []
        event = ctx.get("event") or {}
        event_code = event.get("txt_code") or ctx.params.get("event_code") or "EVENT"
        staging_dir = (svc.config or {}).get("staging_dir")
        stamp = _utc_stamp()
        db = svc.db

        # --- the .md (template) ---
        from python.pipeline.md_writer import write_for_event
        md = render_staging_md(event_code, db, reports, ctx.get("_schedule_skips"), stamp)
        write_for_event(event_code, md, target="local",
                        staging_dir=staging_dir, timestamp=stamp)

        # --- the .diff.md (3-way diff, reused verbatim) ---
        from python.pipeline.three_way_diff import (
            build_diff, confidence_histogram, render_markdown, write_diff,
        )
        matches = [mm for report in reports for f in report
                   if f.section == Section.IDENTITY for mm in f.payload.get("matches", [])]
        source_rows = [{"fencer_name": mm["scraped_name"], "place": mm["place"]} for mm in matches]
        new_rows = [{"fencer_name": mm["scraped_name"], "place": mm["place"],
                     "id_fencer": mm["id_fencer"]} for mm in matches]
        cert_rows = (db.fetch_cert_rows_for_event(event_code)
                     if db is not None and hasattr(db, "fetch_cert_rows_for_event") else [])
        diff_rows = build_diff(source_rows, cert_rows, new_rows)
        hist = confidence_histogram(
            [SimpleNamespace(confidence=mm.get("confidence") or 0.0) for mm in matches])
        diff_md = render_markdown(
            event_code, diff_rows, hist,
            notes=["Aggregated across all brackets; rows joined by place "
                   "(ADR-075 informational diff)."])
        from pathlib import Path
        write_diff(event_code, diff_md,
                   Path(staging_dir) if staging_dir else None, timestamp=stamp)

        self.report(ctx, Section.REACTION, staging_md=True, staging_diff=True, timestamp=stamp)
