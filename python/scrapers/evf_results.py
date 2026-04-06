"""
EVF Results PDF Parser — veteransfencing.eu (ADR-028)

Parses Engarde-generated PDFs from EVF championship results pages.
Extracts final classification (Classement général) with rank, name, country.
"""

from __future__ import annotations

import re
from io import BytesIO

try:
    import pypdf
except ImportError:
    pypdf = None  # type: ignore[assignment]


# EVF code mapping: letter codes → SPWS enums
# Format: {weapon_code}{gender_code}V{category_number}
# Weapon: E=Epee, F=Foil, S=Sabre
# Gender: H=Homme(Men), D=Dame(Women)
# Category: 1-4 → V1-V4
_WEAPON_MAP = {"E": "EPEE", "F": "FOIL", "S": "SABRE"}
_GENDER_MAP = {"H": "M", "D": "F"}
_CATEGORY_MAP = {"1": "V1", "2": "V2", "3": "V3", "4": "V4"}


def evf_code_to_category(code: str) -> tuple[str, str, str]:
    """Convert EVF result code to (weapon, gender, category).

    Examples:
        EHV2 → (EPEE, M, V2)
        SDV3 → (SABRE, F, V3)
        FHV1 → (FOIL, M, V1)
    """
    if len(code) < 4:
        raise ValueError(f"Invalid EVF code: {code}")

    weapon_code = code[0].upper()
    gender_code = code[1].upper()
    cat_number = code[3] if len(code) > 3 else code[-1]

    weapon = _WEAPON_MAP.get(weapon_code)
    gender = _GENDER_MAP.get(gender_code)
    category = _CATEGORY_MAP.get(cat_number)

    if not weapon or not gender or not category:
        raise ValueError(f"Cannot map EVF code: {code}")

    return weapon, gender, category


def parse_evf_result_pdf(pdf_bytes: bytes) -> list[dict]:
    """Extract final classification from Engarde-generated EVF result PDF.

    Returns list of dicts matching scraper contract:
        [{"fencer_name": "SURNAME FirstName", "place": 1, "country": "POL"}, ...]

    Looks for "Classement général" pages (final ranking of all fencers).
    """
    if pypdf is None:
        raise ImportError("pypdf is required for PDF parsing")

    try:
        reader = pypdf.PdfReader(BytesIO(pdf_bytes))
    except Exception:
        return []

    results: list[dict] = []
    seen_ranks: set[tuple[int, str]] = set()  # (rank, name) to dedup across pages

    for page in reader.pages:
        try:
            text = page.extract_text()
        except Exception:
            continue

        if not text:
            continue

        # Only parse "Classement général" (final classification) pages
        if "Classement" not in text or "néral" not in text:
            # Also try without accent: "general"
            if "general" not in text.lower() or "classement" not in text.lower():
                continue

        lines = text.split("\n")
        i = 0
        while i < len(lines):
            line = lines[i].strip()

            # Match: rank (1-3 digits) followed by name text
            m = re.match(r"^(\d{1,3})\s*(.+)", line)
            if m:
                rank = int(m.group(1))
                name_part = m.group(2).strip()

                # Next line should have 3-letter country code
                country = ""
                if i + 1 < len(lines):
                    next_line = lines[i + 1].strip()
                    cm = re.match(r"^([A-Z]{3})", next_line)
                    if cm:
                        country = cm.group(1)
                        i += 1  # skip country line

                # Clean up name (remove trailing whitespace artifacts)
                name_part = re.sub(r"\s+", " ", name_part).strip()

                # Build fencer_name in "SURNAME FirstName" format
                # Names from PDF are already in this format (truncated sometimes)
                fencer_name = name_part

                key = (rank, fencer_name)
                if key not in seen_ranks and country:
                    seen_ranks.add(key)
                    results.append({
                        "fencer_name": fencer_name,
                        "place": rank,
                        "country": country,
                    })

            i += 1

    # Sort by rank
    results.sort(key=lambda r: r["place"])
    return results
