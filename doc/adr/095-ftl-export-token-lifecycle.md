# ADR-095: FTL Export Token Lifecycle Stays Admin-Assisted, Not Self-Service

**Status:** Draft (proposed 2026-09-13; awaiting sign-off)
**Date:** 2026-09-13
**Amends:** [ADR-080](080-clean-roster-ftl-seeding.md) §(h) — corrects the slug it cites (`/pliki-startowe/?k=<uuid>` was drafted but never published) to the real path, and replaces its one-line "gives us something to rotate when a link goes astray — one `UPDATE`" with the full, worked procedure below.
**Relates to:** [ADR-090](090-prod-surface-as-wordpress-menu-item.md) (the capability-link pattern this token follows, unchanged by this decision), [ADR-083](083-server-enforced-authorization.md) (the `auth.role() = 'authenticated'` grant convention this reuses), [ADR-093](093-registration-as-birth-year-source.md) (`IdentityProposals.svelte`, the UI precedent cited in §7)
**Source:** `supabase/migrations/20260912000004_ftl_export_entries.sql`, `frontend/src/ce/FtlExportElement.svelte`, `scripts/cloud-sql.sh`, `scripts/wp_publish_page.py`, `.claude/skills/ftl-token-rotate/SKILL.md`, `.claude/skills/cloud-db-ops/SKILL.md`

## Context

ADR-080(h) and ADR-090's 2026-09-12 amendment settled that the FTL organizer
export page is protected by a capability link rather than a login, and that
the token lives in `tbl_ftl_export_token`, revoked by stamping `ts_revoked`
rather than deleted. Both decisions describe the mechanism and gesture at its
operational cost in one line each — "the capability... gives us something to
rotate... one `UPDATE`" (ADR-080 §(h)) — without saying what an administrator
actually does, in what order, or where to look when a link is lost.

That gap became concrete on 2026-09-13, the day the first tokens were minted.
After publishing the permanent surface at `weteraniszermierki.pl`, the
question was asked directly: *when I forget the link, how do I find it, and
is there any documentation of the token's lifecycle?* Neither of these
existed anywhere canonical:

- The only written record of that day's mint (CERT token
  `9c626dac-8edf-4b83-894b-d2f57454dbd8`, PROD token
  `b3d75527-b5c4-4501-8128-693903957b07`, both labelled `PPW1 Opole —
  organizer`) is `doc/plans/ftl-token-scoping-question-2026-09-13.html` and
  `doc/plans/ftl-export-handover-2026-09-13.html` — session handover pages
  under `doc/plans/`, which this repository treats as scratch, not as a
  canonical reference a future session or a human administrator would think
  to check.
- ADR-080(h) itself cites a slug, `/pliki-startowe/?k=<uuid>`, that was never
  published — the page that shipped the same day carries the corrected slug
  `pliki-zasilajace-xml-ftl` instead, confirmed with the association after a
  spelling correction to the working title. An ADR citing a path that does
  not exist is worse than citing none.
- There is no admin UI for this table at all. `tbl_ftl_export_token`'s own
  RLS policy (`FOR ALL USING (auth.role() = 'authenticated')`,
  `supabase/migrations/20260912000004_ftl_export_entries.sql:64-70`) already
  permits any signed-in administrator to read and write it directly from the
  client — the same grant shape ADR-083 established and
  `frontend/src/lib/api.ts:495-539`'s `fetchIdentityProposals` already relies
  on for `tbl_registration_identity_override` — but no screen exercises that
  permission for this table. The only way to act on it today is the
  Supabase Management API via `scripts/cloud-sql.sh`, which needs
  `SUPABASE_ACCESS_TOKEN` and `CLOUD_SQL_CONFIRM=yes` — a developer or Claude
  session, not a plain website-admin login.

## Decision

### 1 · Stay manual for now; this ADR is the canonical reference

Token creation, discovery, and rotation remain an admin-assisted procedure
run via `scripts/cloud-sql.sh` under the `cloud-db-ops` skill, composed by
`.claude/skills/ftl-token-rotate/SKILL.md` (already built 2026-09-13). This
ADR is the single, self-contained technical reference for that procedure —
not a pointer that sends the reader somewhere else for the actual steps.
`doc/handbook/operations/operator-runbooks.html` carries a short new section
that names this ADR, so a human administrator who would not think to browse
`doc/adr/` still has a way in.

### 2 · Schema and the validity check

```sql
CREATE TABLE tbl_ftl_export_token (
  uuid_token UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  txt_label  TEXT NOT NULL,
  ts_created TIMESTAMPTZ NOT NULL DEFAULT now(),
  ts_revoked TIMESTAMPTZ
);
```

Revocation is `UPDATE ... SET ts_revoked = now()`, **never** `DELETE` — the
migration's own comment states the reason: a dead link must stay
identifiable by its label, so an administrator can tell which organizer's
link just went bad rather than facing an anonymous gap in the table.

Row access is the same grant shape ADR-083 established elsewhere — no
finer-grained admin role exists anywhere in this codebase, "authenticated"
and "administrator" are synonyms:

```sql
CREATE POLICY "Admin manages FTL export tokens" ON tbl_ftl_export_token
  FOR ALL USING (auth.role() = 'authenticated');
```

with `REVOKE ALL ... FROM PUBLIC` and `GRANT SELECT, INSERT, UPDATE ...
TO authenticated` alongside it
(`supabase/migrations/20260912000004_ftl_export_entries.sql:64-70`). This is
what makes the admin UI in Open items cheap if ever built: the table is
already readable and writable by any signed-in administrator directly from
the client, with no new RPC required for list or mint.

`fn_ftl_export_token_valid(p_token)` (`SECURITY DEFINER`, granted only to
`service_role`) is composed into all three public projections —
`fn_ftl_export_events`, `fn_ftl_export_entries`, `fn_ftl_roster`. An absent,
unknown, or revoked token makes all three return **zero rows, never an
error** — deliberate, per ADR-080(h): a stale link should look empty, not
broken, and an error would confirm to a prober that they had found a real
endpoint.

### 3 · The two live URLs, and why the token is never in their markup

`FtlExportElement.svelte`'s access-token derivation
(`frontend/src/ce/FtlExportElement.svelte:74-76`) is:

```ts
const accessToken = $derived(
  token || (typeof location !== 'undefined'
    ? new URLSearchParams(location.search).get('k')
    : '') || '',
)
```

The `token` attribute wins only if a host page explicitly sets one;
otherwise the element reads `?k=` straight from its own URL. Neither live
surface sets the attribute, so **the token is carried entirely by the URL,
never written into either page's static markup**:

| Surface | URL |
|---|---|
| Interim, always available | `https://fencer4life.github.io/spws-automated-ranklist/register.html?view=export&k=<uuid>[&lang=en]` |
| Permanent, public | `https://weteraniszermierki.pl/pliki-zasilajace-xml-ftl/?k=<uuid>[&lang=en]` (WordPress page id 13505, published 2026-09-13 by `scripts/wp_publish_page.py`; **not** added to any WP menu — capability-link-only, per ADR-080(f)) |

`&lang=en` sets the component's initial language; an absent parameter means
Polish, the correct default for a Polish federation's own events. Because
neither page embeds the token, **rotating it never requires editing either
page** — the entire operation is confined to the database, which is the
property that makes §6 below safe to run without a deploy.

### 4 · Finding the current link

```sql
SELECT uuid_token, txt_label, ts_created, ts_revoked
  FROM tbl_ftl_export_token
 WHERE ts_revoked IS NULL;
```

Run via `scripts/cloud-sql.sh <cert|prod> "..."`. Build either URL from §3
by dropping the returned `uuid_token` in. The token table is the **sole**
source of truth per tier — there is deliberately no other record of "the
current link," so a lost link is a lookup here, not an email search.

### 5 · Creating a token for a new organizer

```sql
INSERT INTO tbl_ftl_export_token (txt_label)
VALUES ('<event or organizer name> — organizer')
RETURNING uuid_token, txt_label, ts_created;
```

Run on CERT first, then PROD, exactly as the 2026-09-13 mint did (CERT
`9c626dac-8edf-4b83-894b-d2f57454dbd8`, PROD
`b3d75527-b5c4-4501-8128-693903957b07`, label `PPW1 Opole — organizer`).
Confirm both tables were empty (or that no row with the intended label
existed) immediately beforehand, so a genuinely new mint is not mistaken for
a duplicate. That worked session is precedent, not the canonical record —
this ADR is.

### 6 · Rotating or revoking a token

The full procedure, reproduced here rather than only pointed at, per
`.claude/skills/ftl-token-rotate/SKILL.md`:

1. **Identify the row.** `SELECT uuid_token, txt_label, ts_created,
   ts_revoked FROM tbl_ftl_export_token WHERE txt_label = '<label>';` on
   CERT, then PROD. Live data may not match what a handover doc says it is.
2. **Revoke, both tiers, never `DELETE`:**
   ```sql
   UPDATE tbl_ftl_export_token
      SET ts_revoked = now()
    WHERE txt_label = '<label>'
      AND ts_revoked IS NULL
   RETURNING uuid_token, txt_label, ts_revoked;
   ```
   The `ts_revoked IS NULL` guard stops a second run from clobbering a
   timestamp already set.
3. **Mint the replacement, same label, both tiers** — the exact `INSERT`
   from §5.
4. **Verify the new token positively:**
   ```sql
   SELECT * FROM fn_ftl_export_events('<new-token>');
   ```
   It must return the same live events the old token did. A row existing in
   the table proves nothing on its own; only the RPC does.
5. **Verify the old token negatively** — the same call with the revoked
   UUID must now return **zero rows**. If it still returns events, step 2
   did not land where intended (wrong tier, wrong label, or a silent
   no-op), and the rotation is not done regardless of what step 3 or 4
   showed.
6. **Re-send the new link(s)** (§3's two templates) to whoever held the
   old one, and say the old link now reads as an empty event list, not an
   error.

No step here edits `FtlExportElement.svelte`, `register.html`, or the
WordPress page — that is the payoff of §3.

### 7 · Who can actually do this today

Every step above requires Supabase Management API access via
`scripts/cloud-sql.sh` (`SUPABASE_ACCESS_TOKEN` + `CLOUD_SQL_CONFIRM=yes`) —
a developer or a Claude session with repository and credential access, not a
plain website-admin login, even though the RLS policy from §2
(`auth.role() = 'authenticated'`) would already permit the latter directly.
This is the actual gap against a self-service admin screen, and it is why
this decision is explicitly not final — see Open items.

## Alternatives considered

1. **Build the admin UI now, before writing this ADR.** Rejected for this
   change: only one token has ever been issued, the manual procedure above
   is fully documented and safe, and the UI itself is real, non-trivial
   scope — a new `AppView` value, a `Sidebar.svelte` entry, a new component,
   locale keys, tests — for an operation that has happened once. Deferred,
   not rejected outright; see Open items for what it would reuse.
2. **Leave the procedure undocumented and rely on `doc/plans/` handover
   pages.** Rejected: those pages are Claude's own session scratch space by
   this repository's own convention, not something a future session or a
   human administrator would think to open, which is the exact gap that
   prompted this ADR.
3. **Fix ADR-080(h)'s stale slug in place, without a new ADR.** Rejected:
   the slug correction is one sentence, but the missing lifecycle detail —
   finding, creating, rotating — is substantial enough to need its own
   record with its own sign-off, and folding it silently into ADR-080 would
   bury a new decision (stay manual for now) inside an unrelated one's prose.

## Consequences

- A lost or leaked link is a short Claude/dev-assisted lookup or rotation
  (§4/§6), not a self-service action, until or unless the deferred UI in
  Open items is built.
- ADR-080(h)'s stale slug is corrected by this ADR's own amendment note
  rather than by rewriting that section's original prose — matching this
  corpus's convention of appending amendments instead of rewriting history.
- `doc/handbook/operations/operator-runbooks.html` gains a short pointer
  section, and its `source_globs` are extended to include
  `supabase/migrations/20260912000004_ftl_export_entries.sql` and
  `frontend/src/ce/FtlExportElement.svelte`, so a future change to either
  trips the documentation-ownership check instead of drifting silently — the
  exact failure mode this ADR was written in response to.
- No code changes and no test changes: this is a documentation-only ADR.

## Open items

1. **A dedicated admin UI for `tbl_ftl_export_token`.** Not decided against —
   deferred pending real demand. If built, it needs no new RPC for list or
   mint: `tbl_ftl_export_token`'s RLS already lets any signed-in
   administrator `.from('tbl_ftl_export_token')` directly, exactly as
   `fetchIdentityProposals` does today for `tbl_registration_identity_override`
   (`frontend/src/lib/api.ts:495-539`). The UI precedent to copy is
   `frontend/src/components/IdentityProposals.svelte` +
   `frontend/src/components/BirthYearReview.svelte`, wired under
   `admin_fencers` in `frontend/src/App.svelte:167-215` — a small list
   component, an `isAdmin` prop, action callbacks, and a re-fetch after each
   decision rather than local splicing. A plausible shape: a table of
   label / created / live-or-revoked / masked link with a copy button /
   revoke button, plus a "+ New token" form that inserts a label and shows
   the resulting link once. *Recommendation:* build it once a second
   organizer token is needed, not speculatively now.
2. **Per-organizer scoping**, tracked separately in
   `doc/plans/ftl-token-scoping-question-2026-09-13.html` — the table's
   `txt_label` identifies a token for revocation but does not restrict which
   events it can see; any live token sees every live event. Unaffected by
   this ADR.
