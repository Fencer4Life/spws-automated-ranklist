"""
Name normalization + (scraped, canonical) classification used by the
fencer-matching summary AND the Phase 5 alias-writeback pipeline.

Centralized here so the *exact same* verdict ladder (✓ same person /
❓ ambiguous / ❌ wrong match) is rendered in the staging summary and
applied at sign-off when deciding whether to call
`fn_update_fencer_aliases`. Drift between the two would mean the user
sees one verdict in the .md and the system writes a different one.

All helpers are pure (no I/O) and Polish-aware.
"""

from __future__ import annotations


# Polish diacritic → ASCII fold. Used so "Stanisław" and "Stanislaw" compare
# equal in alias decisions; we must not treat the diacritic difference as
# evidence of a different person.
_PL_FOLD = str.maketrans({
    "ą": "a", "Ą": "a", "ć": "c", "Ć": "c", "ę": "e", "Ę": "e",
    "ł": "l", "Ł": "l", "ń": "n", "Ń": "n", "ó": "o", "Ó": "o",
    "ś": "s", "Ś": "s", "ź": "z", "Ź": "z", "ż": "z", "Ż": "z",
})


def name_fold(s: str) -> str:
    """Casefold + strip Polish diacritics + collapse whitespace runs."""
    if not s:
        return ""
    return " ".join(s.translate(_PL_FOLD).casefold().split())


def levenshtein(a: str, b: str) -> int:
    """Iterative-DP Levenshtein distance. Used for typo classification only."""
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(
                cur[j - 1] + 1,
                prev[j] + 1,
                prev[j - 1] + (0 if ca == cb else 1),
            ))
        prev = cur
    return prev[-1]


def split_polish_name(name: str) -> tuple[str, str]:
    """Best-effort split of `name` into (surname, first_name).

    Polish FTL/Engarde convention is SURNAME (caps) + first name. We pick
    every all-caps token as part of the surname; the rest is the first
    name. Falls back to `parts[0]` as surname when no all-caps tokens are
    present (so single-token strings still return something usable).
    """
    parts = (name or "").split()
    if not parts:
        return "", ""
    surname_parts = [
        p for p in parts
        if p == p.upper() and any(c.isalpha() for c in p)
    ]
    if not surname_parts:
        # No all-caps tokens → assume "Surname Firstname" or a lone token.
        return parts[0], " ".join(parts[1:]) if len(parts) > 1 else ""
    surname = " ".join(surname_parts)
    first = " ".join(p for p in parts if p not in surname_parts)
    return surname, first


def classify_alias_pair(scraped: str, canonical: str) -> tuple[str, str]:
    """Classify a (scraped_name, canonical_name) pair as alias material.

    Returns (icon, reason). `icon` is one of:
      * "✓"  — same person, just spelling/case/whitespace variant. SAFE
               to write to `tbl_fencer.json_name_aliases`.
      * "❓"  — ambiguous; needs human review before write.
      * "❌"  — surname or first-name disagreement strong enough to suggest
               this is the WRONG fencer. Block the write.

    The Phase 5 sign-off uses these icons to decide which pending alias
    pairs flush automatically and which block sign-off.
    """
    s_full = name_fold(scraped)
    c_full = name_fold(canonical)
    if s_full == c_full:
        return "✓", "exact match after normalization"

    s_sur, s_first = split_polish_name(scraped)
    c_sur, c_first = split_polish_name(canonical)

    s_sur_f = name_fold(s_sur)
    c_sur_f = name_fold(c_sur)
    s_fn_f = name_fold(s_first)
    c_fn_f = name_fold(c_first)

    # Surname analysis — strip hyphens for prefix/suffix containment check
    s_sur_h = s_sur_f.replace("-", "").replace(" ", "")
    c_sur_h = c_sur_f.replace("-", "").replace(" ", "")
    surname_identical = s_sur_f == c_sur_f
    surname_contained = (
        bool(s_sur_h) and bool(c_sur_h)
        and (s_sur_h in c_sur_h or c_sur_h in s_sur_h)
    )
    surname_dist = levenshtein(s_sur_h, c_sur_h) if s_sur_h and c_sur_h else 99
    surname_close = surname_dist <= 2

    # First-name analysis
    first_identical = s_fn_f == c_fn_f
    first_dist = levenshtein(s_fn_f, c_fn_f) if s_fn_f and c_fn_f else 99
    first_close = first_dist <= 2

    # Strong "wrong-match" signals: surname or first-name disagreement
    if not (surname_identical or surname_contained or surname_close):
        return "❌", "different surnames — probably wrong match"
    if not (first_identical or first_close):
        return "❌", "different first names — probably wrong match"

    # Now classify the kind of legitimate variation
    if surname_identical and first_identical:
        if scraped != canonical:
            return "✓", "case / spacing only"
        return "✓", "identical"

    if "-" in (scraped + canonical) and surname_contained and not surname_identical:
        return "✓", "likely same person (short form / married — hyphen variant)"
    if surname_contained and not surname_identical:
        return "✓", "surname truncation / expansion"
    s_norm_strict = s_full.replace(" ", "").replace("-", "")
    c_norm_strict = c_full.replace(" ", "").replace("-", "")
    if s_norm_strict == c_norm_strict:
        return "✓", "space / hyphen normalization"
    if surname_close and not first_close:
        return "✓", "likely typo on surname"
    if first_close and not surname_close:
        return "✓", "likely typo on first name"
    if surname_close and first_close:
        return "✓", "likely typo / transliteration"
    return "❓", "ambiguous — review by hand"
