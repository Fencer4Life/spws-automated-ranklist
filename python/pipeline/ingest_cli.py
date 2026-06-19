"""
CLI entry point for the ingestion pipeline.

Two ingest modes:

1. **Unified XML ingest (Phase 6, post-ADR-050)** — `ingest_xml_unified()`.
   Routes local XMLs through the same S1-S7 pipeline + DraftStore the URL
   path uses, so url_results lands on every draft row and the joint-pool
   detector inside fn_commit_event_draft fires on commit (ADR-049).

2. **Legacy direct write** — `run_ingest()` → `orchestrator.process_xml_file`.
   Bypasses drafts and joint-pool detection; kept only for backward
   compatibility with `--from-storage` until the storage harness migrates.
   Emits a DeprecationWarning on every call.

Usage:
    # Unified (post-fix) — for a known event_code with url_event populated:
    python -m pipeline.ingest_cli --event-code PPW4-SPWS-2025-2026 \\
        path/to/file1.xml path/to/file2.xml --season-end-year 2026
    # Then commit the draft batch:
    python -m pipeline.ingest_cli --commit-draft <run_id>

    # Legacy direct write (deprecated):
    python -m pipeline.ingest_cli path/to/file.xml --season-end-year 2026
"""

from __future__ import annotations

import argparse
import os
import sys
import uuid
import zipfile
from dataclasses import dataclass, field
from io import BytesIO
from pathlib import Path

from python.pipeline.db_connector import create_db_connector
from python.pipeline.draft_diff import format_diff
from python.pipeline.draft_store import DraftStore
from python.pipeline.notifications import TelegramNotifier
from python.pipeline.orchestrator import IngestResult, process_xml_file
from python.pipeline.storage_handler import unzip_in_memory


def run_ingest(
    path: str,
    season_end_year: int,
    dry_run: bool = False,
    tournament_type: str = "PPW",
    db=None,
    notifier=None,
) -> IngestResult:
    """Process a local XML file or .zip archive.

    Args:
        path: Path to .xml or .zip file.
        season_end_year: End year of the active season.
        dry_run: If True, skip DB writes.
        tournament_type: Default tournament type for routing.
        db: Optional DbConnector (created from env if None).
        notifier: Optional TelegramNotifier (created from env if None).

    Returns:
        Combined IngestResult.
    """
    if db is None:
        db = create_db_connector()
    if notifier is None:
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )

    filepath = Path(path)

    if filepath.suffix.lower() == ".zip":
        zip_bytes = filepath.read_bytes()
        xml_files = unzip_in_memory(zip_bytes)
        combined = IngestResult()
        for fname, xml_bytes in xml_files.items():
            r = process_xml_file(
                file_bytes=xml_bytes,
                filename=fname,
                db=db,
                notifier=notifier,
                season_end_year=season_end_year,
                tournament_type=tournament_type,
                dry_run=dry_run,
            )
            combined.tournament_ids.extend(r.tournament_ids)
            combined.matched += r.matched
            combined.pending += r.pending
            combined.auto_created += r.auto_created
            combined.skipped += r.skipped
            combined.errors.extend(r.errors)
            combined.skipped_files.extend(r.skipped_files)
        notifier.summary(combined)
        return combined
    else:
        xml_bytes = filepath.read_bytes()
        r = process_xml_file(
            file_bytes=xml_bytes,
            filename=filepath.name,
            db=db,
            notifier=notifier,
            season_end_year=season_end_year,
            tournament_type=tournament_type,
            dry_run=dry_run,
        )
        notifier.summary(r)
        return r


def ingest_xml_unified(
    path: str | list[str],
    event_code: str,
    season_end_year: int,
    url_event_override: str | None = None,
    db=None,
    notifier=None,
    dry_run: bool = False,
) -> str | None:
    """Unified XML ingest — the post-ADR-050 replacement for `process_xml_file`.

    Looks up the event's `url_event` (from `tbl_event.url_event` unless
    `url_event_override` is given), parses each XML with that URL set as
    `source_url`, runs the S1-S7 pipeline via `run_pipeline`, and
    materializes drafts under a single `run_id` via `DraftStore`.

    The caller commits via `--commit-draft <run_id>`, which routes through
    `fn_commit_event_draft` — the function that sets `bool_joint_pool_split`
    on sibling rows sharing `url_results` and re-sums
    `int_participant_count` to the full pool size (ADR-049). Bypassing this
    path (as `process_xml_file` did) silently leaves V-cat slices like
    35 / 36 fencers instead of the full combined-pool size.

    Args:
        path: One XML path, or a list of XML paths under the same event.
        event_code: Event identifier (e.g. "PPW4-SPWS-2025-2026").
        season_end_year: Active season's end year (e.g. 2026).
        url_event_override: If given, used instead of tbl_event.url_event.
        db: DbConnector (created from env if None).
        notifier: TelegramNotifier (created from env if None).
        dry_run: Parse + pipeline only; do not write drafts.

    Returns:
        run_id (str) if drafts were materialized; None if dry_run.

    Raises:
        ValueError: event_code not found, or no url_event populated.
    """
    # Defer imports so test patches on these symbols are honoured.
    from python.scrapers import fencingtime_xml as _ft_xml
    from python.pipeline.review_cli import ReviewSession

    if db is None:
        db = create_db_connector()
    if notifier is None:
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )

    event = db.find_event_by_code(event_code)
    if event is None:
        raise ValueError(
            f"Event {event_code!r} not found in tbl_event. "
            f"Populate it first or check the spelling."
        )

    url_event = (
        url_event_override
        or event.get("url_event")
        or event.get("url_results")
    )
    if not url_event:
        raise ValueError(
            f"Event {event_code!r} has no url_event populated. "
            f"Populate it first:\n"
            f"  UPDATE tbl_event SET url_event = '<URL>' "
            f"WHERE txt_code = '{event_code}';"
        )

    paths = [path] if isinstance(path, (str, Path)) else list(path)

    draft_store = DraftStore(db)
    session = ReviewSession(
        event_code=event_code,
        db=db,
        draft_store=draft_store,
        # ReviewSession's prompt/output callables are unused in batch mode —
        # we drive run_iteration directly without going through its
        # interactive loop. Pass safe defaults so nothing blocks on stdin.
        prompt=lambda _msg: "q",
        output=print,
        season_end_year=season_end_year,
        notifier=notifier,
    )
    # Skip URL reachability validation in batch — the operator vouches for
    # the url_event they populated, and the offline batch path may not have
    # network access to FTL's authed endpoint.
    session.skip_url_validation = True

    # Strip any pre-existing #fragment (e.g. FTL's `#today` decoration)
    # so we don't end up with double-hash URLs like `...#today#FILE.xml`.
    # The first `#` is what browsers honour, so a single per-file fragment
    # keeps the URL clickable AND distinct per source file.
    url_event_base = url_event.split("#", 1)[0]

    for p in paths:
        p_str = str(p)
        file_bytes = Path(p_str).read_bytes()
        # Per-file source_url: event URL + filename fragment. Result:
        #   * each XML file gets a distinct url_results (the fragment),
        #     so the joint-pool detector only groups siblings *within*
        #     one XML (legitimate V0+V1 combined bracket) and never
        #     across files (standalone V2/V3/V4 stay independent).
        #   * The URL remains clickable to the event page (browsers
        #     ignore the # fragment when no matching id exists), so the
        #     UI shows a working link instead of a dead `file://`.
        per_file_url = f"{url_event_base}#{Path(p_str).name}"
        parsed = _ft_xml.parse(file_bytes, source_url=per_file_url)

        if dry_run:
            # Run S1-S7 but skip draft writes — useful for diagnostics.
            from python.pipeline.orchestrator import run_pipeline
            from python.pipeline.overrides import load_for_event
            ctx = run_pipeline(
                parsed=parsed,
                overrides=load_for_event(event_code),
                db=db,
                season_end_year=season_end_year,
                event_code=event_code,
            )
            print(
                f"[dry-run] {p_str}: matches={len(ctx.matches)}, "
                f"halted={ctx.halted}, "
                f"halt={(ctx.halt_reason.value if ctx.halt_reason else '-')}"
            )
            continue

        # Pre-check for structural pool-only files — skip cleanly with a
        # log line before the session writes anything. The pipeline would
        # halt on these anyway via s1_validate_ir, but pre-checking lets
        # us avoid noisy halt-state output for an expected-skip.
        if getattr(parsed, "is_pool_only_qualifier", False):
            print(
                f"  {p_str}: SKIPPED (pool-only qualifier — no DE bracket)"
            )
            continue

        ctx, _ = session.run_iteration(parsed)
        print(
            f"  {p_str}: matches={len(ctx.matches)}, halted={ctx.halted}, "
            f"run_id={session.run_id}"
        )

    return session.run_id if not dry_run else None


def ingest_via_flow(
    path: str | list[str],
    event_code: str,
    season_end_year: int,
    url_event_override: str | None = None,
    db=None,
    notifier=None,
) -> list:
    """NEW pipeline ingest (Step B) — route each source through `run_flow`.

    Parses each XML via the `fencingtime_xml` parser (the FENCINGTIME_XML entry
    in the `scrapers.PARSERS` registry), injects the IR into `svc.config["parsed"]`,
    and runs `INGEST_DOMESTIC`. `Commit` writes live atomically per V-cat bracket
    (Step A) — there is NO draft/review gate (ADR-074: faults auto-resolve inline,
    auto-commit). This is the operator entry point the engine previously lacked.

    Per-file `source_url` = `url_event#<filename>` (same convention as the legacy
    unified path) so each file's rows carry distinct provenance. Pool-only
    qualifier files (no DE bracket) are skipped cleanly.

    Returns one `Context` per ingested file (skipped files omitted).

    Raises:
        ValueError: event_code not found in tbl_event.
    """
    # Deferred imports so test patches on these symbols are honoured and the
    # heavy engine modules only load when this path is taken.
    from python.scrapers import fencingtime_xml as _ft_xml
    from python.pipeline.core.contract import Services
    from python.pipeline.engine.flows import Flow, FlowParams
    from python.pipeline.overrides import load_for_event
    from python.pipeline.run import run_flow

    if db is None:
        db = create_db_connector()
    if notifier is None:
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )

    event = db.find_event_by_code(event_code)
    if event is None:
        raise ValueError(
            f"Event {event_code!r} not found in tbl_event. "
            f"Populate it first or check the spelling."
        )

    url_event = (
        url_event_override
        or event.get("url_event")
        or event.get("url_results")
    )
    url_event_base = (url_event or "").split("#", 1)[0]
    overrides = load_for_event(event_code)
    paths = [path] if isinstance(path, (str, Path)) else list(path)

    contexts = []
    for p in paths:
        p_str = str(p)
        file_bytes = Path(p_str).read_bytes()
        per_file_url = (
            f"{url_event_base}#{Path(p_str).name}" if url_event_base else None
        )
        parsed = _ft_xml.parse(file_bytes, source_url=per_file_url)

        if getattr(parsed, "is_pool_only_qualifier", False):
            print(f"  {p_str}: SKIPPED (pool-only qualifier — no DE bracket)")
            continue

        ctx = _run_parsed_through_flow(parsed, event_code, season_end_year, overrides, db, label=p_str)
        contexts.append(ctx)
    _fire_staging_report(event, contexts, db, notifier=notifier)  # ADR-075
    return contexts


def _run_parsed_through_flow(parsed, event_code, season_end_year, overrides, db,
                             *, label="", commit_cats=None):
    """Route one already-parsed IR bracket through `run_flow(INGEST_DOMESTIC)` and
    print a one-line commit summary. Shared by the file path (`ingest_via_flow`)
    and the URL path (`ingest_event_from_url`). `commit_cats` (the keep-rule's owned
    set, N13.3) restricts which categories `Commit` may write — None ⇒ write all."""
    from python.pipeline.core.contract import Services
    from python.pipeline.engine.flows import Flow, FlowParams
    from python.pipeline.run import run_flow

    svc = Services(db=db, config={
        "parsed": parsed,
        "overrides": overrides,
        "season_end_year": season_end_year,
        "event_code": event_code,
        "commit_cats": commit_cats,
    })
    ctx = run_flow(FlowParams(Flow.INGEST_DOMESTIC), svc=svc)
    committed = ctx.get("committed") or {}
    faults = [f.kind.value for f in ctx.faults]
    if committed.get("skipped"):
        print(f"  {label}: SKIPPED (dropped {committed.get('dropped')}) faults={faults}")
    else:
        tournaments = committed.get("tournaments") or []
        summary = ", ".join(f"{t['vcat']}→t{t['id_tournament']}(n={t['n']})" for t in tournaments)
        print(f"  {label}: committed {len(tournaments)} bracket(s): {summary} faults={faults}")
    return ctx


def _send_staging_via_telegram(notifier, event_code, post_ctx, *, n_tournaments=None):
    """N15 — send the rendered staging report(s) to Telegram (reuses ADR-059
    send_staging_report / send_document). `post_ctx` is the POST_COMMIT Context the
    StagingFormatter stashed `_rendered_md` / `_rendered_diff` on. Best-effort: a
    Telegram hiccup never fails the (already-committed) ingest."""
    if notifier is None or post_ctx is None:
        return
    md = post_ctx.get("_rendered_md")
    diff = post_ctx.get("_rendered_diff")
    try:
        if md:
            extras = {"reason": "cert-reingest",
                      "promote_hint": f"reply `promote {event_code.split('-')[0]}` to push to PROD"}
            if n_tournaments is not None:
                extras["tournament_count"] = n_tournaments
            notifier.send_staging_report(
                event_code=event_code, md_bytes=md.encode("utf-8"),
                kind="full", extras=extras)
        if diff:
            notifier.send_document(
                diff.encode("utf-8"), f"{event_code}-diff.md",
                f"🔀 <b>{event_code}</b> · 3-way diff")
    except Exception as e:                       # never fail a committed ingest on delivery
        print(f"  (Telegram staging send skipped: {e})")


def _fire_staging_report(event, contexts, db, *, schedule_skips=None, notifier=None,
                         source_decisions=None, md_target="local"):
    """Event-scoped POST_COMMIT fire (ADR-075) — render the per-event review files.

    The per-bracket runs each accumulated a `report` (the fifth Context channel);
    here we seed ONE event-level Context with all of them (`_bracket_reports`) so
    `StagingFormatter` shapes them into `<EVENT>.<ts>.md` + `.diff.md` exactly once.
    `source_decisions` (N13) is the keep-rule's per-round verdict (committed / dropped
    pools-only / skipped duplicate) for the omitted + duplicate sections.
    `react=False`: this IS a POST_COMMIT, so it must not re-fire itself.
    """
    if not contexts:
        return None
    from python.pipeline.core.contract import Context, Services
    from python.pipeline.engine.flows import Flow, FlowParams
    from python.pipeline.run import run_flow

    ctx = Context()
    ctx.data["_bracket_reports"] = [c.report for c in contexts]
    ctx.data["event"] = event
    if schedule_skips:
        ctx.data["_schedule_skips"] = schedule_skips
    if source_decisions:
        ctx.data["_source_decisions"] = source_decisions
    svc = Services(db=db,
                   config={"event_code": event.get("txt_code"), "md_target": md_target},
                   notifier=notifier)
    return run_flow(
        FlowParams(Flow.POST_COMMIT, id_event=event.get("id_event")),
        ctx=ctx, svc=svc, react=False,
    )


def _wipe_event_live(db, id_event: int) -> tuple[int, int]:
    """Delete an event's committed results + tournaments (for a clean re-ingest).
    Returns (results_deleted, tournaments_deleted). Keeps the event row."""
    sb = db._sb
    tids = [t["id_tournament"] for t in
            sb.table("tbl_tournament").select("id_tournament").eq("id_event", id_event).execute().data or []]
    rids = [r["id_result"] for r in
            (sb.table("tbl_result").select("id_result").in_("id_tournament", tids).execute().data or [])] if tids else []
    if rids:
        sb.table("tbl_match_candidate").delete().in_("id_result", rids).execute()
        sb.table("tbl_result").delete().in_("id_tournament", tids).execute()
    for tid in tids:
        sb.table("tbl_tournament").delete().eq("id_tournament", tid).execute()
    return len(rids), len(tids)


# FTL endpoints (reused by the URL ingest path).
_FTL_DATA = "https://www.fencingtimelive.com/events/results/data/"
_FTL_RESULTS = "https://www.fencingtimelive.com/events/results/"


def _ftl_has_direct_elimination(client, uuid: str) -> bool:
    """True iff the FTL results page for this round has a DE/Tableau bracket (N13.1).

    A round with pools but no Tableau is a **pools-only qualifier** (ADR-067) and must
    never be scored — this is the from-URL analog of the XML `<Poule>`-no-`<Tableau>`
    check (which only the fencingtime_xml parser had)."""
    import re
    resp = client.get(f"{_FTL_RESULTS}{uuid}")
    resp.raise_for_status()
    return bool(re.search(r"(?i)tableau", resp.text))


def _resolve_sources(rounds, overrides=None):
    """Apply the keep-rule to the discovered FTL rounds (N13.3, ADR domain logic).

    `rounds`: list of dicts `{name, uuid, url, weapon, gender, cats:list[str],
    count:int, has_de:bool}`. `overrides`: `{"skip":[url…], "process":[url…]}` (admin
    choices from the event accordion; `process` forces a round to win, `skip` drops it).

    Returns one enriched record per round: `status` (committed|dropped|skipped),
    `commit_cats` (the categories it owns / will write), `reason`, and `duplicate_of`
    (for a set-aside round, the categories it lost and to which kept round).

    Rules: (1) no DE → dropped (pools-only). (2) per `(weapon,gender,category)` keep
    exactly one source — a dedicated single (one category) beats a BRACKET; else the
    smaller-count source; an admin `process` url forces; an admin `skip` url drops.
    """
    from collections import defaultdict

    overrides = overrides or {}
    skip_urls = set(overrides.get("skip") or [])
    process_urls = set(overrides.get("process") or [])

    rec = {r["uuid"]: {**r, "single": len(r["cats"]) == 1, "status": None,
                       "commit_cats": [], "reason": "", "duplicate_of": []}
           for r in rounds}

    alive = []
    for r in rounds:
        d = rec[r["uuid"]]
        if not r["has_de"]:
            d["status"], d["reason"] = "dropped", "pools-only (no DE)"
        elif r["url"] in skip_urls:
            d["status"], d["reason"] = "skipped", "admin: skipped"
        else:
            alive.append(r)

    candidates = defaultdict(list)
    for r in alive:
        for v in r["cats"]:
            candidates[(r["weapon"], r["gender"], v)].append(r)

    owner = {}
    for cat, cs in candidates.items():
        forced = [r for r in cs if r["url"] in process_urls]
        singles = [r for r in cs if len(r["cats"]) == 1]
        if len(forced) == 1:
            owner[cat] = forced[0]
        elif len(singles) == 1:
            owner[cat] = singles[0]
        elif len(singles) > 1:
            owner[cat] = None                      # anomaly: two dedicated singles
        else:
            owner[cat] = min(cs, key=lambda r: r["count"])   # smaller BRACKET wins

    for r in alive:
        d = rec[r["uuid"]]
        owned = [v for v in r["cats"]
                 if owner.get((r["weapon"], r["gender"], v)) is r]
        d["commit_cats"] = owned
        if owned:
            d["status"] = "committed"
        else:
            d["status"] = "skipped"
            d["reason"] = "duplicate — categories owned by a kept source"
            d["duplicate_of"] = [
                {"category": v, "kept": k["name"]}
                for v in r["cats"]
                if (k := owner.get((r["weapon"], r["gender"], v))) is not None and k is not r
            ]
    return list(rec.values())


def ingest_event_from_url(
    event_code: str,
    season_end_year: int,
    db=None,
    notifier=None,
    replace: bool = False,
    url_event_override: str | None = None,
    send_telegram: bool = False,
    md_target: str = "local",
) -> list:
    """NEW pipeline ingest of a whole SPWS FTL event from its `url_event`
    (eventSchedule) — the URL entry the engine previously lacked (§3.2 gap).

    REUSES the existing scrapers end-to-end: `get_authed_ftl_client` (auth),
    `parse_event_schedule` (bracket discovery + MIKST/DE/guest skip filters),
    `parse_tournament_name` (name → weapon/gender/V-cat, combined → split-by-BY),
    `ftl.parse_json` (FTL data → IR). Each discovered bracket is routed through
    `run_flow(INGEST_DOMESTIC)` (Step B), so `Commit` writes live per V-cat bracket.

    `replace=True` wipes the event's existing results+tournaments first (a clean
    re-ingest). No notifier is built unless one is passed (avoids Telegram).
    """
    from datetime import date as _date

    from python.scrapers import ftl
    from python.scrapers.ftl_auth import get_authed_ftl_client, normalize_ftl_url
    from python.pipeline.ir import ParsedTournament, SourceKind
    from python.pipeline.overrides import load_for_event
    from python.tools.scrape_ftl_event_urls import (
        parse_event_schedule, parse_tournament_name,
    )

    if db is None:
        db = create_db_connector()

    event = db.find_event_by_code(event_code)
    if event is None:
        raise ValueError(f"Event {event_code!r} not found in tbl_event.")
    # N15: the Telegram `ingest <prefix> <url>` command supplies the FTL URL. It is an
    # admin-managed write to tbl_event.url_event (operator-entered, never auto-scraped),
    # then we ingest from it.
    if url_event_override:
        if hasattr(db, "set_event_url_event"):
            db.set_event_url_event(event["id_event"], url_event_override)
        event["url_event"] = url_event_override
    url_event = url_event_override or event.get("url_event") or event.get("url_results")
    if not url_event:
        raise ValueError(f"Event {event_code!r} has no url_event populated.")

    overrides = load_for_event(event_code)                      # identity/alias overrides
    src_overrides = event.get("json_source_overrides")          # admin skip/process (N13.4 col; None until set)
    dt = str(event.get("dt_start") or "")[:10]
    parsed_date = _date.fromisoformat(dt) if dt else None
    contexts = []

    with get_authed_ftl_client() as client:
        sched = client.get(normalize_ftl_url(url_event))
        sched.raise_for_status()
        kept, skipped = parse_event_schedule(sched.text, with_skips=True)
        print(f"discovered {len(kept)} round(s), {len(skipped)} schedule-skipped")
        for s in skipped:
            print(f"  schedule-skip {s['name']!r}: {s['reason']}")

        if replace:
            nr, nt = _wipe_event_live(db, event["id_event"])
            print(f"replace: deleted {nr} results + {nt} tournaments\n")

        # 1) classify each kept round: DE present? which categories? how many fencers?
        round_recs = []
        for b in kept:
            pn = parse_tournament_name(b["name"])
            if pn is None:
                print(f"  SKIP {b['name']!r}: unparseable name")
                continue
            combined = isinstance(pn, list)
            weapon, gender = (pn[0][0], pn[0][1]) if combined else (pn[0], pn[1])
            cats = [t[2] for t in pn] if combined else [pn[2]]
            url = f"{_FTL_RESULTS}{b['uuid']}"
            has_de = _ftl_has_direct_elimination(client, b["uuid"])   # Rule 1 (pools-only drop)
            resp = client.get(f"{_FTL_DATA}{b['uuid']}")
            resp.raise_for_status()
            base = ftl.parse_json(resp.json(), source_url=url)
            round_recs.append(dict(
                name=b["name"], uuid=b["uuid"], url=url, weapon=weapon, gender=gender,
                cats=cats, count=len(base.results), has_de=has_de, _base=base))

        # 2) keep-rule: one source per category (Rule 2), honouring admin overrides
        decisions = _resolve_sources(round_recs, overrides=src_overrides)
        dec = {d["uuid"]: d for d in decisions}

        # 3) ingest only the categories each committed round OWNS (commit_cats)
        for r in round_recs:
            d = dec[r["uuid"]]
            if d["status"] != "committed":
                print(f"  {d['status'].upper()} {r['name']!r}: {d['reason']}")
                continue
            combined = len(r["cats"]) != 1
            parsed = ParsedTournament(
                source_kind=SourceKind.FTL, results=r["_base"].results,
                raw_pool_size=len(r["_base"].results), weapon=r["weapon"], gender=r["gender"],
                category_hint=None if combined else r["cats"][0], parsed_date=parsed_date,
                season_end_year=season_end_year, source_url=r["url"],
                organizer_hint="SPWS", tournament_name=r["name"])
            label = f"{r['name']} [{r['weapon']}/{r['gender']}, owns {d['commit_cats']}]"
            contexts.append(_run_parsed_through_flow(
                parsed, event_code, season_end_year, overrides, db,
                label=label, commit_cats=set(d["commit_cats"])))

    # 4) persist the discovered rounds + status for the event accordion (N13.4)
    sources = _ingest_source_records(decisions, skipped)
    if hasattr(db, "set_event_ingest_sources"):
        try:
            db.set_event_ingest_sources(event["id_event"], sources)
        except Exception as e:  # never fail an ingest on the display-data write
            print(f"  (ingest-sources persist skipped: {e})")

    post = _fire_staging_report(event, contexts, db, schedule_skips=skipped,
                                source_decisions=sources, notifier=notifier,
                                md_target=md_target)  # ADR-075
    if send_telegram:
        _send_staging_via_telegram(notifier, event_code, post, n_tournaments=len(contexts))
    return contexts


def _ingest_source_records(decisions, schedule_skips):
    """Shape the keep-rule decisions + schedule skips into the display records stored
    on `tbl_event.json_ingest_sources` and shown in the accordion (N13.4)."""
    out = []
    for d in decisions:
        out.append({
            "name": d["name"], "url": d["url"],
            "weapon": d.get("weapon"), "gender": d.get("gender"),
            "categories": d.get("cats", []), "count": d.get("count"),
            "status": d["status"], "reason": d.get("reason", ""),
            "committed_categories": d.get("commit_cats", []),
            "duplicate_of": d.get("duplicate_of", []),
        })
    for s in (schedule_skips or []):
        # Build the FTL results URL from the skip's uuid so the operator can click
        # and validate a name-skipped round (e.g. ELIMINACJE) really is a pools round.
        uuid = s.get("uuid")
        out.append({"name": s["name"],
                    "url": f"{_FTL_RESULTS}{uuid}" if uuid else None,
                    "status": "dropped", "reason": s["reason"],
                    "categories": [], "count": None})
    return out


def _handle_draft_commands(args, notifier) -> bool:
    """Phase 2 (ADR-050) draft-management commands.

    Returns True if a draft command was invoked (caller should exit), False
    otherwise (caller continues with the path/from-storage flow).
    """
    db = create_db_connector()
    store = DraftStore(db)

    if args.list_drafts:
        drafts = store.list_drafts()
        if not drafts:
            print("No outstanding drafts.")
            return True
        print(f"{'run_id':<40}  {'tournaments':>11}  {'results':>7}  first_seen")
        for d in drafts:
            print(
                f"{d['run_id']:<40}  {d['tournament_count']:>11}  "
                f"{d['result_count']:>7}  {d.get('first_seen', '?')}"
            )
        return True

    if args.commit_draft:
        result = store.commit(args.commit_draft)
        n_t = result.get("tournaments_committed", 0)
        n_r = result.get("results_committed", 0)
        if n_t == 0 and n_r == 0:
            # Per Decision D1: zero-count outcome → Telegram warning + exit 1
            notifier.warning(
                f"Commit target {args.commit_draft} not found "
                f"(0 tournaments, 0 results). Run --list-drafts to inspect."
            )
            print(f"⚠ No draft found for run_id {args.commit_draft}")
            sys.exit(1)
        print(
            f"Committed draft {args.commit_draft}: {n_t} tournaments, {n_r} results, "
            f"{result.get('joint_pool_siblings_flagged', 0)} joint-pool siblings flagged."
        )
        return True

    if args.discard_draft:
        result = store.discard(args.discard_draft)
        n_t = result.get("tournaments_discarded", 0)
        n_r = result.get("results_discarded", 0)
        if n_t == 0 and n_r == 0:
            notifier.warning(
                f"Discard target {args.discard_draft} not found "
                f"(0 tournaments, 0 results)."
            )
            print(f"⚠ No draft found for run_id {args.discard_draft}")
            sys.exit(1)
        print(f"Discarded draft {args.discard_draft}: {n_t} tournaments, {n_r} results.")
        return True

    if args.resume_run_id:
        tournaments, results = store.read_drafts(args.resume_run_id)
        if not tournaments and not results:
            print(f"⚠ No draft found for run_id {args.resume_run_id}")
            sys.exit(1)
        # Build a payload that matches the dry-run RPC shape so format_diff
        # can render the same markdown.
        payload = {"tournaments": tournaments, "results": results}
        # Local computation of the rpc_result counts (no RPC call needed).
        rpc_result = {
            "tournaments_would_create": len(tournaments),
            "results_would_create": len(results),
            "joint_pool_sibling_groups": _count_joint_groups(tournaments),
        }
        md = format_diff(
            run_id=args.resume_run_id,
            payload=payload,
            rpc_result=rpc_result,
            event_match=None,
        )
        print(md)
        return True

    return False


def _count_joint_groups(tournaments: list[dict]) -> int:
    """Count distinct (weapon, gender, url_results) groups with ≥2 tournaments."""
    from collections import Counter
    keys = Counter(
        (t.get("enum_weapon"), t.get("enum_gender"), t.get("url_results"))
        for t in tournaments
        if t.get("url_results")
    )
    return sum(1 for count in keys.values() if count >= 2)


def main() -> None:
    parser = argparse.ArgumentParser(description="Ingest FencingTime XML results")
    parser.add_argument("path", nargs="*",
                        help="Path(s) to .xml or .zip file(s). With "
                             "--event-code, multiple XMLs land in a single "
                             "draft batch (one run_id).")
    parser.add_argument("--season-end-year", type=int)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--tournament-type", default="PPW")
    parser.add_argument("--from-storage", action="store_true",
                        help="Process files from Supabase Storage staging/ "
                             "(legacy direct-write path; deprecated).")
    parser.add_argument("--event-code", default=None,
                        help="Route XML through the unified pipeline for "
                             "this event_code (recommended). Joint-pool + "
                             "url_results are handled at commit via "
                             "fn_commit_event_draft (ADR-049).")
    parser.add_argument("--url-event", default=None,
                        help="Override tbl_event.url_event for this run "
                             "(used only with --event-code / --flow).")
    parser.add_argument("--flow", choices=["ingest_domestic"], default=None,
                        help="Route through the NEW rule-driven pipeline "
                             "(run_flow). Requires --event-code. Commit writes "
                             "live atomically per V-cat bracket — no draft gate "
                             "(ADR-074).")
    parser.add_argument("--from-url", action="store_true",
                        help="With --flow: ingest the whole event from its "
                             "tbl_event.url_event (FTL eventSchedule), reusing the "
                             "FTL scrapers. No XML paths needed.")
    parser.add_argument("--replace", action="store_true",
                        help="With --flow --from-url: wipe the event's existing "
                             "results+tournaments before re-ingesting.")
    parser.add_argument("--send-telegram", action="store_true",
                        help="With --flow --from-url: send the staging report(s) "
                             "(full + diff) to Telegram (ADR-059 reuse).")
    parser.add_argument("--md-target", choices=["local", "storage", "both"],
                        default="local",
                        help="Where the staging .md lands: local FS (default), the "
                             "Supabase Storage bucket, or both.")
    # Phase 2 (ADR-050) draft-management commands. Mutually exclusive with
    # each other; do not require --season-end-year.
    draft_group = parser.add_mutually_exclusive_group()
    draft_group.add_argument("--commit-draft", metavar="UUID",
                             help="Commit a materialized draft to live tables")
    draft_group.add_argument("--discard-draft", metavar="UUID",
                             help="Discard a materialized draft")
    draft_group.add_argument("--list-drafts", action="store_true",
                             help="List outstanding drafts (run_id, counts, age)")
    draft_group.add_argument("--resume-run-id", metavar="UUID",
                             help="Re-render the markdown diff for an existing draft")
    args = parser.parse_args()

    # Draft commands take precedence and don't need --season-end-year.
    is_draft_cmd = bool(
        args.list_drafts or args.commit_draft or args.discard_draft
        or args.resume_run_id
    )
    if not is_draft_cmd and args.season_end_year is None:
        parser.error("--season-end-year is required unless using a --*-draft / --list-drafts / --resume-run-id flag")

    if is_draft_cmd:
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )
        try:
            _handle_draft_commands(args, notifier)
        except SystemExit:
            raise
        except Exception as e:
            notifier.notify_pipeline_failure(str(e))
            raise
        return

    if args.flow:
        # NEW rule-driven pipeline path (Step B). Auto-commit, no draft gate.
        if not args.event_code:
            parser.error("--flow requires --event-code")
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )
        try:
            if args.from_url:
                ingest_event_from_url(
                    event_code=args.event_code,
                    season_end_year=args.season_end_year,
                    notifier=notifier,
                    replace=args.replace,
                    url_event_override=args.url_event,
                    send_telegram=args.send_telegram,
                    md_target=args.md_target,
                )
            else:
                if not args.path:
                    parser.error("--flow requires at least one XML path (or --from-url)")
                ingest_via_flow(
                    path=args.path,
                    event_code=args.event_code,
                    season_end_year=args.season_end_year,
                    url_event_override=args.url_event,
                    notifier=notifier,
                )
        except Exception as e:
            notifier.notify_pipeline_failure(str(e))
            raise
        return

    if args.from_storage:
        from python.pipeline.storage_handler import StorageHandler
        db = create_db_connector()
        from supabase import create_client
        sb = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
        storage = StorageHandler(sb)
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )

        try:
            staging_files = storage.list_staging_files()
            season = f"SPWS-{args.season_end_year - 1}-{args.season_end_year}"
            for fpath in staging_files:
                file_bytes = storage.download_file(fpath)
                fname = Path(fpath).name

                # Handle both .zip and .xml files in staging
                if fname.lower().endswith(".zip"):
                    xml_files = unzip_in_memory(file_bytes)
                elif fname.lower().endswith(".xml"):
                    xml_files = {fname: file_bytes}
                else:
                    continue

                for xname, xml_bytes in xml_files.items():
                    process_xml_file(
                        file_bytes=xml_bytes,
                        filename=xname,
                        db=db,
                        notifier=notifier,
                        season_end_year=args.season_end_year,
                        tournament_type=args.tournament_type,
                    )

            # ADR-025: do NOT auto-delete staging files — admin triggers cleanup via Telegram
            notifier.info(f"{len(staging_files)} file(s) in staging ready for cleanup.")
        except Exception as e:
            notifier.notify_pipeline_failure(str(e))
            raise
    elif args.event_code:
        # Unified pipeline path (post-ADR-050).
        if not args.path:
            parser.error("--event-code requires at least one XML path")
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )
        try:
            run_id = ingest_xml_unified(
                path=args.path,
                event_code=args.event_code,
                season_end_year=args.season_end_year,
                url_event_override=args.url_event,
                dry_run=args.dry_run,
                notifier=notifier,
            )
            if run_id:
                print(f"Draft batch run_id: {run_id}")
                print(f"Commit with: python -m python.pipeline.ingest_cli "
                      f"--commit-draft {run_id}")
        except Exception as e:
            notifier.notify_pipeline_failure(str(e))
            raise
    elif args.path:
        notifier = TelegramNotifier(
            os.environ.get("TELEGRAM_BOT_TOKEN"),
            os.environ.get("TELEGRAM_CHAT_ID"),
        )
        try:
            # Legacy path: nargs="*" gives a list; take the first element.
            path = args.path[0] if isinstance(args.path, list) else args.path
            result = run_ingest(
                path=path,
                season_end_year=args.season_end_year,
                dry_run=args.dry_run,
                tournament_type=args.tournament_type,
            )
            print(f"Matched: {result.matched}, Pending: {result.pending}, "
                  f"Auto-created: {result.auto_created}, Skipped: {result.skipped}")
            if result.errors:
                print(f"Errors: {result.errors}")
        except Exception as e:
            notifier.notify_pipeline_failure(str(e))
            raise
    else:
        parser.error("Either path or --from-storage is required")


if __name__ == "__main__":
    main()