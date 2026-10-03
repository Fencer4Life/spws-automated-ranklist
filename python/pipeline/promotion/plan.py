"""Plan mode: the CERT run's ingestion run against PROD, writing nothing (ADR-108 §6).

`plan_event` runs the same driver as `ingest-event.yml` (`_ingest_event_rounds`,
the INGEST_DOMESTIC flow per listing) with a `RecordingConnector` in place of the
database connector. The connector reads PROD and records every write as an
operation. A read of something the run itself wrote is answered from the record,
so the flow decides exactly what a live run would: a second listing finds the
fencer the first created, and a later stage reads the birth year an earlier one
moved. A new fencer takes the id the CERT run gave it, so ids stay identical
(ADR-108 §2); a fencer the CERT run did not create refuses the plan.

The plan is the ordered list of operations. `apply_plan` is the reference apply,
through the ordinary connector and not atomic, used by the tests and the LOCAL
acceptance check (`plan_check`); fn_promote_event_apply (build step 9) applies
the same operations in one transaction.

The after-run steps (staging report, joining check, Telegram) are not planned:
promote runs them after the apply commits (ADR-108 §6, step 11).
"""

from __future__ import annotations

import copy
from collections import deque
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass, field
from typing import Any

# What the INGEST_DOMESTIC driver reads, passed to PROD unchanged unless the run
# wrote what is being read. Anything else the flow might call is absent, as it
# is on a connector that never wrote it.
PASS_THROUGH = (
    "fetch_spws_starter_ids",
    "fetch_registration_birth_years",
    "find_event_by_date",
    "find_seasons_containing_dates",
    "call_age_categories_batch",
    "get_type_engine",
)

_FENCER_DEFAULTS = {
    "json_name_aliases": [],
    "enum_gender": None,
    "txt_nationality": "PL",
    "bool_birth_year_estimated": False,
}


class PlanRefused(Exception):
    """Plan mode cannot reproduce the CERT run on PROD. Nothing has been written.
    `kind` is a gate kind (ADR-108 §5): identity or precondition."""

    def __init__(self, kind: str, message: str):
        super().__init__(message)
        self.kind = kind


class RecordingConnector:
    """The database connector's surface for INGEST_DOMESTIC: reads from PROD,
    writes recorded in `ops`, reads of the run's own writes answered from them.

    `created` is the CERT run's created fencers (its master-data changes):
    {id_fencer, surname, first_name}. A creation takes the first unused CERT id
    for the same surname and first name, in id order."""

    def __init__(self, prod: Any, created: Iterable[Mapping[str, Any]]):
        self._prod = prod
        self.ops: list[dict] = []
        self.created: list[dict] = []
        self._cert_ids: dict[tuple[str, str], deque[int]] = {}
        for c in sorted(created, key=lambda c: int(c["id_fencer"])):
            key = (str(c["surname"]), str(c["first_name"]))
            self._cert_ids.setdefault(key, deque()).append(int(c["id_fencer"]))
        self._new: dict[int, dict] = {}
        self._birth_years: dict[int, tuple[int | None, bool]] = {}
        self._events: dict[int, dict] = {}
        self._tournaments: dict[tuple, int] = {}
        self._existing: dict[int, dict[tuple, int]] = {}
        self._prod_ids: set[int] | None = None
        self._next_ref = -1

    def __getattr__(self, name: str) -> Any:
        if name in PASS_THROUGH:
            return getattr(self._prod, name)
        raise AttributeError(name)

    # -- reads with the run's own writes -------------------------------------

    def _moved(self, row: dict) -> dict:
        moved = self._birth_years.get(row["id_fencer"])
        if moved is not None:
            row["int_birth_year"], row["bool_birth_year_estimated"] = moved
        return row

    def fetch_fencer_db(self) -> list[dict]:
        rows = [self._moved(dict(r)) for r in self._prod.fetch_fencer_db()]
        self._prod_ids = {r["id_fencer"] for r in rows}
        return rows + [copy.deepcopy(r) for r in self._new.values()]

    def fetch_birth_years_batch(self, id_fencers: list[int]) -> dict[int, int | None]:
        old = [i for i in id_fencers if i not in self._new]
        out = dict(self._prod.fetch_birth_years_batch(old)) if old else {}
        for i in old:
            if i in self._birth_years and i in out:
                out[i] = self._birth_years[i][0]
        out.update({i: self._new[i]["int_birth_year"] for i in id_fencers if i in self._new})
        return out

    def fetch_genders_batch(self, id_fencers: list[int]) -> dict[int, str | None]:
        old = [i for i in id_fencers if i not in self._new]
        out = dict(self._prod.fetch_genders_batch(old)) if old else {}
        out.update({i: self._new[i]["enum_gender"] for i in id_fencers if i in self._new})
        return out

    def fetch_fencer_basics_batch(self, id_fencers: list[int]) -> dict[int, dict]:
        old = [i for i in id_fencers if i not in self._new]
        out = {
            i: self._moved(dict(r))
            for i, r in (self._prod.fetch_fencer_basics_batch(old) if old else {}).items()
        }
        out.update({i: copy.deepcopy(self._new[i]) for i in id_fencers if i in self._new})
        return out

    def find_event_by_code(self, event_code: str) -> dict | None:
        event = self._prod.find_event_by_code(event_code)
        if event is not None:
            event = dict(event)
            event.update(self._events.get(event["id_event"], {}))
        return event

    # -- writes, recorded -----------------------------------------------------

    def insert_fencer(self, fencer_dict: dict) -> int:
        surname, first = fencer_dict.get("txt_surname"), fencer_dict.get("txt_first_name")
        ids = self._cert_ids.get((str(surname), str(first)))
        if not ids:
            raise PlanRefused(
                "identity",
                f"PROD would create {surname} {first} ({fencer_dict.get('int_birth_year')}); "
                "the CERT run did not. Refresh CERT from PROD and re-run the CERT ingestion.",
            )
        id_fencer = ids.popleft()
        if self._prod_ids is None:
            self._prod_ids = {r["id_fencer"] for r in self._prod.fetch_fencer_db()}
        if id_fencer in self._prod_ids:
            raise PlanRefused(
                "precondition",
                f"The CERT run created {surname} {first} as #{id_fencer}, an id PROD already uses.",
            )
        self.ops.append(
            {"op": "insert_fencer", "id_fencer": id_fencer, "fencer": dict(fencer_dict)}
        )
        row: dict[str, Any] = {**_FENCER_DEFAULTS, "json_name_aliases": []}
        row.update(fencer_dict)
        row["id_fencer"] = id_fencer
        self._new[id_fencer] = row
        self.created.append({"id_fencer": id_fencer, "surname": surname, "first_name": first})
        return id_fencer

    def update_fencer_birth_year(
        self, fencer_id: int, birth_year: int, estimated: bool = False
    ) -> None:
        self.ops.append(
            {
                "op": "update_fencer_birth_year",
                "id_fencer": fencer_id,
                "birth_year": birth_year,
                "estimated": estimated,
            }
        )
        if fencer_id in self._new:
            self._new[fencer_id]["int_birth_year"] = birth_year
            self._new[fencer_id]["bool_birth_year_estimated"] = estimated
        else:
            self._birth_years[fencer_id] = (birth_year, estimated)

    def find_or_create_tournament(
        self,
        event_id: int,
        weapon: str,
        gender: str,
        category: str,
        date: str,
        tournament_type: str,
        url_results: str | None = None,
    ) -> int:
        """PROD's tournament id when it has one, else a negative placeholder the
        apply replaces; the same key always answers the same."""
        key = (event_id, weapon, gender, category)
        if key not in self._tournaments:
            if event_id not in self._existing:
                self._existing[event_id] = {
                    (event_id, t["enum_weapon"], t["enum_gender"], t["enum_age_category"]): t[
                        "id_tournament"
                    ]
                    for t in self._prod.fetch_event_tournaments(event_id)
                }
            found = self._existing[event_id].get(key)
            if found is None:
                found = self._next_ref
                self._next_ref -= 1
            self._tournaments[key] = found
        ref = self._tournaments[key]
        self.ops.append(
            {
                "op": "find_or_create_tournament",
                "ref": ref,
                "event_id": event_id,
                "weapon": weapon,
                "gender": gender,
                "category": category,
                "date": date,
                "tournament_type": tournament_type,
                "url_results": url_results,
            }
        )
        return ref

    def ingest_results(
        self,
        tournament_id: int,
        results_json: list[dict],
        participant_count: int | None = None,
        joined_order: str | None = None,
    ) -> dict:
        self.ops.append(
            {
                "op": "ingest_results",
                "tournament": tournament_id,
                "rows": copy.deepcopy(results_json),
                "participant_count": participant_count,
                "joined_order": joined_order,
            }
        )
        return {"planned": len(results_json)}

    def set_event_url_event(self, id_event: int, url_event: str) -> None:
        self.ops.append({"op": "set_event_url_event", "id_event": id_event, "url_event": url_event})
        self._events.setdefault(id_event, {})["url_event"] = url_event

    def set_event_ingest_sources(self, id_event: int, sources: list) -> None:
        self.ops.append(
            {
                "op": "set_event_ingest_sources",
                "id_event": id_event,
                "sources": copy.deepcopy(sources),
            }
        )
        self._events.setdefault(id_event, {})["json_ingest_sources"] = copy.deepcopy(sources)

    # -- writes a domestic ingestion never makes ------------------------------

    def _refuse(self, what: str) -> None:
        raise PlanRefused(
            "precondition", f"{what} is not part of a domestic ingestion; plan mode refuses it."
        )

    def merge_fencers(self, survivor_id: int, duplicate_id: int) -> None:
        self._refuse(f"Merging fencer #{duplicate_id} into #{survivor_id}")

    def clear_tournament_results(self, tournament_id: int) -> None:
        self._refuse(f"Clearing tournament {tournament_id}")

    def set_tournament_participant_count(self, tournament_id: int, count: int) -> None:
        self._refuse(f"Setting tournament {tournament_id}'s participant count")

    def upsert_joining_check(self, *args: Any, **kwargs: Any) -> None:
        self._refuse("The joining check")


@dataclass
class Plan:
    """What the ingestion would write on PROD, in order, and what it read."""

    event_code: str
    url_event: str
    ops: list[dict] = field(default_factory=list)
    created: list[dict] = field(default_factory=list)
    listings: dict = field(default_factory=dict)
    # ADR-108 §7: the status the lifecycle rule gives PROD's event after the
    # apply, or None when the run committed nothing.
    status: str | None = None

    def to_json(self) -> dict:
        return {
            "event_code": self.event_code,
            "url_event": self.url_event,
            "ops": self.ops,
            "created": self.created,
            "listings": self.listings,
            "status": self.status,
        }


def plan_event(
    event_code: str,
    season_end_year: int,
    prod: Any,
    *,
    url_event: str,
    created: Iterable[Mapping[str, Any]],
) -> Plan:
    """Plan the CERT run of `event_code` on PROD. `prod` is read only; `url_event`
    is the URL the CERT run ingested; `created` its created fencers."""
    from python.pipeline import ingest_cli
    from python.pipeline.promotion import lifecycle
    from python.pipeline.promotion.run_record import ListingLog
    from python.pipeline.stages import _is_international_intake

    recorder = RecordingConnector(prod, created)
    event = recorder.find_event_by_code(event_code)
    if event is None:
        raise PlanRefused("precondition", f"Event {event_code} does not exist on PROD.")
    if _is_international_intake(event):
        raise PlanRefused(
            "precondition",
            f"Event {event_code} is international; promote replays domestic events only.",
        )
    # ADR-086's fill-blank tier: PROD takes the CERT run's URL when it has none.
    current = (event.get("url_event") or "").strip()
    if current and current != url_event:
        raise PlanRefused(
            "precondition",
            f"PROD's url_event for {event_code} is {current}; the CERT run ingested {url_event}. "
            "Correct the URL on one of them and re-run the CERT ingestion.",
        )
    log = ListingLog()
    ingest_cli._ingest_event_rounds(
        event,
        event_code,
        season_end_year,
        url_event,
        None if current else url_event,
        db=recorder,
        notifier=None,
        replace=False,
        send_telegram=False,
        md_target="local",
        run=log,
        post_run=False,
    )
    listings = log.listings()
    end = event.get("dt_end") or event.get("dt_start")
    status = (
        lifecycle.target_status(
            listings, dt_end=lifecycle.as_date(end), today=lifecycle.warsaw_today()
        )
        if end
        else None
    )
    return Plan(event_code, url_event, recorder.ops, recorder.created, listings, status)


def apply_plan(
    ops: Sequence[Mapping[str, Any]],
    db: Any,
    *,
    status: str | None = None,
    event_code: str | None = None,
) -> dict[int, int]:
    """The reference apply: every operation through the ordinary connector, in
    order, then the plan's status (ADR-108 §7) when one is given. Returns each
    tournament reference with the id it resolved to. Not atomic, so it runs in
    tests and on LOCAL only; PROD's apply is fn_promote_event_apply (build step 9)."""
    refs: dict[int, int] = {}
    for op in ops:
        kind = op["op"]
        if kind == "insert_fencer":
            got = db.insert_fencer({**op["fencer"], "id_fencer": op["id_fencer"]})
            if got != op["id_fencer"]:
                raise PlanRefused(
                    "precondition", f"Fencer #{op['id_fencer']} was created as #{got}."
                )
        elif kind == "update_fencer_birth_year":
            db.update_fencer_birth_year(
                op["id_fencer"], op["birth_year"], estimated=op["estimated"]
            )
        elif kind == "find_or_create_tournament":
            got = db.find_or_create_tournament(
                op["event_id"],
                op["weapon"],
                op["gender"],
                op["category"],
                op["date"],
                op["tournament_type"],
                url_results=op["url_results"],
            )
            ref = op["ref"]
            if ref > 0 and got != ref:
                raise PlanRefused(
                    "precondition", f"The plan read tournament {ref}; the apply found {got}."
                )
            refs[ref] = got
        elif kind == "ingest_results":
            db.ingest_results(
                refs[op["tournament"]],
                op["rows"],
                participant_count=op["participant_count"],
                joined_order=op["joined_order"],
            )
        elif kind == "set_event_url_event":
            db.set_event_url_event(op["id_event"], op["url_event"])
        elif kind == "set_event_ingest_sources":
            db.set_event_ingest_sources(op["id_event"], op["sources"])
        else:
            raise ValueError(f"unknown plan operation {kind!r}")
    if status is not None:
        from python.pipeline.promotion import lifecycle

        event = db.find_event_by_code(event_code) if event_code else None
        if event is None:
            raise ValueError(f"a status needs an existing event, not {event_code!r}")
        for step in lifecycle.steps(event.get("enum_status"), status):
            db.set_event_status(event["id_event"], step)
    return refs
