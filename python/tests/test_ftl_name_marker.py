"""FTL.NAME.01 — a category tag in an FTL name never reaches the matcher or an alias.

FTL organisers tag each fencer's category in three ways: mid-name
("ATANASSOW 2 Aleksander", Jabłonna), a numeric suffix ("PRZYKŁADOWSKA Anna
(1)", our own exporter) and a lettered suffix ("KORONA Przemyslaw (V2)", the
Veteran Irish Open 2026). The lettered suffix was kept in the name: staging
then wrote "GAJDA Leszek (V3)" as an alias (2 Oct 2026).
"""

from __future__ import annotations

import pytest


@pytest.mark.parametrize(
    ("raw", "name", "marker"),
    [
        ("KORONA Przemyslaw (V2)", "KORONA Przemyslaw", "2"),
        ("GAJDA Leszek (v3)", "GAJDA Leszek", "3"),
        ("PRZYKŁADOWSKA Anna (1)", "PRZYKŁADOWSKA Anna", "1"),
        ("ATANASSOW 2 Aleksander", "ATANASSOW Aleksander", "2"),
        ("ATANASSOW Aleksander", "ATANASSOW Aleksander", None),
    ],
)
def test_FTL_NAME_01_category_tags_are_split_from_the_name(raw, name, marker):
    from python.scrapers.ftl import _clean_name, _split_name_and_marker

    assert _clean_name(raw) == name
    assert _split_name_and_marker(raw) == (name, marker)
