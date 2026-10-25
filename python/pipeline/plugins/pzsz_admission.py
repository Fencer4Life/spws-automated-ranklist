"""PZSz admission — who a PZSz result belongs to (ADR-111).

PPS and MPS are not PPW: a PZSz field is a senior competition open to every
age, run by a non-veteran organizer. Its results are imported similarly to
EVF's, not exactly like them. This module began as a copy of the EVF
admission (``python/pipeline/international_admission.py``, ADR-106) and
shares nothing with it, so a change on either side cannot alter the other.
The rule, decided by the user on 6 October 2026:

1. **Identity.** SURNAME, first name and birth year: exactly one fencer in the
   fencer table whose surname and first given name equal the source's (Polish
   letters folded, case ignored, a second given name dropped) and whose birth
   year equals the year of the birth date on the PZSz start list. Stored.
   Unlike EVF there is no category band and no PPW or MPW start is required.
   An estimated birth year of ours is compared exactly too.
2. **A confirmed alias** (amendment K1 A, 25 October 2026). When no fencer of
   ours carries the source's name, it may be exactly one fencer's
   user-confirmed, unrevoked alias. The start list's birth year is then read
   under that fencer's canonical surname and first name and must equal ours
   exactly, and no other FTL row may print that canonical name. A plain
   matcher alias nobody confirmed (``json_name_aliases``) never counts.
3. **Once per listing.** Two rows resolving to one fencer are both skipped.
4. **Skipped.** Everything else: a name missing from the start list or
   printed there twice, nobody of that name, a namesake with another birth
   year, or two fencers of ours matching. Nothing creates a fencer, writes an
   alias, changes a birth year or queues a review; there is no PENDING.

FencingTimeLive gives the places and carries no birth year; the start list
(``python/scrapers/pzsz_start_list.py``) arrives in ``svc.config["start_list"]``.
"""

from __future__ import annotations

import json
from collections import Counter
from collections.abc import Iterable
from dataclasses import dataclass

from python.matcher.fuzzy_match import canonicalize_scraped_name, fold_diacritics
from python.pipeline.core.contract import Context, PluginKind, Services
from python.pipeline.plugins.base import BasePlugin
from python.pipeline.plugins.bridge import get_pctx
from python.pipeline.types import StageMatchResult
from python.scrapers.pzsz_start_list import Starter

STORED = "STORED"
SKIPPED = "SKIPPED"

# A name printed twice on the start list: its birth year cannot be told.
_TWICE = -1


@dataclass(frozen=True)
class Admission:
    """One row's decision: the fencer stored (STORED) or nobody (SKIPPED),
    with the start list's birth year and, for a namesake, our fencers of the
    same name as (id_fencer, birth year)."""

    decision: str
    id_fencer: int | None
    birth_year: int | None
    reason: str
    namesakes: tuple[tuple[int, int | None], ...] = ()


def _words(text: str) -> list[str]:
    return fold_diacritics(canonicalize_scraped_name(text)).upper().split()


def start_list_years(starters: Iterable[Starter]) -> dict[tuple[str, ...], int]:
    """The start list's birth year for each folded name; a name printed
    twice maps to ``_TWICE``."""
    years: dict[tuple[str, ...], int] = {}
    for s in starters:
        key = tuple(_words(s.name))
        years[key] = _TWICE if key in years else s.birth_year
    return years


def name_matches(name: str, roster: Iterable[dict]) -> list[dict]:
    """The roster fencers with this source row's surname and first given
    name, whatever their birth year."""
    words = _words(name)
    hits: list[dict] = []
    for f in roster:
        surname = _words(f.get("txt_surname") or "")
        first = _words(f.get("txt_first_name") or "")[:1]
        if not surname or not first:
            continue
        n = len(surname)
        if words[:n] == surname and words[n : n + 1] == first:
            hits.append(f)
    return hits


def _alias_list(value: object) -> list[str]:
    """A fencer's alias column as a list of names (JSONB arrives as a list, a
    JSON string or nothing)."""
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except ValueError:
            return []
    return [a for a in value if isinstance(a, str)] if isinstance(value, list) else []


def confirmed_alias_matches(name: str, roster: Iterable[dict]) -> list[dict]:
    """The roster fencers one of whose user-confirmed, unrevoked aliases is
    this source row's name (whole words, Polish letters folded, a further
    given name in the source dropped)."""
    words = _words(name)
    hits: list[dict] = []
    for f in roster:
        revoked = {tuple(_words(a)) for a in _alias_list(f.get("json_revoked_aliases"))}
        for alias in _alias_list(f.get("json_user_confirmed_aliases")):
            aw = _words(alias)
            if len(aw) >= 2 and tuple(aw) not in revoked and words[: len(aw)] == aw:
                hits.append(f)
                break
    return hits


def _canonical_key(f: dict) -> tuple[str, ...]:
    """Our surname and first given name, folded as the start list is."""
    return tuple(_words(f.get("txt_surname") or "") + _words(f.get("txt_first_name") or "")[:1])


def _admit_by_alias(
    name: str,
    *,
    years: dict[tuple[str, ...], int],
    roster: list[dict],
    listing: set[tuple[str, ...]],
) -> Admission | None:
    """ADR-111 §2 (K1 A): the source name as one fencer's confirmed alias,
    with the start list's year under our canonical name. None when no fencer
    of ours confirmed this name."""
    hits = confirmed_alias_matches(name, roster)
    if not hits:
        return None
    if len(hits) > 1:
        return Admission(SKIPPED, None, None, "confirmed alias of two fencers of ours")
    f = hits[0]
    key = _canonical_key(f)
    label = f"confirmed alias of #{f['id_fencer']}"
    if key in listing:
        return Admission(SKIPPED, None, None, f"{label}, whose own name another FTL row prints")
    year = years.get(key)
    if year is None:
        return Admission(SKIPPED, None, None, f"{label}, whose own name is not on the start list")
    if year == _TWICE:
        return Admission(SKIPPED, None, None, f"{label}, whose own name is twice on the start list")
    if f.get("int_birth_year") != year:
        estimated = " (ours estimated)" if f.get("bool_birth_year_estimated") else ""
        return Admission(
            SKIPPED,
            None,
            year,
            f"{label}, another birth year{estimated}",
            ((f["id_fencer"], f.get("int_birth_year")),),
        )
    return Admission(STORED, f["id_fencer"], year, f"{label}, birth year under our name")


def admit(
    name: str,
    *,
    years: dict[tuple[str, ...], int],
    roster: list[dict],
    listing: Iterable[str] = (),
) -> Admission:
    """Decide one PZSz row (ADR-111 §2). ``listing`` is every FTL name of
    the row's listing, for the confirmed-alias guard."""
    same_name = name_matches(name, roster)
    if not same_name:
        by_alias = _admit_by_alias(
            name, years=years, roster=roster, listing={tuple(_words(n)) for n in listing}
        )
        if by_alias is not None:
            return by_alias
    year = years.get(tuple(_words(name)))
    if year is None:
        return Admission(SKIPPED, None, None, "not on the start list")
    if year == _TWICE:
        return Admission(SKIPPED, None, None, "twice on the start list")
    hits = [f for f in same_name if f.get("int_birth_year") == year]
    if len(hits) == 1:
        return Admission(STORED, hits[0]["id_fencer"], year, "surname, first name, birth year")
    if len(hits) > 1:
        return Admission(SKIPPED, None, year, "two fencers of ours match")
    if same_name:
        namesakes = tuple((f["id_fencer"], f.get("int_birth_year")) for f in same_name)
        estimated = any(f.get("bool_birth_year_estimated") for f in same_name)
        reason = "namesake, another birth year" + (" (ours estimated)" if estimated else "")
        return Admission(SKIPPED, None, year, reason, namesakes)
    return Admission(SKIPPED, None, year, "not in the fencer table")


class AdmitPzszRoster(BasePlugin):
    """The identity step of ``Flow.INGEST_PZSZ_SENIOR``, in place of
    ``ResolveFencers``. Writes nothing: a stored row becomes an AUTO_MATCHED
    match for ``CommitPzszSenior``, a skipped row an EXCLUDED one."""

    name = "AdmitPzszRoster"
    kind = PluginKind.TRANSFORM
    reads = frozenset({"parsed", "event"})
    writes = frozenset({"matches"})

    def run(self, ctx: Context, svc: Services) -> None:
        pctx = get_pctx(ctx)
        assert pctx is not None, (
            "AdmitPzszRoster.run: PipelineContext bridge not set up — it must run after ParseSource"
        )
        start_list = (svc.config or {}).get("start_list")
        assert start_list, (
            "AdmitPzszRoster.run: no PZSz start list — without it there is no "
            "birth year to compare, so nothing is admitted"
        )
        years = start_list_years(start_list)
        roster = svc.db.fetch_fencer_db()
        listing = [r.fencer_name for r in pctx.parsed.results]
        rows = [r for r in pctx.parsed.results if not getattr(r, "bool_excluded", False)]
        decided = [
            (r, admit(r.fencer_name, years=years, roster=roster, listing=listing)) for r in rows
        ]
        # A fencer is stored at most once per listing (ADR-111 §3).
        stored_twice = Counter(a.id_fencer for _, a in decided if a.decision == STORED)
        decided = [
            (r, Admission(SKIPPED, None, a.birth_year, f"two rows resolve to #{a.id_fencer}"))
            if a.decision == STORED and stored_twice[a.id_fencer] > 1
            else (r, a)
            for r, a in decided
        ]
        matches: list[StageMatchResult] = []
        skipped: list[dict] = []
        for r, a in decided:
            stored = a.decision == STORED
            matches.append(
                StageMatchResult(
                    scraped_name=r.fencer_name,
                    place=r.place,
                    id_fencer=a.id_fencer,
                    confidence=100.0 if stored else 0.0,
                    method="AUTO_MATCHED" if stored else "EXCLUDED",
                    notes=a.reason,
                    governed_birth_year=a.birth_year if stored else None,
                )
            )
            if not stored:
                skipped.append(
                    {
                        "scraped_name": r.fencer_name,
                        "place": r.place,
                        "reason": a.reason,
                        "start_list_birth_year": a.birth_year,
                        "namesakes": [{"id_fencer": i, "birth_year": by} for i, by in a.namesakes],
                    }
                )
        # Namesakes first: they are the rows an administrator may need to
        # look at (an estimated birth year of ours, ADR-111 §2).
        skipped.sort(key=lambda s: (not s["namesakes"], s["place"]))
        pctx.matches = matches
        ctx.set("matches", matches)
        self.report(
            ctx,
            "IDENTITY",
            matches=[
                {
                    "scraped_name": m.scraped_name,
                    "id_fencer": m.id_fencer,
                    "place": m.place,
                    "method": m.method,
                    "confidence": m.confidence,
                    "governed_birth_year": m.governed_birth_year,
                    "notes": m.notes,
                }
                for m in matches
            ],
            skipped=skipped,
            created=[],
            reconciled=[],
            conflicts=[],
            alias_writebacks=[],
        )
