"""Static FTLDEL-OPS-01 contract across UI/Edge/GitHub/GAS runtime boundaries."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_ftl_seed_workflow_is_allowlisted_and_gated():
    """FTLDEL-OPS-01: dispatch name, secrets and disabled-by-default cron agree."""
    workflow = (ROOT / ".github/workflows/ftl-seed.yml").read_text()
    edge = (ROOT / "supabase/functions/dispatch-workflow/index.ts").read_text()

    assert '"ftl-seed.yml"' in edge
    assert "workflow_dispatch:" in workflow
    assert "schedule:" in workflow
    assert "ENABLE_FTL_DEADLINE_SEND" in workflow
    assert "SPWS_GMAIL_USER" in workflow
    assert "SPWS_GMAIL_APP_PASSWORD" in workflow
    assert "--sweep-deadlines" in workflow
    assert "concurrency:" in workflow
    assert "FTL deadline sweep failed" in workflow


def test_telegram_sources_dispatch_the_same_contract_and_document_help():
    """FTLDEL-OPS-01: canonical and deployable GAS copies expose one command shape."""
    for relative in ("scripts/gas_email_ingestion.js", "doc/gas/Code.gs"):
        source = (ROOT / relative).read_text()
        assert "case 'send':" in source
        assert "send &lt;EVENT-CODE&gt; participants" in source
        assert "'ftl-seed.yml'" in source
        assert "{ event_code: sendEvent, target: 'prod' }" in source
