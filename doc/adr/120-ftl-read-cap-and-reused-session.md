# ADR-120: FencingTimeLive Is Read Under a Daily Cap, With One Reused Session and a Name

**Status:** Accepted (signed by the user in chat on 2026-11-04, "F4 - B, the rest as recommended", on `doc/plans/ftl-daily-read-budget-2026-11-04.html`); implemented test-first on branch `claude/ftl-read-cap-and-reused-login`, not yet released
**Date:** 2026-11-04
**Amends:** [ADR-068](068-ftl-www-host-and-session-cache.md) (its deferred alternative, the session kept across processes, is now the rule; every request carries a name), [ADR-119](119-partial-ingest-promote-and-organizer-registry.md) (§4: an event read only from FTL is taken at four hours a day and compared by its schedule alone, and a new verdict `budget`; G42 A (2): an FTL event is dry-read only the day before it starts; G45 A: a completed FTL event is no longer re-read automatically, and one event is re-read by hand)
**Relates to:** [ADR-083](083-server-enforced-authorization.md) (the two new tables are deny-by-default, service role only), [ADR-108](108-promote-replays-verified-cert-ingestion.md) §7 (the close's schedule check, which the sync's FTL compare reuses), [ADR-036](036-prod-export-local-mirror.md) (the PROD seed export names its tables one by one and never these)
**Source:** `doc/plans/ftl-daily-read-budget-2026-11-04.html`, `python/scrapers/ftl_auth.py`, `python/scrapers/ftl_ledger.py`, `python/pipeline/promotion/results_sync.py`, `python/pipeline/source_regression.py`, `supabase/migrations/20261104000001_ftl_read_ledger.sql`, `supabase/migrations/20261104000002_ftl_session.sql`, `supabase/migrations/20261104000003_results_sync_budget_verdict.sql`

## Context

FencingTimeLive (FTL) refused the pipeline account's sign-in from the night of 1 to 2 November 2026 ("please contact customer support", [ADR-119](119-partial-ingest-promote-and-organizer-registry.md) G63). The Actions logs and this machine's session records put the block between 22:08 UTC on 1 Nov, the last accepted sign-in, and 06:54 UTC on 2 Nov, the first refused one, with nothing of ours signing in between: FTL acted after the day, on the day's volume.

That day the pipeline sent FTL about 700 requests and 13 sign-ins, from GitHub's runners and one developer machine, all under the HTTP client's default name `python-httpx`:

- two full source re-reads (ADR-119 G45), each reading every international event of the last 30 months whole, about 150 requests apiece, most of them events completed months before;
- 8 to 10 read-only re-reads on LOCAL during an investigation, about 400 requests;
- the daily close and the results sync, a handful.

Nothing counted these requests. Every process signed in afresh, because ADR-068 keeps the 10-day session inside one process only and deferred keeping it across runs. The hourly sync compared an FTL event in progress by reading every final listing every hour, 13 × (1 + L) requests a day for L listings, to learn that nothing had changed. After 2 Nov FTL's edge also answers 403 to any request named `python-httpx/…`; a request named for the association is answered.

FTL's Terms of Use (10 March 2026) allow automated reading only under a written agreement; the user writes to FTL. Meanwhile the ranking needs FTL's results, and the user installed a new login on 4 Nov (one check, under the name below, signed in and read a schedule).

## Decision

### 1 · Every request and sign-in is drawn from the day's cap before it is sent

`python/scrapers/ftl_auth.py` is the one FTL client; every reader already opens it with `get_authed_ftl_client`. The client takes a ledger: before its first request it draws ten requests, and draws again when they are used; a sign-in is drawn on its own, after the requests, so a day with no request left spends no sign-in. A draw is granted up to the day's cap, **120 requests and 2 sign-ins a Warsaw day** (F1 A); a sign-in is granted whole or not at all. When the cap is spent the client raises `FtlBudgetSpent` (an `FtlAuthError`) before anything is sent. On close it gives back the requests it drew and did not use.

The ledger is one CERT row per day, `tbl_ftl_read_ledger`, written through `fn_ftl_ledger_take` and `fn_ftl_ledger_give_back` with the Management API and the access token every FTL step already holds (`python/scrapers/ftl_ledger.py`). CI and LOCAL draw from the same row (F2 A), so the count is the account's. **No ledger, no read:** a process that cannot build one, without the access token, reads no FTL at all. Every workflow step that holds the FTL login holds the token (FTL.WF.01); `phase5-event-runner`, `populate-urls` and `scrape-tournament` gained it. The audit tool's FTL branch, which fetched FTL's data with a bare `httpx.get`, goes through the client.

A run that read FTL ends with "FTL today: n/120 requests, m/2 sign-ins".

### 2 · One session, captured at the sign-in and reused for its life

FTL's session cookie is valid a fixed 10 days from its sign-in and not extended by use (ADR-068). The client takes a session store: the session this process holds, else the stored one, else a sign-in, whose cookie and expiry are stored right after it, before any other request. A session within 12 hours of its end is renewed. A resource that bounces to the login page drops the stored session, only if it is still the cookie this client used, so a newer one another run stored is kept; the next read signs in. A refused sign-in stores nothing and is still remembered per process (ADR-119 G71).

The store is one CERT row, `tbl_ftl_session` (`fn_ftl_session_get`, `fn_ftl_session_put`, `fn_ftl_session_drop`), shared by CI and LOCAL: one sign-in serves every run for 10 days, so at most three sign-ins a month, none in a month without an FTL read. The cookie is a credential: service role only, never the password, never in an error (a failed store raises with the error's kind only), never in the PROD seed export, never in GitHub's Actions cache, which a pull request's workflow could restore in this public repository.

### 3 · FTL is read when it can have changed, and not otherwise

- **Four cycles a day** (F3 A). The results sync takes an event whose every source is an FTL schedule (`ftl_only`) only in the cycles of the UTC hours 08, 12, 16 and 20, by the hour the cycle was due; the other cycles leave it for the next of these and name it in the select's log. A manual `sync <code>` always takes its event. Other engines stay hourly.
- **The schedule alone.** Such an event, except a PZSz event whose compare also hashes its start lists (ADR-119 G35), is compared by its schedule (`schedule_unchanged`): its links are the latest finished CERT run's, and the schedule read now hashes as that run recorded it, exactly as the daily close checks it (ADR-108 §7). One request. Unchanged: nothing to do, or promote only when PROD is behind. Changed, or no run: the cycle ingests, and the ingest reads every final listing as before. The outcome takes the new listings from the two runs.
- **The cap is a verdict.** A cycle stopped by the cap records `budget`, sends one ⏸ line and pauses nothing; the next day's allowance reads the event. From 80% of the cap a cycle's line carries the day's count.
- **Verification reads** (F4 B). The weekly source re-read leaves out a completed event read only from FTL, counted in its line; an open FTL event is still re-read weekly, to catch a listing corrected after its ingest. An FTL event is dry-read only the day before it starts. One event, completed or not, is re-read by hand: `source-regression.yml` with `event_code`.
- **Pacing.** Two FTL requests are at least `FTL_PACE_SECONDS` apart (1 second).

### 4 · The client says who it is

Every request carries `User-Agent: SPWS-ranklist/1.0 (Polish Veterans Fencing Association ranking; reads final results)` (F7 A). FTL can see, allow or refuse the reader by name. One account at a time: no pool of accounts, no switch when one is refused, no browser's name.

### 5 · What a day costs

With no FTL event in progress (most days): nothing, or one schedule read for an event waiting to close or starting tomorrow. With one in progress (an EVF weekend, about 25 listings): four schedule reads, the close's one, and two or three ingests of 1 + L, about 40 to 80 requests, and a sign-in at most once in 10 days. The cap, 120, is a sixth of the day that got the account blocked.

## Alternatives considered

1. **Rotate between several logins** (proposed 4 Nov: four aliases of one mailbox, one password). Rejected: taking the next account because the last was cut off is working round FTL's block; FTL can link the accounts by mailbox and by the machines that sign in, and could block the association outright.
2. **Ask FTL first, read nothing until it answers.** Not chosen by the user: the ranking needs results now. The letter to FTL stays the user's, and this ADR gives it a rate and a name to offer.
3. **Present the client as a browser.** Rejected: a disguise is exactly what FTL's monitoring is right to block.
4. **Keep the session in GitHub's Actions cache.** Rejected: in a public repository a pull request's workflow can restore it.
5. **A cap in a file per machine, LOCAL apart from CI** (F2 B). Rejected: the account's total would be no one's; a LOCAL day would cost a sign-in of its own.
6. **Hourly FTL cycles, each one request** (F3 C). Rejected for four: results show within four hours, and the rate is the one to offer FTL.
7. **No weekly re-read of open FTL events** (F4 A). Rejected by the user (F4 B): it is what catches a place corrected inside a listing already stored before the close.

## Consequences

- New: `python/scrapers/ftl_ledger.py`; migrations `20261104000001_ftl_read_ledger.sql`, `20261104000002_ftl_session.sql`, `20261104000003_results_sync_budget_verdict.sql`; pgTAP 125, 126, 127.
- Changed: `ftl_auth.get_authed_ftl_client` (ledger, session store, pace, name; `use_stores`, `ftl_today_line`, `Grant`, `StoredSession`, `FtlBudgetSpent`); `results_sync` (`ftl_only`, `schedule_only`, `schedule_unchanged`, `FTL_HOURS`, the `budget` verdict, the day's count, the run query's link); `source_regression` (`completed_ftl`, `dry_read`, `--code`); `audit_results.scrape_url`; four workflows (`source-regression.yml` takes `event_code`; three steps gained the access token).
- Tests: FTL.BUDGET.01–09, FTL.SESSION.01–05, FTL.NAME.01, FTL.PACE.01 (`test_ftl_auth.py`); FTL.STORE.01–05, FTL.WF.01, FTL.SEED.01 (`test_ftl_ledger.py`); SYNC.FTL.01, SYNC.SEL.06–09, SYNC.CYCLE.10–16 (`test_results_sync.py`); SRC.REGR.10–13 (`test_source_regression.py`); SYNC.PAUSE.01 now reads the latest migration's verdict CHECK. The test suite's conftest gives every test no ledger, no pace and no access token, so no test reaches CERT or FTL.
- A LOCAL run that reads FTL needs the access token in `.env` and draws from CERT's cap.
- The `ftl-scrape` skill, the handbook's ingestion, workflow-catalog, security-posture, codebase-map, operator-runbook and local-development pages describe these rules.
- Not changed: the daily close's read (one schedule per open event), the ingest's read (the event written whole), every other engine's rhythm, the eight workflows' FTL secrets.

## Open items

- **FTL's answer.** The user writes to FTL's support. If FTL sets another rate or offers an API, the cap and the hours change with it; this ADR is then amended.
- **Live proof** after release: the first FTL read of CI signs in once and stores the session; the next reads use it; a cycle's log ends with the day's count.
