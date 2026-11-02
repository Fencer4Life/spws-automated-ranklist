"""Fixtures shared by every test under python/tests."""

from __future__ import annotations

from pathlib import Path

import pytest


@pytest.fixture(autouse=True)
def staging_writes_stay_in_the_test(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """ADR-119 G25: the 3-way diff and the staging report fall back to the
    repository's own doc/staging when they are given no folder, so a test that
    gave none rewrote a committed file. Both fallbacks now point at the test's
    own temporary folder; a test that names a folder is unaffected (P3.D13)."""
    from python.pipeline import md_writer, three_way_diff

    monkeypatch.setattr(three_way_diff, "_project_root", lambda: tmp_path)
    monkeypatch.setattr(md_writer, "DEFAULT_STAGING_DIR", tmp_path / "doc" / "staging")


@pytest.fixture(autouse=True)
def the_checkouts_token_stays_out_of_the_test(
    request: pytest.FixtureRequest, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Every Supabase token reader takes the checkout's .env before the environment
    (python/supabase_token.py, scripts/supabase-token.sh), so a test that sets or
    removes SUPABASE_ACCESS_TOKEN would be handed the real token instead, and send it
    wherever the test points. Here both readers, and every process a test starts,
    read a .env that does not exist; a module marked real_dotenv (the LOCAL = PROD
    check) reads the real one (ENVTOKEN.07)."""
    if request.node.get_closest_marker("real_dotenv") is None:
        monkeypatch.setenv("SUPABASE_TOKEN_ENV_FILE", str(tmp_path / "no-such.env"))


@pytest.fixture(autouse=True)
def each_test_signs_in_to_ftl_afresh() -> None:
    """ADR-119 G71: a refused FTL sign-in is remembered for the rest of the
    process, so one test's refusal would answer the next test's sign-in. Each
    test starts with no session and no refusal (FTL.REFUSED.*)."""
    from python.scrapers.ftl_auth import reset_session_cache

    reset_session_cache()
