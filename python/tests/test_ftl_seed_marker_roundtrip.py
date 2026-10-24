"""FR-125 — a generated seed name round-trips through the results matcher.

Moved unchanged from test_ftl_feed_seed_send.py (where it was FTLDEL-PY-07) when
the e-mail delivery was removed (ADR-080 amendment 2026-10-24). It guards seed
generation, not delivery, and no other test crosses this boundary.
"""

from __future__ import annotations

from python.matcher.fuzzy_match import canonicalize_scraped_name
from python.pipeline.ftl_seed_export import format_nom_with_marker


def test_generated_marker_roundtrips_to_canonical_scraped_name():
    """FR125.RT.01 (was FTLDEL-PY-07): exporter and matcher agree across their graph boundary.

    Built from the marker's real placement (ADR-080 §1 amended 2026-09-12):
    Fencing Time renders "Nom Prenom", so the string the scraper actually meets
    is "SAMECKA-NACZYŃSKA (1) Martyna". The previous form put the digit last,
    where split_name_marker does not match it at all.
    """
    nom = format_nom_with_marker("SAMECKA-NACZYŃSKA", "1")
    assert canonicalize_scraped_name(f"{nom} Martyna") == ("SAMECKA-NACZYŃSKA Martyna")
