"""Mutation suite for the PZSz reader (ADR-116 §9; RTM PZSZ.LET.MUTATION).

The reader must never publish a *wrong* value. To prove it, each golden letter
is perturbed by random chains of the operators below — dash and space variants,
tripled glyphs and letter-spacing, soft hyphens, a street split across the line
break, swapped label forms, and injected noise that competes for the answer
(a payee account block, an other-city organizer, a hotel address, a prize in
euro, a payment deadline, a copied last-year date, a duplicated letter). Across
roughly six thousand cases the invariant is absolute:

* the address is the golden one or nothing — never a different string;
* the fee is the golden one or nothing — never a different amount;
* the dates are the golden ones or nothing — never a date the letter did not
  set as the event's.

Operators either preserve the answer (the normaliser maps their change back) or
touch only the noise around it; none corrupts the answer's own glyphs, because a
reader cannot be blamed for faithfully reading a mangled ground truth. That is
out of scope here and covered by the golden set's clean shapes.
"""

from __future__ import annotations

import random
import re

import pytest

from python.scrapers.pzsz_letter import read_letter
from python.tests.pzsz_golden_letters import GOLDEN, Golden

BASES = tuple(g for g in GOLDEN if g.has_text)
CASES_PER_BASE = 550


def _as_html(text: str) -> bytes:
    """Route plain golden text through the reader's HTML branch, as the golden
    test does — the extraction differs by source, the passes do not."""
    return f"<html><body><pre>{text}</pre></body></html>".encode()


_DASHES = "–—‒―−"
_STREET_SPLIT = re.compile(r"(ul\.?|al\.?|pl\.?)\s+([^\d,\n]+?)\s+(\d)")


def op_dashes(text: str, rng: random.Random) -> str:
    return text.replace("-", rng.choice(_DASHES))


def op_nbsp(text: str, rng: random.Random) -> str:
    return text.replace(" ", " ") if rng.random() < 0.5 else text.replace(", ", ", ")


def op_curly_quotes(text: str, rng: random.Random) -> str:
    return text.replace('"', rng.choice(["“", "”"]))


def op_blank_lines(text: str, rng: random.Random) -> str:
    # Widen existing paragraph breaks only. A real extractor never inserts a
    # blank between a wrapped street and its house number (T7 adjacency), so
    # shattering every single newline would test a shape that cannot occur.
    return text.replace("\n\n", "\n\n\n" if rng.random() < 0.5 else "\n \n\n")


def op_crlf(text: str, rng: random.Random) -> str:
    return text.replace("\n", "\r\n")


def op_trailing_ws(text: str, rng: random.Random) -> str:
    return "\n".join(line + "   " for line in text.split("\n"))


def op_soft_hyphens(text: str, rng: random.Random) -> str:
    # The normaliser removes soft hyphens, so scattering them is answer-safe.
    out = []
    for ch in text:
        out.append(ch)
        if ch.isalpha() and rng.random() < 0.15:
            out.append("­")
    return "".join(out)


def op_split_street(text: str, rng: random.Random) -> str:
    return _STREET_SPLIT.sub(lambda m: f"{m.group(1)} {m.group(2)}\n{m.group(3)}", text, count=1)


def op_swap_label(text: str, rng: random.Random) -> str:
    for a, b in (
        ("Miejsce zawodów", "Obiekt"),
        ("Obiekt", "Lokalizacja"),
        ("Startowe", "Opłata startowa"),
    ):
        if a in text:
            return text.replace(a, b, 1)
    return text


def op_letter_space_komunikat(text: str, rng: random.Random) -> str:
    return text.replace("KOMUNIKAT", "K O M U N I K A T", 1)


def op_footnote_label(text: str, rng: random.Random) -> str:
    for label in ("Startowe", "Wpisowe", "Program"):
        if label in text:
            return text.replace(label, f"{label}{rng.randint(1, 9)}", 1)
    return text


def op_tripled_title(text: str, rng: random.Random) -> str:
    return text.replace("KOMUNIKAT", "KKKOOOMMMUUUNNNIIIKKKAAATTT", 1)


_LABEL_HEAD = re.compile(
    r"(?i)^\s*(?:miejsce\s+zawod\w*|miejsce|obiekt|lokalizacja|termin\w*|data)"
)


def op_uppercase_labels(text: str, rng: random.Random) -> str:
    # Uppercase only the recognised label TOKEN, never any of the value, so the
    # operator tests case-insensitive region detection without corrupting the
    # answer's own glyphs — whatever other operators did to the line first.
    def up(line: str) -> str:
        m = _LABEL_HEAD.match(line)
        return (line[: m.end()].upper() + line[m.end() :]) if m else line

    return "\n".join(up(line) for line in text.split("\n"))


def op_inject_letterhead(text: str, rng: random.Random) -> str:
    head = (
        "Stowarzyszenie Organizacyjne z siedzibą\n"
        "ul. Kontaktowa 9, 00-001 Zamość\n"
        "tel. 600 100 200, e-mail: biuro@example.org\n"
    )
    return head + text


def op_inject_payee(text: str, rng: random.Random) -> str:
    block = (
        "\nWpłaty na konto organizatora:\n"
        "ul. Bankowa 5, 99-999 Rachunkowo\n"
        "Nr konta: 11 2222 3333 4444 5555 6666 7777\n"
        "Tytułem: opłata startowa\n"
    )
    return text + block


def op_inject_hotel(text: str, rng: random.Random) -> str:
    block = "\nZakwaterowanie:\nHotel Olimp, ul. Hotelowa 3, 88-888 Nocleg\n"
    return text + block


def op_inject_prize(text: str, rng: random.Random) -> str:
    return text + "\nNagrody: 1 miejsce 1200 euro, 2 miejsce 800 euro\n"


def op_inject_deadline(text: str, rng: random.Random) -> str:
    return text + "\nZgłoszenia przyjmujemy do dnia 1 stycznia 2027 r.\n"


def op_inject_times(text: str, rng: random.Random) -> str:
    return text + "\nProgram: weryfikacja godz. 9.00, walki od godz. 10.00 do godz. 15.30\n"


def op_inject_last_year(text: str, rng: random.Random) -> str:
    return text + "\nW ubiegłym roku edycja odbyła się 10 października 2025 r.\n"


def op_inject_entrance(text: str, rng: random.Random) -> str:
    return text.replace("\n\n", "\n(wjazd od ul. Bocznej, parking za halą)\n\n", 1)


def op_duplicate(text: str, rng: random.Random) -> str:
    return text + "\n\n" + text


OPERATORS = (
    op_dashes,
    op_nbsp,
    op_curly_quotes,
    op_blank_lines,
    op_crlf,
    op_trailing_ws,
    op_soft_hyphens,
    op_split_street,
    op_swap_label,
    op_letter_space_komunikat,
    op_footnote_label,
    op_tripled_title,
    op_uppercase_labels,
    op_inject_letterhead,
    op_inject_payee,
    op_inject_hotel,
    op_inject_prize,
    op_inject_deadline,
    op_inject_times,
    op_inject_last_year,
    op_inject_entrance,
    op_duplicate,
)


def _mutate(base_text: str, rng: random.Random) -> tuple[str, list[str]]:
    k = rng.randint(1, 6)
    chosen = rng.sample(OPERATORS, k)
    text = base_text
    for op in chosen:
        text = op(text, rng)
    return text, [op.__name__ for op in chosen]


@pytest.mark.parametrize("base", BASES, ids=lambda b: b.name)
def test_mutations_never_emit_a_wrong_value(base: Golden) -> None:
    allowed_fee = {None, base.fee} | set(base.fee_candidates)
    violations: list[str] = []
    ran = 0
    for case_i in range(CASES_PER_BASE):
        rng = random.Random(f"{base.name}:{case_i}")
        text, chain = _mutate(base.text, rng)
        r = read_letter(_as_html(text), base.ctx)
        if not r.has_text:
            continue
        ran += 1
        addr = r.address.value if r.address else None
        if addr not in (None, base.address):
            violations.append(f"ADDRESS {addr!r} via {chain}")
        fee = r.fee.value if r.fee else None
        if fee not in allowed_fee:
            violations.append(f"FEE {fee!r} via {chain}")
        if r.dt_start not in (None, base.dt_start):
            violations.append(f"DT_START {r.dt_start!r} via {chain}")
        if r.dt_end not in (None, base.dt_end, base.dt_start):
            violations.append(f"DT_END {r.dt_end!r} via {chain}")
    assert ran >= CASES_PER_BASE // 2, (
        f"{base.name}: only {ran} cases had text — the pipeline was skipped"
    )
    assert not violations, f"{base.name}: {len(violations)} wrong values\n" + "\n".join(
        violations[:12]
    )


def test_the_suite_covers_about_six_thousand_cases() -> None:
    assert len(BASES) * CASES_PER_BASE >= 5000
