"""CERT→PROD reconcile-run report (human-readable .md log, like the scrape log).

Plan test IDs recon-rep.1–recon-rep.8. The report is column-agnostic: it diffs
whole-row projections (to_jsonb minus noise), so URLs, fees, registration flags
— and any future column — appear automatically with no code change.
"""

from __future__ import annotations

from python.pipeline.reconcile_report import compute_changes, render_report


def _proj(**kw):
    """A projected event row (id/ts columns already stripped, organizer→code)."""
    base = {"txt_name": "X", "txt_location": "City", "organizer_code": "EVF"}
    base.update(kw)
    return base


class TestComputeChanges:
    def test_detects_created_and_deleted_by_code(self):
        """recon-rep.1"""
        before = {"A-2025-2026": _proj(), "B-2025-2026": _proj()}
        after = {"A-2025-2026": _proj(), "C-2025-2026": _proj()}
        ch = compute_changes(before, after)
        assert ch["created"] == ["C-2025-2026"]
        assert ch["deleted"] == ["B-2025-2026"]

    def test_updated_is_one_entry_per_changed_field(self):
        """recon-rep.2 — the MPW-name case."""
        before = {"MPW-2025-2026": _proj(txt_name="MPW")}
        after = {"MPW-2025-2026": _proj(txt_name="Mistrzostwa Polski Weteranów")}
        ch = compute_changes(before, after)
        assert ch["updated"] == [
            {
                "code": "MPW-2025-2026",
                "field": "txt_name",
                "old": "MPW",
                "new": "Mistrzostwa Polski Weteranów",
            }
        ]

    def test_column_agnostic_picks_up_unknown_future_field(self):
        """recon-rep.3 — a column that doesn't exist today is diffed anyway."""
        before = {"E-2025-2026": _proj(some_future_col=None)}
        after = {"E-2025-2026": _proj(some_future_col="new-value")}
        ch = compute_changes(before, after)
        assert ch["updated"] == [
            {"code": "E-2025-2026", "field": "some_future_col", "old": None, "new": "new-value"}
        ]

    def test_noise_fields_excluded(self):
        """recon-rep.4 — env-local / timestamp columns never count as changes."""
        before = {"E-2025-2026": _proj(ts_updated="t1", id_event=1)}
        after = {"E-2025-2026": _proj(ts_updated="t2", id_event=99)}
        ch = compute_changes(before, after)
        assert ch["updated"] == []

    def test_no_changes_is_all_empty(self):
        """recon-rep.5"""
        rows = {"A-2025-2026": _proj()}
        ch = compute_changes(rows, dict(rows))
        assert ch == {"created": [], "deleted": [], "updated": []}


class TestRenderReport:
    def _applied(self):
        return {
            "created": [],
            "deleted": ["PEW68-2026-2027", "PEW69-2026-2027"],
            "updated": [
                {
                    "code": "MPW-2025-2026",
                    "field": "txt_name",
                    "old": "MPW",
                    "new": "Mistrzostwa Polski Weteranów",
                }
            ],
        }

    def test_report_has_change_row_and_summary(self):
        """recon-rep.6 — the two examples the user asked for appear verbatim."""
        md = render_report(
            season="SPWS-2025-2026",
            timestamp="20260711-145203Z",
            cert_ref="certref",
            prod_ref="prodref",
            trigger="manual",
            season_guard_ok=True,
            applied=self._applied(),
            deleted_evidence={
                "PEW68-2026-2027": "PLANNED, 0 results",
                "PEW69-2026-2027": "PLANNED, 0 results",
            },
            divergences={"created": [], "deleted": [], "updated": []},
            rpc={"created": 0, "updated": 26, "deleted": 7, "delete_skipped": []},
            prod_count=26,
            cert_count=26,
        )
        # the field-change row
        assert "MPW-2025-2026" in md and "txt_name" in md
        assert "Mistrzostwa Polski Weteranów" in md
        # the delete rows carry the guard evidence
        assert "PEW68-2026-2027" in md and "PLANNED, 0 results" in md
        # the summary line
        assert "created 0, updated 26, deleted 7, delete_skipped 0" in md
        # convergence
        assert "26" in md and "SPWS-2025-2026" in md

    def test_no_op_run_still_renders_a_report(self):
        """recon-rep.7 — a run that changed nothing writes a terse, dated record."""
        md = render_report(
            season="SPWS-2025-2026",
            timestamp="20260712-060000Z",
            cert_ref="certref",
            prod_ref="prodref",
            trigger="cron",
            season_guard_ok=True,
            applied={"created": [], "deleted": [], "updated": []},
            deleted_evidence={},
            divergences={"created": [], "deleted": [], "updated": []},
            rpc={"created": 0, "updated": 26, "deleted": 0, "delete_skipped": []},
            prod_count=26,
            cert_count=26,
        )
        assert "No changes" in md or "no changes" in md
        assert "20260712-060000Z" in md

    def test_delete_skipped_is_surfaced_prominently(self):
        """recon-rep.8 — a results-bearing event the guard refused must stand out."""
        md = render_report(
            season="SPWS-2025-2026",
            timestamp="20260712-060000Z",
            cert_ref="certref",
            prod_ref="prodref",
            trigger="cron",
            season_guard_ok=True,
            applied={"created": [], "deleted": [], "updated": []},
            deleted_evidence={},
            divergences={"created": [], "deleted": [], "updated": []},
            rpc={"created": 0, "updated": 26, "deleted": 0, "delete_skipped": [200]},
            prod_count=27,
            cert_count=26,
        )
        assert "200" in md
        assert "skip" in md.lower()
