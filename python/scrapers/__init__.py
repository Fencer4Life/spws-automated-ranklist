"""
Scraper package — parser registry for the unified ingestion pipeline.

Phase 1 / part 2 — ADR-050.

The ``PARSERS`` dict maps each :class:`SourceKind` to its canonical
IR-emitting parser. Some sources have multiple entry points (e.g. FTL has
``parse_json`` and ``parse_csv``); the registry exposes the JSON variant
because that's what the FTL API yields. Callers needing a different
variant import it directly from the source module.

The registry is the single source of truth for "which parsers exist".
A pytest contract (test_ir_contracts.py::TestParserRegistry) asserts that
every :class:`SourceKind` has an entry and every entry is callable.
"""

from __future__ import annotations

from python.pipeline.ir import SourceKind
from python.scrapers.dartagnan import parse_rankings as _dartagnan_parse_rankings
from python.scrapers.engarde import parse_html as _engarde_parse_html
from python.scrapers.evf_results import parse_results as _evf_parse_results
from python.scrapers.fencingtime_xml import parse as _ft_xml_parse
from python.scrapers.file_import import parse as _file_import_parse
from python.scrapers.fourfence import parse_html as _fourfence_parse_html
from python.scrapers.ftl import parse_json as _ftl_parse_json
from python.scrapers.ophardt import parse_results as _ophardt_parse_results


PARSERS = {
    SourceKind.FENCINGTIME_XML: _ft_xml_parse,
    SourceKind.FTL:             _ftl_parse_json,
    SourceKind.ENGARDE:         _engarde_parse_html,
    SourceKind.FOURFENCE:       _fourfence_parse_html,
    SourceKind.DARTAGNAN:       _dartagnan_parse_rankings,
    SourceKind.EVF_API:         _evf_parse_results,
    SourceKind.FILE_IMPORT:     _file_import_parse,
    SourceKind.OPHARDT_HTML:    _ophardt_parse_results,
}


__all__ = ["PARSERS"]
