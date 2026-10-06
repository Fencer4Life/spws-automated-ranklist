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


def test_telegram_bot_does_not_offer_the_withdrawn_delivery():
    """FTLDEL-OPS-01: the bot no longer starts ftl-seed.yml (ADR-080 §5 withdrawn 2026-09-25)."""
    source = (ROOT / "scripts/gas_telegram_bot.js").read_text()
    assert "case 'send':" not in source
    assert "send &lt;EVENT-CODE&gt; participants" not in source
    assert "'ftl-seed.yml'" not in source
