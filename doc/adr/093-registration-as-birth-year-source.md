# ADR-093: Registration as an Authoritative Birth-Year Source

**Status:** Accepted (2026-09-12; database and form implemented, operator alert implemented)
**Date:** 2026-09-12
**Supersedes:** [ADR-079](079-event-self-registration-identity.md) §1 (*Core invariant — registration is READ-ONLY on `tbl_fencer`*), and the "by construction" security consequence stated there. §§2–5 stand, as do both of ADR-079's own amendments.
**Amends:** [ADR-080](080-clean-roster-ftl-seeding.md) §2's restatement of the read-only invariant ("the **declared** birth year (read-only invariant), not `tbl_fencer`'s"). The seeding behaviour that sentence describes is unchanged — only its claim that nothing flows back.
**Relates to:** [ADR-078](078-gdpr-data-handling.md) (a new personal-data surface and its retention), [ADR-083](083-server-enforced-authorization.md) (deny-by-default grants; its pgTAP 52.7 caught a defect in this work), [ADR-072](072-cdc-recompute-debounce.md) and [ADR-071](071-mdm-dedup-sweep.md) (the self-heal path this decision depends on), [ADR-047](047-vcat-invariant-trigger-and-splitter-consolidation.md) (`trg_assert_result_vcat` does **not** fire on `tbl_fencer`, which is why the self-heal is load-bearing), [ADR-056](056-vcat-from-birthyear.md) and [ADR-010](010-age-category-by-birth-year.md) (what a birth year determines)
**Source:** `doc/plans/ftl-xml-export-2026-09-12.html` §4/§5/§7; migrations `20260912000001`, `20260912000002`, `20260912000003`

## Context

`fn_match_registration_fencer` (`supabase/migrations/20260704000001_event_registration_schema.sql:201`)
matches the exact tuple `(upper(surname), upper(first name), birth year)` and nothing
else. That strictness is deliberate and correct: an exact-tuple matcher can never
merge two different people. But it has no near-miss path at all, so a birth year off
by one and a genuine newcomer are indistinguishable to it — both fall into the
unmatched bucket, silently, and nobody is told.

The consequence is not theoretical. Measured on PROD on 2026-09-12,
PPW1-2026-2027 had 43 registrations, 36 matched, and **all seven misses were near
misses rather than newcomers**:

| Declared | In `tbl_fencer` | Classification |
| --- | --- | --- |
| BUJKO Paulina 1982 | #30, 1979, confirmed | birth year differs |
| STAŃCZYK MARCIN 1979 | #280, 1980, confirmed | birth year differs |
| KRZYSZTOF Łęcki 1991 | #168 ŁĘCKI Krzysztof 1991 | name fields exchanged |
| KANIECKI, PERKOWSKI, SIEJKOWSKI, ZANEUSKAYA | absent | genuinely new |

Each near miss produces the same outcome: the fencer is created again at ingestion,
and the same person reaches the organizer's software twice. PEW5efs-2026-2027 shows
the same shape — 14 registrations, 8 matched, two birth-year disagreements (LEAHEY,
MADDEN) and four newcomers.

Two further facts constrain any fix:

- **`tbl_fencer` has no uniqueness constraint on name + birth year** — only the
  primary key and the non-unique `idx_fencer_name`. PROD carries two live same-name
  pairs: #197 MŁYNEK Janusz 1951 (19 results) beside #356 MŁYNEK Janusz 1984, and
  #354/#355 KRAWCZYK Paweł (1989/1954). A name-based rule that wrote to "the"
  matching row could write onto the wrong person, and that is unrecoverable.
- **Nine fencers have no birth year at all.** `int_birth_year = p_birth_year` is never
  true for them, so the existing matcher cannot reach those rows by construction — not
  as an oversight, but as a property of equality with NULL.

ADR-079 §1 made registration read-only on `tbl_fencer` and derived a security property
from it: *"a malicious registration can at most create a junk, ephemeral, deletable
`tbl_registration` row — it cannot mutate an identity or a ranking, because that code
path does not exist in the registration flow."* ADR-079 §4's threat model then leans on
that: *"The real defences: (a) the read-only invariant + confirmed-BY-sacrosanct rule →
no data corruption."*

This decision deliberately reverses that invariant, so both statements need answering
rather than quietly outliving their basis. The reason to reverse it: **a registration
is a first-hand declaration by a fencer about their own birth year, and that outranks
anything we derived by scraping.** Twenty PROD rows carry
`bool_birth_year_estimated = true` — eighteen of them with results — and the person
who can settle each one is filling in the form.

## Decision

### 1 · The declaration outranks a derived value, and may write back

Registration may write `tbl_fencer.int_birth_year`. It still writes nothing else
there, creates no fencers, and touches no results and no ranking — ADR-079 §1's other
prohibitions stand. `fn_match_registration_fencer` and `fn_create_registration` are
**unchanged**, so the 36 of 43 registrations that already resolve keep their existing
path byte for byte; the new lookup is consulted only after that path misses.

### 2 · The lookup classifies; it never decides

`fn_registration_identity_candidates` (`20260912000001:89`) scans by **name**, not by
tuple — which is also how it sees the nine NULL-birth-year rows — and labels every
candidate `EXACT | SWAPPED | BY_NULL | BY_DIFFERS`. It returns **all** of them.

Returning all of them is the safety property, not a convenience: where two people share
a name, software choosing between them is the unrecoverable mistake. The caller applies
a fixed six-rung order, and "exactly one" is the *order itself* rather than a condition
repeated on each rule:

| Rung | Condition | Action |
| --- | --- | --- |
| 1 | exactly one `EXACT` | link and stop — today's behaviour, untouched |
| 2 | more than one `EXACT` | duplicate-fencer defect; surface to an administrator |
| 3 | exactly one `SWAPPED` | ask the fencer (the B prompt) |
| 4 | exactly one `BY_NULL` | populate silently, mark confirmed |
| 5 | any `BY_DIFFERS` | ask, listing **every** candidate (the D prompt) |
| 6 | nothing matched | echo the canonical name back before minting a new identity |

MŁYNEK Janusz 1984 registering reaches rung 1, not rung 5 — there *is* an exact match,
so the ambiguity with the 1951 Janusz never arises. Ambiguity bites only when no exact
match exists, and rung 5 then shows both with their birth years and lets the person
choose. The one human who knows the answer is already looking at the screen.

### 3 · The write is gated on a capability, not on knowing a name

`fn_confirm_registration_identity` (`20260912000002:88`) is `SECURITY DEFINER` and
anon-callable, because the fencer correcting their own entry **is** the anonymous
visitor. Four guards make that acceptable:

1. **The edit token.** The caller must present `tbl_registration.uuid_edit_token`
   (ADR-079's 2026-08-28 amendment), so they must hold the handle for the row they
   just created — not merely know a name. `fn_create_registration` is not widened.
2. **The candidate set, recomputed server-side** from that registration's own stored
   declaration. Without this the function would be a rewrite-any-fencer's-birth-year
   primitive; with it the reachable set is the handful of people sharing the
   registrant's name.
3. **A confirmed year cannot be changed by the public at all** — it can only be
   *proposed*. This guard was wrong when first written and is recorded here as it was
   corrected, because the reasoning matters more than the conclusion. The original
   claim was that "rung 5 requires an explicit human answer". That was true of the form
   and never of the server: `ADOPT_DECLARED` is a **parameter, not a click**, so the
   server cannot distinguish a fencer pressing the button from a crafted RPC call, and
   the edit token is no obstacle to a caller who mints it for a row they just created.
   Demonstrated rather than argued on a PROD-mirrored LOCAL on 2026-09-12 — an
   anonymous caller knowing only the name "BUJKO Paulina" moved a confirmed 1979 to
   1900 with no human involved. Migration `20260912000003` therefore removes the
   capability instead of narrowing it: the public call records a PENDING row and
   touches nothing, and `fn_apply_identity_override` is administrator-only. Re-run
   against the fix, the same attack leaves the master row at 1979, the queue empty and
   the audit log silent. See §4.
4. **A plain `UPDATE`**, never a trigger-disabling path — see §5.

The three answers map to the D prompt's three buttons: `ADOPT_DECLARED` corrects the
master birth year; `FIX_REGISTRATION` corrects the registration and leaves the fencer
untouched; `DIFFERENT_PERSON` writes nothing.

### 4 · Three tiers of birth year — and the third is loud

A NULL is a gap and an estimate is a guess; both are overwritten by policy and neither
contradicts anything anyone checked. An **already-confirmed** year is different in
kind: a member of the public is changing a value somebody had verified, which moves
that fencer between V-categories and re-scores every event they have played.

It is still **askable** — that is the point of the reversal — but the public cannot
carry it out. `fn_confirm_registration_identity` records a PENDING row in
`tbl_registration_identity_override` (`20260912000002:43`), raises a `WARNING`, and the
recompute drain announces it over Telegram via `fn_claim_identity_override_alerts`. The
master row moves only when an administrator calls `fn_apply_identity_override`, which is
not granted to `anon`.

The honest trade: the fencer's declaration is captured the instant they make it and is
never lost, but it is not *applied* until somebody looks. Since the alert already meant a
correction waited up to fifteen minutes, an honest fencer gives up very little; an
attacker gives up the write entirely. Rejected as insufficient: a plausibility bound on
the declared year, which stops `1900` and does nothing about `1979 -> 1982` — the change
an attacker would actually choose.

`trg_audit_fencer` already recorded every such change, and that is precisely why it is
not sufficient: it records *every* fencer update identically, so this one is
indistinguishable from an administrator fixing a typo unless somebody already knows to
look. Evidence you have to know to go and find is not a signal.

The override row denormalises the declared name because ADR-079 makes
`tbl_registration` ephemeral — purged once results are ingested and reconciled. A plain
foreign key would delete the evidence at exactly the moment somebody asks why a
fencer's birth year changed.

The two quiet tiers stay quiet deliberately. An alert that fires routinely is an alert
nobody reads, and the one that matters would then arrive into a muted channel.

### 5 · The ranking heals itself, and must not be prevented from doing so

`trg_assert_result_vcat` fires only on `tbl_result` (ADR-047), so it does **not** guard
a birth-year change on `tbl_fencer`: on its own, such a change would leave every old
result in its old V-category with no error raised anywhere.

What saves it is `trg_fencer_change_enqueue`, which fires `AFTER UPDATE ON tbl_fencer`
and is column-aware — birth year or nationality enqueues, name or alias does not. It
queues a recompute of every event that fencer played (ADR-071/ADR-072), and the PROD
drain runs every fifteen minutes. Verified live on 2026-09-12 against BUJKO Paulina on
a PROD-mirrored LOCAL: the correction re-queued the event she had actually played and
`trg_audit_fencer` logged it.

The write is therefore a plain `UPDATE`, guarded on `IS DISTINCT FROM` so a no-op
confirmation does not re-queue every event for nothing. **Any path that disables
triggers leaves the ranking inconsistent with no error at all.**

### 6 · Where the decision is actually made

Removing the public's ability to write left the correction with nowhere to land.
`fn_apply_identity_override` was administrator-only from the start, but nothing listed
what was waiting: the Telegram alert carried a proposal id and the decision was a
hand-made RPC call. **A proposal nobody can see is a correction that never happens** —
and the population it fails is the honest one, since an attacker's proposal being
ignored forever is the desired outcome.

`IdentityProposals.svelte` renders the pending list at the top of the existing
birth-year review tab, which is where an administrator already goes to make exactly this
kind of judgement. Three properties are deliberate:

- **Invisible when empty.** The panel sits above a screen opened for other reasons, so
  an empty frame every day would train the reader to scroll past the one day it matters.
- **Both years on every row**, because "a birth year changed" is not actionable and
  "1979 → 1982" is.
- **The declared name comes from the proposal**, not from a join to the registration —
  ADR-079 purges that row after ingestion, so a join would lose the evidence exactly
  when somebody asks what happened.

The database remains the real control. The panel is the second of two independent
checks, not the only one: `fn_apply_identity_override` has no `anon` grant, and
`tbl_registration_identity_override` is unreadable to `anon` at all — both verified
against a running LOCAL, where an anonymous read returns `42501 permission denied` and
an anonymous apply is refused by name.

## Alternatives considered

1. **Loosen `fn_match_registration_fencer` to match on name alone, or fuzzily.**
   Rejected. Its exact-tuple strictness is the one property guaranteeing it can never
   merge two different people, and PROD has two same-name pairs to merge. The fix is to
   show the near miss to a human, not to make the matcher guess.
2. **Keep the read-only invariant; let ingestion reconcile as today.** Rejected — that
   *is* today, and today produces the duplicate. Ingestion reconciliation happens after
   the event, whereas the damage (the same person entered twice in the organizer's
   software) happens at the event.
3. **Refuse every ambiguity and surface it to an administrator.** Rejected for rung 5.
   Kept only for rung 2, where the ambiguity is a data defect rather than a question.
   The person who knows whether they were born in 1979 or 1982 is the one filling in the
   form; routing that to an administrator adds a hop and a delay to a question they
   cannot answer better.
4. **Echo the canonical name back to every registrant for confirmation.** Declined by
   the user as friction in front of everyone, and narrowed to rung 6 only — the path
   where a brand-new identity is about to be minted, which costs nothing for anyone who
   matched. This is also the only rung that can reach a first-time international
   entrant: the swap retry needs a fencer already in the table, so it catches
   KRZYSZTOF Łęcki (#168 exists) and stays silent for NAGY Orsolya (absent).
5. **Record the override but do not alert.** Rejected — see §4. A record nobody is told
   about is indistinguishable from no record for the period that matters.
6. **Gate the write on a magic-link email instead of the edit token.** Rejected: the
   email gate was designed in ADR-079 §2 and never built (Phases 4/5, blocked on the
   mail provider), and its own amendment removed it from the flow. Reusing the edit
   token reuses a capability that exists and is already the authorisation for
   `fn_update_registration`.

### Answering ADR-079 §4's threat model

ADR-079 §4 listed four defences, the first being *"the read-only invariant +
confirmed-BY-sacrosanct rule → no data corruption"*. Half of that is now gone, so it is
restated rather than left to decay:

- The **read-only invariant** is replaced by four narrower controls (§3). What an
  attacker gains is not "mutate any identity" but "change the birth year of someone
  whose name they typed, having created a registration for them, on an event still
  open for entry, leaving a durable record that alerts an operator".
- The **confirmed-BY-sacrosanct rule survives in full**, and in the server rather than
  in the form. No public caller can change a confirmed birth year; it can only be
  proposed, and applying is administrator-only. This was not true of the first
  implementation and was fixed the same day (see §3 guard 3).
- Defences (b) venue-level check, (c) results-based ranking, and (d) the abuse log are
  unchanged.
- The residual exposure is vandalism of one **estimated** birth year, which is still
  applied immediately by design — the person correcting a guess is its subject. It is
  detectable through `trg_audit_fencer` and reversible, and the recompute queue repairs
  the ranking either way. For a veterans' ranking that is accepted knowingly.
- A bogus registration can still be created for anyone whose name is known. That is
  unchanged by this decision and is ADR-079 §4's existing residual, answered there by
  the venue check.

The rate limit ADR-079 §4 promises and which was never built remains unbuilt, and this
decision makes it slightly more valuable than before. It is tracked in
`doc/plans/registration-impersonation-posture-2026-08-28.html`.

## Consequences

**New files**

- `supabase/migrations/20260912000001_registration_identity_candidates.sql` — the
  lookup and the first version of the write.
- `supabase/migrations/20260912000002_registration_identity_override_alert.sql` —
  `tbl_registration_identity_override`, the loud branch, and
  `fn_claim_identity_override_alerts`.
- `supabase/tests/75_registration_identity_candidates.sql` — 31 assertions.
- `scripts/mirror-prod-local.sh` — rebuilds LOCAL as a faithful PROD copy, which is how
  the ladder was verified against all 57 real registrations.

**Changed**

- `frontend/src/components/RegistrationForm.svelte` — the `identity_check` step and the
  resolution ladder (`resolveIdentity`, line 504). PL and EN keys added.
- `frontend/src/lib/api.ts`, `types.ts` — two RPC wrappers and their types.
- `python/pipeline/recompute/worker.py`, `db_connector.py` — the operator alert.
- `frontend/src/components/IdentityProposals.svelte` — the administrator's list (§6),
  mounted above the birth-year review tab in `App.svelte`.
- `.github/workflows/recompute-drain.yml`, `recompute-drain-prod.yml` — the drain step
  never received `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID`, so the notifier would have
  been built as `None` and the alert dropped in silence.

**Tests** — pgTAP 75.1–75.16; vitest 9.212–9.218 for the administrator's list; 75.1 pins the untouched fast path and is the regression
that protects the other 36. Vitest 6.30–6.42. Pytest N5.8–N5.11. `52_security_posture`
gains both anon-callable functions to its allowlist.

**A defect this work caused and ADR-083's test caught.** Postgres grants `EXECUTE` on a
new function to `PUBLIC` by default, so `fn_claim_identity_override_alerts` was
anon-callable without any `GRANT` being written — an anonymous caller could have
claimed every pending override and stamped it notified, silencing the alert through the
same public surface that triggers it. Found by pgTAP 52.7's **set-equality** allowlist,
which a deny-list of known-bad names would have missed entirely, and fixed with an
explicit `REVOKE`. "I did not write a `GRANT`" is not the same as "anon cannot call it".

**Defects found and deliberately not fixed here** — three pre-existing bootstrap defects
surfaced while building the PROD mirror; they are fixed in the same change but belong to
ADR-036, not to this decision, and are recorded in its amendment.

## Open items

1. **Rung 2 is not reachable from the form.** Because the form calls the untouched exact
   matcher first, and that function ends in `LIMIT 1`, a double exact match returns
   early and never reaches the ladder. Making it reachable would mean calling the
   candidate lookup on *every* submission, changing the call pattern for the 36 that
   currently work — the opposite of this decision's central constraint. PROD has zero
   duplicate exact triples today, so this guards against a future defect.
   *Recommendation:* leave the form as built and detect the case in the reconciliation
   report (plan §10 step 4), whose audience is the administrator the rung names. The
   database function already classifies it correctly (pinned by 75.6). **Awaiting the
   user's decision.**

2. **The rate limit ADR-079 §4 promised and nobody built** remains unbuilt. It bounds
   volume rather than a single targeted change, so it was not the answer to the exposure
   in §3, but it still has value against a flood of proposals. Tracked in
   `doc/plans/registration-impersonation-posture-2026-08-28.html`.
