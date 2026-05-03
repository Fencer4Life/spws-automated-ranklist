"""
Verdict .md target router (ADR-058 + ADR-061).

Writes already-rendered markdown to filesystem (LOCAL) and/or Supabase Storage
(CERT/PROD). This module does NOT render markdown — that stays in
phase5_runner.py / phase5_report.py for now (extraction is future work).

Usage from CLI tools:
    md_writer.write_for_event(
        event_code="EVENT-A-2024-2025",
        md_text=rendered,
        target="local",  # or "storage", "both", "none"
        staging_dir=Path("doc/staging"),  # for local
        supabase_client=sb,               # for storage
    )

Plan-test-ID 5.5 (python/tests/test_md_writer.py).
"""

from __future__ import annotations

from pathlib import Path
from typing import Literal

from python.pipeline.storage_md import StorageMdHandler


# Default for LOCAL CLI invocations: repo's doc/staging/
DEFAULT_STAGING_DIR: Path = Path("doc/staging")

Target = Literal["local", "storage", "both", "none"]
_VALID_TARGETS = ("local", "storage", "both", "none")


def write_for_event(
    event_code: str,
    md_text: str,
    target: Target = "local",
    *,
    staging_dir: Path | str | None = None,
    supabase_client=None,
) -> str | None:
    """Persist a rendered .md for one event to the chosen target(s).

    Args:
        event_code: e.g. "EVENT-A-2024-2025". Must match [A-Z0-9_-]+ for the
            storage path; for the local path, used as the filename stem.
        md_text: full markdown body (already rendered upstream).
        target: "local" (filesystem), "storage" (Supabase Storage),
            "both" (filesystem AND Storage), "none" (no-op).
        staging_dir: directory for local writes; defaults to DEFAULT_STAGING_DIR.
        supabase_client: required for "storage" or "both".

    Returns:
        For "local": absolute path string.
        For "storage": "<event_code>/full.md" (the Storage path).
        For "both": local path string (Storage path also written).
        For "none": None.
    """
    if target not in _VALID_TARGETS:
        raise ValueError(f"invalid target {target!r}: must be one of {_VALID_TARGETS}")

    if target == "none":
        return None

    local_path: str | None = None
    storage_path: str | None = None

    if target in ("local", "both"):
        sdir = Path(staging_dir) if staging_dir is not None else DEFAULT_STAGING_DIR
        sdir.mkdir(parents=True, exist_ok=True)
        out = sdir / f"{event_code}.md"
        out.write_text(md_text, encoding="utf-8")
        local_path = str(out)

    if target in ("storage", "both"):
        if supabase_client is None:
            raise ValueError(
                f"target={target!r} requires supabase_client; got None"
            )
        handler = StorageMdHandler(supabase_client)
        storage_path = handler.upload_full(event_code, md_text.encode("utf-8"))

    # Return policy: local path wins when both targets succeed (operator-facing
    # for shell flows); storage path returned for storage-only.
    if local_path is not None:
        return local_path
    return storage_path


def write_delta_for_event(
    event_code: str,
    md_bytes: bytes,
    timestamp: str,
    *,
    supabase_client,
) -> str:
    """Persist a delta .md to Storage only (deltas don't go to filesystem).

    Used by EVF parity sweep (ADR-060). Always Storage; never filesystem.
    """
    handler = StorageMdHandler(supabase_client)
    return handler.upload_delta(event_code, md_bytes, timestamp)
