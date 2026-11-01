"""The LOCAL-equals-PROD check fails on a rejected token (ADR-119 G21 B).

`test_prod_mirror.py` skips as a whole when no SUPABASE_ACCESS_TOKEN is set, as
in CI. A token that is set but rejected used to skip it too, so a stale token in
the environment hid a real mismatch (three leftover fencers on LOCAL, 31 Oct
2026). These tests live apart from that module so they run without a token.
"""

from __future__ import annotations

import pytest


def test_rejected_token_fails_instead_of_skipping(monkeypatch):
    """MIRROR.TOKEN.01 a 401 from the Management API fails the check, and says the token
    in the environment was rejected without showing it."""
    from python.tests import test_prod_mirror as mirror

    def rejected(_table: str) -> int:
        raise RuntimeError('Management API error: 401 {"message":"Unauthorized"}')

    monkeypatch.setattr(mirror, "_prod_count", rejected)
    with pytest.raises(pytest.fail.Exception, match="SUPABASE_ACCESS_TOKEN was rejected"):
        mirror.fetch_prod_counts()


def test_other_errors_still_raise(monkeypatch):
    """MIRROR.TOKEN.02 any other Management API error propagates unchanged."""
    from python.tests import test_prod_mirror as mirror

    def broken(_table: str) -> int:
        raise RuntimeError("Management API error: 500 boom")

    monkeypatch.setattr(mirror, "_prod_count", broken)
    with pytest.raises(RuntimeError, match="500 boom"):
        mirror.fetch_prod_counts()
