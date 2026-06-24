"""
Plan-test-ID 5.6: storage_md.py — Supabase Storage wrapper for staging-reports bucket.

Mirrors the existing StorageHandler pattern (xml-inbox bucket). Mocked-client
tests verify upload/download/signed_url shape; no live Supabase needed.

ADR-058 — staging-reports bucket. ADR-061 — LOCAL safety.
"""

from __future__ import annotations

from unittest.mock import MagicMock

import pytest


def test_storage_md_upload_full_md_calls_correct_path():
    # 5.6.1 — upload(event_code='X', md_text='# foo', kind='full') uploads
    # to staging-reports/X/full.md with text/markdown content type.
    from python.pipeline.storage_md import StorageMdHandler

    sb = MagicMock()
    handler = StorageMdHandler(sb)
    handler.upload_full("EVENT-A-2024-2025", b"# verdict\n")

    sb.storage.from_.assert_called_with("staging-reports")
    sb.storage.from_().upload.assert_called_once()
    args, kwargs = sb.storage.from_().upload.call_args
    # First positional arg is path; second is bytes.
    assert args[0] == "EVENT-A-2024-2025/full.md"
    assert args[1] == b"# verdict\n"
    # Content-type passed in file_options dict
    file_opts = kwargs.get("file_options") or (args[2] if len(args) > 2 else {})
    assert file_opts.get("content-type") == "text/markdown"
    # upsert=true so subsequent regens replace in place
    assert file_opts.get("upsert") in ("true", True)


def test_storage_md_upload_delta_uses_timestamped_path():
    # 5.6.2 — upload_delta places file under deltas/<ts>.md
    from python.pipeline.storage_md import StorageMdHandler

    sb = MagicMock()
    handler = StorageMdHandler(sb)
    path = handler.upload_delta(
        event_code="EVENT-A-2024-2025",
        md_bytes=b"# delta\n",
        timestamp="20260603_034512",
    )

    sb.storage.from_().upload.assert_called_once()
    assert path == "EVENT-A-2024-2025/deltas/20260603_034512.md"
    args, _ = sb.storage.from_().upload.call_args
    assert args[0] == "EVENT-A-2024-2025/deltas/20260603_034512.md"


def test_storage_md_download_returns_bytes_on_hit():
    # 5.6.3 — download returns bytes on success, None on 404
    from python.pipeline.storage_md import StorageMdHandler

    sb = MagicMock()
    sb.storage.from_().download.return_value = b"# foo\n"
    handler = StorageMdHandler(sb)
    out = handler.download_full("X")
    assert out == b"# foo\n"


def test_storage_md_download_returns_none_on_missing():
    # 5.6.4 — download returns None when storage raises (404 / not found)
    from python.pipeline.storage_md import StorageMdHandler

    sb = MagicMock()
    sb.storage.from_().download.side_effect = Exception("Object not found")
    handler = StorageMdHandler(sb)
    out = handler.download_full("MISSING-EVENT")
    assert out is None


def test_storage_md_signed_url_returns_url_string():
    # 5.6.5 — signed_url returns the URL string from Supabase response
    from python.pipeline.storage_md import StorageMdHandler

    sb = MagicMock()
    sb.storage.from_().create_signed_url.return_value = {
        "signedURL": "https://example.com/staging-reports/X/full.md?token=abc",
        "signedUrl": "https://example.com/staging-reports/X/full.md?token=abc",
    }
    handler = StorageMdHandler(sb)
    url = handler.signed_url_full("X", ttl_seconds=3600)
    assert "staging-reports/X/full.md" in url
    sb.storage.from_().create_signed_url.assert_called_with("X/full.md", 3600)


def test_storage_md_event_code_validation_rejects_path_traversal():
    # 5.6.6 — defence-in-depth: event_code with invalid chars is rejected
    from python.pipeline.storage_md import StorageMdHandler

    sb = MagicMock()
    handler = StorageMdHandler(sb)
    with pytest.raises(ValueError, match="invalid event_code"):
        handler.upload_full("../etc/passwd", b"")
    with pytest.raises(ValueError, match="invalid event_code"):
        handler.upload_full("X/../../Y", b"")
    with pytest.raises(ValueError, match="invalid event_code"):
        handler.upload_full("", b"")


def test_storage_md_bucket_constant():
    # 5.6.7 — BUCKET constant is "staging-reports" per ADR-058
    from python.pipeline.storage_md import StorageMdHandler

    assert StorageMdHandler.BUCKET == "staging-reports"
