"""
Ingestion pipeline orchestrator.

Parses FencingTime XML → resolves identities → calls DB ingest RPC.
Routes notifications through TelegramNotifier at each step.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime

from python.scrapers.fencingtime_xml import (
    detect_categories_from_altname,
    parse_fencingtime_xml_enriched,
    parse_xml_metadata,
    split_combined_results,
)
from python.matcher.fuzzy_match import find_best_match
from python.matcher.pipeline import (
    DOMESTIC_TYPES,
    auto_create_fencer,
    resolve_tournament_results,
)


@dataclass
class IngestResult:
    """Summary of a single file ingestion."""

    tournament_ids: list[int] = field(default_factory=list)
    matched: int = 0
    pending: int = 0
    auto_created: int = 0
    skipped: int = 0
    errors: list[str] = field(default_factory=list)
    skipped_files: list[str] = field(default_factory=list)


def process_xml_file(
    file_bytes: bytes,
    filename: str,
    db,
    notifier,
    season_end_year: int,
    tournament_type: str = "PPW",
    dry_run: bool = False,
) -> IngestResult:
    """Process a single FencingTime XML file through the pipeline.

    Args:
        file_bytes: Raw XML content.
        filename: Original filename (for logging/notifications).
        db: DbConnector instance.
        notifier: TelegramNotifier instance.
        season_end_year: End year of the active season.
        tournament_type: PPW, MPW, PEW, MEW, or MSW.
        dry_run: If True, parse and match but skip DB writes.

    Returns:
        IngestResult with counts and any errors.
    """
    result = IngestResult()

    # 1. Parse metadata
    try:
        metadata = parse_xml_metadata(file_bytes)
    except Exception as e:
        result.errors.append(f"Failed to parse metadata from {filename}: {e}")
        notifier.notify_pipeline_failure(f"XML parse error: {filename} — {e}")
        return result

    # 2. Skip preliminary rounds (Sexe="X")
    if metadata.get("gender") == "X":
        result.skipped_files.append(filename)
        notifier.info(f"Skipped preliminary round: {filename}")
        return result

    # 3. Parse enriched results
    enriched = parse_fencingtime_xml_enriched(file_bytes)
    if not enriched:
        result.errors.append(f"No fencer data (Tireurs) in {filename}")
        notifier.notify_pipeline_failure(f"Empty XML (no Tireurs): {filename}")
        return result

    # 4. Detect categories from AltName
    categories = detect_categories_from_altname(metadata.get("alt_name", ""))

    # 5. Fetch fencer DB for matching
    fencer_db = db.fetch_fencer_db()

    # 6. Handle combined vs single category
    if len(categories) > 1:
        # Combined category — split by DOB/DB lookup
        split_result = split_combined_results(enriched, categories, fencer_db, season_end_year)
        # ADR-024: notify about unresolved DOB fencers
        if split_result.unresolved:
            result.pending += len(split_result.unresolved)
            notifier.notify_missing_dob(
                len(split_result.unresolved),
                filename,
            )
        for cat, cat_results in split_result.buckets.items():
            _process_category(
                cat_results, metadata, cat, fencer_db, db, notifier,
                season_end_year, tournament_type, dry_run, result,
            )
    else:
        category = categories[0] if categories else "V2"
        _process_category(
            enriched, metadata, category, fencer_db, db, notifier,
            season_end_year, tournament_type, dry_run, result,
        )

    return result


def _process_category(
    enriched_results: list[dict],
    metadata: dict,
    category: str,
    fencer_db: list[dict],
    db,
    notifier,
    season_end_year: int,
    tournament_type: str,
    dry_run: bool,
    result: IngestResult,
) -> None:
    """Process results for a single category within a file."""
    if not enriched_results:
        return
    _prev_pending = result.pending
    weapon = metadata["weapon"]
    gender = metadata["gender"]
    raw_date = metadata.get("date", "")
    # Convert DD.MM.YYYY → YYYY-MM-DD for PostgreSQL
    try:
        date = datetime.strptime(raw_date, "%d.%m.%Y").strftime("%Y-%m-%d")
    except ValueError:
        date = raw_date  # already ISO or unparseable — pass through

    # Event-centric lookup (ADR-025): find event by date, then find/create tournament
    event = None
    tournament = None
    event = db.find_event_by_date(date)
    if event is None:
        # Fallback: try legacy global tournament lookup for backwards compatibility
        tournament = db.find_tournament(weapon, gender, category, date)
        if tournament is None:
            result.errors.append(
                f"No event scheduled for {date} and no tournament found: {weapon} {gender} {category}"
            )
            notifier.notify_tournament_not_found(weapon, gender, category, date, "")
            return
        tournament_id = tournament["id_tournament"]
    else:
        # Create tournament under event if it doesn't exist
        tournament_id = db.find_or_create_tournament(
            event["id_event"], weapon, gender, category, date, tournament_type
        )

    t_type = tournament_type

    # Check for duplicate import (warn but proceed — ADR-014 handles idempotent reimport)
    if hasattr(db, 'has_existing_results') and db.has_existing_results(tournament_id):
        tourn_info = f"{weapon} {gender} {category}"
        notifier.notify_duplicate_import(tourn_info)

    # Resolve identities using matcher pipeline
    scraped_names = [r["fencer_name"] for r in enriched_results]
    resolved = resolve_tournament_results(
        scraped_names, fencer_db, t_type, category, season_end_year
    )

    # Build JSONB payload for RPC
    results_json = []
    place_idx = 0

    for r in enriched_results:
        name = r["fencer_name"]
        place = r["place"]

        # Find match result for this name
        match = None
        for m in resolved.matched:
            if m.scraped_name == name:
                match = m
                break

        if match is None:
            # Check if it was skipped (international, unmatched)
            if name in resolved.skipped:
                result.skipped += 1
                continue
            # Check auto-created
            is_auto = any(
                ac["txt_surname"].upper() in name.upper()
                for ac in resolved.auto_created
            )
            if is_auto:
                # Insert fencer first
                ac_data = next(
                    ac for ac in resolved.auto_created
                    if ac["txt_surname"].upper() in name.upper()
                )
                if not dry_run:
                    new_id = db.insert_fencer({
                        **ac_data,
                        "txt_nationality": r.get("country", "PL"),
                    })
                else:
                    new_id = -1
                result.auto_created += 1
                results_json.append({
                    "id_fencer": new_id,
                    "int_place": place,
                    "txt_scraped_name": name,
                    "num_confidence": 0,
                    "enum_match_status": "NEW_FENCER",
                })
                continue
            # Shouldn't reach here, but skip gracefully
            result.skipped += 1
            continue

        # Matched or pending
        if match.status == "AUTO_MATCHED":
            result.matched += 1
            results_json.append({
                "id_fencer": match.id_fencer,
                "int_place": place,
                "txt_scraped_name": name,
                "num_confidence": match.confidence,
                "enum_match_status": "AUTO_MATCHED",
            })
        elif match.status == "PENDING":
            result.pending += 1
            results_json.append({
                "id_fencer": match.id_fencer,
                "int_place": place,
                "txt_scraped_name": name,
                "num_confidence": match.confidence,
                "enum_match_status": "PENDING",
            })
        elif match.status == "NEW_FENCER":
            # Domestic auto-create
            ac_data = auto_create_fencer(name, category, season_end_year)
            if not dry_run:
                new_id = db.insert_fencer({
                    **ac_data,
                    "txt_nationality": r.get("country", "PL"),
                })
            else:
                new_id = -1
            result.auto_created += 1
            results_json.append({
                "id_fencer": new_id,
                "int_place": place,
                "txt_scraped_name": name,
                "num_confidence": 0,
                "enum_match_status": "NEW_FENCER",
            })

    # Ingest to DB
    if results_json and not dry_run:
        db.ingest_results(tournament_id, results_json)
        result.tournament_ids.append(tournament_id)
        tourn_label = str(tournament_id)
        if event is not None:
            tourn_label = f"{event.get('txt_code', '')}-{category}-{gender}-{weapon}"
        elif tournament is not None:
            tourn_label = tournament.get("txt_code", str(tournament_id))
        notifier.notify_import_success(
            tourn_label,
            {"matched": result.matched, "pending": result.pending,
             "auto_created": result.auto_created, "skipped": result.skipped},
        )
    elif results_json:
        result.tournament_ids.append(tournament_id)

    # Notify pending identity reviews (only for this tournament's new pending)
    pending_this_tourn = result.pending - _prev_pending
    if pending_this_tourn > 0:
        notifier.notify_identity_review(pending_this_tourn, tourn_label if results_json else "")