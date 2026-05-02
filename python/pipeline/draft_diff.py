"""
Markdown diff formatter — Phase 2 (ADR-050) dry-run risk gate.

Per Decision D3 (conversation 2026-05-01): tournament-level diff with
aggregate match-method counts. Per-fencer detail and 3-way diff against
live tables are deferred to Phase 3.

Usage:
    md = format_diff(
        run_id="abc-123",
        payload={"tournaments": [...], "results": [...]},  # IR JSONB sent to RPC
        rpc_result={"tournaments_would_create": 4, ...},   # fn_dry_run_event_draft return
        event_match={"id_event": 42, "txt_code": "PEW3-..."} | None,
    )
    Path("/tmp/draft-abc-123.md").write_text(md)
"""

from __future__ import annotations

from collections import Counter, defaultdict


def format_diff(
    run_id: str,
    payload: dict,
    rpc_result: dict,
    event_match: dict | None,
) -> str:
    """Render the dry-run markdown diff."""
    tournaments = payload.get("tournaments") or []
    results = payload.get("results") or []

    # ----- Header -----
    lines: list[str] = [
        f"# Draft `{run_id}` — DRY RUN",
        "",
        f"Run id: `{run_id}`",
    ]
    if event_match:
        lines.append(
            f"Event match: **{event_match.get('txt_code', '?')}** "
            f"(id_event={event_match.get('id_event', '?')})"
        )
    else:
        lines.append("Event match: _none — dry-run did not look up live event_")

    n_tour = rpc_result.get("tournaments_would_create", len(tournaments))
    n_res = rpc_result.get("results_would_create", len(results))
    n_joint = rpc_result.get("joint_pool_sibling_groups", 0)
    lines.append(
        f"Would create: **{n_tour} tournaments**, **{n_res} results** "
        f"({n_joint} joint-pool sibling group(s))"
    )
    lines.append("")

    # ----- Per-tournament table -----
    if tournaments:
        results_by_code: dict[str, int] = defaultdict(int)
        for r in results:
            code = r.get("txt_code") or ""
            results_by_code[code] += 1

        lines.append("## Tournaments")
        lines.append("")
        lines.append("| Code | Weapon | Gender | Cat | Date | Results | Source URL |")
        lines.append("|------|--------|--------|-----|------|--------:|------------|")
        for t in tournaments:
            code = t.get("txt_code", "?")
            lines.append(
                f"| {code} "
                f"| {t.get('enum_weapon', '?')} "
                f"| {t.get('enum_gender', '?')} "
                f"| {t.get('enum_age_category', '?')} "
                f"| {t.get('dt_tournament', '?')} "
                f"| {results_by_code.get(code, 0)} "
                f"| {t.get('url_results', '') or '_(none)_'} |"
            )
        lines.append("")

    # ----- Match-method aggregate -----
    if results:
        method_counts: Counter[str] = Counter()
        for r in results:
            method_counts[r.get("enum_match_method") or "UNSPECIFIED"] += 1
        lines.append("## Match summary")
        lines.append("")
        lines.append("| Method | Count |")
        lines.append("|--------|------:|")
        # Stable order: known methods first, then unknown
        ordering = ["AUTO_MATCHED", "PENDING", "AUTO_CREATED", "EXCLUDED",
                    "UNSPECIFIED"]
        seen: set[str] = set()
        for method in ordering:
            if method in method_counts:
                lines.append(f"| {_humanize(method)} | {method_counts[method]} |")
                seen.add(method)
        for method, count in method_counts.items():
            if method not in seen:
                lines.append(f"| {_humanize(method)} | {count} |")
        lines.append("")

    return "\n".join(lines)


def _humanize(method: str) -> str:
    return {
        "AUTO_MATCHED": "Auto-matched",
        "PENDING": "Pending",
        "AUTO_CREATED": "Auto-created",
        "EXCLUDED": "Excluded",
        "UNSPECIFIED": "Unspecified",
    }.get(method, method)
