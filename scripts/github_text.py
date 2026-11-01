"""Text that a GitHub Summary page shows as written: no tag, no mention, no issue link.

Shared by scripts/release_notes.py (each Release run's notes) and scripts/ci_summary.py
(each CI job's results), so the two escape alike. <, > and & are escaped; an @ and a #
before a digit are written as entities followed by a word joiner. GitHub finds mentions
and issue numbers in the rendered text, where an entity is a plain character again, so
the joiner is what stops the link; it is invisible.

Plans: doc/plans/release-notes-on-every-release-run-2026-11-01.html,
doc/plans/ci-test-summaries-2026-11-01.html. Tests: RELNOTES.03, CISUM.04.
"""

from __future__ import annotations

import html
import re

WORD_JOINER = "&#8288;"
LINKS = re.compile(r"@|#(?=\d)")


def text(raw: str) -> str:
    """Plain text for GitHub: escaped, and no mention or issue link."""
    escaped = html.escape(raw, quote=False)
    return LINKS.sub(lambda m: ("&#64;" if m.group() == "@" else "&#35;") + WORD_JOINER, escaped)
