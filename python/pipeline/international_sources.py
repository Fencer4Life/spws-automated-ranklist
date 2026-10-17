"""The brackets of an international event (ADR-113).

An EVF or FIE event is read from every result URL it holds (`url_event` …
`url_event_5`), or, when it holds none, from EVF's own results (ADR-105 §1.5:
the organiser's results first, EVF's only when nothing else exists):

- an FTL schedule is read here, so each listing keeps FTL's Finished flag
  (ADR-108 §7): a listing that is not finished is skipped and listed, and
  keeps the event IN_PROGRESS;
- any other URL (Engarde, 4fence, Ophardt, d'Artagnan, one results page) is
  read by the reader the Phase 5 runner uses, `Fetcher.fetch_event_url_with_skips`;
- EVF's results come from `evf_results.scrape_event_results`, one bracket per
  weapon, gender and category.

Each bracket is one listing in the shape the run record keeps (ADR-108 §4):
its name, its key (`uuid`: FTL's id, or the bracket's own results URL), its
weapon, gender and single category, its row count, and the parse. Team
brackets are skipped (ADR-105 §5.5). A bracket without one V0–V4 category,
or two sources for one bracket, refuses the event before anything is written
(ADR-105 §5.3, §5.4).

Ingest on CERT and promote's plan on PROD both read the event through here.
"""

from __future__ import annotations

from collections.abc import Callable, Mapping
from dataclasses import replace
from datetime import date
from typing import Any

from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind

SLOTS = ("url_event", "url_event_2", "url_event_3", "url_event_4", "url_event_5")
CATEGORIES = ("V0", "V1", "V2", "V3", "V4")
FTL_DATA = "https://www.fencingtimelive.com/events/results/data/"
FTL_RESULTS = "https://www.fencingtimelive.com/events/results/"
EVF_SOURCE = "evf:"
UNPARSEABLE = "unparseable name"


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
) -> tuple[list[dict], list[dict], list[dict]]:
    """Every bracket of the event: (listings, schedule entries, skipped).

    The schedule entries are what the run record hashes as the event's
    schedule; the skipped entries are listed in the staging report."""
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
            r = _evf_brackets(int(url[len(EVF_SOURCE) :]), evf_scrape)
            k, s = [{"uuid": x["uuid"], "name": x["name"]} for x in r], []
        elif _is_ftl_schedule(url):
            r, k, s = _ftl_schedule(url)
        else:
            r, k, s = _other_source(url, fetcher)
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
) -> tuple[list[dict], list[dict]]:
    """What the daily close re-reads for an international run (ADR-108 §7,
    ADR-113): FTL's schedule as listed, with each listing's Finished flag;
    every other source's brackets, which are final once published. The pair
    hashes as the run recorded it once `lifecycle.split_final` has run."""
    kept: list[dict] = []
    skipped: list[dict] = []
    for url in urls:
        if url.startswith(EVF_SOURCE):
            recs = _evf_brackets(int(url[len(EVF_SOURCE) :]), evf_scrape)
            kept += [{"uuid": r["uuid"], "name": r["name"], "finished": True} for r in recs]
        elif _is_ftl_schedule(url):
            from python.scrapers.ftl_auth import get_authed_ftl_client, normalize_ftl_url
            from python.tools.scrape_ftl_event_urls import parse_event_schedule

            with get_authed_ftl_client() as client:
                sched = client.get(normalize_ftl_url(url))
                sched.raise_for_status()
                listed, skips = parse_event_schedule(sched.text, with_skips=True)
            kept += listed
            skipped += skips
        else:
            recs, k, s = _other_source(url, fetcher)
            kept += [{**x, "finished": True} for x in k]
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
        "_base": parsed,
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
    from python.pipeline.promotion.lifecycle import split_final
    from python.scrapers import ftl
    from python.scrapers.ftl_auth import get_authed_ftl_client, normalize_ftl_url
    from python.tools.scrape_ftl_event_urls import parse_event_schedule, parse_tournament_name

    recs: list[dict] = []
    with get_authed_ftl_client() as client:
        sched = client.get(normalize_ftl_url(url))
        sched.raise_for_status()
        listed, skipped = parse_event_schedule(sched.text, with_skips=True)
        final, not_final = split_final(listed)
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


def _other_source(url: str, fetcher: Any) -> tuple[list[dict], list[dict], list[dict]]:
    if fetcher is None:
        from python.pipeline.review_cli import Fetcher

        fetcher = Fetcher()
    parsed_list, skipped = fetcher.fetch_event_url_with_skips(url)
    recs: list[dict] = []
    for parsed in parsed_list:
        category = getattr(parsed, "category_hint", None)
        name = parsed.tournament_name or f"{parsed.weapon} {parsed.gender} {category}"
        _refuse_uncategorised(name, parsed.source_url, category)
        recs.append(_listing(parsed, name=name, uuid=parsed.source_url or name))
    kept = [{"uuid": r["uuid"], "name": r["name"]} for r in recs]
    return recs, kept, list(skipped)


def _evf_brackets(id_evf_event: int, evf_scrape: Callable[[int], list[dict]] | None) -> list[dict]:
    if evf_scrape is None:
        from python.scrapers.evf_results import scrape_event_results

        evf_scrape = scrape_event_results
    groups: dict[tuple, list[dict]] = {}
    for row in evf_scrape(id_evf_event):
        key = (row.get("weapon"), row.get("gender"), row.get("category"))
        groups.setdefault(key, []).append(row)
    recs: list[dict] = []
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
        recs.append(_listing(parsed, name=name, uuid=uuid))
    return recs


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
