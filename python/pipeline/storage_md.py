"""
Supabase Storage handler for the staging-reports bucket (ADR-058).

Persists per-event verdict markdown so CERT/PROD operators can read them via
Telegram (ADR-059) without local repo access.

Path scheme:
    staging-reports/{event_code}/full.md             — replace-on-regen
    staging-reports/{event_code}/deltas/{ts}.md      — append-only EVF deltas

Defence-in-depth: event_code is validated against a regex before being
interpolated into a Storage path.

Plan-test-ID 5.6 (python/tests/test_storage_md.py).

LOCAL note (ADR-061): instantiating this class on LOCAL is fine, but actual
upload calls require a connected supabase client whose Storage server is
operational. LOCAL flows default to filesystem (md_writer target=local).
"""

from __future__ import annotations

import re

_EVENT_CODE_RE = re.compile(r"^[A-Z0-9_-]+$")


class StorageMdHandler:
    """Wraps a Supabase client for staging-reports bucket I/O."""

    BUCKET = "staging-reports"

    def __init__(self, supabase_client) -> None:
        self._sb = supabase_client

    # --- internal helpers ---------------------------------------------------

    @staticmethod
    def _validate_event_code(event_code: str) -> None:
        if not event_code or not _EVENT_CODE_RE.match(event_code):
            raise ValueError(
                f"invalid event_code {event_code!r}: must match {_EVENT_CODE_RE.pattern}"
            )

    def _bucket(self):
        return self._sb.storage.from_(self.BUCKET)

    # --- upload -------------------------------------------------------------

    def upload_full(self, event_code: str, md_bytes: bytes) -> str:
        """Upload {event_code}/full.md. Replaces if exists. Returns the path."""
        self._validate_event_code(event_code)
        path = f"{event_code}/full.md"
        self._bucket().upload(
            path,
            md_bytes,
            file_options={"content-type": "text/markdown", "upsert": "true"},
        )
        return path

    def upload_delta(self, event_code: str, md_bytes: bytes, timestamp: str) -> str:
        """Upload {event_code}/deltas/{timestamp}.md (append-only). Returns the path."""
        self._validate_event_code(event_code)
        if not re.match(r"^\d{8}_\d{6}$", timestamp):
            raise ValueError(f"invalid timestamp {timestamp!r}: expected yyyyMMdd_HHmmss")
        path = f"{event_code}/deltas/{timestamp}.md"
        self._bucket().upload(
            path,
            md_bytes,
            file_options={"content-type": "text/markdown", "upsert": "false"},
        )
        return path

    def upload_reconcile(self, season: str, md_bytes: bytes, timestamp: str) -> str:
        """Upload reconcile/{season}/{timestamp}.md (append-only run log).

        The subject is a CERT→PROD reconcile RUN scoped to a season (not a
        single event), so it lives under a dedicated `reconcile/` prefix to
        keep run logs from mingling with the per-event scrape reports.
        """
        self._validate_event_code(season)  # season codes match [A-Z0-9_-]+
        if not re.match(r"^\d{8}-\d{6}Z$", timestamp):
            raise ValueError(f"invalid timestamp {timestamp!r}: expected yyyyMMdd-HHmmssZ")
        path = f"reconcile/{season}/{timestamp}.md"
        self._bucket().upload(
            path,
            md_bytes,
            file_options={"content-type": "text/markdown", "upsert": "false"},
        )
        return path

    # --- download -----------------------------------------------------------

    def download_full(self, event_code: str) -> bytes | None:
        """Download {event_code}/full.md or return None on 404 / not found."""
        self._validate_event_code(event_code)
        try:
            return self._bucket().download(f"{event_code}/full.md")
        except Exception:
            return None

    # --- signed URL ---------------------------------------------------------

    def signed_url_full(self, event_code: str, ttl_seconds: int = 3600) -> str:
        """Return a signed URL for {event_code}/full.md."""
        self._validate_event_code(event_code)
        resp = self._bucket().create_signed_url(f"{event_code}/full.md", ttl_seconds)
        # supabase-py returns dict with 'signedURL' (capital URL) historically,
        # newer clients use 'signedUrl'. Try both.
        if isinstance(resp, dict):
            return resp.get("signedURL") or resp.get("signedUrl") or ""
        return ""
