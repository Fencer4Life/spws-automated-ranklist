# Telegram `ingest` command — manual GAS update guide

Adds an **`ingest <prefix> <url> [cert|prod]`** command to your Telegram bot, mirroring the existing
**`promote`** command. It dispatches the `ingest-event.yml` GitHub Actions workflow, which re-ingests the
event from the FTL URL on CERT (or PROD), populates `url_results`, and sends the staging report(s) back to
Telegram. **`promote` is unchanged** — review the staging docs, then `promote <prefix>` as usual.

> This is the **only out-of-repo step**. The GAS (Google Apps Script) project lives in your Google account
> (set up per ADR-023/025 for email polling + `checkTelegramCommands`), so it can't be edited from the repo.

## What the command does

```
ingest PPW4 https://fencingtimelive.com/tournaments/eventSchedule/D0993…  cert
        └prefix┘ └────────────── FTL eventSchedule URL ──────────────┘  └target (optional, default cert)┘
```
→ dispatches `ingest-event.yml` with `{event_code, season_end_year, target, url_event:<url>}`.

## Steps

1. **Open the script** — [script.google.com](https://script.google.com) → your **SPWS** Apps Script project
   (the one that already runs `checkTelegramCommands()` on a 5-minute trigger).
2. **Find the anchor** — `Ctrl-F` for **`promote`** inside `checkTelegramCommands()`. That `case`/`if` block is
   your template: it already (a) resolves an event by prefix in the active season and (b) POSTs a
   `workflow_dispatch`. **Copy how it does both** — you'll reuse the same two pieces.
3. **Paste the `ingest` case** next to `promote` (snippet below). **Adjust the 3 names marked `// ADJUST`** to
   match your existing code:
   - the **PAT** constant (whatever `promote` uses, e.g. `GH_PAT` / `GITHUB_TOKEN`),
   - the **repo** string (e.g. `"Fencer4Life/spws-automated-ranklist"`),
   - the **prefix→event_code resolver** (`promote` already has one — reuse it, don't write a new one).
4. **Update `/help`** — add one line: `ingest <prefix> <url> [cert|prod] — re-ingest an event from its FTL URL + staging to Telegram`.
5. **Save** (Ctrl-S). The existing 5-minute `getUpdates` trigger picks it up — **no redeploy** needed (unless
   your project is a *web-app* deployment: Deploy → Manage deployments → redeploy the head).
6. **Test** — in the Telegram chat send:
   `ingest PPW4 https://fencingtimelive.com/tournaments/eventSchedule/<uuid> cert`
   Within ~5 min the run starts; when it finishes you receive the full `PPW4-…-full.md` + the `-diff.md`
   documents. Then review and `promote PPW4`.

## Snippet (adapt the 3 `// ADJUST` names to your code)

```javascript
// --- Telegram command: ingest <prefix> <url> [cert|prod] ------------------
// Mirrors the `promote` command. Dispatches ingest-event.yml on GitHub Actions.
function handleIngestCommand_(text, chatId) {
  // text e.g. "ingest PPW4 https://fencingtimelive.com/...  cert"
  const parts = text.trim().split(/\s+/);          // [ "ingest", prefix, url, target? ]
  if (parts.length < 3) {
    sendTelegram_(chatId, "Usage: ingest <prefix> <url> [cert|prod]");
    return;
  }
  const prefix = parts[1];
  const url    = parts[2];
  const target = (parts[3] || "cert").toLowerCase();

  if (!/^https?:\/\//.test(url)) {
    sendTelegram_(chatId, "❌ ingest: <url> must be an http(s) FTL eventSchedule URL");
    return;
  }
  if (target !== "cert" && target !== "prod") {
    sendTelegram_(chatId, "❌ ingest: target must be cert or prod");
    return;
  }

  // Reuse the SAME active-season prefix resolver `promote` uses.   // ADJUST (resolver name)
  const eventCode = resolveEventCodeByPrefix_(prefix);             // -> e.g. "PPW4-2025-2026"
  if (!eventCode) {
    sendTelegram_(chatId, "❌ ingest: no active-season event matching '" + prefix + "'");
    return;
  }
  // season_end_year = trailing year of the event code (…-2025-2026 -> 2026)
  const m = eventCode.match(/-(\d{4})$/);
  const seasonEndYear = m ? m[1] : "";

  const repo = "Fencer4Life/spws-automated-ranklist";             // ADJUST (repo)
  const pat  = GH_PAT;                                            // ADJUST (PAT constant)

  const resp = UrlFetchApp.fetch(
    "https://api.github.com/repos/" + repo + "/actions/workflows/ingest-event.yml/dispatches",
    {
      method: "post",
      contentType: "application/json",
      headers: { "Authorization": "token " + pat, "Accept": "application/vnd.github+json" },
      muteHttpExceptions: true,
      payload: JSON.stringify({
        ref: "main",
        inputs: {
          event_code: eventCode,
          season_end_year: seasonEndYear,
          target: target,
          url_event: url
        }
      })
    });

  const code = resp.getResponseCode();
  if (code === 204) {
    sendTelegram_(chatId, "⏳ ingest dispatched: " + eventCode + " (" + target +
                          "). Staging report will arrive when it finishes.");
  } else {
    sendTelegram_(chatId, "❌ ingest dispatch failed (" + code + "): " +
                          resp.getContentText().slice(0, 300));
  }
}
```

Wire it into the dispatcher next to `promote`, e.g.:
```javascript
} else if (cmd === "ingest") {
  handleIngestCommand_(text, chatId);
}
```
*(`sendTelegram_` / `resolveEventCodeByPrefix_` / `GH_PAT` are placeholder names — use whatever your existing
script already defines; `promote` references the same ones.)*

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `dispatch failed (401/403)` | PAT wrong/expired or missing Actions: read+write | Rotate per cicd-operations-manual §1.4 (the dispatch PAT) |
| `dispatch failed (422)` | `ingest-event.yml` not on the default branch, or a bad input name | Confirm the workflow is on `main`; inputs are `event_code/season_end_year/target/url_event` |
| `no active-season event matching` | prefix doesn't match an event this season | Check the prefix (same matching as `promote`) |
| No staging docs arrive | run failed, or `TELEGRAM_*` secrets unset on the runner | Open the Actions run; verify repo secrets `TELEGRAM_BOT_TOKEN/CHAT_ID` |
