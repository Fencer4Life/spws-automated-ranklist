# ADR-084: Calendar Quarter Barrel + Single Event Card

**Status:** Draft (proposed 2026-08-09; awaiting sign-off)
**Date:** 2026-08-09
**Supersedes:** [ADR-015](015-m8-ui-design-decisions.md) §2 (Calendar Layout — Vertical Timeline) and its `m8_calendar_view.html` mockup registry entry. ADR-015 §§1, 3–9 are untouched.
**Amends:** [ADR-018](018-rolling-score.md) (withdraws the calendar rolling-progress strip; the scoring rule is unaffected), [ADR-017](017-season-configurable-evf-toggle.md) (records the calendar's own toggle field and the data constraint), [ADR-079](079-event-self-registration-identity.md) §7 (decouples the entry-list gate from the registration cutoff), [ADR-030](030-event-registration-url-deadline.md) (relocates the registration DOM contract), [ADR-005](005-svelte-state-i18n.md) (retires the no-pluralisation trade-off), [ADR-028](028-evf-calendar-results-import.md) (carves out one-time curated enrichment), [ADR-037](037-derived-display-status-awaiting-results.md) (repoints consumers), [ADR-040](040-multi-slot-event-urls.md) (permits render-time day labels)
**Relates to:** [ADR-007](007-shadow-dom-deferred.md) (Shadow DOM + CSP on `<spws-calendar>`), [ADR-009](009-cert-prod-runtime-toggle.md) (the env footer this view carries), [ADR-046](046-pew-weapon-suffix.md) (weapon derived from code suffix), [ADR-077](077-event-lifecycle-season-skeletons.md) (`CREATED` hidden until dated), [ADR-063](063-polish-plural-and-grupy-zbiorcze.md) (Polish grammatical case as a first-class concern)
**Source:** `doc/plans/kalendarz-barrel-2026-08-08.html` (plan + live acceptance mock), `doc/plans/kalendarz-barrel-adr-alignment-2026-08-09.html` (ADR audit)

## Context

The public Calendar is the SPWS surface a fencer opens to decide whether to enter a competition. It renders today as three stacked mechanisms in `CalendarView.svelte` (659 lines): a month-grouped reverse-chronological event list, a flat rolling-progress strip above it, and a season dropdown that clamps the whole view to one season.

**The complaint that started this was specific, and it is a design defect rather than a taste preference.** The progress strip encodes two independent variables in one visual channel: hue carries event type (`pew` / `imew` / `mpw` / `ppw` via `slotTypeClass()`, `CalendarView.svelte:241-246`), and *lightness of that same hue* carries completion. Two variables sharing one channel means neither reads cleanly — a light PEW slot and a dark PPW slot are not comparable on either dimension. The strip is also gated to the active season (`isActiveSeason`, read only at `:34` and `:269`), so it vanishes exactly when a fencer is looking at history.

A second, independent finding came from the card content. Pulled live from `vw_calendar` on 2026-08-08 — 126 rows, 103 after excluding `CREATED` skeletons:

| Field | Populated | On the card today |
| --- | --- | --- |
| `num_tournaments` | 103/103 | **Yes**, prominently |
| `num_entry_fee` | 28/103 | Yes |
| `txt_venue_address` | 22/103 | **No** |
| `dt_registration_deadline` | 5/103 | Yes |
| Fee tiers (`_2w` / `_3w`) | 1/103 | Yes |

The tournament count was the easiest thing to display and the least useful thing to read: it answers a question nobody asks. Meanwhile the venue address — the field a fencer pastes into a maps app or sends to a driver — was absent entirely. The list optimised for what the data had, not for what the decision needs.

The same pull established four data realities this design must survive rather than assume away:

- **Location is missing on PEW only.** Domestic 22/22 = 100%; PEW 30/75 = 40%, improving by season as the scraper gained the field. A location-dependent layout would degrade only for international events.
- **`txt_country` is free text in mixed languages** — `Polska`, `Germany`, `GRUZJA`, and both `Great Britain` and `United Kingdom` for one country.
- **The scraper writes venue strings into the city field.** `Sporthalle der Städtischen Berufsschule für Informationstechnik` and `Savoy Terrace - Buda Castle` are stored as `txt_location`.
- **`arr_weapons` is unusable.** The column exists with `DEFAULT '{EPEE,FOIL,SABRE}'` and 102 of 103 events sit on that default, so "all three" means both *genuinely all three* and *nobody set this*. The real weapon lives in the lowercase code suffix per ADR-046.

Finally, **320px is the floor** — an iPhone SE is a real device in this user base, and the embed sits inside a host page with no width guarantee.

## Decision

Replace the month-grouped list, the rolling-progress strip and the season dropdown with a **rotating three-row quarter barrel** that is the primary navigation control, driving a **single full-detail event card** beneath it.

A live, interactive mock built on all 103 real CERT events is the **acceptance criterion** for this ADR: the work is done when the implemented component matches it. It sits at the top of `doc/plans/kalendarz-barrel-2026-08-08.html`. Reading that file as source does not exercise it; it must be served and driven.

### 1 · Each variable gets its own channel

The defect above is fixed by separation, not by re-tuning colours:

| Variable | Channel |
| --- | --- |
| Event type | **Hue** |
| Completed | **Fill** (not lightness of the type hue) |
| Next upcoming | **Ring** |

### 2 · Three-row drum, rotation by `translateY`, facing by `rotateX`

The focused quarter is centred; the previous quarter recedes above at `rotateX(46deg)` and the next below at `-46deg`. Rotation is a `translateY` on the drum; per-row facing angle is `rotateX`. **The DOM never re-renders on rotate — only classes change.**

### 3 · Detail tiers follow rotation

The focused row shows day, month and code. Receded rows drop to day + code at 38px. The selected panel additionally carries the city, spells its month out in full (`19 września`, not `19 wrz`), and is 56px tall.

### 4 · Continuous history; the barrel owns season state

The drum rolls back to the start of history with **no season clamp**. Crossing a season boundary *drives* season state rather than being constrained by it — which is what allowed the season dropdown to be deleted. Quarters may legitimately hold two seasons: CERT contains `PEW2e-2023-2024` dated `2022-01-08` and `PEW8f-2025-2026` sitting among 2024-25 events.

### 5 · Overlap, not shrink

When a quarter's panels do not fit the viewport, they **fan and overlap at full size** rather than compressing. Compression is the conventional response and it is wrong here: at 320px a compressed panel stops being readable, whereas an overlapped one still exposes an edge.

- Positions are fixed at `i × S`, where `S = (available − W_selected) ÷ (n − 1)`, floor 13px.
- `z-index = 200 − |i − selected| × 2`, so the stack peaks on the selection. Panels left of it expose their left edge; panels right of it expose their right edge.
- **Only `z-index` changes on select** — selecting is a paint operation, never a layout reflow.
- The selected panel widens to 78px to carry a city, 74px without one. Uniform negative margins mean every later panel shifts right automatically, with no special-casing.

Verified in the mock at the 320px floor: five panels sit flat, six fan; a ten-panel quarter fans at `margin-left: -23px` (S = 25px) with z-indices 192/194/196/198/**200**/198/196/194/192/190.

### 6 · Whole row is the tap target

Tapping a receded row rotates it to centre. Tapping a panel on the focused row selects that event. There is no separate affordance to discover.

### 7 · Engraved seams

The quarter label (`4Q26`) sits at 11px muted on a hairline above each row and rotates with it. The season code (`25/26`) sits at the seam's right end on the focused row, and **permanently** on season-boundary seams, which take a 2px stronger rule. This is where the deleted dropdown's information went.

### 8 · One card, ordered by what a fencer acts on

Identity first (date, code, name, place), then a two-chip status line, then a rule, then **the decision block**: entry fee, both tiered fees, registration deadline, and the two links. Weapons close the card as small muted pills — they qualify an event, they are not why anyone opened it.

- **Optional fields render only when present.** No `brak danych` placeholders.
- **Fee tiers are gated on the event's weapon count.** An event covering foil alone has no two-weapon price; a populated `num_entry_fee_2w` there is a *data error*, not something to render. The tiers are otherwise **independent, not a set** — an event may fill the base fee and `_3w` while leaving `_2w` null, so one line per non-null field.
- **Currency is stored, not assumed:** `txt_entry_fee_currency ?? 'PLN'`.
- **Location is always a city, never a venue.** Venue belongs in `txt_venue_address`. The card never infers a city that is not literally in the string. **If `txt_location` holds anything, it appears** — classification picks which line it goes on, never whether it is visible. This fixes a live defect where 9 events with a location displayed none.
- **The venue address replaces the old country-and-season row** and carries a 22px copy-icon button. What lands on the clipboard is the **full composed address** — venue, city, country name — even though the card shows only a flag, because a string pasted into a maps app cannot see the flag. The button attaches to the city line when there is no venue, and is absent only when there is no location at all.
- **The copy button has no visible text**, so its `aria-label` and `title` *are* its accessible name and both are translated and both flip to `Skopiowano` / `Copied` on success. The glyph is **inline SVG** — ADR-007's strict CSP makes an icon font or sprite one more asset that can fail to load. Use `navigator.clipboard.writeText()` with an `execCommand` fallback, since the Clipboard API needs a secure context and the public embed may sit on a plain-http host page.

### 9 · Entry list is gated on `dt_start > today`, not on the registration cutoff

**This is a deliberate behaviour change** and it amends ADR-079 §7. Today both links share one cutoff, `regCutoff = dt_registration_deadline ?? dt_start` (`CalendarView.svelte:53-58`), so on an event with a stored deadline the entry list disappears the moment entries close.

That is the wrong rule for this link. Who has entered becomes **more** interesting once the list is final: you check the draw, see who is in your category, and decide whether the trip is worth it. Registration and the entry list answer different questions and must not share a date. The entry list is additionally suppressed on a `CANCELLED` event.

The registration side is **unchanged** and ported verbatim from ADR-030: the deadline *text* has its own stricter test requiring `dt_registration_deadline` non-null, while the links survive until the deadline or, absent one, until the event starts — which is what keeps them live for the 98 of 103 events with no stored deadline. `regUrgent` still turns the block red under seven days. ADR-079's in-app modal behaviour is unchanged: `bool_use_spws_registration` calls `preventDefault()` and opens `RegistrationModal`; an external URL still navigates.

**Consequence for implementation:** `registrationState(event, today)` must return the registration and entry-list flags **separately**, not one shared `regOpen`.

No existing test pins the old coupling — every test touching `.entry-list-link` sets a future deadline equal to `dt_start`, and the one past-deadline test asserts only the registration link — so this costs **new** tests rather than rewrites. The uncomfortable half is why it was cheap: the coupling was never covered, so nothing would have caught it drifting either way.

### 10 · One scope control, `PPW | +EVF`, governed per season

Centred below the header. It is governed by the scoring-config field `show_evf_toggle_calendar` ("Pokaż przełącznik +EVF w Kalendarzu"), which resolves with a default of **`true`** — the opposite of its ranklist sibling `show_evf_toggle`, split deliberately by ADR-044 so the two surfaces are independent. Do not re-merge them.

**Off does not merely hide the button — it constrains the data.** `CalendarView.svelte:291` reads `!showEvfToggle || scopeFilter === 'ppw'`, so with the config off the calendar is domestic-only regardless of scope state; hiding the control alone would strand EVF events on screen with no way to filter them. In the mock this is the difference between 103 panels and 22. This behaviour is real today but was never recorded in ADR-017, which is why that ADR is amended here.

The flag arrives asynchronously from `fn_export_scoring_config`, so the scope default must **re-sync on every change** until the user picks explicitly. A scope initialised once at mount is wrong for the first paint.

`isInternationalEvent` is ported verbatim: `bool_has_international || /^(PEW|MEW|MSW|PSW|IMEW|IMSW)/.test(txt_code)`.

### 11 · Results links are labelled by day, never by weapon

One URL renders as `Wyniki`; several render as `Dzień 1`, `Dzień 2`. Two weapons on one day still read as that day.

This follows ADR-040, which holds the five URL slots to be equal-status with no role labels, no per-slot enum and no primary pointer. An earlier per-weapon design was wrong and was removed. **The label is derived at render time from the URL's own content and never stored**, which is what keeps it compatible — Engarde encodes the date in the path (`2025_09_20_pbt`), so those URLs label themselves. A stored role remains rejected.

Where a platform does not encode the date, fall back to **bare numbering** — `Wyniki 1`, `Wyniki 2`. ADR-040 forbids inferring day from slot position, because slots are compacted on save and therefore non-semantic. Bare numbering degrades honestly and fails visibly, which signals which platforms need a parser.

### 12 · Localisation, including three-form Polish plurals

Every string goes through `t()` and `locales/{en,pl}.json`. Registry codes (`SPWS`, `EVF`, `FIE`), event codes and device names are proper nouns and stay untranslated.

Two things a naive port gets wrong, both amending ADR-005:

- **Polish months in a date are genitive** — `18 kwietnia`, not `18 kwiecień`. Because they appear only inside dates here the genitive forms can be stored directly, but a `month_N` key reused for a standalone heading elsewhere would then read wrongly. The calendar gets **its own month keys** rather than borrowing `month_1…12`.
- **Polish has three plural forms and the count picks between them** — `1 turniej` · `2–4 turnieje` · `0 and 5+ turniejów` — with the trap that **12, 13 and 14 take the genitive** despite ending in 2–4, while 22, 23 and 24 do not. ADR-005 recorded "no pluralisation support" as an accepted trade-off on the grounds that no key then contained a plural. **That trade-off has since expired in production:** `tournaments_count` is a flat string concatenated with the count at `CalendarView.svelte:72`, so `2 turniejów` and `1 tournaments` are both on screen today. A count-keyed pluralisation helper replaces it. ADR-063 already established Polish grammatical case as a first-class concern in this codebase, so this is an extension of an existing principle rather than a new one.

### 13 · Derivation moves into a pure module; no SQL in this work

All derivation currently lives inline in the component, which is why its test file is 788 lines of component-mounting tests. `lib/calendarQuarters.ts` is **new and pure — no Svelte** — and owns: quarter bucketing by `dt_start`, season-boundary detection, anchor resolution, next-upcoming, scope filtering, `registrationState()`, `countryCode()`, and the type split.

Two ordering hazards it must absorb rather than inherit:

- `fetchPriorSeasonEvents` (`api.ts:206`) sorts by `.order('txt_code')` while `fetchCalendarEvents` (`:172`) sorts by `.order('dt_start')`. Since `txt_code` orders `PEW10` before `PEW2`, the multi-season path arrives in an order that is neither chronological nor numeric. **`calendarQuarters.ts` sorts by `dt_start` itself and never trusts caller order**, pinned by a test that feeds deliberately shuffled input.
- **Next-upcoming is derived from the *filtered* set**, not assigned once — toggling scope must move the ring.

The multi-season load is a caller change, not a new query: volume is roughly 20 events per season, so a single up-front load is simpler than lazy-loading on boundary approach and removes the fetch-per-rotation problem entirely.

**There is no migration, no `vw_calendar` rebuild and no SQL in this work.** An earlier draft proposed `txt_nearest_hub` / `num_nearest_hub_km`; it was dropped on 2026-08-09 as the only unrequested item with no acceptance criterion attached. Raise it separately if wanted.

### 14 · The four-way type split is kept, and the fourth bucket is renamed

`slotTypeClass()` (`CalendarView.svelte:241-246`) already types events four ways, but the stylesheet paints `.slot.ppw.completed` and `.slot.mpw.completed` identically — **`MPW` is classified separately and then rendered the same**. The distinction was built and never cashed in.

Keep the four-way split in `calendarQuarters.ts` and let the barrel decide whether the fourth gets its own treatment:

| Bucket | Absorbs | Note |
| --- | --- | --- |
| `ppw` | domestic regular series, GP | |
| `mpw` | `MPW` | **kept distinct** even though nothing styles it yet |
| `pew` | EVF circuit | |
| `int` | `IMEW`, `IMSW`, `MEW`, `MSW`, `PSW` | **renamed** from the live `imew` |

Keeping `mpw` matters for the open past-season-anchor item, which asks for championships to be marked distinctly so finished seasons keep a focal point once next-upcoming has nothing to point at. That is not new machinery — it is styling a bucket the code has carried, unstyled, all along. Discarding the bucket would turn a styling decision into a prerequisite.

### 15 · Country flags are CSS, and depend on an enrichment pass

`CountryFlag.svelte` draws horizontal bands, vertical bands and offset crosses in CSS. **No emoji** — inconsistent on Android, absent on many devices — and **no image requests**, per ADR-007's CSP.

It has an unstated prerequisite: `txt_country` is free text today. Normalisation to ISO-3166 alpha-2 is a **one-time enrichment pass with human review of ambiguous cases, never a per-render web lookup**. `countryCode(raw)` returns `null` for unrecognised input so the component degrades to no flag and is not blocked on the pass completing.

This is why ADR-028 is amended. Its refresh contract lists `txt_location` and `txt_country` as **never refreshed** — a rule that exists to stop the scraper overwriting curated values, not to freeze the columns forever. A one-time curated enrichment write is a different act from a scraper refresh, and the never-refreshed rule continues to bind the scraper afterwards.

### 16 · What is removed, and what is carried unchanged

**Removed:**

| Removed | Why |
| --- | --- |
| Month-grouped event list | Replaced by the barrel; ADR-015 §2 superseded |
| Rolling-progress strip | The two-channel defect; ADR-018's UI consequence withdrawn |
| Season dropdown | The barrel owns season state (§4); the seam carries the code (§7) |
| Time filter (all / past / future) | The drum *is* the time control |
| Weapon filter | Dropped entirely — the data is not to be compressed |
| Tournament count on the card | Filled 103/103 and useless to read there; still loaded, still drives the barrel |
| `isActiveSeason` prop | Existed only to gate the strip (`:34`, `:269`); becomes a lie once the strip goes. Delete from the props interface, from `App.svelte:81`, **and** the derivation at `App.svelte:399` |

**Carried unchanged — deliberately, not by omission:**

- **The CERT/PROD environment footer.** `activeEnv` is `$bindable` and `App.svelte:379-380` derives `supabaseUrl` / `supabaseKey` from it, so pressing `PD` re-points the whole Supabase client at production. Four tests in `env-toggle.test.ts` mount `CalendarView` solely to drive this. Leaving `dualEnv` / `activeEnv` declared but unrendered compiles clean, passes `svelte-check`, and fails only at runtime as a silently missing control — the worst way for this one to fail. It is **deliberately temporary**: it retires when PROD moves off GitHub Pages to the WordPress CMS, together with both props and those four tests. Carry it across unchanged and **do not improve it**; the byte-identical second copy in `App.svelte:70-79` also stays, because hoisting it would add the footer to admin views that do not have it.
- **`getEventDisplayStatus()`** from `lib/eventStatus.ts` — already exhaustive over the lifecycle plus derived awaiting-results (ADR-037). `EventCard` consumes it unchanged; zero new work.
- **The two ADR-037 / ADR-077 data rules**, ported into `calendarQuarters.ts` verbatim: `CREATED` events hidden as dateless planning skeletons (`:264`), and the cancelled-event notice window of `dt_end + 7 days` (`:250-256`).

### 17 · Scroll behaviour

The page scrolls; the barrel is **not** pinned. Pinning ~250px of drum above every card on a 568px screen leaves under half the display for the thing the reader came for, and the barrel is not used continuously — you spin it, pick, then read.

## Alternatives considered

1. **Keep the timeline and just re-tune the strip's colours.** Rejected — the defect is two variables in one channel, so any palette inherits it. Re-tuning would have bought a nicer-looking version of the same unreadable encoding.
2. **Horizontal timeline** — this is what ADR-015 §2 explicitly rejected as "poor mobile", and the objection deserves an answer rather than a reversal. It was right about a *scrolling* horizontal timeline, where the viewport is a sliding window over an unbounded strip and the reader loses their place. The barrel is not that: it is **quantised** into quarters, three rows are visible at once with the focus always centred, and the seams keep absolute position legible. The mobile objection is met by measurement at the rejected breakpoint — 320px verified throughout, five panels flat and six fanning — rather than by assertion.
3. **Compress panels to fit the viewport.** Rejected — at 320px a compressed panel is illegible, which trades a visible overlap for an invisible failure. Overlap keeps every panel at full size and trades *visibility* for *size*, so a date fragment always survives.
4. **Shrink the drum to one row, or a flat carousel.** Rejected — the receded rows are what make the control legible as a continuum; one row is a dropdown with extra steps.
5. **Pin the barrel to the top.** Rejected on the 568px arithmetic in §17.
6. **A `CalendarFilters.svelte` component.** Rejected. It was sized to hold two controls, the scope segment and a weapon picker; the weapon filter is a settled removal, so one control is left and it goes inline in the orchestrator with the state it depends on. A judgment call, not a constraint — extract it if the scope control ever gains a second dimension.
7. **Per-weapon result-link labels.** Rejected as an ADR-040 violation; day labels replaced them.
8. **Retaining the weapon filter with a `localStorage` preference shared with the ranking tab's `BROŃ` selector.** Rejected with the filter itself; there is no preference left to persist.
9. **Nearest-hub / nearest-airport fields on the card.** Dropped 2026-08-09 (§13) — never requested, no acceptance criterion, and the sole reason this work would have needed a migration.
10. **Folding `MPW` into `ppw`** as the mock does, dropping the unused class. Rejected for the module (§14) — it would make the past-season-anchor decision a prerequisite instead of a styling choice.

## Consequences

- **Four new files:** `lib/calendarQuarters.ts`, `components/CalendarBarrel.svelte`, `components/EventCard.svelte`, `components/CountryFlag.svelte`. `CalendarView.svelte` becomes an orchestrator. **Not five** — `CalendarFilters.svelte` is not built.
- **Test triage spans two files and is not optional.** `CalendarView.test.ts` holds 49 tests and `env-toggle.test.ts` a further 4 mounting the same component — **53 in scope**. Every one gets a decision recorded in one of three buckets — **move** (behaviour survives), **rewrite** (behaviour deliberately changed), **delete** (assertions about removed DOM) — and no test is deleted without recording its bucket. The *rewrite* bucket is currently empty; see §9.
- **Three of those deletions retire an ADR-018 consequence.** R.23, R.24 and R.25 (`CalendarView.test.ts:374`, `:390`, `:401`) assert `.rolling-progress`, `.slot`, and `.slot.completed` / `.slot.planned`. They are the recorded verification of ADR-018's calendar UI, so ADR-018 must be amended in the same change rather than left pointing at deleted tests.
- **Carry-over is not affected, and ADR-018's calendar description is corrected rather than merely withdrawn.** ADR-018 describes the calendar strip as three-state — green ✓ completed, amber `↩` carried, grey — empty. **Only two of those states were ever built.** `positionSlots` (`CalendarView.svelte:268`) computes a single boolean, `completed: e.enum_status === 'COMPLETED'`; the template renders `class:completed` / `class:planned`; the CSS at `:638-656` covers exactly those two per type bucket. The word *carried* and the `↩` glyph do not appear in `CalendarView.svelte`, and nothing in it reads prior-season results — the strip is named `rolling-progress` while displaying no rolling data. Carry-over's actual surface is `DrilldownModal.svelte:49-104` (the `↩` banner, `.carried-row`, striped swatches, legend), driven by `bool_has_carryover` on the ranking row types (`types.ts:95`, `:105`). It is a ranking concept: a fencer's points from last season's event at the same position stand in until this season's event at that position is scored. **A calendar has no carried state to lose** — an event either takes place or it does not. So ADR-018's amendment withdraws the calendar UI consequence *and* corrects a three-state claim that never matched the implementation, which is a documentation defect predating this redesign.
- **Two live defects are reported, not silently fixed:** the `tournaments_count` pluralisation defect (§12), and the duplicated env footer between `App.svelte` and `CalendarView.svelte` (§16 — leave it, it retires with the WordPress migration).
- **One finding to verify, not fix:** `ce/CalendarElement.svelte` derives `demo ? MOCK_CALENDAR_EVENTS : []`, meaning the non-demo embed renders empty. Confirm how the production `spws-calendar` element is actually fed before changing anything; if it is genuinely unwired that is a separate report. Note also that the embed renders **no header** — `CalendarElement` mounts `CalendarView` alone, so the hamburger, wordmark and language toggle are app-only chrome. Should that change, the logo's `src="SPWS-logo.png"` is document-relative and would resolve against the host page and 404.
- **`SCORED` label dependency.** ADR-077 recorded that the display map omits `CREATED` and `SCORED`, both rendering as "Planned", marked as a fix. `CREATED` is moot here since the barrel hides it, but `SCORED` is a real state on the forward spine and the card must label it. Verify against `eventStatus.ts` before assuming ADR-037's helper is complete.
- **Zero DB impact.** No migration, no view rebuild, no `types.ts` extension, no `plpgsql-check` run.
- **Documentation:** register in specification Appendix C; update `doc/handbook/product/product-surfaces.html`, `doc/handbook/subsystems/events-and-registration.html`, and `doc/handbook/reference/codebase-map.html`. RTM check for requirements touching calendar presentation — ADR-030's FR-90/FR-91 and ADR-079's FR-120–FR-130 keep their wording but the test IDs they cite move.

## Open items

Both remaining items land in `resolveAnchorQuarter()`, which is why that function is written **last** in the pure module.

1. **What the card opens on** — next upcoming, most recent result, or time-sensitive. **Recommendation: time-sensitive** — the result for seven days after an event ends, then the next upcoming. The Monday after a competition weekend everyone wants results; three weeks later nobody does. The seven-day window already exists in the codebase for cancelled-event notices, so it is not a new concept to explain. *The mock opens on next-upcoming because that was the simplest thing to demonstrate; that is not a decision.*
2. **Past-season anchor** — finished seasons have no next-upcoming event, so the drum loses its focal point and rows read flat. **Recommendation:** mark championships (`MPW`, `MŚW`, `MEW`) distinctly using the `mpw` and `int` buckets §14 preserves, so past rows keep structure. Marking events the viewer competed in would be better but is impossible on a public embed with no viewer identity.

## Verification

`npm run check` and `svelte-check` on every changed `.svelte` and `.ts`; `npx vitest run` for the full frontend suite. Browser preview via the `frontend-ce-dev` launch config on port 5299 (`index.ce.html`), at 320, 360 and 390px.

**Measure, do not eyeball** — most of the geometry findings in this design were caught that way and would have passed a glance:

- five panels flat at 320px, six fanning; no content spilling past a panel border, and the selected panel's outline not clipped by the row's scroll container
- the selected panel's month in full and untruncated in **both** languages — `października` is the widest
- rotation across a season boundary updates season state
- the `PPW | +EVF` control appears only when `show_evf_toggle_calendar` allows it, **and** turning it off actually removes EVF events rather than only hiding the buttons
- the next-upcoming ring moves when scope is toggled
- all three fee lines with the right currency, and no tier on a single-weapon event
- the entry-list link present on a future event whose deadline has passed, and absent on a cancelled one
- copy-to-clipboard writing the full composed address, with the icon confirming and reverting
- `EN | PL` switching every string, including plural forms at counts of 1, 2 and 5
- the CERT/PROD footer still present and still switching environments

A 320px screenshot placed beside the mock is the acceptance check.
