"""Golden-set gate for the PZSz reader (ADR-116 §9; RTM PZSZ.LET.GOLDEN).

Each PII-free golden letter (``pzsz_golden_letters``) is read through
:func:`read_letter` and every field is checked exactly. A wrong value fails;
an abstention is asserted where the letter is genuinely ambiguous. The letters
are plain text, so the bytes are UTF-8 encoded — the HTML branch of the kind
detector is exercised by the account-number-free shapes, and the no-text case
(a scan) by an empty body.
"""

from __future__ import annotations

import pytest

from python.scrapers.pzsz_letter import read_letter
from python.tests.pzsz_golden_letters import GOLDEN, Golden


def _read(case: Golden):
    # A plain-text body is not a PDF/DOCX/HTML magic match; wrap it so the kind
    # detector routes it through the HTML text branch (tags absent, text kept).
    body = case.text if not case.text else f"<html><body><pre>{case.text}</pre></body></html>"
    return read_letter(body.encode("utf-8"), case.ctx)


@pytest.mark.parametrize("case", GOLDEN, ids=lambda c: c.name)
def test_golden_letter(case: Golden) -> None:
    r = _read(case)
    assert r.has_text is case.has_text, case.traps
    if not case.has_text:
        return
    assert r.city_match is case.city_match, f"{case.name}: city_match"
    assert (r.address.value if r.address else None) == case.address, f"{case.name}: address"
    assert r.address_candidates == case.address_candidates, f"{case.name}: address candidates"
    assert (r.fee.value if r.fee else None) == case.fee, f"{case.name}: fee"
    assert sorted(r.fee_candidates) == sorted(case.fee_candidates), f"{case.name}: fee candidates"
    assert r.dt_start == case.dt_start, f"{case.name}: dt_start"
    assert r.dt_end == case.dt_end, f"{case.name}: dt_end"
