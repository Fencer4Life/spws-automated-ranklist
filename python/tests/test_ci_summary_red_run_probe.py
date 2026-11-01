"""Throwaway: one deliberately failing test, so a red CI run shows what its Summary
page says about a failure (doc/plans/ci-test-summaries-2026-11-01.html, V2).

Lives only on a draft pull request that is closed unmerged; never on main.
"""


def test_CISUM_V2_probe_fails_on_purpose() -> None:
    """CISUM.V2 probe: fails on purpose; the pytest section must name it."""
    assert 1 == 2, "deliberate failure for the CI summary check V2"
