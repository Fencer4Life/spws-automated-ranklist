"""Post-commit participant-count URL validator (ADR-069).

After a commit, for every committed tournament we re-fetch its result URL,
compute the per-V-cat membership the bracket actually contains (split by
birth_year via `vcat_for_age`, mirroring the pipeline's `s7_split_by_vcat`),
and compare it to the stored `int_participant_count`.

This catches the failure class the pgTAP internal invariant cannot see:
result-row CONTAMINATION, where the stored result-row count is itself wrong
(e.g. PPW3-V1-F-EPEE committed 10 rows while the FTL bracket holds 6). The
pgTAP invariant (pcount == COUNT(tbl_result)) only proves internal
consistency; this validator proves the count matches the live source.

Severity model:
  - "halt" — stored count != per-V-cat FTL membership. Blocks the run.
  - "warn" — no URL to check (cert_ref / xlsx), or the URL could not be
    fetched. Never a silent pass, but does not block.

The validator is pure given (tournaments, fetcher): the caller fetches the
committed rows from the DB and decides what a halt does (the recreate flow
fails the run and re-wipes; nothing is promoted until clean).
"""
from __future__ import annotations

from dataclasses import dataclass

from python.pipeline.stages import vcat_for_age


@dataclass
class CountFinding:
    """One participant-count finding for a single tournament."""
    txt_code: str
    vcat: str | None
    url: str | None
    stored: int | None
    ftl_true: int | None
    severity: str            # "halt" | "warn"
    reason: str              # "mismatch" | "no_url" | "fetch_error"
    message: str = ""


def has_halt(findings: list[CountFinding]) -> bool:
    """True iff any finding is halt-severity (a real count mismatch)."""
    return any(f.severity == "halt" for f in findings)


def _per_vcat_counts(parsed, season_end_year: int) -> dict[str, int]:
    """Count fencers in a fetched bracket per V-cat (by birth_year)."""
    counts: dict[str, int] = {}
    for r in getattr(parsed, "results", []) or []:
        by = getattr(r, "birth_year", None)
        vc = vcat_for_age(season_end_year - by) if by else None
        if vc is not None:
            counts[vc] = counts.get(vc, 0) + 1
    return counts


def validate_event_participant_counts(
    tournaments: list[dict],
    fetcher,
    *,
    season_end_year: int,
) -> list[CountFinding]:
    """Validate each tournament's int_participant_count against its URL bracket.

    Args:
      tournaments: dicts with keys txt_code, enum_age_category, url_results,
                   int_participant_count.
      fetcher:     object exposing fetch_url(url) -> ParsedTournament whose
                   .results entries carry .birth_year (e.g.
                   Fetcher(http_client=get_authed_ftl_client())).
      season_end_year: season end year for the V-cat split.

    Returns a list of findings; only mismatches are halt-severity. An empty
    list (or warn-only) means no blocking problem.
    """
    findings: list[CountFinding] = []

    # Fetch each distinct URL once; record fetch errors.
    cache: dict[str, dict[str, int]] = {}
    errored: set[str] = set()
    distinct_urls = {
        t.get("url_results") for t in tournaments if t.get("url_results")
    }
    for url in distinct_urls:
        try:
            parsed = fetcher.fetch_url(url)
            cache[url] = _per_vcat_counts(parsed, season_end_year)
        except Exception as e:  # noqa: BLE001 — any fetch/parse failure → warn
            errored.add(url)
            cache[url] = {}
            findings.append(CountFinding(
                txt_code="(url)", vcat=None, url=url, stored=None, ftl_true=None,
                severity="warn", reason="fetch_error",
                message=f"could not fetch/parse {url}: {e}",
            ))

    for t in tournaments:
        code = t.get("txt_code", "?")
        vcat = t.get("enum_age_category")
        url = t.get("url_results")
        stored = t.get("int_participant_count")

        if not url:
            findings.append(CountFinding(
                txt_code=code, vcat=vcat, url=None, stored=stored, ftl_true=None,
                severity="warn", reason="no_url",
                message="no url_results to validate against",
            ))
            continue
        if url in errored:
            findings.append(CountFinding(
                txt_code=code, vcat=vcat, url=url, stored=stored, ftl_true=None,
                severity="warn", reason="fetch_error",
                message="bracket URL could not be fetched (see (url) finding)",
            ))
            continue

        ftl_true = cache.get(url, {}).get(vcat, 0)
        if stored != ftl_true:
            findings.append(CountFinding(
                txt_code=code, vcat=vcat, url=url, stored=stored, ftl_true=ftl_true,
                severity="halt", reason="mismatch",
                message=(f"int_participant_count={stored} but FTL bracket holds "
                         f"{ftl_true} {vcat} fencer(s)"),
            ))

    return findings
