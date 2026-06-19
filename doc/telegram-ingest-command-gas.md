# Telegram `ingest` command — how to update the GAS script

Adds **`ingest <prefix> <url> [cert|prod]`** to the Telegram bot: re-ingest one event from its FTL URL on
CERT (or PROD), populate `url_results`, and get the staging report(s) back in the chat. Then review and
`promote`. The bare `ingest` (no args) keeps its old "process emailed staging files" behaviour.

**The full, ready-to-paste script is in the repo:** [`doc/gas/Code.gs`](gas/Code.gs). It is the *entire* GAS
project with the change already applied — you replace your whole `Code.gs` with it. **No new Script
Properties** are needed (it reuses `GITHUB_PAT`, `GITHUB_REPO`, `SUPABASE_ACCESS_TOKEN`/`SUPABASE_PROJECT_REF`,
`SUPABASE_PROD_REF` that your existing commands already use), and `ingest-event.yml` is already on `main`.

```
ingest PPW4 https://fencingtimelive.com/tournaments/eventSchedule/<uuid>  cert
       └prefix┘ └────────────── FTL eventSchedule URL ───────────────┘  └target (opt, default cert)┘
```

---

## 1. Log into the right Google account

1. Open [accounts.google.com](https://accounts.google.com) on a **desktop browser** (the Apps Script editor
   barely works on mobile).
2. Sign in with the Google account that runs the SPWS automation — the one that receives the result emails /
   owns the bot wiring (ADR-023 set the script up there, e.g. `spws.weterani@gmail.com`). Switch account via
   the top-right avatar if you have several.

## 2. Open Apps Script & find the project

1. Go to **[script.google.com](https://script.google.com)**.
2. Left sidebar → **My Projects** — the list of all Apps Script projects this account owns.
3. Identify the right one:
   - name like **"SPWS" / "Ranklist" / "Telegram" / "Ingestion"**;
   - not sure? open a candidate and **Ctrl-F** for `checkTelegramCommands` or `promote` — the right project has them;
   - or open **⏰ Triggers** (clock icon, left sidebar) — the right project has time-based triggers running
     **every 5 minutes** (`checkEmailForResults` + `checkTelegramCommands`).
   - If `script.google.com` shows nothing, the script may be **bound to a Google Sheet**: open that Sheet →
     **Extensions → Apps Script**.

## 3. Replace the whole `Code.gs`

1. In the editor, open the file that holds `checkTelegramCommands` (usually **`Code.gs`**).
2. Open [`doc/gas/Code.gs`](gas/Code.gs) from this repo → **Select All (Ctrl-A) → Copy**.
3. Back in the Apps Script editor: click in the code, **Select All (Ctrl-A) → Paste** (overwrite everything).
4. **Save** (Ctrl-S, or the 💾 icon).

No redeploy needed — the existing 5-minute trigger picks it up. (Only if your project is a *web-app*
deployment: Deploy → Manage deployments → redeploy the head.)

## 4. Test

From the Telegram chat:

```
ingest PPW4 https://fencingtimelive.com/tournaments/eventSchedule/D586C1250E8C41D3BB9B9E5772CB998F cert
```

You get `⏳ Event Re-ingest Triggered`, then ~1 min later the full `.md` + `.diff.md` staging documents.
Review them, then `promote PPW4`.

---

## What changed (for verification)

Only two blocks differ from the previous script — everything else is byte-identical.

**(a) `case 'ingest':`** is now overloaded — `ingest <prefix> <url> [cert|prod]` resolves the prefix to the
canonical event code via `fn_event_status` (same as `status`/`promote`), derives the season-end year from the
code, and dispatches `ingest-event.yml` with `{event_code, season_end_year, target, url_event}`. A bare
`ingest` still dispatches `ingest.yml` (emailed-staging path).

**(b) Help → Pipeline** — the `ingest` entry now documents `ingest <prefix> <url> [cert|prod]` plus the
bare-`ingest` legacy line.

## Troubleshooting

| Reply / symptom | Cause | Fix |
|---|---|---|
| `No matching event on cert` | prefix matched no active-season event | check the prefix (same matching as `status`/`promote`) |
| `GitHub dispatch failed: ... 401/403` | `GITHUB_PAT` expired / missing Actions: read+write | rotate per [cicd-operations-manual §1.4](cicd-operations-manual.md) |
| `... 404` | `GITHUB_REPO` wrong | must be `Fencer4Life/spws-automated-ranklist` |
| `... 422` | `ingest-event.yml` not on the default branch | confirm the workflow is on `main` |
| No staging docs arrive | the run failed, or `TELEGRAM_*` secrets unset on the runner | open the Actions run; verify repo secrets `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` |
| Nothing happens | command not reaching the handler | the script overloads the existing `ingest` case — make sure you replaced the **whole** `Code.gs` |
