"""WEAPON.EVENT — an international event is read for its own weapons (ADR-119 G52 A).

doc/plans/partial-ingest-promote-results-sync-2026-10-31.html, G52.

The event's weapons are `arr_weapons`, else its PEW code's letters (ADR-046; the rule
the Phase 5 runner keeps, INTL.WPN.01, decision F A of 2 Oct 2026). Jabłonna
2025 is two EVF events on one FTL schedule: PEW7es-2024-2025 (épée and sabre)
and PEW8f-2024-2025 (foil). The reader took every bracket the organiser
published, so a re-read of either would store the other's brackets, and a
bracket dated after the end date kept the event IN_PROGRESS. The reader now
keeps to the event's weapons: a bracket of another weapon is skipped, before it
is fetched, refused or asked whether it is final, with the reason
"not a weapon of this event"; it never holds the event open, and G42's
source-consistency report names it. A code without letters (MSW-2026-2027,
IMEW-2023-2024, the legacy PEW3-2024-2025) names no weapon, so every weapon is
the event's.

  WEAPON.EVENT.01  the event's weapons, by that one rule;
  WEAPON.EVENT.02  an FTL schedule: another weapon's brackets, finished or not,
                   categorised or not, are skipped and never fetched;
  WEAPON.EVENT.03  Engarde: another weapon's competition, running or done, is
                   skipped and never holds the event;
  WEAPON.EVENT.04  EVF's results: another weapon's brackets are skipped;
  WEAPON.EVENT.05  the daily close's re-read classifies as the ingest's read
                   (the schedule hash), given the event's row.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock, patch

import pytest

from python.pipeline import international_sources as src
from python.pipeline.ir import ParsedResult, ParsedTournament, SourceKind
from python.pipeline.promotion import lifecycle
from python.pipeline.promotion.run_record import schedule_sha256

SCHEDULE = (
    "https://www.fencingtimelive.com/tournaments/eventSchedule/D050FA69743A43B590473A6442DF7AF7"
)
ENGARDE = "https://engarde-service.com/tournament/hunfencing/2026_budapest"


@pytest.mark.parametrize(
    ("event", "weapons"),
    [
        ({"txt_code": "PEW7es-2024-2025"}, {"EPEE", "SABRE"}),
        ({"txt_code": "PEW8f-2024-2025"}, {"FOIL"}),
        ({"txt_code": "PEW2efs-2026-2027"}, {"EPEE", "FOIL", "SABRE"}),
        ({"txt_code": "PEW3ef-2026-2027", "arr_weapons": None}, {"EPEE", "FOIL"}),
        ({"txt_code": "PEW3ef-2026-2027", "arr_weapons": ["EPEE"]}, {"EPEE"}),  # stored first
        ({"txt_code": "MSW-2026-2027"}, None),
        ({"txt_code": "IMEW-2023-2024"}, None),
        ({"txt_code": "PEW3-2024-2025"}, None),
        (None, None),
    ],
)
def test_WEAPON_EVENT_01_the_event_s_weapons_by_the_one_rule(event, weapons):
    """The rule the Phase 5 runner keeps (INTL.WPN.01): arr_weapons, else a PEW
    code's letters; none named, every weapon is the event's."""
    assert src.weapons_of(event) == (frozenset(weapons) if weapons else None)


class _Resp:
    def __init__(self, text="", js=None):
        self.text = text
        self._js = js

    def raise_for_status(self):
        pass

    def json(self):
        return self._js


class _Client:
    def __init__(self, data):
        self.data = data
        self.got: list[str] = []

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def get(self, url):
        self.got.append(url)
        if "eventSchedule" in url:
            return _Resp(text="<schedule/>")
        if "/events/results/data/" not in url:
            # The listing's results page (G65 R2): every bracket here has a DE round.
            return _Resp(text='<a href="/tableaus/scores/X/Y">Table of 16</a>')
        return _Resp(js=self.data[url.rsplit("/", 1)[-1]])


def _rows(n):
    return [
        {"id": f"f{p}", "name": f"SURNAME{p} Jan", "place": str(p), "country": "POL"}
        for p in range(1, n + 1)
    ]


# Jabłonna 2025's schedule, as PEW7es-2024-2025 (épée and sabre) reads it.
LISTED = [
    {"uuid": "E1", "name": "Vet-40 Men's Epee", "finished": True, "day": "2025-03-29"},
    {"uuid": "F1", "name": "Vet-40 Men's Foil", "finished": True, "day": "2025-03-30"},
    {"uuid": "S2", "name": "Vet-50 Women's Sabre", "finished": True, "day": "2025-03-29"},
    {
        "uuid": "F9",
        "name": "Women's Foil Category 1 and 2 Combined",
        "finished": True,
        "day": "2025-03-30",
    },
    {"uuid": "F3", "name": "Vet-60 Men's Foil", "finished": False, "day": "2025-03-30"},
    {"uuid": "E3", "name": "Vet-60 Men's Epee", "finished": False, "day": "2025-03-29"},
]
TEAMS = [{"uuid": "T1", "name": "Vet Team Men's Epee", "reason": "team event"}]


def _patched(client):
    return (
        patch("python.scrapers.ftl_auth.get_authed_ftl_client", return_value=client),
        patch("python.scrapers.ftl_auth.normalize_ftl_url", side_effect=lambda u: u),
        patch(
            "python.tools.scrape_ftl_event_urls.parse_event_schedule",
            return_value=([dict(x) for x in LISTED], [dict(x) for x in TEAMS]),
        ),
    )


def _read_ftl(code="PEW7es-2024-2025"):
    client = _Client({"E1": _rows(29), "S2": _rows(9)})
    a, b, c = _patched(client)
    with a, b, c:
        return src.read_brackets({"txt_code": code}, [SCHEDULE]), client


def test_WEAPON_EVENT_02_another_weapons_ftl_brackets_are_skipped_unfetched():
    (recs, kept, skipped), client = _read_ftl()
    assert [(r["uuid"], r["weapon"]) for r in recs] == [("E1", "EPEE"), ("S2", "SABRE")]
    assert [k["uuid"] for k in kept] == ["E1", "S2"]
    assert [(s["uuid"], s["reason"]) for s in skipped[:-1]] == [
        ("T1", "team event"),
        ("F1", src.OTHER_WEAPON),
        ("F9", src.OTHER_WEAPON),  # uncategorised, but not this event's: no refusal
        ("F3", src.OTHER_WEAPON),  # not finished, but not this event's: holds nothing
    ]
    # This event's own unfinished bracket still holds it, as before.
    assert skipped[-1]["uuid"] == "E3" and lifecycle.is_not_final(skipped[-1]["reason"])
    assert not any(u.endswith(("F1", "F9", "F3")) for u in client.got)


def test_WEAPON_EVENT_02_a_code_without_letters_reads_every_weapon():
    with pytest.raises(ValueError, match="no single source category"):
        _read_ftl("MSW-2026-2027")  # the combined foil bracket is this event's


def _parsed(weapon: str, category: str = "V1") -> ParsedTournament:
    url = f"https://engarde-service.com/competition/hunfencing/2026_budapest/{weapon.lower()}{category}"
    return ParsedTournament(
        source_kind=SourceKind.ENGARDE,
        results=[ParsedResult(source_row_id="1", fencer_name="NOWAK Jan", place=1)],
        raw_pool_size=12,
        weapon=weapon,
        gender="M",
        category_hint=category,
        source_url=url,
        tournament_name=f"{weapon} {category}",
        parsed_date=date(2026, 11, 14),
    )


RUNNING_SABRE = {
    "weapon": "SABRE",
    "name": "SABRE MALE 2",
    "url": "https://engarde-service.com/competition/hunfencing/2026_budapest/sabremale2",
    "reason": "not completed (tableau)",
    "finished": False,
    "state": "tableau",
}


def test_WEAPON_EVENT_03_another_weapons_engarde_competition_never_holds_the_event():
    fetcher = MagicMock()
    fetcher.fetch_event_url_with_skips.return_value = (
        [_parsed("EPEE"), _parsed("SABRE")],
        [dict(RUNNING_SABRE)],
    )
    recs, kept, skipped = src.read_brackets(
        {"txt_code": "PEW3ef-2026-2027"}, [ENGARDE], fetcher=fetcher, finality=src.SETTLED
    )
    assert [r["weapon"] for r in recs] == ["EPEE"]
    assert len(kept) == 1
    assert [(s["name"], s["reason"]) for s in skipped] == [
        ("SABRE MALE 2", src.OTHER_WEAPON),
        ("SABRE V1", src.OTHER_WEAPON),
    ]
    assert not any(lifecycle.is_not_final(s["reason"]) for s in skipped)


def test_WEAPON_EVENT_04_another_weapons_evf_brackets_are_skipped():
    def scrape(_id):
        return [
            {"weapon": "FOIL", "gender": "M", "category": "V1", "fencer_name": "A B", "place": 1},
            {"weapon": "SABRE", "gender": "M", "category": "V1", "fencer_name": "C D", "place": 1},
        ]

    recs, _kept, skipped = src.read_brackets(
        {"txt_code": "PEW8f-2024-2025", "id_evf_event": 77},
        ["evf:77"],
        evf_scrape=scrape,
        finality=src.SETTLED,
    )
    assert [r["weapon"] for r in recs] == ["FOIL"]
    assert [(s["name"], s["reason"]) for s in skipped] == [("EVF SABRE M V1", src.OTHER_WEAPON)]


def test_WEAPON_EVENT_05_the_close_re_reads_as_the_ingest_read():
    (_recs, kept, skipped), _ = _read_ftl()
    client = _Client({})
    a, b, c = _patched(client)
    with a, b, c:
        again_kept, again_skipped = src.read_schedule(
            [SCHEDULE], event={"txt_code": "PEW7es-2024-2025"}
        )
    final, not_final = lifecycle.split_final(again_kept)
    assert schedule_sha256(final, [*again_skipped, *not_final]) == schedule_sha256(kept, skipped)
