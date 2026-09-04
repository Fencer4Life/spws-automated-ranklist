<!-- Keyed on the event so the tilt animation restarts when the barrel selects a
     different one; a CSS animation does not replay on a class that never left. -->
{#key event.id_event}
  <div
    class="card {type}"
    class:cancelled={display.cssClass === 'status-cancelled'}
  >
  <!-- Row one: who runs it, what is fenced, and which event. The date moved to
       its own row below, which is what buys the space for all three. The code is
       complete — suffix and season — and the logo shrinks to make room. -->
  <div class="chd">
    <img class="orglogo reg-{registry}" src={LOGO_SRC[registry]} alt={registry} />
    {#if weapons.length > 0}
      <div class="wps">
        {#each weapons as weapon}
          <span class="wp {weapon}">{t(WEAPON_KEY[weapon])}</span>
        {/each}
      </div>
    {/if}
    <span class="chdsp"></span>
    <span class="ccd {type}" title={event.txt_code}>{shortCode}</span>
  </div>

  <div class="cdt">{dateLabel}</div>

  <div class="cnm">{event.txt_name}</div>

  <!-- Shown when there is a city OR a country. txt_location sometimes holds a
       venue string the scraper wrote into it ("Savoy Terrace - Buda Castle"),
       which splitLocation classifies as venue-only and routes to the address
       line below. Gating the whole row on `city` therefore dropped the FLAG and
       the country with it, leaving a Budapest event with no indication of where
       it is. -->
  {#if city || countryLabel}
    <div class="clo">
      <CountryFlag code={iso} label={countryLabel} />
      {#if city}<span class="cct">{city}</span>{/if}
      {#if !addressLine && clipboard}
        <button
          class="cpy"
          type="button"
          aria-label={copied ? t('copied') : t('copy_address')}
          title={copied ? t('copied') : t('copy_address')}
          onclick={copyAddress}
        >
          {#if copied}
            <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M20 6L9 17l-5-5" /></svg>
          {:else}
            <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><rect x="9" y="9" width="11" height="11" rx="2" /><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" /></svg>
          {/if}
        </button>
      {/if}
      {#if countryLabel}<span class="ctry">{countryLabel}</span>{/if}
    </div>
  {/if}

  {#if addressLine}
    <div class="addr">
      <span class="addrt">{addressLine}</span>
      {#if clipboard}
        <button
          class="cpy"
          type="button"
          aria-label={copied ? t('copied') : t('copy_address')}
          title={copied ? t('copied') : t('copy_address')}
          onclick={copyAddress}
        >
          {#if copied}
            <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M20 6L9 17l-5-5" /></svg>
          {:else}
            <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><rect x="9" y="9" width="11" height="11" rx="2" /><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" /></svg>
          {/if}
        </button>
      {/if}
    </div>
  {/if}

  <div class="chips">
    <span class="chp status {isNextUpcoming ? 'next' : display.cssClass}">
      {isNextUpcoming ? t('calendar_next_up') : t(display.labelKey)}
    </span>
    {#if movedFrom}
      <span class="chp moved">{t('calendar_date_moved_from').replace('{date}', formatDeadline(movedFrom))}</span>
    {/if}
  </div>

  <div class="dvv"></div>

  {#if showFees || reg.showDeadline}
    <div class="facts">
      {#if event.num_entry_fee != null}
        <div class="fct fee">
          <span class="fk">{t('entry_fee')}</span>
          <span class="fv">{event.num_entry_fee} {currency}</span>
        </div>
      {/if}
      {#if fee2w != null}
        <div class="fct fee">
          <span class="fk">{t('event_entry_fee_2w_label')}</span>
          <span class="fv">{fee2w} {currency}</span>
        </div>
      {/if}
      {#if fee3w != null}
        <div class="fct fee">
          <span class="fk">{t('event_entry_fee_3w_label')}</span>
          <span class="fv">{fee3w} {currency}</span>
        </div>
      {/if}
      {#if reg.showDeadline && event.dt_registration_deadline}
        <div class="fct deadline" class:reg-urgent={reg.urgent}>
          <span class="fk">{t('event_registration_deadline_label')}</span>
          <span class="fv registration-deadline">
            {formatDeadline(event.dt_registration_deadline)}
          </span>
        </div>
      {/if}
    </div>
  {/if}

  {#if display.cssClass === 'status-awaiting'}
    <p class="note awaiting">{t('event_awaiting_message')}</p>
  {:else if display.cssClass === 'status-cancelled'}
    <p class="note cancelled-note">{t('event_cancelled_message')}</p>
  {/if}

  {#if pills.length > 0}
    <div class="pills">
      {#each pills as pill}
        <a
          class="pl {pill.kind}"
          href={pill.href}
          target="_blank"
          rel="noopener"
          onclick={pill.onclick}
        >{pill.label} &rarr;</a>
      {/each}
    </div>
  {/if}

  </div>
{/key}

<script lang="ts">
  // The single full-detail event card the barrel drives — ADR-084 §8.
  //
  // Ordered by what a fencer actually acts on: identity first (date, code,
  // name, place), then a two-chip status line, then a rule, then the decision
  // block (fees, deadline, the two links). Weapons close the card as small
  // muted pills — they qualify an event, they are not why anyone opened it.
  //
  // Every optional row is omitted entirely when its field is empty. No
  // "brak danych" placeholders.

  import type { CalendarEvent } from '../lib/types'
  import { getEventDisplayStatus } from '../lib/eventStatus'
  import { t } from '../lib/locale.svelte'
  import CountryFlag from './CountryFlag.svelte'
  import {
    allowsFeeTier,
    composeAddress,
    countryCode,
    formatDeadline,
    movedFromDate,
    panelType,
    registrationState,
    registryOf,
    resultUrls,
    splitLocation,
    todayIso,
    type WeaponLetter,
  } from '../lib/calendarMonths'
  import type { WeaponType } from '../lib/types'

  const WEAPON_KEY: Record<WeaponLetter, string> = { E: 'epee', F: 'foil', S: 'sabre' }
  const WEAPON_TYPE: Record<WeaponLetter, WeaponType> = {
    E: 'EPEE',
    F: 'FOIL',
    S: 'SABRE',
  }

  /** The organizer's own mark, replacing the registry abbreviation chip.
   *  `alt` carries the abbreviation, which is now its only appearance — it is
   *  what a screen reader announces and what shows if an asset fails to load. */
  const LOGO_SRC: Record<'SPWS' | 'EVF' | 'FIE' | 'PZSz', string> = {
    SPWS: 'SPWS-logo.png',
    EVF: 'EVF-logo.png',
    FIE: 'FIE-logo.svg',
    PZSz: 'PZSz-logo.png',
  }

  let {
    event,
    isNextUpcoming = false,
    today = todayIso(),
    onopenregistration,
    onopenentrylist,
  }: {
    event: CalendarEvent
    isNextUpcoming?: boolean
    today?: string
    /** ADR-079 §7 — open RegistrationModal instead of navigating. */
    onopenregistration?: (event: CalendarEvent) => void
    onopenentrylist?: (event: CalendarEvent) => void
  } = $props()

  let copied = $state(false)

  const type = $derived(panelType(event.txt_code))
  /** Which body runs this event, for the logo.
   *
   *  The row is the fact; `registryOf(panelType(code))` is a prefix heuristic
   *  and it disagrees with the database on two of the ten code families in use
   *  — DMEW (EVF, guessed SPWS) and IMEW (EVF, guessed FIE). It stays as the
   *  fallback for rows that carry no organizer, and for an organizer with no
   *  mark of its own, because a best guess beats an empty registry slot.
   *
   *  `type` is untouched and still drives the tile hue, which is a
   *  presentation channel rather than a claim about who organises what. */
  const registry = $derived(
    (['SPWS', 'EVF', 'FIE', 'PZSz'] as const).find(
      (r) => r === event.txt_organizer_code,
    ) ?? registryOf(type),
  )
  const display = $derived(
    getEventDisplayStatus(event.enum_status, event.dt_end, event.dt_start, today),
  )
  const reg = $derived(registrationState(event, today))
  // The event table decides, not the code. The trailing [efs] exists to
  // differentiate EVF events; 28 of 97 events carry no suffix at all — every
  // PPW, MPW, GP, IMEW, IMSW, MSW, DMEW and VFC — and their pills never
  // rendered. arr_weapons is now maintained for every family (migration
  // 20260904000001), so it is the single source.
  const weapons = $derived(
    (['E', 'F', 'S'] as WeaponLetter[]).filter((w) =>
      (event.arr_weapons ?? []).includes(WEAPON_TYPE[w]),
    ),
  )
  // The FULL code — weapon suffix and season both. Two earlier passes trimmed
  // it for width (panelLabel(), then the prefix) and both threw away real
  // information: the suffix is the authoritative weapon record (ADR-046,
  // ADR-086) and the season is what distinguishes PPW1 across years on a
  // calendar that shows every season at once.
  //
  // Width is handled by letting the LOGO shrink instead. It is the only element
  // in row one that can give ground without losing meaning — pills and code are
  // text and would truncate mid-word.
  const shortCode = $derived(event.txt_code)
  // ADR-077 amendment: EVF moved this event and it is still ahead. Composes
  // with the status chip rather than replacing it — a moved date qualifies a
  // PLANNED event, it does not change what the event IS.
  const movedFrom = $derived(movedFromDate(event))
  const currency = $derived(event.txt_entry_fee_currency ?? 'PLN')

  const location = $derived(splitLocation(event.txt_location))
  const city = $derived(location.city)
  // The venue address column wins; a venue the scraper wrote into txt_location
  // is the fallback so the string is never lost.
  const addressLine = $derived(event.txt_venue_address?.trim() || location.venue)

  const iso = $derived(countryCode(event.txt_country))
  const countryLabel = $derived(
    iso ? t(`country_${iso}`) : (event.txt_country ?? ''),
  )
  const clipboard = $derived(
    composeAddress({
      venue: addressLine,
      city,
      // Fall back to the raw value so an un-normalised country still travels.
      country: iso ? t(`country_${iso}`) : event.txt_country,
    }),
  )

  // A tier can only exist where the tier does — a foil-only event has no
  // two-weapon price, so a populated field there is a data error.
  const fee2w = $derived(
    allowsFeeTier(event.txt_code, 2) ? (event.num_entry_fee_2w ?? null) : null,
  )
  const fee3w = $derived(
    allowsFeeTier(event.txt_code, 3) ? (event.num_entry_fee_3w ?? null) : null,
  )
  const showFees = $derived(event.num_entry_fee != null || fee2w != null || fee3w != null)

  /**
   * The weekday for an ISO date, Monday-first to match `cal_dow_short_1..7`.
   * `getUTCDay()` is 0=Sunday, so Sunday maps to 7.
   */
  function dow(iso: string): string {
    const d = new Date(`${iso}T00:00:00Z`).getUTCDay()
    return t(`cal_dow_short_${d === 0 ? 7 : d}`)
  }

  const dateLabel = $derived.by(() => {
    const start = event.dt_start
    if (!start) return ''
    const [sy, sm, sd] = start.split('-').map(Number)
    const startMonth = t(`cal_month_${sm}`)
    const end = event.dt_end

    // The weekday sits immediately before its own day number rather than on a
    // second line aligned under it. Alignment only works for the two-day case:
    // MSW Tbilisi runs 9–13 October, five days behind two numbers, and six
    // events in the pool cross a month boundary. Inline degrades correctly for
    // all of them, and does not depend on glyph widths that differ between
    // "sob"/"niedz" and "Sat"/"Sun".
    if (!end || end === start) return `${dow(start)} ${sd} ${startMonth} ${sy}`

    const [ey, em, ed] = end.split('-').map(Number)
    if (ey === sy && em === sm) {
      return `${dow(start)} ${sd} – ${dow(end)} ${ed} ${startMonth} ${sy}`
    }
    if (ey === sy) {
      return `${dow(start)} ${sd} ${startMonth} – ${dow(end)} ${ed} ${t(`cal_month_${em}`)} ${sy}`
    }
    return `${dow(start)} ${sd} ${startMonth} ${sy} – ${dow(end)} ${ed} ${t(`cal_month_${em}`)} ${ey}`
  })

  type Pill = {
    kind: string
    label: string
    href: string
    onclick?: (e: MouseEvent) => void
  }

  const pills = $derived.by(() => {
    const out: Pill[] = []

    // ADR-040: slots are equal-status, so labels are by DAY, never by weapon,
    // and are derived here at render time rather than stored.
    const urls = resultUrls(event)
    if (event.enum_status === 'COMPLETED' && urls.length > 0) {
      urls.forEach((href, i) => {
        out.push({
          kind: 'results-link',
          label: urls.length === 1 ? t('event_results') : `${t('event_results_day')} ${i + 1}`,
          href,
        })
      })
    }

    if (reg.showRegistrationLink && event.url_registration) {
      out.push({
        kind: 'registration-link',
        label: t('event_registration'),
        href: event.url_registration,
        onclick: reg.useSpwsModal
          ? (e: MouseEvent) => {
              e.preventDefault()
              onopenregistration?.(event)
            }
          : undefined,
      })
    }

    if (reg.showEntryListLink && event.url_entry_list) {
      out.push({
        kind: 'entry-list-link',
        label: t('reg_entry_list_link'),
        href: event.url_entry_list,
        onclick: (e: MouseEvent) => {
          e.preventDefault()
          onopenentrylist?.(event)
        },
      })
    }

    if (event.url_invitation) {
      out.push({
        kind: 'invitation-link',
        label: t('organizer_announcement'),
        href: event.url_invitation,
      })
    }

    return out
  })

  async function copyAddress(): Promise<void> {
    if (!clipboard) return
    // The Clipboard API needs a secure context and the public embed may sit on
    // a plain-http host page, so fall back to execCommand.
    try {
      await navigator.clipboard.writeText(clipboard)
    } catch {
      const scratch = document.createElement('textarea')
      scratch.value = clipboard
      scratch.setAttribute('readonly', '')
      scratch.style.position = 'absolute'
      scratch.style.left = '-9999px'
      document.body.appendChild(scratch)
      scratch.select()
      try {
        document.execCommand('copy')
      } catch {
        /* nothing more to try — leave the button unconfirmed */
      }
      document.body.removeChild(scratch)
    }
    // A clipboard write is otherwise completely silent.
    copied = true
    setTimeout(() => (copied = false), 1400)
  }
</script>

<style>
  /* ===== Card surface =====================================================
     Three treatments, chosen from a set of five: a layered elevation shadow, a
     solid top edge in the selected tile's own colour, and a brief tilt when the
     card content swaps.

     Two were rejected and are deliberately absent. A top-lit surface gradient
     shifted contrast from top to bottom behind a lot of small text — fee keys,
     chips, pills — and cost legibility for depth the shadow already gives. An
     inner bevel added nothing once the shadow was there. There are NO gradients
     on this card: the top edge started as a wash falling from the top and is a
     solid bar precisely because that was the rejected gradient under another
     name. */
  .card {
    background: var(--surface-1, #f1efe9);
    border-radius: 12px;
    padding: 12px;
    position: relative;
    box-shadow:
      0 1px 2px rgba(16, 24, 40, 0.1),
      0 6px 16px -4px rgba(16, 24, 40, 0.16),
      0 18px 38px -12px rgba(16, 24, 40, 0.14);
    animation: card-tilt 0.42s cubic-bezier(0.22, 0.61, 0.36, 1);
  }
  /* The top edge picks up the organizer hue of the tile the caret points at, so
     the card reads as extruded from it rather than floating underneath. */
  .card::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    border-radius: 12px 12px 0 0;
    background: var(--edge, #6f7d8f);
  }
  .card.ppw,
  .card.mpw {
    --edge: #2e7d52;
  }
  .card.pew {
    --edge: #1f6fb0;
  }
  .card.int {
    --edge: #b1791d;
  }
  /* PZSz's own brand red is #c72626. A desaturated relative of it stays
     recognisably theirs while sitting in the same tonal family as the SPWS
     green, EVF blue and FIE amber above. */
  .card.pzs {
    --edge: #c05555;
  }
  @keyframes card-tilt {
    from {
      transform: perspective(760px) rotateX(9deg) translateY(-5px);
      opacity: 0.55;
    }
    to {
      transform: none;
      opacity: 1;
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .card {
      animation: none;
    }
  }
  @media (prefers-color-scheme: dark) {
    .card {
      box-shadow:
        0 1px 2px rgba(0, 0, 0, 0.5),
        0 6px 16px -4px rgba(0, 0, 0, 0.55),
        0 18px 38px -12px rgba(0, 0, 0, 0.5);
    }
  }
  /* A blanket `opacity` on the card would dim the highlighted cancelled chip
     with everything else — opacity on a parent applies to every descendant, so
     the one element that must stand out would be the one muted. The dimming is
     applied to the content instead, and the chip is left at full strength. */
  .card.cancelled .cnm {
    text-decoration: line-through;
    text-decoration-thickness: 1.5px;
  }
  .card.cancelled .cnm,
  .card.cancelled .cct,
  .card.cancelled .ctry,
  .card.cancelled .addrt,
  .card.cancelled .cdt,
  .card.cancelled .facts,
  .card.cancelled .wps,
  .card.cancelled .pills {
    opacity: 0.62;
  }
  .chd {
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
  }
  /* Pushes the code to the right edge without justify-content, so the logo and
     pills stay packed together on the left. */
  .chdsp {
    flex: 1 1 auto;
    min-width: 0;
  }
  /* 28px: twice the abbreviation chip it replaces. 14px was tried first and
     failed -- SPWS and FIE are wordmarks and survived, but the EVF and PZSz
     roundels are square and detailed (ring text, three crossed weapons) and
     collapsed into a coloured dot. A roundel needs height, which is exactly what
     a chip-height slot denies it. */
  .orglogo {
    /* Sized against the weapon pills beside it, which stand 14px tall (9px at
       line-height 1.5). 18px reads as the organizer's mark without becoming the
       loudest thing in a row whose job is the event's identity. */
    height: 18px;
    width: auto;
    max-width: 80px;
    display: block;
    /* Shrinkable, and it is the ONLY thing in this row that shrinks. Measured at
       the 375px viewport: the SPWS wordmark (124px) beside three weapon pills
       and the short code needs 326px in a 315px row — 11px over, and a flex row
       clips rather than wraps, so the code was being cut off. The logo yields
       because object-fit keeps it legible while it does; the pills and the code
       are text and would only truncate. */
    flex: 0 1 auto;
    min-width: 0;
    object-fit: contain;
    object-position: left center;
  }
  /* 1.5x the shared height, for the two ROUNDELS. EVF and PZSz are dense circular
     marks — a ring of text around a fencer, and three crossed weapons over a flag
     arc — where 18px reads as a speck. SPWS and FIE are wordmarks: they spend
     their pixels on width and stay legible at the shared height, so enlarging
     them would only make them shout.

     Height is what a roundel needs and width buys it nothing, which is why this
     sets both and not a scale factor. */
  .orglogo.reg-PZSz,
  .orglogo.reg-EVF {
    height: 27px;
    max-width: 27px;
  }
  /* The date leads the card.
     ADR-084 §8 orders this card by what a fencer acts on, and identity — date,
     code, name, place — comes first. The date was nonetheless the SMALLEST text
     on it at 11px muted, quieter than the fee keys. It is the first thing
     anyone checks ("can I go?"), so it now reads as a headline: larger than the
     event name, and in the primary colour rather than the secondary one. */
  .cdt {
    /* 16, not 17: the weekday at each end added ~60px, and 16px is what keeps
       the common label — "sob 26 – niedz 27 września 2026", 249px — beside the
       code pill on one row inside a 360px card. A range crossing a month is
       longer than any workable size and is allowed to wrap; that is six events
       in the pool, nearly all historical. */
    font-size: 16px;
    font-weight: 700;
    line-height: 1.15;
    letter-spacing: -0.01em;
    color: var(--text-primary, #1c1b19);
  }
  /* The header stops being a baseline-aligned pair once the date is much larger
     than the code chip; centring keeps the chip beside it rather than hanging. */
  .chd {
    align-items: center;
  }
  /* Smaller than the 11px it was: the date line grew a weekday at each end
     ("sob 26 – niedz 27 września 2026"), and at 320px the pill was the thing
     that pushed the header onto two rows. The code is reference detail — the
     date is what the header is for — so the pill gives up the space. */
  .ccd {
    /* 8.5px, weight 700 to hold legibility that small. Sized against the
       LONGEST code in the upcoming pool — PEW11efs-2026-2027, 18 characters,
       106px — inside the 107px left over once the date has its row. The code is
       reference detail and appears on the tile as well; the date is what the
       header exists for, so the pill is what gives way. */
    font-size: 8.5px;
    font-weight: 700;
    padding: 1px 6px;
    border-radius: 8px;
    white-space: nowrap;
    flex: 0 0 auto;
    letter-spacing: -0.01em;
  }
  .cdt {
    min-width: 0;
  }
  .ccd.ppw,
  .ccd.mpw {
    background: #eaf3de;
    color: #173404;
  }
  .ccd.pew {
    background: #e6f1fb;
    color: #042c53;
  }
  .ccd.int {
    background: #faeeda;
    color: #412402;
  }
  .ccd.pzs {
    background: #fbeaea;
    color: #4b0f0f;
  }
  .cnm {
    font-size: 15px;
    font-weight: 600;
    margin-top: 6px;
    line-height: 1.25;
  }
  .clo {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-top: 3px;
  }
  .cct {
    font-size: 15px;
    font-weight: 600;
    line-height: 1.25;
  }
  .addr {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    margin-top: 3px;
  }
  .addrt {
    flex: 1;
    min-width: 0;
    font-size: 11px;
    color: var(--text-secondary, #565550);
    line-height: 1.35;
  }
  .cpy {
    flex: 0 0 auto;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    padding: 0;
    border-radius: 6px;
    border: 1px solid var(--border, rgba(0, 0, 0, 0.13));
    background: var(--surface-2, #fff);
    color: var(--text-muted, #8a887f);
    cursor: pointer;
  }
  .chips {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
    margin-top: 8px;
  }
  .chp {
    font-size: 11px;
    padding: 2px 7px;
    border-radius: 8px;
    background: var(--surface-2, #fff);
    color: var(--text-secondary, #565550);
    border: 1px solid var(--border, rgba(0, 0, 0, 0.13));
  }
  .chp.status {
    border-color: transparent;
  }
  .chp.next {
    background: #e6f1fb;
    color: #185fa5;
  }
  /* Completed goes GREY, not green. Under the inverted palette the past
     recedes, and a green "Zakończone" chip would contradict a greyed tile. */
  .chp.status-completed,
  .chp.status-scored {
    background: var(--grey-bg, #e6eaef);
    color: var(--grey, #6f7d8f);
  }
  .chp.status-planned,
  .chp.status-created,
  .chp.status-scheduled {
    background: #eaf3de;
    color: #173404;
  }
  .chp.status-inprogress {
    background: #fbe9c4;
    color: #5c3d06;
  }
  .chp.status-awaiting {
    background: #faeeda;
    color: #412402;
  }
  /* Cancelled is HIGHLIGHTED, not tinted: it is the one thing on the card that
     must not be missed, and the pale wash lost against everything else. */
  .chp.status-cancelled {
    background: #a32d2d;
    color: #fff;
    font-weight: 700;
    letter-spacing: 0.04em;
  }
  /* Registry carries the organizer hue OUTLINED, while status is filled. Hue
     alone could not separate them: an SPWS event that is "Zaplanowane" would
     render two adjacent chips in the same green and read as one blob. */
  .chp.reg-SPWS {
    background: transparent;
    color: #2c6a47;
    border-color: #8fbfa2;
  }
  .chp.reg-EVF {
    background: transparent;
    color: #1f6fb0;
    border-color: #9cc4e4;
  }
  .chp.reg-FIE {
    background: transparent;
    color: #8a5c12;
    border-color: #dcb877;
  }
  /* Full localised country name, after the copy button. */
  .ctry {
    font-size: 11px;
    color: var(--text-secondary, #565550);
    white-space: nowrap;
    flex: 0 0 auto;
  }
  /* Amber, the same attention colour as status-awaiting. The two never co-occur:
     awaiting-results means the event is past, moved means it is still ahead.
     Deliberately not the cancelled red — a moved event is still happening. */
  /* The status chip stays honest — the event IS still planned. The alert lives
     here instead, so the two facts compose rather than one masking the other. */
  .chp.moved {
    background: #faeeda;
    color: #412402;
    border-color: transparent;
  }
  .dvv {
    height: 1px;
    background: var(--border, rgba(0, 0, 0, 0.13));
    margin: 10px 0;
  }
  .facts {
    margin-top: 2px;
  }
  .fct {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: 10px;
  }
  /* Three fee tiers plus a deadline is four rows on a 320px card. The fees are
     set deliberately small and tight — they are reference detail, while the
     deadline below is the row that actually forces a decision. */
  .fct.fee {
    padding: 0;
    line-height: 1.5;
  }
  .fct.fee .fk {
    font-size: 9px;
  }
  .fct.fee .fv {
    font-size: 10px;
    font-weight: 600;
  }
  .fct.deadline {
    padding: 5px 0 2px;
  }
  .fk {
    font-size: 11px;
    color: var(--text-muted, #8a887f);
  }
  .fv {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary, #1c1b19);
    white-space: nowrap;
  }
  .fct.reg-urgent .fk,
  .fct.reg-urgent .fv {
    color: #a32d2d;
  }
  .note {
    font-size: 11px;
    line-height: 1.4;
    margin: 8px 0 0;
  }
  .note.awaiting {
    color: #854f0b;
  }
  .note.cancelled-note {
    color: #a32d2d;
  }
  .pills {
    display: flex;
    gap: 5px;
    flex-wrap: wrap;
    margin-top: 9px;
  }
  .pl {
    font-size: 11px;
    font-weight: 600;
    padding: 4px 10px;
    border-radius: 14px;
    border: 1px solid var(--accent, #185fa5);
    color: var(--accent, #185fa5);
    background: var(--surface-2, #fff);
    text-decoration: none;
    display: inline-block;
  }
  /* In the header now, not the card's foot, so no top margin and no wrapping —
     the row is sized to hold logo + pills + short code on one line. */
  .wps {
    display: flex;
    gap: 4px;
    flex: 0 0 auto;
  }
  /* Size, face and padding are UNCHANGED from the muted version; only the
     colours and the weight move. Each weapon gets its own filled hue so the set
     reads at a glance instead of as three grey words -- and the hues are chosen
     clear of the organizer channel (SPWS green, EVF blue, FIE amber, PZSz red),
     which already owns the card's top edge. */
  /* One filled hue per weapon. Text is the darkest stop of its own ramp on a
     light tint, which keeps contrast without the pills shouting over the event
     name directly beneath them. */
  .wp.E {
    background: #cfe8dd;
    color: #0b3d2e;
  }
  .wp.F {
    background: #ddd9f5;
    color: #2b2564;
  }
  .wp.S {
    background: #f7ddd2;
    color: #5c2410;
  }
  .wp {
    font-size: 9px;
    line-height: 1.5;
    padding: 0 6px;
    border-radius: 7px;
    font-weight: 600;
    white-space: nowrap;
    background: var(--surface-0, #f7f6f3);
    color: var(--text-muted, #8a887f);
    border: 1px solid var(--border, rgba(0, 0, 0, 0.13));
  }
</style>
