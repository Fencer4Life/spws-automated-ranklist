---
name: ftl-token-rotate
description: "MANDATORY when rotating, revoking, or reissuing an FTL export capability token (tbl_ftl_export_token) in this repo (SPWS Automated Ranklist System) — a link has leaked, an organizer no longer needs access, or a token is being reissued on a schedule. Composes cloud-db-ops and scripts/cloud-sql.sh rather than duplicating them; revokes by UPDATE, never DELETE, and proves the old token is actually dead before calling the rotation done. Triggers on: rotate the FTL token, revoke the export token, reissue the organizer link, the download link leaked, cut off this organizer's access, mint a replacement token."
---

# Rotating an FTL export capability token

`tbl_ftl_export_token` gates the three public RPCs behind
`/pliki-zasilajace-xml-ftl/?k=<uuid>` and `register.html?view=export&k=<uuid>`
(see [doc/plans/ftl-token-scoping-question-2026-09-13.html](../../../doc/plans/ftl-token-scoping-question-2026-09-13.html)).
Today's tokens are unscoped — any live token sees every live event — so
"rotating" one is purely a token-table operation: revoke the old row, mint a
new one, verify both directions, then re-send the new link. Nothing else in
the system needs to change.

## This is cloud-db-ops, composed, not reimplemented

Every write below goes through `scripts/cloud-sql.sh` with
`CLOUD_SQL_CONFIRM=yes`, exactly as `cloud-db-ops` requires. Read that skill
first if this is your first cloud write this session. The one addition here
is specific to tokens: **prove the old token is dead, not just that the new
one works** — a rotation that only checks the new token can silently leave
the old link functioning if the `UPDATE` targeted the wrong row.

## The one rule that matters most

**Revoke by `UPDATE`, never `DELETE`.** The migration comment on
`tbl_ftl_export_token` is explicit: never delete, so a link that stops
working can still be identified by its label. A rotation that deletes the
old row destroys the evidence of which organizer's link just went bad.

## Procedure

1. **Identify the row.** `SELECT uuid_token, txt_label, ts_created,
   ts_revoked FROM tbl_ftl_export_token WHERE txt_label = '<label>'` on
   CERT, then PROD. Show the user both results before touching anything —
   live data may not match what a handover doc says it is.

2. **Revoke the old row, both tiers.**
   ```sql
   UPDATE tbl_ftl_export_token
      SET ts_revoked = now()
    WHERE txt_label = '<label>'
      AND ts_revoked IS NULL
   RETURNING uuid_token, txt_label, ts_revoked;
   ```
   CERT first, then PROD, each with `CLOUD_SQL_CONFIRM=yes`. The
   `ts_revoked IS NULL` guard stops a second run from clobbering the
   timestamp of a token already revoked earlier.

3. **Mint the replacement, same label, both tiers.**
   ```sql
   INSERT INTO tbl_ftl_export_token (txt_label)
   VALUES ('<label>')
   RETURNING uuid_token, txt_label, ts_created;
   ```
   CERT first, then PROD — same count-before/`RETURNING`-after discipline as
   the original mint in the 2026-09-13 handover.

4. **Verify the new token positively.** Call the real RPC, not just check
   the row exists:
   ```sql
   SELECT * FROM fn_ftl_export_events('<new-prod-token>');
   ```
   It should return the same live events the old token did. A row existing
   in the table proves nothing on its own — the 2026-09-13 mint caught
   exactly this by checking the RPC, not the INSERT's own output.

5. **Verify the old token negatively.** Same call with the revoked UUID:
   ```sql
   SELECT * FROM fn_ftl_export_events('<old-prod-token>');
   ```
   This must now return zero rows. If it still returns events, the
   `UPDATE` in step 2 did not land on PROD (wrong tier, wrong label, or it
   silently no-op'd) — do not tell the user the rotation is done until this
   comes back empty.

6. **Nothing to edit on the WordPress page or `register.html`.** Say this
   out loud to the user — it is the step people expect and the one that
   does not exist. The token is never written into page markup on either
   surface (`FtlExportElement.svelte`'s `accessToken` derivation falls back
   to `?k=` in the URL); rotating it changes only these DB rows.

7. **Re-send the new link(s)** to whoever held the old one:
   `https://weteraniszermierki.pl/pliki-zasilajace-xml-ftl/?k=<new-uuid>`
   and/or `register.html?view=export&k=<new-uuid>` (`&lang=en` as needed).
   Tell them the old link now reads as an empty event list, not an error.

## Scope

Single-file skill — this procedure only composes `scripts/cloud-sql.sh`. It
does not need its own scripts or reference material.
