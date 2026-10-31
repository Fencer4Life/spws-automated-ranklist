"""The brackets of an international event (ADR-113), and when each one is final (ADR-119 §1).

An EVF or FIE event, or any federation's on the international route, is read
from every result URL it holds (`url_event` … `url_event_5`), or, when it holds
none, from EVF's own results (ADR-105 §1.5: the organiser's results first,
EVF's only when nothing else exists):

- an FTL schedule is read here, so each listing keeps FTL's Finished flag
  (ADR-108 §7);
- any other URL (Engarde, 4fence, Ophardt, d'Artagnan, one results page) is
  read by the reader the Phase 5 runner uses, `Fetcher.fetch_event_url_with_skips`;
- EVF's results come from `evf_results.scrape_event_results`, one bracket per
  weapon, gender and category.

**The engine contract (D14 A).** Every engine answers one question per
bracket: is it final? `ENGINES` says which engines answer it themselves: FTL
(the schedule row says Finished) and Engarde (the competition's state is
"completed"). A bracket such an engine shows unfinished is skipped with a
reason that starts "not final", which keeps the event IN_PROGRESS. The other
engines say nothing, so a `Finality` decides (D2 B): the live ingest records
when it first saw each bracket's content and takes it once that content is 60
minutes old or the event's end date has passed (`Sightings`); promote's plan
takes exactly what the CERT run took (`TakenByRun`); the daily close, which
runs after the end date, takes everything published (`SETTLED`). A new engine
is one entry in `ENGINES`, its reader, and its row in
``doc/handbook/reference/organizers-and-engines.html``.

Each bracket is one listing in the shape the run record keeps (ADR-108 §4):
its name, its key (`uuid`: FTL's id, or the bracket's own results URL), its
weapon, gender and single category, its row count, the parse, and `finished`.
Team brackets are skipped (ADR-105 §5.5). A bracket without one V0–V4
category, or two sources for one bracket, refuses the event before anything is
written (ADR-105 §5.3, §5.4).

Ingest on CERT, promote's plan on PROD and the daily close all read the event
through here, source by source in the same order, so a schedule hashes the
same in all three.
"""

from __future__ import annotations

import datetime as dt
from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass, replace
from datetime import date
from typing import Any, Protocol

from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.promotion import lifecycle

SLOTS = ("url_event", "url_event_2", "url_event_3", "url_event_4", "url_event_5")
CATEGORIES = ("V0", "V1", "V2", "V3", "V4")
FTL_DATA = "https://www.fencingtimelive.com/events/results/data/"
FTL_RESULTS = "https://www.fencingtimelive.com/events/results/"
EVF_SOURCE = "evf:"
UNPARSEABLE = "unparseable name"
SETTLE_MINUTES = 60


# --------------------------------------------------------------------------
# The engine contract
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Engine:
    name: str
    label: str
    # True: the engine says itself when a bracket is final.
    signal: bool


ENGINES: dict[str, Engine] = {
    e.name: e
    for e in (
        Engine("ftl", "FencingTimeLive", True),
        Engine("engarde", "Engarde", True),
        Engine("fourfence", "4fence", False),
        Engine("ophardt", "Ophardt", False),
        Engine("dartagnan", "d'Artagnan", False),
        Engine("evf", "EVF results", False),
        Engine("page", "a single results page", False),
    )
}


def engine_of(url: str) -> str:
    """The engine a result URL is read with, as `Fetcher` dispatches it."""
    from python.pipeline.review_cli import (
        _is_dartagnan_index,
        _is_fourfence_event,
        _is_ophardt_tournament,
    )
    from python.scrapers.engarde import engarde_tournament

    if (url or "").startswith(EVF_SOURCE):
        return "evf"
    if _is_ftl_schedule(url):
        return "ftl"
    if engarde_tournament(url) is not None:
        return "engarde"
    if _is_fourfence_event(url):
        return "fourfence"
    if _is_ophardt_tournament(url):
        return "ophardt"
    if _is_dartagnan_index(url):
        return "dartagnan"
    return "page"


class Finality(Protocol):
    def settled(self, key: str, sha256: str) -> bool: ...


class _Settled:
    """Every published bracket is final: the event is over (the daily close)."""

    def settled(self, key: str, sha256: str) -> bool:
        del key, sha256  # every bracket, whatever its content
        return True


SETTLED = _Settled()


class Sightings:
    """The live ingest's rule (D2 B): a bracket is final once its content was
    first seen at least `SETTLE_MINUTES` ago, or once the event has ended.
    `record(key, sha256)` stores the sighting and answers its first time."""

    def __init__(
        self,
        record: Callable[[str, str], dt.datetime | str],
        *,
        now: dt.datetime,
        ended: bool,
    ):
        self.record = record
        self.now = now
        self.ended = ended

    def settled(self, key: str, sha256: str) -> bool:
        if self.ended:
            return True
        seen = self.record(key, sha256)
        first = (
            dt.datetime.fromisoformat(seen.replace("Z", "+00:00"))
            if isinstance(seen, str)
            else seen
        )
        return self.now - first >= dt.timedelta(minutes=SETTLE_MINUTES)


class TakenByRun:
    """Promote's plan: a bracket is final when the CERT run took exactly this
    content of it (ADR-108 §6). The plan never reads or writes a sighting."""

    def __init__(self, rounds: Iterable[Mapping[str, Any]]):
        self.taken = {str(r.get("uuid")): r.get("sha256") for r in rounds if r.get("sha256")}

    def settled(self, key: str, sha256: str) -> bool:
        return self.taken.get(key) == sha256


def sightings_for(
    db: Any, event: Mapping[str, Any], *, now: dt.datetime | None = None
) -> Sightings:
    """The live ingest's finality for an event: sightings stored through the
    connector, and ended once today in Warsaw is past the end date."""
    now = now or dt.datetime.now(dt.UTC)
    end = event.get("dt_end") or event.get("dt_start")
    ended = bool(end) and lifecycle.warsaw_today(now) > lifecycle.as_date(end)
    code = str(event.get("txt_code"))
    return Sightings(
        lambda key, sha: db.record_listing_sighting(code, key, sha), now=now, ended=ended
    )


# --------------------------------------------------------------------------
# The event's sources
# --------------------------------------------------------------------------


def event_sources(event: Mapping[str, Any], override: str | None = None) -> list[dict]:
    """The event's result slots and URLs in slot order, blanks and repeated
    URLs dropped. An operator's override URL replaces them all, as the
    event's `url_event`. An event with none reads EVF's results, recorded as
    the source `evf:<EVF event id>` so promote and the daily close read the
    same thing (Q3 A)."""
    if override:
        return [{"slot": "url_event", "url": override}]
    out: list[dict] = []
    for slot in SLOTS:
        url = (event.get(slot) or "").strip()
        if url and url not in (s["url"] for s in out):
            out.append({"slot": slot, "url": url})
    if not out and event.get("id_evf_event"):
        out.append({"slot": "evf", "url": f"{EVF_SOURCE}{int(event['id_evf_event'])}"})
    return out


def event_source_urls(event: Mapping[str, Any], override: str | None = None) -> list[str]:
    """The event's result URLs in slot order (`event_sources`)."""
    return [s["url"] for s in event_sources(event, override)]


def read_brackets(
    event: Mapping[str, Any],
    urls: list[str],
    *,
    fetcher: Any = None,
    evf_scrape: Callable[[int], list[dict]] | None = None,
    finality: Finality | None = None,
) -> tuple[list[dict], list[dict], list[dict]]:
    """Every final bracket of the event: (listings, schedule entries, skipped).

    The schedule entries are what the run record hashes as the event's
    schedule; the skipped entries are listed in the staging report. A source
    without a finished signal needs `finality`."""
    recs: list[dict] = []
    kept: list[dict] = []
    skipped: list[dict] = []
    if not urls:
        raise ValueError(
            f"Event {event.get('txt_code')!r} has no result URL and no EVF event to read "
            "EVF's results from. Set the organiser's results URL on the event (Admin)."
        )
    for url in urls:
        if url.startswith(EVF_SOURCE):
            r, s = _evf_brackets(int(url[len(EVF_SOURCE) :]), evf_scrape, finality)
            k = [{"uuid": x["uuid"], "name": x["name"], "finished": True} for x in r]
        elif _is_ftl_schedule(url):
            r, k, s = _ftl_schedule(url)
        else:
            r, k, s = _other_source(url, fetcher, finality)
        recs += r
        kept += k
        skipped += s
    _refuse_two_sources(event, recs)
    return recs, kept, skipped


def read_schedule(
    urls: list[str],
    *,
    fetcher: Any = None,
    evf_scrape: Callable[[int], list[dict]] | None = None,
    finality: Finality = SETTLED,
) -> tuple[list[dict], list[dict]]:
    """What the daily close re-reads for an international run (ADR-108 §7,
    ADR-113): each source classified as `read_brackets` classifies it, in the
    same order, so the pair hashes as the run recorded it. The close runs
    after the end date, so by default every published bracket is settled."""
    kept: list[dict] = []
    skipped: list[dict] = []
    for url in urls:
        if url.startswith(EVF_SOURCE):
            recs, s = _evf_brackets(int(url[len(EVF_SOURCE) :]), evf_scrape, finality)
            kept += [{"uuid": r["uuid"], "name": r["name"], "finished": True} for r in recs]
            skipped += s
        elif _is_ftl_schedule(url):
            from python.scrapers.ftl_auth import get_authed_ftl_client, normalize_ftl_url
            from python.tools.scrape_ftl_event_urls import parse_event_schedule

            with get_authed_ftl_client() as client:
                sched = client.get(normalize_ftl_url(url))
                sched.raise_for_status()
                listed, skips = parse_event_schedule(sched.text, with_skips=True)
            final, not_final = lifecycle.split_final(listed)
            kept += final
            skipped += [*skips, *not_final]
        else:
            _recs, k, s = _other_source(url, fetcher, finality)
            kept += k
            skipped += s
    return kept, skipped


def _is_ftl_schedule(url: str) -> bool:
    from python.pipeline.review_cli import _is_ftl_event_schedule

    return _is_ftl_event_schedule(url)


def _listing(parsed: ParsedTournament, *, name: str, uuid: str) -> dict:
    return {
        "name": name,
        "uuid": uuid,
        "url": parsed.source_url,
        "weapon": parsed.weapon,
        "gender": parsed.gender,
        "cats": [parsed.category_hint],
        "count": len(parsed.results),
        "has_de": True,
        "finished": True,
        "_base": parsed,
    }


def _settled(rec: Mapping[str, Any], engine: str, finality: Finality | None) -> bool:
    """For an engine without a signal: may this bracket be taken now?"""
    from python.pipeline.promotion.run_record import listing_sha256

    if finality is None:
        raise ValueError(
            f"{rec['name']!r} comes from {ENGINES[engine].label}, which gives no finished "
            "signal; the sightings rule (a Finality) must decide whether it is final, and "
            "none was given (ADR-119 §1)."
        )
    sha = listing_sha256(rec["name"], rec["uuid"], rec["has_de"], rec["_base"].results)
    return finality.settled(str(rec["uuid"]), sha)


def _waiting(rec: Mapping[str, Any]) -> dict:
    """The skip for a bracket from an engine without a signal, not yet settled."""
    return {
        "uuid": rec["uuid"],
        "name": rec["name"],
        "url": rec["url"],
        "weapon": rec["weapon"],
        "reason": lifecycle.SEEN_ONCE,
    }


def _refuse_uncategorised(name: str, url: str | None, category: str | None) -> None:
    if category not in CATEGORIES:
        raise ValueError(
            f"International bracket {name!r} ({url}) has no single source category "
            f"({category!r}); its results are filed under the bracket's own category and "
            "none is derived from birth years (ADR-105). Nothing was written."
        )


def _day(value: Any) -> date | None:
    try:
        return date.fromisoformat(str(value)[:10]) if value else None
    except ValueError:
        return None


def _ftl_schedule(url: str) -> tuple[list[dict], list[dict], list[dict]]:
    from python.scrapers import ftl
    from python.scrapers.ftl_auth import get_authed_ftl_client, normalize_ftl_url
    from python.tools.scrape_ftl_event_urls import parse_event_schedule, parse_tournament_name

    recs: list[dict] = []
    with get_authed_ftl_client() as client:
        sched = client.get(normalize_ftl_url(url))
        sched.raise_for_status()
        listed, skipped = parse_event_schedule(sched.text, with_skips=True)
        final, not_final = lifecycle.split_final(listed)
        named = []
        for b in final:
            pn = parse_tournament_name(b["name"])
            if pn is None:
                skipped.append({"uuid": b["uuid"], "name": b["name"], "reason": UNPARSEABLE})
                continue
            if isinstance(pn, list):
                (weapon, gender, _), category = pn[0], None
            else:
                weapon, gender, category = pn
            _refuse_uncategorised(b["name"], f"{FTL_RESULTS}{b['uuid']}", category)
            named.append((b, weapon, gender, category))
        for b, weapon, gender, category in named:
            resp = client.get(f"{FTL_DATA}{b['uuid']}")
            resp.raise_for_status()
            base = ftl.parse_json(resp.json(), source_url=f"{FTL_RESULTS}{b['uuid']}")
            parsed = replace(
                base,
                raw_pool_size=len(base.results),
                weapon=weapon,
                gender=gender,
                category_hint=category,
                source_url=f"{FTL_RESULTS}{b['uuid']}",
                tournament_name=b["name"],
                parsed_date=_day(b.get("day")),
            )
            recs.append(_listing(parsed, name=b["name"], uuid=b["uuid"]))
    return recs, final, [*skipped, *not_final]


def _other_source(
    url: str, fetcher: Any, finality: Finality | None
) -> tuple[list[dict], list[dict], list[dict]]:
    if fetcher is None:
        from python.pipeline.review_cli import Fetcher

        fetcher = Fetcher()
    engine = engine_of(url)
    parsed_list, reader_skips = fetcher.fetch_event_url_with_skips(url)
    skipped: list[dict] = []
    for s in reader_skips:
        if s.get("finished") is False:
            # The engine shows the bracket unfinished (Engarde's state).
            s = {**s, "reason": lifecycle.not_final_at(ENGINES[engine].label, s.get("state"))}
        skipped.append(s)
    recs: list[dict] = []
    for parsed in parsed_list:
        category = getattr(parsed, "category_hint", None)
        name = parsed.tournament_name or f"{parsed.weapon} {parsed.gender} {category}"
        _refuse_uncategorised(name, parsed.source_url, category)
        rec = _listing(parsed, name=name, uuid=parsed.source_url or name)
        if not ENGINES[engine].signal and not _settled(rec, engine, finality):
            skipped.append(_waiting(rec))
            continue
        recs.append(rec)
    kept = [{"uuid": r["uuid"], "name": r["name"], "finished": True} for r in recs]
    return recs, kept, skipped


def _evf_brackets(
    id_evf_event: int,
    evf_scrape: Callable[[int], list[dict]] | None,
    finality: Finality | None,
) -> tuple[list[dict], list[dict]]:
    if evf_scrape is None:
        from python.scrapers.evf_results import scrape_event_results

        evf_scrape = scrape_event_results
    groups: dict[tuple, list[dict]] = {}
    for row in evf_scrape(id_evf_event):
        key = (row.get("weapon"), row.get("gender"), row.get("category"))
        groups.setdefault(key, []).append(row)
    recs: list[dict] = []
    skipped: list[dict] = []
    for (weapon, gender, category), rows in groups.items():
        name = f"EVF {weapon} {gender} {category}"
        uuid = f"evf:{id_evf_event}:{weapon}:{gender}:{category}"
        _refuse_uncategorised(name, uuid, category)
        parsed = ParsedTournament(
            source_kind=SourceKind.EVF_API,
            results=[
                ParsedResult(
                    source_row_id=f"{uuid}:{i}",
                    fencer_name=r["fencer_name"],
                    place=int(r["place"]),
                    fencer_country=r.get("country"),
                )
                for i, r in enumerate(rows)
            ],
            raw_pool_size=len(rows),
            weapon=weapon,
            gender=gender,
            category_hint=category,
            tournament_name=name,
        )
        rec = _listing(parsed, name=name, uuid=uuid)
        if not _settled(rec, "evf", finality):
            skipped.append(_waiting(rec))
            continue
        recs.append(rec)
    return recs, skipped


def _refuse_two_sources(event: Mapping[str, Any], recs: list[dict]) -> None:
    seen: dict[tuple, str] = {}
    for r in recs:
        key = (r["weapon"], r["gender"], r["cats"][0])
        if key in seen:
            raise ValueError(
                f"Event {event.get('txt_code')!r} has two sources for one bracket "
                f"{'/'.join(str(k) for k in key)}: {seen[key]} and {r['url'] or r['uuid']}. "
                "A tournament holds one source bracket's N (ADR-105 §5.4); keep one URL. "
                "Nothing was written."
            )
        seen[key] = r["url"] or r["uuid"]
