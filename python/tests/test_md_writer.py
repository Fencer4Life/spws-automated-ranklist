"""
Plan-test-ID 5.5: md_writer.py — target router for verdict .md files.

Routes already-rendered markdown to filesystem (LOCAL) and/or Supabase Storage
(CERT/PROD). This module does NOT render markdown — that stays in
phase5_runner.py for now (extraction is future work). It only handles
persistence target.

ADR-058 — staging-reports bucket. ADR-061 — LOCAL preserves filesystem default.
"""

from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock

import pytest


def test_md_writer_target_local_writes_filesystem(tmp_path):
    # 5.5.1 — target='local' writes doc/staging/{event_code}.md
    from python.pipeline.md_writer import write_for_event

    out = write_for_event(
        event_code="EVENT-A-2024-2025",
        md_text="# verdict\n",
        target="local",
        staging_dir=tmp_path,
    )
    expected = tmp_path / "EVENT-A-2024-2025.md"
    assert expected.exists()
    assert expected.read_text() == "# verdict\n"
    assert out == str(expected)


def test_md_writer_target_storage_calls_storage_handler():
    # 5.5.2 — target='storage' calls StorageMdHandler.upload_full
    from python.pipeline.md_writer import write_for_event

    sb = MagicMock()
    out = write_for_event(
        event_code="EVENT-A-2024-2025",
        md_text="# verdict\n",
        target="storage",
        supabase_client=sb,
    )
    sb.storage.from_.assert_called_with("staging-reports")
    sb.storage.from_().upload.assert_called_once()
    assert out == "EVENT-A-2024-2025/full.md"


def test_md_writer_target_both_writes_both(tmp_path):
    # 5.5.3 — target='both' writes filesystem AND Storage
    from python.pipeline.md_writer import write_for_event

    sb = MagicMock()
    out = write_for_event(
        event_code="X",
        md_text="# foo\n",
        target="both",
        staging_dir=tmp_path,
        supabase_client=sb,
    )
    assert (tmp_path / "X.md").exists()
    sb.storage.from_().upload.assert_called_once()
    # Returns local path when both targets succeed
    assert out is not None
    assert "X.md" in out


def test_md_writer_target_none_is_noop(tmp_path):
    # 5.5.4 — target='none' writes nothing
    from python.pipeline.md_writer import write_for_event

    sb = MagicMock()
    out = write_for_event(
        event_code="X",
        md_text="# foo\n",
        target="none",
        staging_dir=tmp_path,
        supabase_client=sb,
    )
    assert not (tmp_path / "X.md").exists()
    sb.storage.from_().upload.assert_not_called()
    assert out is None


def test_md_writer_invalid_target_raises():
    # 5.5.5 — invalid target value raises ValueError
    from python.pipeline.md_writer import write_for_event

    with pytest.raises(ValueError, match="invalid target"):
        write_for_event(
            event_code="X",
            md_text="",
            target="bogus",  # pyright: ignore[reportArgumentType] — intentionally invalid, proves rejection
            staging_dir=Path("/tmp"),
        )


def test_md_writer_storage_target_without_client_raises(tmp_path):
    # 5.5.6 — target='storage' without supabase_client raises
    from python.pipeline.md_writer import write_for_event

    with pytest.raises(ValueError, match="supabase_client"):
        write_for_event(event_code="X", md_text="", target="storage")


def test_md_writer_local_target_without_staging_dir_uses_default(tmp_path, monkeypatch):
    # 5.5.7 — target='local' defaults to repo doc/staging/ when staging_dir omitted
    # (we monkeypatch the default to tmp_path to avoid touching the real repo)
    from python.pipeline import md_writer

    monkeypatch.setattr(md_writer, "DEFAULT_STAGING_DIR", tmp_path)
    md_writer.write_for_event(
        event_code="EVENT-DEFAULT",
        md_text="# default\n",
        target="local",
    )
    assert (tmp_path / "EVENT-DEFAULT.md").exists()


def test_write_reconcile_local_uses_reconcile_subfolder(tmp_path):
    # recon-rep.9 — target='local' writes doc/staging/reconcile/{season}.{ts}.md
    from python.pipeline.md_writer import write_reconcile

    out = write_reconcile(
        season="SPWS-2025-2026",
        md_text="# reconcile\n",
        target="local",
        timestamp="20260711-145203Z",
        staging_dir=tmp_path,
    )
    expected = tmp_path / "SPWS-2025-2026.20260711-145203Z.md"
    assert expected.exists()
    assert out == str(expected)


def test_write_reconcile_storage_uses_reconcile_prefix():
    # recon-rep.10 — target='storage' → reconcile/{season}/{ts}.md
    from unittest.mock import MagicMock

    from python.pipeline.md_writer import write_reconcile

    sb = MagicMock()
    path = write_reconcile(
        season="SPWS-2025-2026",
        md_text="# reconcile\n",
        target="storage",
        timestamp="20260711-145203Z",
        supabase_client=sb,
    )
    assert path == "reconcile/SPWS-2025-2026/20260711-145203Z.md"
    sb.storage.from_.assert_called_with("staging-reports")
