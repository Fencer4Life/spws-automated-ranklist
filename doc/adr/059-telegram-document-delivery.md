# ADR-059: Telegram `sendDocument` as primary verdict read surface

**Status:** Proposed
**Date:** 2026-05-03
**Amends:** ADR-025 (Event-Centric Ingestion + Telegram Admin), ADR-058 (staging-reports bucket).

## Context

Phase 5.5 of the rebuild persists verdict `.md` files to Supabase Storage (per ADR-058). The operator needs a way to **read** these files on a phone and archive them in their Obsidian vault.

Three reading surfaces were considered:

1. **Admin UI Markdown viewer** — Svelte component that fetches the `.md` from Storage via signed URL and renders with a Markdown library (`marked`).
2. **Email delivery** — push the `.md` as an email attachment.
3. **Telegram document delivery** — push the `.md` as a Telegram document attachment via the existing bot.

The operator already uses Telegram heavily (per ADR-025): all alerting, daily cron summaries, EVF parity notifications, ingest results. Telegram has Obsidian-friendly share-sheet integration on mobile (tap → "Open with" → Obsidian). The operator explicitly asked for Telegram delivery so they can save `.md` files to their Obsidian vault on phone.

## Decision

Telegram Bot API `sendDocument` is the primary verdict read surface. No admin-UI Markdown viewer is built.

**`TelegramNotifier.send_document`** (new method in `python/pipeline/notifications.py`):

```python
def send_document(
    self,
    file_bytes: bytes,
    filename: str,
    caption: str,
    *,
    chat_id: str | None = None,
) -> dict:
    """POST multipart/form-data to /sendDocument."""
```

POSTs `multipart/form-data` to `https://api.telegram.org/bot<token>/sendDocument` with:
- `document` part: `(filename, file_bytes, "text/markdown")`
- `chat_id` form field
- `caption` form field with HTML parse mode

**Higher-level wrapper** `send_staging_report(event_code, md_bytes, kind, extras)` builds a structured caption (e.g. `📄 EVENT-A · full · 6 tournaments · 47 ❌ aliases pending`) and an explicit filename (`{event_code}-full.md` or `{event_code}-delta-{ts}.md`).

**When Telegram fires:**

| Trigger | Document sent? | Reason |
|---|---|---|
| Email XML ingestion (`ingest.yml` → `ingest_cli`) | ✅ `full.md` per resolved event | First materialisation. |
| Event-URL ingestion (`phase5-event-runner.yml` → `phase5_runner`) | ✅ `full.md` | Same. |
| Operator alias mutation → `regen-report.yml` → `phase5_report` | ✅ `full.md` (auto, tagged `reason='regen'`) | Operator wants every regenerated verdict on phone. |
| EVF daily parity sweep detects ≥1 change | ✅ `delta.md` | Unattended overnight; operator wakes up to read changes. |
| EVF parity sweep finds zero drift | ❌ silent | No-op silence. |

**Verified feasibility against [core.telegram.org/bots/api](https://core.telegram.org/bots/api):**
- `sendDocument` accepts arbitrary file types via `multipart/form-data`.
- Standard Bot API size limit: 50 MB upload. Our `.md` files are ~30 KB (full) and ~5 KB (delta) — three orders of magnitude under.
- MIME type `text/markdown` is accepted; no extension blacklist for sendDocument.

**Behavioural caveat:** mobile Telegram clients render `.md` as a generic file attachment with a download/open icon (operator taps → "Open with" → Obsidian). Telegram Desktop sometimes shows inline text preview. No client treats `.md` as suspicious or strips it.

## Alternatives considered

### A. In-UI Markdown viewer

Rejected: adds frontend dependency (`marked` ~50 KB), signed-URL plumbing, environment-switching code; operator prefers to read on phone in Obsidian, not at desk in browser.

### B. Email delivery

Rejected: slower (poll vs push), no Obsidian share-sheet integration, requires SMTP secrets.

### C. Webhook to Obsidian sync API

Rejected: overkill, requires per-operator Obsidian sync configuration, ties the system to a specific Obsidian setup.

### D. Send `.md` content as `sendMessage` text

Rejected: 4096-character limit per message; `.md` files exceed this.

## Consequences

**Positive:**
- Operator reads on phone immediately after CI completes — no admin-UI navigation required.
- Telegram scrollback IS the verdict history, naturally indexed by event_code via filename.
- Captions tagged `kind='full'/'delta'` and `reason='regen'/etc` so the operator can mentally sort scrollback.
- Drops a frontend dependency — admin UI stays lean.

**Negative:**
- High-frequency triage sessions emit many `.md` deliveries (one per alias mutation that triggers regen). Mitigation: caption-tagged `reason='regen'` so the operator can mentally batch them. Not throttled in this ADR.
- LOCAL devs do not receive Telegram by default (no token env var); that's intentional but means LOCAL devs must explicitly opt in by setting `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` to test the document-delivery code path against a personal test bot.
- Telegram client behaviour for `.md` varies by platform; CERT smoke step C8 verifies all three (iOS, Android, Desktop) before declaring done.

## Status — deliverables (proposed, not yet shipped)

- `python/pipeline/notifications.py` extension (`send_document`, `send_staging_report`)
- `python/tests/test_telegram_send_document.py` — multipart shape, null-safety, caption rendering
- Wired into `ingest_cli.py`, `phase5_runner.py`, `phase5_report.py`, `evf_parity_sweep.py`
- GAS `/help` text update + 4 new operator commands (`/regen`, `/stage`, `/parity`, `/verdict`) per ADR-061
