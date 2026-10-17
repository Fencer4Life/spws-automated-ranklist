"""The international section of a staging report (ADR-105 §5.8, ADR-106 §1).

One table row per international bracket: the source N, the highest place, the
rows stored, how many of those the source did not print POL for, the PENDING
rows and the rejected rows. Two cases are flagged: an N equal to the rows
printed POL (the source may list only the Poles, which is exactly the shape of
the old damage), and a bracket whose source prints no country at all (an
Engarde page headed Club, ENG.NAT.01), where only identity can store a row.

At an FIE event (MSW, PSW) a federation enters at most 4 fencers per
individual bracket, so a bracket with more of one federation is flagged as a
likely parse error; it is still ingested (ADR-106 amendment, D5 A).

Every PENDING row is listed below the table with its candidate: the event's
override file resolves it.

The Phase 5 runner and the CERT ingest (ADR-113) render the same section.
"""

from __future__ import annotations

from collections import Counter
from collections.abc import Iterable
from typing import Any


def section_lines(event_code: str, brackets: Iterable[tuple[Any, Any]]) -> list[str]:
    """The section for `brackets`, each a (parsed, context with `matches` and
    `rejected`) pair. Empty for a domestic event."""
    from python.pipeline.db_connector import derive_tourn_type_from_event_code
    from python.pipeline.international_admission import (
        FIE_MAX_PER_FEDERATION,
        fold_federation,
        is_fie_type,
    )
    from python.pipeline.joined_brackets import BracketField
    from python.pipeline.stages import _is_international_intake

    if not _is_international_intake({"txt_code": event_code}):
        return []
    fie = is_fie_type(derive_tourn_type_from_event_code(event_code))
    lines = [
        "## International brackets — source size and admission (ADR-105, ADR-106)",
        "",
        "| Bracket | V-cat | Wpn | Gen | N (source) | Highest place | Stored | Stored, not printed POL "
        "| PENDING | Rejected | Check |",
        "|---|---|---|---|---:|---:|---:|---:|---:|---:|---|",
    ]
    pending: list[tuple[str, Any]] = []
    for parsed, ctx in brackets:
        if parsed is None or ctx is None:
            continue
        places = [r.place for r in parsed.results]
        n = BracketField.source(places, parsed.raw_pool_size).size
        stored = [m for m in ctx.matches if m.method not in ("EXCLUDED", "PENDING")]
        held = [m for m in ctx.matches if m.method == "PENDING"]
        printed_pol = sum(1 for r in parsed.results if r.fencer_country == "POL")
        flags: list[str] = []
        if places and all(r.fencer_country is None for r in parsed.results):
            flags.append("⚠ the source has no country: only an identity match is stored")
        elif printed_pol and n == printed_pol:
            flags.append(
                "⚠ N equals the rows printed POL: confirm the source lists the whole bracket"
            )
        if fie:
            per_federation = Counter(fold_federation(r.fencer_country) for r in parsed.results)
            over = sorted(
                (code, k)
                for code, k in per_federation.items()
                if code and k > FIE_MAX_PER_FEDERATION
            )
            if over:
                flags.append(
                    f"⚠ more than {FIE_MAX_PER_FEDERATION} fencers of one federation ("
                    + ", ".join(f"{code} {k}" for code, k in over)
                    + "): the FIE enters 4 at most, check the parse"
                )
        check = "; ".join(flags) or "✓"
        name = (
            getattr(parsed, "_ftl_source_name", None)
            or getattr(parsed, "tournament_name", None)
            or getattr(parsed, "source_url", None)
            or "?"
        )
        bracket = f"{parsed.category_hint or '—'} {parsed.weapon or '?'} {parsed.gender or '?'}"
        pending.extend((bracket, m) for m in held)
        lines.append(
            f"| {name} | {parsed.category_hint or '—'} | {parsed.weapon or '?'} | "
            f"{parsed.gender or '?'} | {n} | {max(places, default=0)} | {len(stored)} | "
            f"{sum(1 for m in stored if m.entered_for != 'POL')} | {len(held)} | "
            f"{len(ctx.rejected)} | {check} |"
        )
    lines.append("")
    if pending:
        lines += [
            f"### PENDING — resolve in doc/overrides/{event_code}.yaml, then run the ingestion again",
            "",
            "Printed POL and not stored: no identity match to exactly one fencer"
            + ("" if fie else " with an SPWS start")
            + ". For each row add an identity entry (scraped name → fencer) or a "
            "match_method entry EXCLUDED, then run the ingestion again.",
            "",
            "| Bracket | Place | Name | Candidate |",
            "|---|---:|---|---|",
        ]
        for bracket, m in pending:
            candidate = m.id_fencer if m.id_fencer is not None else "—"
            lines.append(f"| {bracket} | {m.place} | {m.scraped_name} | {candidate} |")
        lines.append("")
    return lines
