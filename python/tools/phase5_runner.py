"""
Phase 5 ingestion runner — non-interactive driver for the unified pipeline.

For each event in the Phase 5 worklist:
  1. fetch + parse a single URL via Fetcher.fetch_url
  2. run Stages 1-7 via run_pipeline → PipelineContext
  3. write a markdown summary to doc/staging/<event_code>.md
  4. (separately) operator reviews summary; if OK, calls commit

Usage:
    python -m python.tools.phase5_runner --event-code GP1-2023-2024 \\
        --url "https://www.fencingtimelive.com/tournaments/eventSchedule/..."

Writes:
    doc/staging/<event_code>.md    — summary for operator review
    doc/staging/<event_code>.diff.md (if Stages 8-11 advance via separate step)

Test scope: not unit-tested directly; the underlying pipeline + review_cli
machinery is covered by Phase 3/4 pytests.
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

from python.pipeline.db_connector import create_db_connector
from python.pipeline.draft_store import DraftStore
from python.pipeline.review_cli import Fetcher, ReviewSession, SourceChoice


def _summary_md(event_code: str, url: str, ctx, parsed) -> str:
    """Build the per-event markdown summary."""
    lines: list[str] = []
    lines.append(f"# Phase 5 ingestion summary — `{event_code}`")
    lines.append("")
    lines.append(f"- **Source URL:** {url}")
    lines.append(f"- **Source kind:** {getattr(parsed, 'source_kind', '?')}")

    # Parsed-IR overview
    n_results = len(getattr(parsed, "results", []) or [])
    lines.append(f"- **Parsed results:** {n_results}")
    if hasattr(parsed, "tournament_name"):
        lines.append(f"- **Parsed tournament name:** {parsed.tournament_name!r}")
    if hasattr(parsed, "city"):
        lines.append(f"- **Parsed city:** {parsed.city!r}")
    if hasattr(parsed, "country"):
        lines.append(f"- **Parsed country:** {parsed.country!r}")
    if hasattr(parsed, "weapon"):
        lines.append(f"- **Parsed weapon:** {parsed.weapon!r}")
    if hasattr(parsed, "gender"):
        lines.append(f"- **Parsed gender:** {parsed.gender!r}")
    if hasattr(parsed, "age_category"):
        lines.append(f"- **Parsed age category:** {parsed.age_category!r}")
    if hasattr(parsed, "tournament_date"):
        lines.append(f"- **Parsed date:** {parsed.tournament_date!r}")

    lines.append("")
    lines.append("## Pipeline status")
    lines.append("")
    if ctx.halted:
        lines.append(f"- **Status:** ❌ HALTED at `{ctx.halted_at_stage}`")
        lines.append(f"- **Reason:** `{ctx.halt_reason.value if ctx.halt_reason else '?'}`")
        lines.append(f"- **Detail:** {ctx.halt_detail}")
    else:
        lines.append("- **Status:** ✅ Stages 1-7 passed")
    lines.append(f"- **PEW cascade pending:** {ctx.pew_cascade_pending}")
    lines.append(f"- **Run ID:** `{ctx.run_id or '(not yet written)'}`")

    # Matcher histogram (if matches present)
    matches = getattr(ctx, "matches", []) or []
    if matches:
        lines.append("")
        lines.append("## Matcher results")
        lines.append("")
        method_counts = Counter(getattr(m, "method", "?") for m in matches)
        lines.append("| Method | Count |")
        lines.append("|---|---:|")
        for method, count in sorted(method_counts.items()):
            lines.append(f"| `{method}` | {count} |")

        # Confidence histogram (if available)
        confs = [getattr(m, "confidence", None) for m in matches]
        confs = [c for c in confs if c is not None]
        if confs:
            buckets = Counter()
            for c in confs:
                if c >= 0.95: buckets["[0.95–1.00] high"] += 1
                elif c >= 0.85: buckets["[0.85–0.95) good"] += 1
                elif c >= 0.70: buckets["[0.70–0.85) borderline"] += 1
                else: buckets["[<0.70] suspect"] += 1
            lines.append("")
            lines.append("| Confidence bucket | Count |")
            lines.append("|---|---:|")
            for k in ["[0.95–1.00] high", "[0.85–0.95) good", "[0.70–0.85) borderline", "[<0.70] suspect"]:
                lines.append(f"| {k} | {buckets.get(k, 0)} |")

    # Tricky parts surfaced
    tricky: list[str] = []
    if ctx.halted:
        tricky.append(f"⚠ Pipeline halted at `{ctx.halted_at_stage}`. See **Detail** above.")
    pending = [m for m in matches if getattr(m, "method", "") == "PENDING"]
    if pending:
        tricky.append(f"🔍 {len(pending)} fencers in PENDING (matcher uncertain). Listed below.")
    excluded = [m for m in matches if getattr(m, "method", "") == "EXCLUDED"]
    if excluded:
        tricky.append(f"⤵ {len(excluded)} rows excluded (foreigner / non-POL filter etc.).")
    if ctx.pew_cascade_pending:
        tricky.append("↻ PEW weapon-set changed — cascade rename will fire on commit.")

    lines.append("")
    lines.append("## Tricky parts")
    lines.append("")
    if not tricky:
        lines.append("_(none — clean run)_")
    else:
        for t in tricky:
            lines.append(f"- {t}")

    if pending:
        lines.append("")
        lines.append("### PENDING matches")
        lines.append("")
        lines.append("| Scraped name | Top candidate | Confidence |")
        lines.append("|---|---|---:|")
        for m in pending[:20]:
            scraped = getattr(m, "scraped_name", "?")
            cand = getattr(m, "candidate_name", "?")
            conf = getattr(m, "confidence", "?")
            lines.append(f"| {scraped} | {cand} | {conf} |")
        if len(pending) > 20:
            lines.append(f"| _…+{len(pending) - 20} more_ |  |  |")

    lines.append("")
    lines.append("## Next step")
    lines.append("")
    if ctx.halted:
        lines.append("- Halt at Stage 7 means the URL→data validation rejected this fetch. Edit override YAML or re-supply a different URL.")
    else:
        lines.append("- Operator reviews this summary.")
        lines.append("- If OK → tell Claude to commit; commit_lifecycle fires Stage 8b cascade + parity gate as appropriate; promotion to CERT/PROD is the next step after that.")
        lines.append("- If not OK → edit `doc/overrides/<event_code>.yaml` to fix identity/URL/splitter, then re-run.")

    lines.append("")
    return "\n".join(lines)


def _fetch_event_meta(db, event_code: str) -> dict:
    """Read event metadata + all 5 url_event* slots.

    Returns dict with: id_event, txt_code, dt_start, dt_end, organizer_code,
    urls (list of (slot, url) for non-null url_event* columns).
    """
    sb = db._sb
    # Fetch every column on tbl_event so the summary can show full detail
    resp = (
        sb.table("tbl_event").select("*").eq("txt_code", event_code).execute()
    )
    if not resp.data:
        raise ValueError(f"event {event_code!r} not found")
    row = resp.data[0]
    urls: list[tuple[int, str]] = []
    for slot, key in [(1, "url_event"), (2, "url_event_2"), (3, "url_event_3"),
                      (4, "url_event_4"), (5, "url_event_5")]:
        v = row.get(key)
        if v and v.strip():
            urls.append((slot, v.strip()))

    # Resolve organizer code
    org_code = "UNKNOWN"
    if row.get("id_organizer"):
        org_resp = (
            sb.table("tbl_organizer")
              .select("txt_code")
              .eq("id_organizer", row["id_organizer"])
              .execute()
        )
        if org_resp.data:
            org_code = org_resp.data[0]["txt_code"]

    return {
        "id_event": row["id_event"],
        "txt_code": row["txt_code"],
        "dt_start": row["dt_start"],
        "dt_end": row.get("dt_end"),
        "organizer_code": org_code,
        "txt_location": row.get("txt_location"),
        "urls": urls,
        "_full_row": row,  # every column for the per-event detail dump
    }


def _coerce_date(value):
    """Coerce ISO-string/date/datetime into a `date` object (Stage 1 expects this)."""
    from datetime import date, datetime
    if value is None:
        return None
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    if isinstance(value, datetime):
        return value.date()
    try:
        return date.fromisoformat(str(value)[:10])
    except ValueError:
        return None


def _stamp_event_metadata(parsed, *, parsed_date, country_default: str | None,
                           city_default: str | None):
    """Stamp event-level metadata onto a ParsedTournament IR.

    Phase 5 defaults applied when the source doesn't emit a value:
      - parsed_date ← tbl_event.dt_start (FTL JSON doesn't carry date)
      - country     ← 'PL' for SPWS-organized events (per project_spws_country_default.md)
      - city        ← tbl_event.txt_location (URL is fallback for non-SPWS sources)
    """
    import dataclasses as _dc
    if _dc.is_dataclass(parsed):
        kwargs = {}
        if hasattr(parsed, "parsed_date") and not getattr(parsed, "parsed_date", None):
            kwargs["parsed_date"] = parsed_date
        if country_default and hasattr(parsed, "country") and not getattr(parsed, "country", None):
            kwargs["country"] = country_default
        if city_default and hasattr(parsed, "city") and not getattr(parsed, "city", None):
            kwargs["city"] = city_default
        if kwargs:
            try:
                return _dc.replace(parsed, **kwargs)
            except TypeError:
                pass
    if not getattr(parsed, "parsed_date", None):
        try:
            setattr(parsed, "parsed_date", parsed_date)
        except Exception:
            pass
    if country_default and not getattr(parsed, "country", None):
        try:
            setattr(parsed, "country", country_default)
        except Exception:
            pass
    if city_default and not getattr(parsed, "city", None):
        try:
            setattr(parsed, "city", city_default)
        except Exception:
            pass
    return parsed


def main() -> int:
    parser = argparse.ArgumentParser(description="Phase 5 per-event ingestion driver")
    # event-code is required for ingestion; optional in --commit-run-id mode
    # because the runner can derive it from the history rows.
    parser.add_argument("--event-code", default="REQUIRED")
    parser.add_argument("--season-end-year", type=int, default=2024)
    parser.add_argument("--staging-dir", default="doc/staging")
    parser.add_argument(
        "--commit-run-id",
        help="Commit a previously-staged draft run by id and exit. "
             "User reviews the staging .md first; when satisfied, sign off "
             "by running with this flag. No new ingestion happens in this mode.",
    )
    args = parser.parse_args()

    # In ingestion mode (no --commit-run-id), --event-code is required
    if not args.commit_run_id and args.event_code == "REQUIRED":
        parser.error("--event-code is required for ingestion mode")

    # Sign-off / commit-only mode: skip ingestion, commit the named run AND
    # append the just-committed tournaments + results to the Phase 5 seed
    # increments file. End-of-day, the increments file is merged into the
    # main seed so a fresh `reset-dev.sh` reproduces the rebuild.
    if args.commit_run_id:
        db = create_db_connector()

        # Phase 5 alias writeback — before fn_commit_event_draft so the
        # alias is on the fencer when the result row references it.
        # Re-derives pending pairs from the persisted drafts (works even
        # if the staging summary was generated in an earlier process).
        # ❌ pairs BLOCK sign-off; ✓ pairs flush; ❓ pairs are surfaced
        # but skipped (operator must edit fencer-alias UI to handle them).
        from python.pipeline.alias_writeback import (
            derive_pending_from_run_id, has_blocking_pairs,
            flush_pending_aliases,
        )
        pending = derive_pending_from_run_id(db, args.commit_run_id)
        if has_blocking_pairs(pending):
            print(
                f"⛔ sign-off BLOCKED — {sum(1 for p in pending if p.icon=='❌')} "
                "❌ pairs (suspected wrong matches) in this run. "
                "Fix overrides / source data and re-stage before signing off.",
                file=sys.stderr,
            )
            for p in pending:
                if p.icon == "❌":
                    print(
                        f"  ❌ id_fencer={p.id_fencer} "
                        f"scraped={p.scraped_name!r} canonical={p.canonical!r} "
                        f"({p.reason})",
                        file=sys.stderr,
                    )
            return 2

        flush_result = flush_pending_aliases(db, pending)
        if flush_result["written"] or flush_result["errors"]:
            print(
                f"  alias writes: {flush_result['written']} written, "
                f"{flush_result['skipped_ambiguous']} ambiguous skipped, "
                f"{len(flush_result['errors'])} errors",
                file=sys.stderr,
            )
            for fid, alias, msg in flush_result["errors"]:
                print(f"    ⚠ alias write FAILED id_fencer={fid} "
                      f"alias={alias!r}: {msg}", file=sys.stderr)

        try:
            resp = db._sb.rpc("fn_commit_event_draft", {
                "p_run_id": args.commit_run_id
            }).execute()
            print(f"✅ committed run {args.commit_run_id}: {resp.data}",
                  file=sys.stderr)
        except Exception as e:
            print(f"❌ commit failed for {args.commit_run_id}: {e}",
                  file=sys.stderr)
            return 1
        # Resolve event_code from the commit's history rows (or argv override)
        event_code = args.event_code if args.event_code != "REQUIRED" else None
        if not event_code:
            # Look up via the just-inserted ingest_history rows on the run_id
            # (best-effort — operator can pass --event-code explicitly too).
            hist = (
                db._sb.table("tbl_tournament_ingest_history")
                      .select("id_tournament")
                      .eq("txt_run_id", args.commit_run_id)
                      .limit(1)
                      .execute()
            ).data
            if hist:
                t = (
                    db._sb.table("tbl_tournament")
                          .select("id_event")
                          .eq("id_tournament", hist[0]["id_tournament"])
                          .execute()
                ).data
                if t:
                    e = (
                        db._sb.table("tbl_event")
                              .select("txt_code")
                              .eq("id_event", t[0]["id_event"])
                              .execute()
                    ).data
                    if e:
                        event_code = e[0]["txt_code"]
        if not event_code:
            print("⚠ no event_code resolved; seed file NOT updated. "
                  "Re-run with --event-code <code> --commit-run-id <id>.",
                  file=sys.stderr)
            return 0
        n = _append_event_to_seed(db, event_code)
        print(f"✅ appended {n} INSERT rows for {event_code} to "
              f"supabase/seed_phase5_increments.sql", file=sys.stderr)
        return 0

    db = create_db_connector()
    store = DraftStore(db)
    fetcher = Fetcher()
    session = ReviewSession(
        event_code=args.event_code,
        db=db,
        draft_store=store,
        season_end_year=args.season_end_year,
        fetcher=fetcher,
    )

    # Read event metadata + all 5 url_event* slots
    event_meta = _fetch_event_meta(db, args.event_code)
    event_urls = event_meta["urls"]
    if not event_urls:
        print(f"event {args.event_code!r} has no url_event* set — nothing to scrape",
              file=sys.stderr)
        return 1
    print(f"→ {args.event_code} (organizer={event_meta['organizer_code']}, "
          f"dt_start={event_meta['dt_start']}): {len(event_urls)} url_event slot(s) populated",
          file=sys.stderr)

    # Country default: SPWS-organized events always = 'PL' per
    # project_spws_country_default.md
    country_default = "PL" if event_meta["organizer_code"] == "SPWS" else None

    # Loop every populated URL slot; accumulate per-tournament IRs across all
    ctxs: list = []  # list of (slot, parsed, ctx, error)
    pool_brackets: list[dict] = []  # {weapon, name, url, reason}
    for slot, ev_url in event_urls:
        print(f"→ slot {slot}: fetching {ev_url}", file=sys.stderr)
        try:
            parsed_list, splitter_skips = fetcher.fetch_event_url_with_skips(ev_url)
        except Exception as e:
            import traceback as _tb
            tb = _tb.format_exc()
            print(f"   EXCEPTION fetching slot {slot}: {e}", file=sys.stderr)
            print(tb, file=sys.stderr)
            ctxs.append((slot, None, None, str(e)))
            continue
        # Splitter-time skips (Mixed / DE / unparseable) — surface as pool brackets
        for sk in splitter_skips:
            pool_brackets.append({
                "weapon": sk.get("weapon"),
                "name": sk.get("name", "?"),
                "url": sk.get("url", ""),
                "reason": sk.get("reason", "splitter skip"),
            })
        print(f"   → {len(parsed_list)} per-tournament IR(s) discovered, "
              f"{len(splitter_skips)} skipped at splitter",
              file=sys.stderr)

        for i, parsed in enumerate(parsed_list, start=1):
            # Stamp event-level date + country defaults on the parsed IR
            parsed = _stamp_event_metadata(
                parsed,
                parsed_date=_coerce_date(event_meta["dt_start"]),
                country_default=country_default,
                city_default=event_meta.get("txt_location"),
            )
            n_results = len(getattr(parsed, "results", []) or [])
            if n_results == 0:
                # V0 (or any sub-tournament) with zero results: skip pipeline,
                # nothing to ingest.
                print(f"   [{i}/{len(parsed_list)}] skip (0 results) — "
                      f"{getattr(parsed, 'weapon', '?')}/{getattr(parsed, 'gender', '?')}/"
                      f"{getattr(parsed, 'age_category', '?')}", file=sys.stderr)
                ctxs.append((slot, parsed, None, "0 results"))
                continue
            print(f"   [{i}/{len(parsed_list)}] Stages 1-7 "
                  f"({getattr(parsed, 'weapon', '?')}/{getattr(parsed, 'gender', '?')}/"
                  f"{getattr(parsed, 'age_category', '?')}, n={n_results})",
                  file=sys.stderr)
            try:
                ctx, _diff_path = session.run_iteration(parsed, staging_dir=Path(args.staging_dir))
                ctxs.append((slot, parsed, ctx, None))
                print(f"     halted={ctx.halted}", file=sys.stderr)
                # Track pool-round halts for the per-weapon invariant check
                if ctx.halted and getattr(ctx, "is_pool_round", False):
                    bracket_name = (
                        getattr(parsed, "_ftl_source_name", None)
                        or getattr(parsed, "tournament_name", None)
                        or "?"
                    )
                    pool_brackets.append((parsed.weapon or "?", bracket_name))
            except Exception as e:
                print(f"     EXCEPTION: {e}", file=sys.stderr)
                ctxs.append((slot, parsed, None, str(e)))

    # Post-bracket consolidation:
    # 1. Merge duplicate (event, V-cat, weapon, gender) tournament_drafts.
    # 2. Drop tournament_drafts that have zero result_drafts after consolidation
    #    (e.g. PENDING/UNMATCHED-only V-cat groups that never produced a
    #    finalized result row). User-rule 2026-05-02: no empty tournaments.
    if session.run_id:
        _consolidate_duplicate_codes(db, session.run_id)
        _drop_empty_tournament_drafts(db, session.run_id)

    # Per-weapon pool-round invariant (≤2 per weapon per event)
    pool_warnings = _check_pool_round_count(pool_brackets)
    for w in pool_warnings:
        print(w, file=sys.stderr)

    # ─── PHASE 5 OPTION-1 STAGE-TIME ALIAS FLUSH ──────────────────────────
    # Pre-write EVERY pending alias pair (✓ ❓ ❌) to tbl_fencer.json_name_aliases
    # so the FencerAliasManager UI surfaces them all. The user uses
    # Transfer / Discard / Create on the bad ones — those RPCs are now
    # draft-aware (migration 20260502000009), so tbl_result_draft follows.
    #
    # Source = in-memory ctx.matches across every bracket (NOT
    # tbl_result_draft) so we also catch PENDING-method rows. PENDING
    # rows have id_fencer set (matcher's best guess) but never enter
    # tbl_result_draft — without this path, low-confidence wrong matches
    # like "BURLIKOWSKI Bartosz → KOWALSKI Bartosz" never reach the UI
    # and the operator has no way to fix them.
    if session.run_id:
        from python.pipeline.alias_writeback import (
            compute_pending_from_matches, flush_pending_aliases,
        )
        try:
            all_matches = []
            all_ids = set()
            for slot, parsed, ctx, err in ctxs:
                if ctx is None or not getattr(ctx, "matches", None):
                    continue
                for m in ctx.matches:
                    if getattr(m, "id_fencer", None) is not None:
                        all_matches.append(m)
                        all_ids.add(m.id_fencer)
            basics = (
                db.fetch_fencer_basics_batch(sorted(all_ids))
                if hasattr(db, "fetch_fencer_basics_batch") else {}
            )
            stage_pending = compute_pending_from_matches(all_matches, basics)
            if stage_pending:
                stage_flush = flush_pending_aliases(
                    db, stage_pending, include_all=True,
                )
                n_block = sum(1 for p in stage_pending if p.icon == "❌")
                n_amb = sum(1 for p in stage_pending if p.icon == "❓")
                n_ok = sum(1 for p in stage_pending if p.icon == "✓")
                print(
                    f"  stage-time alias flush: "
                    f"{stage_flush['written']} written to tbl_fencer "
                    f"(❌={n_block} ❓={n_amb} ✓={n_ok} — all surfaced in "
                    f"FencerAliasManager UI), "
                    f"{len(stage_flush['errors'])} errors",
                    file=sys.stderr,
                )
        except Exception as e:  # noqa: BLE001
            print(f"  ⚠ stage-time alias flush failed: {e}", file=sys.stderr)

    # ─── SIGN-OFF STOP ─────────────────────────────────────────────
    # No auto-commit. The runner writes drafts + summary and STOPS here
    # so the user can review the staging .md and decide whether to commit.
    # To sign off, re-invoke with --commit-run-id <run_id>.
    md = _multi_summary_md(
        args.event_code, event_meta, ctxs, db=db,
        pool_brackets=pool_brackets, pool_warnings=pool_warnings,
        run_id=session.run_id,
        url_check_results=getattr(session, "url_check_results", {}),
    )
    out_path = Path(args.staging_dir) / f"{args.event_code}.md"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(md, encoding="utf-8")
    print(f"→ Wrote {out_path}", file=sys.stderr)
    return 0


def _consolidate_duplicate_codes(db, run_id: str) -> int:
    """Merge tournament_draft rows that share (run_id, txt_code).

    For each duplicate group:
      - Keep the row with the most result_drafts (ties: lowest id_tournament_draft)
      - Reassign result_drafts from the others to the keeper
      - Delete the other tournament_draft rows
      - bool_joint_pool_split = TRUE if any contributor had it set, else FALSE

    Returns the number of duplicate rows removed.
    """
    sb = db._sb
    # Find all duplicate codes for this run
    rows = (
        sb.table("tbl_tournament_draft")
          .select("id_tournament_draft,txt_code,bool_joint_pool_split")
          .eq("txt_run_id", run_id)
          .execute()
    ).data or []
    by_code: dict[str, list[dict]] = {}
    for r in rows:
        by_code.setdefault(r["txt_code"], []).append(r)
    removed = 0
    for code, group in by_code.items():
        if len(group) <= 1:
            continue
        # Count result_drafts per tournament_draft id
        ids = [r["id_tournament_draft"] for r in group]
        counts = {
            i: len((sb.table("tbl_result_draft")
                      .select("id_result_draft")
                      .eq("id_tournament_draft", i).execute()).data or [])
            for i in ids
        }
        # Keep highest count; ties → lowest id (stable)
        keeper_id = max(ids, key=lambda i: (counts[i], -i))
        any_joint = any(r["bool_joint_pool_split"] for r in group)
        # Reassign result_drafts from losers to keeper
        for i in ids:
            if i == keeper_id:
                continue
            (sb.table("tbl_result_draft")
               .update({"id_tournament_draft": keeper_id})
               .eq("id_tournament_draft", i).execute())
            (sb.table("tbl_tournament_draft")
               .delete()
               .eq("id_tournament_draft", i).execute())
            removed += 1
        # Update keeper's joint flag if any contributor had it set
        if any_joint:
            (sb.table("tbl_tournament_draft")
               .update({"bool_joint_pool_split": True})
               .eq("id_tournament_draft", keeper_id).execute())
        print(f"  ↻ merged {len(group)} duplicate {code} drafts → "
              f"keeper id={keeper_id} ({sum(counts.values())} results consolidated)",
              file=sys.stderr)
    return removed


def _sql_quote(v) -> str:
    """Postgres-safe SQL literal quoting for strings/numbers/None."""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)):
        return str(v)
    s = str(v).replace("'", "''")
    return f"'{s}'"


def _append_event_to_seed(db, event_code: str) -> int:
    """Append the just-committed event's tbl_tournament + tbl_result rows to
    the Phase 5 seed-increments file. Returns the count of INSERT rows added.

    Rows are written in the same shape as the existing seed file: tournament
    INSERTs by full column list; result INSERTs use sub-SELECTs by fencer
    surname+first_name and tournament code so the increments file stays
    identity-stable across re-runs.
    """
    from datetime import datetime
    from pathlib import Path

    sb = db._sb
    ev = (
        sb.table("tbl_event").select("id_event").eq("txt_code", event_code).execute()
    ).data
    if not ev:
        return 0
    id_event = ev[0]["id_event"]

    tournaments = (
        sb.table("tbl_tournament")
          .select("id_tournament,txt_code,txt_name,enum_type,num_multiplier,"
                  "dt_tournament,int_participant_count,enum_weapon,enum_gender,"
                  "enum_age_category,url_results,enum_import_status,"
                  "txt_import_status_reason,bool_joint_pool_split,"
                  "enum_parser_kind,dt_last_scraped,txt_source_url_used")
          .eq("id_event", id_event)
          .order("enum_weapon").order("enum_gender").order("enum_age_category")
          .execute()
    ).data or []

    tournament_ids = [t["id_tournament"] for t in tournaments]
    results = []
    if tournament_ids:
        results = (
            sb.table("tbl_result")
              .select("id_fencer,id_tournament,int_place,num_final_score,"
                      "num_match_confidence,enum_match_method,txt_scraped_name")
              .in_("id_tournament", tournament_ids)
              .execute()
        ).data or []

    # Build fencer-id → (surname, first_name) lookup for the result sub-selects
    fencer_ids = list({r["id_fencer"] for r in results if r.get("id_fencer")})
    fencer_map: dict[int, dict] = {}
    if fencer_ids:
        rows = (
            sb.table("tbl_fencer")
              .select("id_fencer,txt_surname,txt_first_name")
              .in_("id_fencer", fencer_ids)
              .execute()
        ).data or []
        fencer_map = {r["id_fencer"]: r for r in rows}
    tournament_code_map = {t["id_tournament"]: t["txt_code"] for t in tournaments}

    out_path = Path("supabase/seed_phase5_increments.sql")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if not out_path.exists():
        out_path.write_text(
            "-- Phase 5 seed increments — appended per-event as the operator\n"
            "-- signs off each ingestion. End-of-day this file is merged into\n"
            "-- the main seed (`supabase/seed_local_<date>.sql`) so a fresh\n"
            "-- `reset-dev.sh` reproduces the rebuild.\n",
            encoding="utf-8",
        )

    lines: list[str] = []
    ts = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    lines.append("")
    lines.append(f"-- ========= Event {event_code} (committed {ts}) =========")
    lines.append("")

    # Tournaments — straight INSERT by event txt_code
    for t in tournaments:
        cols = ("id_event", "txt_code", "txt_name", "enum_type", "num_multiplier",
                "dt_tournament", "int_participant_count", "enum_weapon",
                "enum_gender", "enum_age_category", "url_results",
                "enum_import_status", "txt_import_status_reason",
                "bool_joint_pool_split", "enum_parser_kind", "dt_last_scraped",
                "txt_source_url_used")
        vals = ["(SELECT id_event FROM tbl_event WHERE txt_code = "
                f"{_sql_quote(event_code)})"]
        vals.extend(_sql_quote(t.get(c)) for c in cols[1:])
        lines.append(
            f"INSERT INTO tbl_tournament ({', '.join(cols)}) VALUES "
            f"({', '.join(vals)})\n"
            f"ON CONFLICT (txt_code) DO NOTHING;"
        )

    # Results — sub-SELECT by fencer (surname,first_name) + tournament (txt_code)
    n_rows = 0
    for r in results:
        f = fencer_map.get(r["id_fencer"])
        tcode = tournament_code_map.get(r["id_tournament"])
        if not f or not tcode:
            continue
        surname = _sql_quote(f["txt_surname"])
        first = _sql_quote(f["txt_first_name"])
        tcode_q = _sql_quote(tcode)
        place = _sql_quote(r.get("int_place"))
        score = _sql_quote(r.get("num_final_score"))
        conf = _sql_quote(r.get("num_match_confidence"))
        method = _sql_quote(r.get("enum_match_method"))
        scraped = _sql_quote(r.get("txt_scraped_name"))
        lines.append(
            f"INSERT INTO tbl_result (id_fencer, id_tournament, int_place, "
            f"num_final_score, num_match_confidence, enum_match_method, "
            f"txt_scraped_name) "
            f"SELECT (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = "
            f"{surname} AND txt_first_name = {first} LIMIT 1), "
            f"(SELECT id_tournament FROM tbl_tournament WHERE txt_code = "
            f"{tcode_q}), {place}, {score}, {conf}, {method}, {scraped} "
            f"WHERE NOT EXISTS (SELECT 1 FROM tbl_result WHERE id_fencer = "
            f"(SELECT id_fencer FROM tbl_fencer WHERE txt_surname = {surname} "
            f"AND txt_first_name = {first} LIMIT 1) AND id_tournament = "
            f"(SELECT id_tournament FROM tbl_tournament WHERE txt_code = "
            f"{tcode_q}));"
        )
        n_rows += 1

    with out_path.open("a", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return len(tournaments) + n_rows


def _check_pool_round_count(pool_brackets: list) -> list[str]:
    """Verify the SPWS invariant: at most 2 pool rounds per weapon per event.

    Accepts either:
      - list of (weapon, name) tuples (legacy)
      - list of dicts with `weapon` and `name` keys (new — also carries `url`/`reason`)

    Returns a list of human-readable warning strings (empty when the
    invariant holds). The runner prints these to the operator and to the
    staging .md so the user notices an unusual event.
    """
    from collections import Counter

    def _wpn(b):
        return b["weapon"] if isinstance(b, dict) else b[0]

    def _name(b):
        return b["name"] if isinstance(b, dict) else b[1]

    counts = Counter(_wpn(b) for b in pool_brackets)
    warnings: list[str] = []
    for weapon, n in sorted(counts.items(), key=lambda kv: str(kv[0])):
        if n > 2:
            sample = ", ".join(_name(b) for b in pool_brackets if _wpn(b) == weapon)
            warnings.append(
                f"⚠ {n} pool rounds detected for weapon {weapon!r} — SPWS "
                f"convention is at most 2 per weapon per event. Brackets: {sample}"
            )
    return warnings


def _drop_empty_tournament_drafts(db, run_id: str) -> int:
    """Delete tournament_draft rows that have zero result_drafts.

    Empty tournaments would commit as orphan tbl_tournament rows with no
    fencers — a data hygiene problem the operator never wants. Per user
    rule 2026-05-02: no empty tournaments.
    """
    sb = db._sb
    rows = (
        sb.table("tbl_tournament_draft")
          .select("id_tournament_draft,txt_code")
          .eq("txt_run_id", run_id)
          .execute()
    ).data or []
    dropped = 0
    for r in rows:
        rd = (
            sb.table("tbl_result_draft")
              .select("id_result_draft")
              .eq("id_tournament_draft", r["id_tournament_draft"])
              .execute()
        ).data or []
        if not rd:
            (sb.table("tbl_tournament_draft")
               .delete()
               .eq("id_tournament_draft", r["id_tournament_draft"])
               .execute())
            print(f"  ⊘ dropped empty draft {r['txt_code']}", file=sys.stderr)
            dropped += 1
    return dropped


def _live_tournament_rows(db, event_code: str) -> list[dict]:
    """Read post-commit live tournament rows for the event."""
    sb = db._sb
    ev = (
        sb.table("tbl_event").select("id_event").eq("txt_code", event_code).execute()
    ).data
    if not ev:
        return []
    id_event = ev[0]["id_event"]
    return (
        sb.table("tbl_tournament")
          .select("id_tournament,txt_code,enum_age_category,enum_weapon,enum_gender,"
                  "dt_tournament,url_results,txt_source_url_used,bool_joint_pool_split,"
                  "int_participant_count")
          .eq("id_event", id_event)
          .order("enum_weapon")
          .order("enum_gender")
          .order("enum_age_category")
          .execute()
    ).data or []


def _draft_tournament_rows(db, run_id: str) -> list[dict]:
    """Read pre-commit draft tournament rows for the run — all columns."""
    sb = db._sb
    return (
        sb.table("tbl_tournament_draft")
          .select("*")
          .eq("txt_run_id", run_id)
          .order("enum_weapon")
          .order("enum_gender")
          .order("enum_age_category")
          .execute()
    ).data or []


_PL_FOLD = str.maketrans({
    "ą": "a", "Ą": "a", "ć": "c", "Ć": "c", "ę": "e", "Ę": "e",
    "ł": "l", "Ł": "l", "ń": "n", "Ń": "n", "ó": "o", "Ó": "o",
    "ś": "s", "Ś": "s", "ź": "z", "Ź": "z", "ż": "z", "Ż": "z",
})


def _name_fold(s: str) -> str:
    """Casefold + strip Polish diacritics + collapse whitespace runs."""
    if not s:
        return ""
    return " ".join(s.translate(_PL_FOLD).casefold().split())


def _lev(a: str, b: str) -> int:
    """Levenshtein distance, iterative DP. Used for typo classification only."""
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(
                cur[j - 1] + 1,
                prev[j] + 1,
                prev[j - 1] + (0 if ca == cb else 1),
            ))
        prev = cur
    return prev[-1]


def _split_polish_name(name: str) -> tuple[str, str]:
    """Best-effort split into (surname, first_name) using Polish convention.

    Surname = the all-caps token(s). First name = the rest. Falls back to
    first token = surname if no token is all-caps.
    """
    parts = (name or "").split()
    if not parts:
        return "", ""
    surname_parts = [p for p in parts if p == p.upper() and any(c.isalpha() for c in p)]
    if not surname_parts:
        # No all-caps tokens → assume "Surname Firstname" or single token
        return parts[0], " ".join(parts[1:]) if len(parts) > 1 else ""
    surname = " ".join(surname_parts)
    first = " ".join(p for p in parts if p not in surname_parts)
    return surname, first


def _classify_alias_pair(scraped: str, canonical: str) -> tuple[str, str]:
    """Classify a (scraped, canonical) alias-needed pair.

    Returns (icon, reason) for the 'Looks like' column. The icon is `✓`
    (likely same person), `❌` (probably wrong match), or `❓` (ambiguous).
    """
    s_full = _name_fold(scraped)
    c_full = _name_fold(canonical)
    if s_full == c_full:
        return "✓", "exact match after normalization"

    s_sur, s_first = _split_polish_name(scraped)
    c_sur, c_first = _split_polish_name(canonical)

    s_sur_f = _name_fold(s_sur)
    c_sur_f = _name_fold(c_sur)
    s_fn_f = _name_fold(s_first)
    c_fn_f = _name_fold(c_first)

    # Surname analysis — strip hyphens for prefix/suffix containment check
    s_sur_h = s_sur_f.replace("-", "").replace(" ", "")
    c_sur_h = c_sur_f.replace("-", "").replace(" ", "")
    surname_identical = s_sur_f == c_sur_f
    surname_contained = (
        bool(s_sur_h) and bool(c_sur_h) and (
            s_sur_h in c_sur_h or c_sur_h in s_sur_h
        )
    )
    surname_dist = _lev(s_sur_h, c_sur_h) if s_sur_h and c_sur_h else 99
    surname_close = surname_dist <= 2

    # First name analysis
    first_identical = s_fn_f == c_fn_f
    first_dist = _lev(s_fn_f, c_fn_f) if s_fn_f and c_fn_f else 99
    first_close = first_dist <= 2

    # Verdicts — surname disagreement is the strong "wrong-match" signal
    if not (surname_identical or surname_contained or surname_close):
        return "❌", "different surnames — probably wrong match"
    if not (first_identical or first_close):
        return "❌", "different first names — probably wrong match"

    # Now classify the kind of legitimate variation
    if surname_identical and first_identical:
        if scraped != canonical:
            return "✓", "case / spacing only"
        return "✓", "identical"

    if "-" in (scraped + canonical) and surname_contained and not surname_identical:
        return "✓", "likely same person (short form / married — hyphen variant)"
    if surname_contained and not surname_identical:
        return "✓", "surname truncation / expansion"
    s_norm_strict = s_full.replace(" ", "").replace("-", "")
    c_norm_strict = c_full.replace(" ", "").replace("-", "")
    if s_norm_strict == c_norm_strict:
        return "✓", "space / hyphen normalization"
    if surname_close and not first_close:
        return "✓", "likely typo on surname"
    if first_close and not surname_close:
        return "✓", "likely typo on first name"
    if surname_close and first_close:
        return "✓", "likely typo / transliteration"
    return "❓", "ambiguous — review by hand"


def _build_fencer_matching_summary(db, ctxs: list) -> dict:
    """Walk every bracket's ctx.matches and classify each one for the
    Phase 5 staging summary.

    Returns:
        {
            "total": int,
            "by_method": {method: count},
            "alias_existing": list[match-detail],     # matched via an alias already on tbl_fencer
            "alias_new_needed": list[match-detail],   # canonical name + aliases differ from scraped
            "birth_year_missing": list[match-detail], # int_birth_year is NULL
            "birth_year_estimated": list[match-detail],
            "by_canonical": int,                      # matched via canonical name (clean)
        }
    Each match-detail: {scraped_name, id_fencer, canonical, aliases,
                         tournament_code, place, method}.
    """
    from collections import Counter

    # Collect every match with id_fencer set + tournament-code context
    rows: list[dict] = []
    for slot, parsed, ctx, err in ctxs:
        if ctx is None or not getattr(ctx, "matches", None):
            continue
        # event-level draft tournament code: derived from event + parsed v-cat etc.,
        # but the cleaner reference is parsed.tournament_name + ftl source name.
        for m in ctx.matches:
            if m.id_fencer is None:
                continue
            rows.append({
                "scraped_name": m.scraped_name,
                "id_fencer": m.id_fencer,
                "place": m.place,
                "method": m.method,
                "confidence": m.confidence,
                "ftl_bracket": getattr(parsed, "_ftl_source_name", None) or "—",
                "weapon": getattr(parsed, "weapon", "?"),
                "gender": getattr(parsed, "gender", "?"),
            })

    if not rows:
        return {
            "total": 0, "by_method": {}, "alias_existing": [],
            "alias_new_needed": [], "birth_year_missing": [],
            "birth_year_estimated": [], "by_canonical": 0,
        }

    # Batch-fetch fencer basics
    ids = sorted({r["id_fencer"] for r in rows})
    basics = (
        db.fetch_fencer_basics_batch(ids)
        if hasattr(db, "fetch_fencer_basics_batch") else {}
    )

    def _norm(s: str) -> str:
        """Casefold + collapse whitespace for canonical-name comparison."""
        return " ".join(str(s or "").split()).casefold()

    alias_existing: list[dict] = []
    alias_new_needed: list[dict] = []
    by_missing: list[dict] = []
    by_estimated: list[dict] = []
    by_canonical = 0
    method_counts = Counter()

    for r in rows:
        method_counts[r["method"]] += 1
        f = basics.get(r["id_fencer"])
        if not f:
            continue
        canonical = f"{f.get('txt_surname','')} {f.get('txt_first_name','')}".strip()
        canonical_alt = f"{f.get('txt_first_name','')} {f.get('txt_surname','')}".strip()
        aliases = f.get("json_name_aliases") or []
        if not isinstance(aliases, list):  # tolerate malformed seed shapes
            aliases = []
        scraped_norm = _norm(r["scraped_name"])
        canonical_norm = _norm(canonical)
        canonical_alt_norm = _norm(canonical_alt)

        detail = {
            **r,
            "canonical": canonical,
            "aliases": aliases,
            "by": f.get("int_birth_year"),
            "by_estimated": bool(f.get("bool_birth_year_estimated")),
        }

        # Alias classification
        if scraped_norm == canonical_norm or scraped_norm == canonical_alt_norm:
            by_canonical += 1
        elif any(scraped_norm == _norm(a) for a in aliases):
            alias_existing.append(detail)
        else:
            alias_new_needed.append(detail)

        # Birth-year flags
        if f.get("int_birth_year") is None:
            by_missing.append(detail)
        elif f.get("bool_birth_year_estimated"):
            by_estimated.append(detail)

    return {
        "total": len(rows),
        "by_method": dict(method_counts),
        "alias_existing": alias_existing,
        "alias_new_needed": alias_new_needed,
        "birth_year_missing": by_missing,
        "birth_year_estimated": by_estimated,
        "by_canonical": by_canonical,
    }


def _format_fencer_matching_section(stats: dict) -> list[str]:
    """Render the fencer-matching block as markdown lines."""
    lines: list[str] = []
    lines.append("## Fencer matching")
    lines.append("")
    if stats["total"] == 0:
        lines.append("_(no matched fencers across any bracket — every row PENDING/UNMATCHED)_")
        return lines

    lines.append(f"- **Total matches with id_fencer:** {stats['total']}")
    lines.append("")
    lines.append("### By method")
    lines.append("")
    lines.append("| Method | Count |")
    lines.append("|---|---:|")
    for m, c in sorted(stats["by_method"].items()):
        lines.append(f"| `{m}` | {c} |")
    lines.append("")

    lines.append("### Name resolution")
    lines.append("")
    lines.append("| Path | Count |")
    lines.append("|---|---:|")
    lines.append(f"| ✅ matched via canonical name (no alias) | {stats['by_canonical']} |")
    lines.append(f"| 🔗 matched via existing alias on `tbl_fencer.json_name_aliases` | "
                 f"{len(stats['alias_existing'])} |")
    lines.append(f"| 🆕 alias would need to be added (scraped name not yet in aliases) | "
                 f"{len(stats['alias_new_needed'])} |")
    lines.append("")

    if stats["alias_new_needed"]:
        # Top-of-section verdict table — most important quality signal.
        # Rows sorted ❌ (wrong) first, then ❓ (ambiguous), then ✓.
        verdicts = []
        for d in stats["alias_new_needed"]:
            icon, reason = _classify_alias_pair(d["scraped_name"], d["canonical"])
            verdicts.append((icon, reason, d))
        rank = {"❌": 0, "❓": 1, "✓": 2}
        verdicts.sort(key=lambda v: (rank.get(v[0], 9), v[2]["scraped_name"]))

        lines.append("**🆕 Aliases that would be created on commit — verdict table:**")
        lines.append("")
        lines.append("| Scraped | Resolved | Looks like |")
        lines.append("|---|---|---|")
        for icon, reason, d in verdicts:
            lines.append(
                f"| `{d['scraped_name']}` | {d['canonical']} | {icon} {reason} |"
            )
        lines.append("")
        # Detail (id_fencer / existing aliases / bracket / place) for the
        # operator who needs to act on a flagged row
        lines.append("<details><summary>Per-alias context (id_fencer, existing aliases, bracket, place)</summary>")
        lines.append("")
        lines.append("| Scraped | Resolved (id_fencer) | Existing aliases | Bracket | Place |")
        lines.append("|---|---|---|---|---:|")
        for icon, reason, d in verdicts:
            existing = "; ".join(d["aliases"]) if d["aliases"] else "_(none)_"
            lines.append(
                f"| `{d['scraped_name']}` | {d['canonical']} (#{d['id_fencer']}) | "
                f"{existing} | {d['ftl_bracket']} | {d['place']} |"
            )
        lines.append("")
        lines.append("</details>")
        lines.append("")

    if stats["alias_existing"]:
        lines.append("**🔗 Matches via existing aliases:**")
        lines.append("")
        lines.append("| Scraped name | Resolved fencer (id_fencer) | Tournament bracket | Place |")
        lines.append("|---|---|---|---:|")
        for d in sorted(stats["alias_existing"],
                        key=lambda x: (x["weapon"], x["gender"], x["scraped_name"])):
            lines.append(
                f"| `{d['scraped_name']}` | {d['canonical']} (#{d['id_fencer']}) | "
                f"{d['ftl_bracket']} | {d['place']} |"
            )
        lines.append("")

    lines.append("### Birth-year quality")
    lines.append("")
    lines.append("| Path | Count |")
    lines.append("|---|---:|")
    by_clean = stats["total"] - len(stats["birth_year_missing"]) - len(stats["birth_year_estimated"])
    lines.append(f"| ✅ matched fencer has known + confirmed birth year | {by_clean} |")
    lines.append(f"| 🟡 birth year estimated (`bool_birth_year_estimated = true`) | "
                 f"{len(stats['birth_year_estimated'])} |")
    lines.append(f"| 🚨 birth year MISSING (`int_birth_year = NULL`) — V-cat undefined | "
                 f"{len(stats['birth_year_missing'])} |")
    lines.append("")

    if stats["birth_year_missing"]:
        lines.append("**🚨 Fencers with NULL birth year — V-cat could not be derived:**")
        lines.append("")
        lines.append("| Fencer | Scraped name | id_fencer | Tournament bracket | Place |")
        lines.append("|---|---|---:|---|---:|")
        for d in stats["birth_year_missing"]:
            lines.append(
                f"| {d['canonical']} | `{d['scraped_name']}` | {d['id_fencer']} | "
                f"{d['ftl_bracket']} | {d['place']} |"
            )
        lines.append("")

    if stats["birth_year_estimated"]:
        lines.append("**🟡 Fencers with estimated birth year — V-cat may be wrong:**")
        lines.append("")
        lines.append("| Fencer | Estimated BY | Scraped name | Tournament bracket | Place |")
        lines.append("|---|---:|---|---|---:|")
        for d in stats["birth_year_estimated"]:
            lines.append(
                f"| {d['canonical']} (#{d['id_fencer']}) | {d['by']} | "
                f"`{d['scraped_name']}` | {d['ftl_bracket']} | {d['place']} |"
            )
        lines.append("")
    return lines


def _draft_results_for_tournament(db, id_tournament_draft: int) -> list[dict]:
    """Read all result_drafts for a draft tournament — full columns."""
    sb = db._sb
    return (
        sb.table("tbl_result_draft")
          .select("*")
          .eq("id_tournament_draft", id_tournament_draft)
          .order("int_place")
          .execute()
    ).data or []


def _draft_result_count(db, id_tournament_draft: int) -> int:
    sb = db._sb
    rows = (
        sb.table("tbl_result_draft")
          .select("id_result_draft")
          .eq("id_tournament_draft", id_tournament_draft)
          .execute()
    ).data or []
    return len(rows)


def _live_result_count(db, id_tournament: int) -> int:
    sb = db._sb
    rows = (
        sb.table("tbl_result")
          .select("id_result")
          .eq("id_tournament", id_tournament)
          .execute()
    ).data or []
    return len(rows)


def _format_pending_alias_writes_section(pending: list) -> list[str]:
    """Render the "Pending alias writes" markdown block.

    Pre sign-off the operator sees exactly which (id_fencer, alias) pairs
    will be written to `tbl_fencer.json_name_aliases` when they invoke
    `--commit-run-id`. ❌ pairs are surfaced first (they BLOCK sign-off);
    ✓ pairs flush automatically; ❓ pairs require operator decision.
    """
    lines: list[str] = []
    lines.append("### Pending alias writes (on sign-off)")
    lines.append("")
    if not pending:
        lines.append(
            "_No alias writes pending — every matched scraped name is "
            "already the canonical name or an existing alias._"
        )
        lines.append("")
        return lines

    n_block = sum(1 for p in pending if p.icon == "❌")
    n_amb = sum(1 for p in pending if p.icon == "❓")
    n_ok = sum(1 for p in pending if p.icon == "✓")
    lines.append(
        f"- **{n_ok}** ✓ pairs will be written to "
        f"`tbl_fencer.json_name_aliases` automatically on sign-off."
    )
    if n_amb:
        lines.append(
            f"- **{n_amb}** ❓ pairs need operator decision — they are "
            "skipped at sign-off (no alias written)."
        )
    if n_block:
        lines.append(
            f"- **{n_block}** ❌ pairs BLOCK sign-off — suspected wrong "
            "matches. Fix the source data / add identity overrides / "
            "edit the fencer-alias UI and re-stage."
        )
    lines.append("")
    lines.append("| Verdict | id_fencer | Alias to add | Canonical | Reason |")
    lines.append("|---|---:|---|---|---|")
    for p in pending:
        lines.append(
            f"| {p.icon} | {p.id_fencer} | "
            f"`{p.scraped_name}` | `{p.canonical}` | {p.reason} |"
        )
    lines.append("")
    return lines


def _multi_summary_md(
    event_code: str, event_meta: dict, ctxs: list, db=None,
    pool_brackets: list | None = None, pool_warnings: list | None = None,
    run_id: str | None = None,
    url_check_results: dict | None = None,
) -> str:
    """Per-event summary with full header + per-tournament details.

    Reads live `tbl_tournament` post-commit when `db` is provided so the
    summary reflects the actual committed state, not the parse-time IR.
    """
    lines: list[str] = []
    lines.append(f"# Phase 5 ingestion summary — `{event_code}`")
    lines.append("")

    # ⭐ Fencer matching is the most important part of the scrape ingestion
    # quality report — it surfaces alias false-positives, BY estimation,
    # and missing identities. Goes FIRST so the operator sees it before
    # any other detail.
    if db is not None:
        stats = _build_fencer_matching_summary(db, ctxs)
        lines.append("> **⭐ Most important section — review the matching "
                     "below before signing off.**")
        lines.append("")
        lines.extend(_format_fencer_matching_section(stats))

        # Phase 5 Option-1 (2026-05-02): the pending list comes from
        # `derive_pending_from_run_id` rather than the in-memory stats,
        # so even after the stage-time flush wrote ❌ aliases to
        # tbl_fencer they keep showing up here for the operator to fix
        # via the FencerAliasManager UI. Sign-off blocks on any ❌.
        from python.pipeline.alias_writeback import (
            derive_pending_from_run_id, has_blocking_pairs,
        )
        if run_id:
            pending = derive_pending_from_run_id(db, run_id)
        else:
            pending = []
        lines.extend(_format_pending_alias_writes_section(pending))
        if has_blocking_pairs(pending):
            lines.append("")
            lines.append(
                "> ⛔ **Sign-off BLOCKED** — there are ❌ rows above "
                "(suspected wrong matches). Open the **FencerAliasManager** "
                "UI (`http://localhost:5173/?admin=1`), expand the affected "
                "fencer, and use **↪ Transfer**, **+ Create new fencer**, "
                "or **✕ Discard** on each ❌ alias. Then re-run "
                "`python -m python.tools.phase5_runner --event-code "
                f"{event_code}` to verify the ❌ count drops to zero "
                "before signing off with `--commit-run-id`."
            )
            lines.append("")

    # Header — full event row dump (every populated column)
    lines.append("## Event header — every populated `tbl_event` field")
    lines.append("")
    lines.append("| Field | Value |")
    lines.append("|---|---|")
    lines.append(f"| **resolved organizer** | {event_meta.get('organizer_code', '?')} |")
    lines.append(f"| **resolved season_end_year** (from event-date range) | "
                 f"{event_meta.get('dt_end', '?')} |")
    full_row = event_meta.get("_full_row") or {}
    for k in sorted(full_row.keys()):
        v = full_row[k]
        if v is None or v == "":
            continue
        # URL fields can be long; show full so URL is verifiable
        v_str = str(v)
        lines.append(f"| `{k}` | {v_str} |")
    lines.append("")
    lines.append(f"**Source URL slots ({len(event_meta.get('urls', []))}):**")
    lines.append("")
    for slot, url in event_meta.get("urls", []):
        lines.append(f"- slot {slot}: {url}")
    lines.append("")

    # Bracket-level (parser) status
    halted = 0
    excs = 0
    ok = 0
    empty = 0
    for _, parsed, ctx, err in ctxs:
        if parsed is None:
            excs += 1
        elif err == "0 results":
            empty += 1
        elif err or ctx is None:
            excs += 1
        elif ctx.halted:
            halted += 1
        else:
            ok += 1
    lines.append("## Bracket parse status (FTL sub-tournaments before V-cat split)")
    lines.append("")
    lines.append(f"- ✅ clean: **{ok}**")
    lines.append(f"- ❌ halted: **{halted}**")
    lines.append(f"- ⊘ empty: **{empty}** (skipped — no fencers)")
    lines.append(f"- 🔥 exceptions: **{excs}**")
    lines.append("")

    # Tournament rows — show committed (live) if any, else show drafts
    if db is not None:
        live = _live_tournament_rows(db, event_code)
        if live:
            total_results = sum(_live_result_count(db, t["id_tournament"]) for t in live)
            lines.append(f"## Committed tournaments ({len(live)} tournaments, {total_results} results)")
            lines.append("")
            lines.append("| Code | V-cat | Wpn | Gen | Date | Joint | Results | Source URL |")
            lines.append("|---|---|---|---|---|---|---:|---|")
            for t in live:
                code = t["txt_code"]
                vcat = t.get("enum_age_category") or "?"
                wpn = t.get("enum_weapon") or "?"
                gen = t.get("enum_gender") or "?"
                dt = t.get("dt_tournament") or "—"
                joint = "✓" if t.get("bool_joint_pool_split") else ""
                n = _live_result_count(db, t["id_tournament"])
                # Prefer the human-friendly url_results (clickable from a
                # browser); fall back to txt_source_url_used (the actual
                # fetched endpoint, e.g. FTL's /events/results/data/<UUID>)
                # only when the human URL is empty.
                src = t.get("url_results") or t.get("txt_source_url_used") or ""
                # Show the FULL URL (no truncation) — the operator clicks
                # it to verify the bracket matches. Truncated URLs led to
                # the false "defective URL" report 2026-05-02.
                src_short = src
                lines.append(f"| `{code}` | {vcat} | {wpn} | {gen} | {dt} | {joint} | {n} | {src_short} |")
            lines.append("")
        elif run_id:
            drafts = _draft_tournament_rows(db, run_id)
            total_results = sum(_draft_result_count(db, t["id_tournament_draft"]) for t in drafts)
            lines.append(f"## Draft tournaments — pending sign-off "
                         f"({len(drafts)} tournaments, {total_results} results)")
            lines.append("")
            # Overview table — at-a-glance scannable list
            lines.append("### Overview")
            lines.append("")
            lines.append("| Code | V-cat | Wpn | Gen | Date | Joint | Results | URL ✓ | Source URL |")
            lines.append("|---|---|---|---|---|---|---:|---|---|")
            for t in drafts:
                code = t["txt_code"]
                vcat = t.get("enum_age_category") or "?"
                wpn = t.get("enum_weapon") or "?"
                gen = t.get("enum_gender") or "?"
                dt = t.get("dt_tournament") or "—"
                joint = "✓" if t.get("bool_joint_pool_split") else ""
                n = _draft_result_count(db, t["id_tournament_draft"])
                src = t.get("url_results") or t.get("txt_source_url_used") or ""
                # URL reachability verdict (live-validated pre-save).
                # ✓ = reachable + body confirms results page; ❌ + reason
                # otherwise. Empty when no validation was attempted.
                verdict = (url_check_results or {}).get(code)
                if verdict is None:
                    url_ok = ""
                elif getattr(verdict, "ok", False):
                    url_ok = "✓"
                else:
                    url_ok = f"❌ {getattr(verdict, 'reason', '?')}"
                lines.append(f"| `{code}` | {vcat} | {wpn} | {gen} | {dt} | "
                             f"{joint} | {n} | {url_ok} | {src} |")
            lines.append("")

            # Full detail per tournament — every draft column + per-fencer results
            lines.append("### Full detail per tournament")
            lines.append("")
            for t in drafts:
                code = t["txt_code"]
                lines.append(f"#### `{code}`")
                lines.append("")
                lines.append("| Field | Value |")
                lines.append("|---|---|")
                for k in sorted(t.keys()):
                    if k == "txt_run_id":  # noisy and same for every draft
                        continue
                    v = t[k]
                    if v is None or v == "":
                        v_str = "_(null)_"
                    else:
                        v_str = str(v)
                    lines.append(f"| `{k}` | {v_str} |")
                # Per-fencer result rows
                results = _draft_results_for_tournament(db, t["id_tournament_draft"])
                if results:
                    lines.append("")
                    lines.append(f"**Result rows ({len(results)}):**")
                    lines.append("")
                    lines.append("| Place | Scraped name | id_fencer | Confidence | Method |")
                    lines.append("|---:|---|---:|---:|---|")
                    for r in results:
                        place = r.get("int_place", "?")
                        nm = r.get("txt_scraped_name") or "—"
                        idf = r.get("id_fencer", "—")
                        conf = r.get("num_match_confidence")
                        conf_s = f"{float(conf):.1f}" if conf is not None else "—"
                        method = r.get("enum_match_method") or "—"
                        lines.append(f"| {place} | {nm} | {idf} | {conf_s} | {method} |")
                lines.append("")
        else:
            lines.append("## Tournaments")
            lines.append("")
            lines.append("_(no run id — drafts unavailable)_")
            lines.append("")

    # (Fencer matching block is now at the very top of the summary —
    # it's the most important quality signal so it leads the report.)

    # Pool rounds detected — verify the splitter caught them all
    pool_brackets = pool_brackets or []
    lines.append(f"## Pool rounds detected ({len(pool_brackets)} brackets)")
    lines.append("")
    if pool_brackets:
        lines.append("| Weapon | Bracket name | Reason | URL |")
        lines.append("|---|---|---|---|")
        # Sort by weapon then name for readability
        for b in sorted(pool_brackets, key=lambda x: (str(x.get("weapon") or ""), x.get("name", ""))):
            wpn = b.get("weapon") or "?"
            nm = b.get("name", "?")
            rsn = b.get("reason", "?")
            u = b.get("url", "")
            lines.append(f"| {wpn} | {nm} | {rsn} | {u} |")
        # Pool-rounds-per-weapon count summary
        from collections import Counter
        per_w = Counter(str(b.get("weapon") or "?") for b in pool_brackets)
        lines.append("")
        lines.append("**Per-weapon pool-round count** (SPWS rule: ≤ 2 per weapon):")
        lines.append("")
        lines.append("| Weapon | Pool rounds |")
        lines.append("|---|---:|")
        for w, n in sorted(per_w.items()):
            flag = " ⚠" if n > 2 else ""
            lines.append(f"| {w} | {n}{flag} |")
    else:
        lines.append("_(none detected — splitter found no Mixed/DE/etc. brackets and no per-bracket gender-mix halts fired)_")
    lines.append("")

    if pool_warnings:
        lines.append("**Pool-count warnings:**")
        lines.append("")
        for w in pool_warnings:
            lines.append(f"- {w}")
        lines.append("")

    # Tricky parts
    lines.append("## Tricky parts")
    lines.append("")
    tricky: list[str] = []
    if halted:
        tricky.append(f"❌ {halted} bracket(s) halted at a pipeline stage.")
    if excs:
        tricky.append(f"🔥 {excs} bracket(s) raised exceptions during pipeline run.")
    if pool_warnings:
        tricky.append(f"⚠ {len(pool_warnings)} pool-count warning(s) above.")
    if not tricky:
        lines.append("_(none — clean run)_")
    else:
        for t in tricky:
            lines.append(f"- {t}")

    # Sign-off block
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## ✋ Sign-off required")
    lines.append("")
    lines.append("This run is in **drafts** — nothing committed to live tables yet.")
    lines.append("")
    lines.append(f"- **Run ID:** `{run_id or '(no run id)'}`")
    lines.append(f"- **Event code:** `{event_code}`")
    lines.append("")
    lines.append("**Review the tables above.** Verify pool rounds were correctly classified and no real tournament was skipped. When satisfied, sign off by committing:")
    lines.append("")
    lines.append("```")
    lines.append(f"python -m python.tools.phase5_runner --commit-run-id {run_id or '<run_id>'}")
    lines.append("```")
    lines.append("")
    lines.append("If something is wrong, **do not commit** — discard via `fn_discard_event_draft('<run_id>')` and re-run.")
    return "\n".join(lines)


if __name__ == "__main__":
    sys.exit(main())
