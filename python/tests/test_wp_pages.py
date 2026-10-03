"""WP.PAGE.01–02 — the WordPress page bodies and the script that publishes them.

ADR-109 (FR-151); plan doc/plans/wordpress-ranking-points-table-brainstorm-2026-10-02.html
§03, §05 and Part II. Every public WordPress page body is one element tag from the
file host; doc/wordpress/ keeps a reference copy of each, with the PROD anon key
replaced by a placeholder. scripts/wp_publish_page.py fills the placeholder from
SUPABASE_PROD_ANON_KEY when it posts a body, never prints the key, and refuses to
post a body that still holds the placeholder.
"""

from __future__ import annotations

import importlib.util
import re
import sys
from pathlib import Path
from types import ModuleType, SimpleNamespace
from typing import Any

import pytest

ROOT = Path(__file__).resolve().parents[2]
WP_DIR = ROOT / "doc/wordpress"
SCRIPT = ROOT / "scripts/wp_publish_page.py"

PLACEHOLDER = "@@SUPABASE_PROD_KEY@@"
BUNDLE = 'src="https://fencer4life.github.io/spws-automated-ranklist/assets/main.ce.js"'
ASSET_BASE = 'asset-base="https://fencer4life.github.io/spws-automated-ranklist/"'
HREFS = (
    'href-home="https://weteraniszermierki.pl/"',
    'href-ranking="/ranking/"',
    'href-calendar="/znajdz-zawody/"',
    'href-calculator="/kalkulator-punktow/"',
    'href-table="/tabela-punktacji/"',
)
# Anything shaped like a real Supabase key: a legacy JWT anon key or a new
# publishable key. A reference copy may hold neither.
KEY_SHAPE = re.compile(r"eyJ[A-Za-z0-9_-]{10,}|sb_publishable_[A-Za-z0-9_-]{10,}")

# The five page bodies (plan §03): file name → the element tag it must open with.
PAGES = {
    "ranking.html": '<spws-ranklist chrome="site" view="ranklist" admin-entry',
    "znajdz-zawody.html": '<spws-calendar chrome="site"',
    "kalkulator-punktow.html": '<spws-document doc="kalkulator-punktow"',
    "tabela-punktacji.html": '<spws-document doc="tabela-punktacji"',
    "pliki-zasilajace-xml-ftl.html": "<spws-ftl-export",
}
SITE_PAGES = (
    "ranking.html",
    "znajdz-zawody.html",
    "kalkulator-punktow.html",
    "tabela-punktacji.html",
)
DB_PAGES = ("ranking.html", "znajdz-zawody.html", "pliki-zasilajace-xml-ftl.html")


def _body(name: str) -> str:
    path = WP_DIR / name
    assert path.is_file(), f"doc/wordpress/{name} is missing"
    return path.read_text(encoding="utf-8")


# ── WP.PAGE.01 — the reference copies ─────────────────────────────────────────


@pytest.mark.parametrize("name", sorted(PAGES))
def test_wp_page_01_reference_copy_loads_the_stable_bundle_inside_the_theme_style(
    name: str,
) -> None:
    """WP.PAGE.01 — each body loads assets/main.ce.js and hides the theme (ADR-090 §7)."""
    body = _body(name)
    assert BUNDLE in body
    assert "<style>" in body and "header.header" in body and "footer.footer" in body
    assert '<div class="spws-embed">' in body
    assert PAGES[name] in body
    assert ASSET_BASE in body


@pytest.mark.parametrize("name", SITE_PAGES)
def test_wp_page_01_site_pages_carry_every_address(name: str) -> None:
    """WP.PAGE.01 — the four public pages tell the bar and the drawer where everything is."""
    body = _body(name)
    for attr in HREFS:
        assert attr in body, f"{name}: {attr}"


@pytest.mark.parametrize("name", sorted(PAGES))
def test_wp_page_01_reference_copy_carries_the_placeholder_never_a_key(name: str) -> None:
    """WP.PAGE.01 — a page that reads the database holds the placeholder; none holds a key."""
    body = _body(name)
    assert KEY_SHAPE.search(body) is None, f"{name} holds something shaped like a key"
    values = re.findall(r'supabase-prod-key="([^"]*)"', body)
    if name in DB_PAGES:
        assert values == [PLACEHOLDER]
    else:
        # The documents frame their own PROD copy; the page passes no key at all.
        assert values == []
    assert "supabase-cert-" not in body


# ── WP.PAGE.02 — the publishing script fills the placeholder ─────────────────

SECRET = "sb_publishable_TESTONLY_not_a_real_key_0123456789"


def _load_script() -> ModuleType:
    spec = importlib.util.spec_from_file_location("wp_publish_page_under_test", SCRIPT)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def wp(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> ModuleType:
    """The script, pointed at a throwaway .env and a fake XML-RPC endpoint."""
    module = _load_script()
    env_file = tmp_path / ".env"
    env_file.write_text(f'SUPABASE_PROD_ANON_KEY="{SECRET}"\n', encoding="utf-8")
    monkeypatch.setattr(module, "ENV_FILE", str(env_file))
    monkeypatch.delenv("SUPABASE_PROD_ANON_KEY", raising=False)
    monkeypatch.setenv("WP_PUBLISH_CONFIRM", "yes")
    monkeypatch.setattr(module, "creds", lambda: ("https://wp.example", "user", "app-password"))
    calls: list[tuple[str, tuple[Any, ...]]] = []

    def fake_call(_url: str, method: str, params: tuple[Any, ...]) -> Any:
        calls.append((method, params))
        if method == "wp.newPost":
            return 4242
        return {"post_status": "draft", "link": "https://wp.example/x/"}

    monkeypatch.setattr(module, "xmlrpc_call", fake_call)
    module.calls = calls  # type: ignore[attr-defined]
    return module


def _posted_content(calls: list[tuple[str, tuple[Any, ...]]]) -> str:
    for method, params in calls:
        if method == "wp.newPost":
            return params[3]["post_content"]
        if method == "wp.editPost":
            return params[4]["post_content"]
    raise AssertionError("nothing was posted")


def test_wp_page_02_fill_prod_key_replaces_the_placeholder(wp: ModuleType) -> None:
    """WP.PAGE.02 — the fill function puts the key from .env where the placeholder was."""
    body = f'<spws-ranklist supabase-prod-key="{PLACEHOLDER}"></spws-ranklist>'
    filled = wp.fill_prod_key(body)
    assert f'supabase-prod-key="{SECRET}"' in filled
    assert PLACEHOLDER not in filled


def test_wp_page_02_create_and_update_post_the_filled_body_and_never_print_the_key(
    wp: ModuleType, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """WP.PAGE.02 — both write paths post the filled body; the key never reaches the terminal."""
    content = tmp_path / "body.html"
    content.write_text(
        f'<spws-calendar supabase-prod-key="{PLACEHOLDER}"></spws-calendar>', encoding="utf-8"
    )

    wp.cmd_create(
        SimpleNamespace(slug="ranking", title="Ranking", content_file=str(content), status="draft")
    )
    assert SECRET in _posted_content(wp.calls)
    assert PLACEHOLDER not in _posted_content(wp.calls)

    wp.calls.clear()
    wp.cmd_update(
        SimpleNamespace(page_id=13472, title=None, content_file=str(content), status=None)
    )
    assert SECRET in _posted_content(wp.calls)

    out = capsys.readouterr()
    assert SECRET not in out.out and SECRET not in out.err


def test_wp_page_02_refuses_a_body_that_still_holds_the_placeholder(
    wp: ModuleType, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """WP.PAGE.02 — with no key to fill, nothing is posted and the run fails."""
    (tmp_path / ".env").write_text("", encoding="utf-8")
    content = tmp_path / "body.html"
    content.write_text(
        f'<spws-ranklist supabase-prod-key="{PLACEHOLDER}"></spws-ranklist>', encoding="utf-8"
    )

    with pytest.raises(SystemExit) as exc:
        wp.cmd_create(
            SimpleNamespace(
                slug="ranking", title="Ranking", content_file=str(content), status="draft"
            )
        )
    assert exc.value.code not in (0, None)
    with pytest.raises(SystemExit) as exc:
        wp.cmd_update(
            SimpleNamespace(page_id=13472, title=None, content_file=str(content), status=None)
        )
    assert exc.value.code not in (0, None)

    assert not [m for m, _ in wp.calls if m in ("wp.newPost", "wp.editPost")]
    assert "SUPABASE_PROD_ANON_KEY" in capsys.readouterr().err


def test_wp_page_02_a_body_without_the_placeholder_is_posted_unchanged(
    wp: ModuleType, tmp_path: Path
) -> None:
    """WP.PAGE.02 — the documents carry no key; their body goes out as written."""
    body = '<spws-document doc="tabela-punktacji"></spws-document>'
    content = tmp_path / "body.html"
    content.write_text(body, encoding="utf-8")
    wp.cmd_update(SimpleNamespace(page_id=1, title=None, content_file=str(content), status=None))
    assert _posted_content(wp.calls) == body
