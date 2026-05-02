"""
Phase 5 — automatic alias write-back at sign-off.

Wires the existing `fn_update_fencer_aliases` RPC (Phase 3 backend, was
never invoked from Python) into the per-event sign-off flow. Goal: for
every AUTO_MATCHED row whose scraped name differs from the matched
fencer's canonical name in a way the verdict ladder rates as ✓ ("same
person, spelling variant"), the scraped name is written to that
fencer's `json_name_aliases` BEFORE `fn_commit_event_draft` runs — so the
permanent alias trail mirrors the staging summary the operator just OK'd.

Two surfaces:
  * `compute_pending_aliases` — pure function that takes the
    fencer-matching summary dict (built by phase5_runner) and returns
    deduped per-(id_fencer, alias) pairs partitioned by verdict icon.
  * `flush_pending_aliases` — calls the RPC for every ✓ pair against the
    DbConnector. Idempotent (the RPC is a no-op if the alias already
    exists). Returns count of writes attempted (not errors).

Sign-off blocks (refuses to commit) when ❌ pairs exist — those are
suspected wrong matches, not aliases. The operator must fix the source
match (override / update the source data / correct the fencer table)
and re-stage before sign-off.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from python.pipeline.name_classify import classify_alias_pair


@dataclass(frozen=True)
class PendingAlias:
    """One concrete (id_fencer, alias) write-candidate.

    Attributes:
        id_fencer: target fencer row.
        scraped_name: the alias text we'd write (raw, not folded — we
            store the original casing the source emitted).
        canonical: fencer's "txt_surname txt_first_name" for display.
        icon: "✓" / "❓" / "❌" — verdict from `classify_alias_pair`.
        reason: short human-readable explanation.
    """
    id_fencer: int
    scraped_name: str
    canonical: str
    icon: str
    reason: str


def compute_pending_aliases(stats: dict) -> list[PendingAlias]:
    """Derive (id_fencer, alias) write-candidates from the matching stats.

    `stats` is the dict returned by phase5_runner._build_fencer_matching_summary.
    The `alias_new_needed` bucket already holds every match where the
    scraped name is neither the canonical name NOR an existing alias —
    those are the alias-candidate rows. We classify each one with the
    shared verdict ladder and dedupe by (id_fencer, scraped_name).

    Returns the list sorted with ❌ first (so blockers float to the top
    in the summary), then ❓, then ✓.
    """
    seen: set[tuple[int, str]] = set()
    out: list[PendingAlias] = []
    for d in stats.get("alias_new_needed", []) or []:
        key = (d["id_fencer"], d["scraped_name"])
        if key in seen:
            continue
        seen.add(key)
        icon, reason = classify_alias_pair(d["scraped_name"], d["canonical"])
        out.append(PendingAlias(
            id_fencer=d["id_fencer"],
            scraped_name=d["scraped_name"],
            canonical=d["canonical"],
            icon=icon,
            reason=reason,
        ))
    rank = {"❌": 0, "❓": 1, "✓": 2}
    out.sort(key=lambda p: (rank.get(p.icon, 9), p.canonical, p.scraped_name))
    return out


def has_blocking_pairs(pending: Iterable[PendingAlias]) -> bool:
    """True iff any ❌ pair exists. Sign-off must refuse on True."""
    return any(p.icon == "❌" for p in pending)


def flush_pending_aliases(
    db, pending: Iterable[PendingAlias], *, include_all: bool = False,
) -> dict:
    """Call `fn_update_fencer_aliases` for pending pairs.

    Default behavior (`include_all=False`): only ✓ pairs flush. ❌ and ❓
    are skipped (used by the sign-off path that pre-blocks on ❌).

    Phase 5 Option-1 stage-time flush (`include_all=True`): EVERY pair
    flushes — ✓, ❓, AND ❌ — so the FencerAliasManager UI can surface
    them all for operator review. Wrong matches reach `tbl_fencer`
    briefly; the operator resolves them via Transfer / Discard / Create
    (the corresponding RPCs were extended in
    `20260502000009_phase5_alias_draft_aware.sql` to also update
    `tbl_result_draft`, so the draft rows follow the alias).

    Returns:
        {"written": int, "skipped_blocked": int, "skipped_ambiguous": int,
         "errors": list[(id_fencer, alias, error_msg)]}

    `skipped_*` counts only mean something when `include_all=False`.
    """
    result = {
        "written": 0,
        "skipped_blocked": 0,
        "skipped_ambiguous": 0,
        "errors": [],
    }
    for p in pending:
        if not include_all:
            if p.icon == "❌":
                result["skipped_blocked"] += 1
                continue
            if p.icon == "❓":
                result["skipped_ambiguous"] += 1
                continue
        try:
            # Idempotent — passing an already-present alias is a no-op.
            db._sb.rpc(
                "fn_update_fencer_aliases",
                {"p_id_fencer": p.id_fencer, "p_alias": p.scraped_name},
            ).execute()
            result["written"] += 1
        except Exception as exc:  # noqa: BLE001
            result["errors"].append(
                (p.id_fencer, p.scraped_name, f"{type(exc).__name__}: {exc}")
            )
    return result


def compute_pending_from_matches(
    matches: list, basics_by_id: dict,
) -> list[PendingAlias]:
    """Classify EVERY matched draft row, regardless of existing aliases.

    `matches` is an iterable of objects with attributes/keys
    `id_fencer`, `scraped_name` (or `txt_scraped_name`); `basics_by_id` is
    a dict {id_fencer: {txt_surname, txt_first_name, json_name_aliases?}}.
    Used by both the stage-time .md renderer and the sign-off blocker
    check — single source of truth so the verdicts shown to the operator
    are exactly the ones gating sign-off.

    Skips only TRUE canonical matches (`scraped` == "txt_surname txt_first_name"
    or "txt_first_name txt_surname" after Polish-fold). Every other
    non-empty draft row is run through `classify_alias_pair` and returned
    with its ✓ / ❓ / ❌ verdict — even if the alias is already in the
    matched fencer's `json_name_aliases` (Option-1 stage-time flush
    writes ALL pending pairs, so we cannot use "alias-already-there" as
    evidence the row is OK).
    """
    def _norm(s: str) -> str:
        return " ".join(str(s or "").split()).casefold()

    seen: set[tuple[int, str]] = set()
    out: list[PendingAlias] = []
    for m in matches:
        # Accept either StageMatchResult-style attrs OR draft-row dicts.
        id_fencer = getattr(m, "id_fencer", None)
        if id_fencer is None and isinstance(m, dict):
            id_fencer = m.get("id_fencer")
        if id_fencer is None:
            continue
        scraped = (
            getattr(m, "scraped_name", None)
            or (m.get("scraped_name") if isinstance(m, dict) else None)
            or (m.get("txt_scraped_name") if isinstance(m, dict) else None)
        )
        if not scraped:
            continue
        f = basics_by_id.get(id_fencer)
        if not f:
            continue
        canonical = (
            f"{f.get('txt_surname','')} {f.get('txt_first_name','')}".strip()
        )
        canonical_alt = (
            f"{f.get('txt_first_name','')} {f.get('txt_surname','')}".strip()
        )
        if _norm(scraped) == _norm(canonical) or _norm(scraped) == _norm(canonical_alt):
            continue  # truly canonical — no alias needed

        key = (id_fencer, scraped)
        if key in seen:
            continue
        seen.add(key)
        icon, reason = classify_alias_pair(scraped, canonical)
        out.append(PendingAlias(
            id_fencer=id_fencer, scraped_name=scraped,
            canonical=canonical, icon=icon, reason=reason,
        ))
    rank = {"❌": 0, "❓": 1, "✓": 2}
    out.sort(key=lambda p: (rank.get(p.icon, 9), p.canonical, p.scraped_name))
    return out


def derive_pending_from_run_id(
    db, run_id: str, *, ignore_existing_aliases: bool = False,
) -> list[PendingAlias]:
    """Re-derive pending aliases at sign-off time from the persisted drafts.

    Reads `tbl_result_draft` rows for `run_id`, joins on `tbl_fencer`
    for canonical names + existing aliases, then runs the same
    classification pipeline as `compute_pending_aliases`.

    Args:
        ignore_existing_aliases: when True, scraped names that already
            appear in the matched fencer's `json_name_aliases` are STILL
            classified (instead of being skipped). Phase 5 Option-1
            uses this from the sign-off path: stage-time flush has
            populated `tbl_fencer.json_name_aliases` with EVERY pending
            pair (incl. ❌), so the default "skip if alias-already-there"
            filter would silently swallow unresolved blockers. With this
            flag set, sign-off catches them via classify_alias_pair —
            they're ❌ regardless of whether the alias exists.
    """
    drafts = (
        db._sb.table("tbl_result_draft")
        .select(
            "id_fencer, txt_scraped_name, enum_match_method, "
            "id_tournament_draft"
        )
        .eq("txt_run_id", run_id)
        .execute()
    ).data or []

    # Auto-method drafts only — PENDING / EXCLUDED never alias-write.
    auto_methods = {"AUTO_MATCH", "USER_CONFIRMED", "AUTO_CREATED"}
    rows = [
        r for r in drafts
        if r.get("id_fencer") is not None
        and r.get("enum_match_method") in auto_methods
        and r.get("txt_scraped_name")
    ]
    if not rows:
        return []

    ids = sorted({r["id_fencer"] for r in rows})
    basics = (
        db.fetch_fencer_basics_batch(ids)
        if hasattr(db, "fetch_fencer_basics_batch") else {}
    )

    # Phase 5 user-confirmed-alias filter (migration 20260502000010):
    # skip rows where the scraped name is in the matched fencer's
    # `json_user_confirmed_aliases` (operator clicked Keep). Plain
    # `json_name_aliases` is NOT a user-confirmed signal because the
    # stage-time flush populates it with every pending pair (incl. ❌)
    # for UI surfacing. We need the explicit confirmation column so
    # unresolved wrong-match flushes still surface as ❌ blockers.
    def _norm(s: str) -> str:
        return " ".join(str(s or "").split()).casefold()

    filtered_rows: list[dict] = []
    for r in rows:
        f = basics.get(r["id_fencer"])
        if not f:
            continue
        confirmed = f.get("json_user_confirmed_aliases") or []
        if not isinstance(confirmed, list):
            confirmed = []
        scraped_norm = _norm(r["txt_scraped_name"])
        if any(scraped_norm == _norm(a) for a in confirmed):
            continue
        filtered_rows.append(r)

    return compute_pending_from_matches(filtered_rows, basics)
