"""
NAME.CLS — the alias-pair checker used at Phase 5 sign-off.

python/pipeline/name_classify.py:classify_alias_pair decides whether a
(scraped, roster) name pair is a spelling variant (✓), unclear (❓) or a
suspected wrong match (❌, which blocks sign-off). The runner's
`_classify_alias_pair` is the same function.
"""

from __future__ import annotations

import pytest

from python.pipeline.name_classify import classify_alias_pair
from python.tools.phase5_runner import _classify_alias_pair


class TestSecondGivenName:
    @pytest.mark.parametrize(
        "scraped,canonical",
        [
            ("SZKODA Marek", "SZKODA Marek Tomasz"),
            ("KOWALSKI Jan Paweł", "KOWALSKI Jan"),
            ("NOWAK Anna", "NOWAK Anna Maria"),
        ],
    )
    def test_a_second_given_name_is_the_same_first_name(self, scraped, canonical):
        """NAME.CLS.01 Polish fencers often carry two given names and a source
        lists one: FTL's "SZKODA Marek" is SZKODA Marek Tomasz (Jabłonna 2025).
        The first given names agree, so it is a variant, not a wrong match; the
        matcher already scores it 100."""
        icon, reason = classify_alias_pair(scraped, canonical)
        assert (icon, reason) == ("✓", "second given name")

    @pytest.mark.parametrize(
        "scraped,canonical",
        [
            ("SZKODA Piotr", "SZKODA Marek Tomasz"),
            ("SZKODA Tomasz", "SZKODA Marek Tomasz"),
            ("BISKUPSKI Marek", "MIKULICKI Arkadiusz"),
        ],
    )
    def test_another_first_name_is_still_a_wrong_match(self, scraped, canonical):
        """NAME.CLS.02 only the FIRST given name counts: a different first
        name, or the second given name alone, stays ❌; so does another
        surname."""
        assert classify_alias_pair(scraped, canonical)[0] == "❌"

    def test_the_runner_uses_the_same_checker(self):
        """NAME.CLS.03 the runner's copy is the shared function, so the
        staging summary and sign-off cannot disagree."""
        assert _classify_alias_pair("SZKODA Marek", "SZKODA Marek Tomasz") == (
            "✓",
            "second given name",
        )


class TestShortSurnameTypo:
    @pytest.mark.parametrize(
        "scraped,canonical,icon",
        [
            ("ŁOJAK Szymon", "NOWAK Szymon", "❌"),
            ("KOWALSKY Jan", "KOWALSKI Jan", "✓"),
            ("NOWAK Szymon", "NOWAKK Szymon", "✓"),
        ],
    )
    def test_two_letters_apart_in_a_short_surname_is_another_name(self, scraped, canonical, icon):
        """NAME.CLS.04 ŁOJAK and NOWAK are two letters apart in five: two
        surnames, not a typo (Jabłonna 2026 wrote "ŁOJAK Szymon" onto NOWAK
        Szymon). A surname of up to six letters allows one letter of typo; a
        longer one, two."""
        assert classify_alias_pair(scraped, canonical)[0] == icon
