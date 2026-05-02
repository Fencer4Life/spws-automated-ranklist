"""
Tests for python/pipeline/overrides.py — Phase 3 (ADR-050) override YAML parser.

Schema lock 2026-05-02 (5 surfaces, EVF V0 ack deliberately omitted):
  identity / splitter / url / match_method / joint_pool

Plan IDs P3.OV1-P3.OV15.
"""

from __future__ import annotations

from pathlib import Path
from textwrap import dedent

import pytest


@pytest.fixture
def tmp_override(tmp_path):
    """Write a YAML override file under tmp_path/doc/overrides/<code>.yaml."""
    overrides_dir = tmp_path / "doc" / "overrides"
    overrides_dir.mkdir(parents=True)

    def _write(event_code: str, yaml_text: str) -> Path:
        p = overrides_dir / f"{event_code}.yaml"
        p.write_text(yaml_text)
        return p

    return _write


class TestLoadAndDefaults:
    def test_missing_file_returns_empty_overrides(self, tmp_path):
        """P3.OV1: load_for_event(<unknown>) → empty Overrides, no error."""
        from python.pipeline.overrides import load_for_event
        result = load_for_event("NONEXISTENT", overrides_dir=tmp_path / "doc" / "overrides")
        assert result.identity == []
        assert result.url is None

    def test_empty_yaml_file_returns_empty_overrides(self, tmp_override, tmp_path):
        """P3.OV2: empty (or `{}`) YAML → empty Overrides."""
        from python.pipeline.overrides import load_for_event
        tmp_override("EMPTY-1", "{}")
        result = load_for_event("EMPTY-1", overrides_dir=tmp_path / "doc" / "overrides")
        assert result.identity == []
        assert result.match_method == []


class TestIdentitySection:
    def test_parses_id_fencer_link(self, tmp_override, tmp_path):
        """P3.OV3: identity entry with id_fencer link parses."""
        from python.pipeline.overrides import load_for_event
        tmp_override("EVT-1", dedent("""
            identity:
              - scraped_name: "J SMITH"
                id_fencer: 4291
        """))
        result = load_for_event("EVT-1", overrides_dir=tmp_path / "doc" / "overrides")
        assert len(result.identity) == 1
        assert result.identity[0].scraped_name == "J SMITH"
        assert result.identity[0].id_fencer == 4291
        assert result.identity[0].create_fencer is None

    def test_parses_create_fencer(self, tmp_override, tmp_path):
        """P3.OV4: identity entry with create_fencer parses."""
        from python.pipeline.overrides import load_for_event
        tmp_override("EVT-2", dedent("""
            identity:
              - scraped_name: "MUELLER, Hans"
                create_fencer:
                  surname: MÜLLER
                  first_name: Hans
                  birth_year: 1968
                  nationality: DE
        """))
        result = load_for_event("EVT-2", overrides_dir=tmp_path / "doc" / "overrides")
        assert result.identity[0].create_fencer["surname"] == "MÜLLER"
        assert result.identity[0].create_fencer["birth_year"] == 1968

    def test_identity_with_neither_id_nor_create_raises(self, tmp_override, tmp_path):
        """P3.OV11: identity entry missing both id_fencer and create_fencer raises."""
        from python.pipeline.overrides import OverrideValidationError, load_for_event
        tmp_override("EVT-3", dedent("""
            identity:
              - scraped_name: "X"
        """))
        with pytest.raises(OverrideValidationError, match="id_fencer.*create_fencer"):
            load_for_event("EVT-3", overrides_dir=tmp_path / "doc" / "overrides")

    def test_identity_with_both_raises(self, tmp_override, tmp_path):
        """P3.OV12: identity entry with both id_fencer and create_fencer raises (conflict)."""
        from python.pipeline.overrides import OverrideValidationError, load_for_event
        tmp_override("EVT-4", dedent("""
            identity:
              - scraped_name: "X"
                id_fencer: 1
                create_fencer:
                  surname: Y
                  first_name: Z
                  birth_year: 1970
        """))
        with pytest.raises(OverrideValidationError, match="conflict|both|exclusive"):
            load_for_event("EVT-4", overrides_dir=tmp_path / "doc" / "overrides")


class TestSplitterSection:
    def test_parses_birth_year_and_vcat_overrides(self, tmp_override, tmp_path):
        """P3.OV5: splitter section with both override types parses."""
        from python.pipeline.overrides import load_for_event
        tmp_override("EVT-5", dedent("""
            splitter:
              birth_year_overrides:
                "SMITH, John": 1968
                "BROWN, Alice": 1965
              vcat_overrides:
                "AMBIGUOUS, Person": V1
        """))
        result = load_for_event("EVT-5", overrides_dir=tmp_path / "doc" / "overrides")
        assert result.splitter.birth_year_overrides == {
            "SMITH, John": 1968,
            "BROWN, Alice": 1965,
        }
        assert result.splitter.vcat_overrides == {"AMBIGUOUS, Person": "V1"}


class TestUrlSection:
    def test_parses_url_override(self, tmp_override, tmp_path):
        """P3.OV6: url section parses validation_url + reason."""
        from python.pipeline.overrides import load_for_event
        tmp_override("EVT-6", dedent("""
            url:
              validation_url: "https://ftl.example.com/PEW3-foo/results"
              override_reason: "Recorded URL 404s"
        """))
        result = load_for_event("EVT-6", overrides_dir=tmp_path / "doc" / "overrides")
        assert result.url.validation_url == "https://ftl.example.com/PEW3-foo/results"
        assert result.url.override_reason == "Recorded URL 404s"


class TestMatchMethodSection:
    def test_parses_match_method_override(self, tmp_override, tmp_path):
        """P3.OV7: match_method entry parses with valid force_method enum."""
        from python.pipeline.overrides import load_for_event
        tmp_override("EVT-7", dedent("""
            match_method:
              - scraped_name: "AMBIGUOUS NAME"
                force_method: PENDING
                note: "Manual review needed"
        """))
        result = load_for_event("EVT-7", overrides_dir=tmp_path / "doc" / "overrides")
        assert result.match_method[0].scraped_name == "AMBIGUOUS NAME"
        assert result.match_method[0].force_method == "PENDING"

    def test_invalid_force_method_raises(self, tmp_override, tmp_path):
        """P3.OV13: match_method with invalid force_method enum raises."""
        from python.pipeline.overrides import OverrideValidationError, load_for_event
        tmp_override("EVT-8", dedent("""
            match_method:
              - scraped_name: "X"
                force_method: BOGUS_VALUE
        """))
        with pytest.raises(OverrideValidationError, match="force_method"):
            load_for_event("EVT-8", overrides_dir=tmp_path / "doc" / "overrides")


class TestJointPoolSection:
    def test_parses_joint_pool_force_flag(self, tmp_override, tmp_path):
        """P3.OV8: joint_pool force_flag entry parses with siblings list."""
        from python.pipeline.overrides import load_for_event
        tmp_override("EVT-9", dedent("""
            joint_pool:
              force_flag:
                - tournament_code: "PEW3-V0-EPEE-M"
                  siblings: ["PEW3-V1-EPEE-M"]
                  note: "PPW5-class case"
        """))
        result = load_for_event("EVT-9", overrides_dir=tmp_path / "doc" / "overrides")
        assert len(result.joint_pool) == 1
        assert result.joint_pool[0].tournament_code == "PEW3-V0-EPEE-M"
        assert result.joint_pool[0].siblings == ["PEW3-V1-EPEE-M"]


class TestFullFile:
    def test_all_five_sections_parse(self, tmp_override, tmp_path):
        """P3.OV9: full override file with all 5 sections parses."""
        from python.pipeline.overrides import load_for_event
        tmp_override("EVT-FULL", dedent("""
            identity:
              - scraped_name: "X"
                id_fencer: 1
            splitter:
              birth_year_overrides:
                "Y": 1970
            url:
              validation_url: "https://example.com"
            match_method:
              - scraped_name: "Z"
                force_method: AUTO_MATCHED
            joint_pool:
              force_flag:
                - tournament_code: "T-V0"
                  siblings: ["T-V1"]
        """))
        result = load_for_event("EVT-FULL", overrides_dir=tmp_path / "doc" / "overrides")
        assert len(result.identity) == 1
        assert result.splitter.birth_year_overrides == {"Y": 1970}
        assert result.url.validation_url == "https://example.com"
        assert len(result.match_method) == 1
        assert len(result.joint_pool) == 1


class TestErrorPaths:
    def test_unknown_top_level_key_warning(self, tmp_override, tmp_path, caplog):
        """P3.OV10: unknown top-level key logs warning, doesn't error."""
        import logging
        from python.pipeline.overrides import load_for_event
        tmp_override("EVT-WARN", dedent("""
            identity: []
            unknown_section:
              foo: bar
        """))
        with caplog.at_level(logging.WARNING, logger="python.pipeline.overrides"):
            result = load_for_event("EVT-WARN", overrides_dir=tmp_path / "doc" / "overrides")
        assert result.identity == []
        assert any("unknown_section" in rec.message for rec in caplog.records)

    def test_malformed_yaml_raises_clear_error(self, tmp_override, tmp_path):
        """P3.OV14: malformed YAML raises OverrideValidationError with file path in message."""
        from python.pipeline.overrides import OverrideValidationError, load_for_event
        tmp_override("EVT-BAD", "identity: [\n  bad")
        with pytest.raises(OverrideValidationError, match="EVT-BAD"):
            load_for_event("EVT-BAD", overrides_dir=tmp_path / "doc" / "overrides")


class TestPathResolution:
    def test_load_for_event_uses_default_dir(self, monkeypatch, tmp_path):
        """P3.OV15: default overrides_dir resolves to <project>/doc/overrides/."""
        from python.pipeline.overrides import load_for_event
        # No override file in default dir → empty result, no exception
        result = load_for_event("DOES-NOT-EXIST")
        assert result.identity == []
