"""
Supabase Storage handler for the ingestion pipeline.

Manages the xml-inbox bucket: staging/ (incoming), archive/ (post-import),
and current/ (latest event's unzipped XMLs).
"""

from __future__ import annotations

import zipfile
from io import BytesIO


class StorageHandler:
    """Wraps a Supabase client for Storage bucket operations."""

    BUCKET = "xml-inbox"

    def __init__(self, supabase_client) -> None:
        self._sb = supabase_client

    def list_staging_files(self) -> list[str]:
        """Return list of file paths in staging/."""
        files = self._sb.storage.from_(self.BUCKET).list("staging")
        return [f"staging/{f['name']}" for f in files]

    def download_file(self, path: str) -> bytes:
        """Download a file from the bucket and return its bytes."""
        return self._sb.storage.from_(self.BUCKET).download(path)

    def archive_zip(self, staging_path: str, season: str, event: str) -> str:
        """Move a zip from staging/ to archive/{season}/{event}.zip.

        Tries move first; falls back to download+upload+delete.
        Returns the archive path.
        """
        archive_path = f"archive/{season}/{event}.zip"
        try:
            self._sb.storage.from_(self.BUCKET).move(staging_path, archive_path)
        except Exception:
            # Fallback: copy + delete
            data = self._sb.storage.from_(self.BUCKET).download(staging_path)
            self._sb.storage.from_(self.BUCKET).upload(archive_path, data)
            self._sb.storage.from_(self.BUCKET).remove([staging_path])
        return archive_path

    def compress_previous_event(self, season: str, previous_event: str) -> None:
        """Remove unzipped XMLs from current/ for a previous event."""
        files = self._sb.storage.from_(self.BUCKET).list(f"current/{season}/{previous_event}")
        if files:
            paths = [f"current/{season}/{previous_event}/{f['name']}" for f in files]
            self._sb.storage.from_(self.BUCKET).remove(paths)


def unzip_in_memory(zip_bytes: bytes) -> dict[str, bytes]:
    """Extract .xml files from a zip archive in memory.

    Returns:
        dict mapping filename to xml bytes (non-XML files are skipped).
    """
    result = {}
    with zipfile.ZipFile(BytesIO(zip_bytes), "r") as zf:
        for name in zf.namelist():
            if name.lower().endswith(".xml"):
                result[name] = zf.read(name)
    return result