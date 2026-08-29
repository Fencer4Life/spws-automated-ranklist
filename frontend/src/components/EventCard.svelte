<div class="card" class:cancelled={display.cssClass === 'status-cancelled'}>
  <div class="chd">
    <span class="cdt">{dateLabel}</span>
    <span class="ccd {type}">{event.txt_code}</span>
  </div>

  <div class="cnm">{event.txt_name}</div>

  {#if city}
    <div class="clo">
      <CountryFlag code={iso} label={countryLabel} />
      <span class="cct">{city}</span>
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
    <span class="chp">{registry}</span>
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

  {#if weapons.length > 0}
    <div class="wps">
      {#each weapons as weapon}
        <span class="wp">{t(WEAPON_KEY[weapon])}</span>
      {/each}
    </div>
  {/if}
</div>

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
    weaponLetters,
    type WeaponLetter,
  } from '../lib/calendarQuarters'

  const WEAPON_KEY: Record<WeaponLetter, string> = { E: 'epee', F: 'foil', S: 'sabre' }

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
  const registry = $derived(registryOf(type))
  const display = $derived(
    getEventDisplayStatus(event.enum_status, event.dt_end, event.dt_start, today),
  )
  const reg = $derived(registrationState(event, today))
  const weapons = $derived(weaponLetters(event.txt_code))
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

  const dateLabel = $derived.by(() => {
    const start = event.dt_start
    if (!start) return ''
    const [sy, sm, sd] = start.split('-').map(Number)
    const startMonth = t(`cal_month_${sm}`)
    const end = event.dt_end
    if (!end || end === start) return `${sd} ${startMonth} ${sy}`

    // Most competitions run a weekend, and "10–11 stycznia" answers a question
    // "10 stycznia" leaves open — whether to book two nights.
    const [ey, em, ed] = end.split('-').map(Number)
    if (ey === sy && em === sm) return `${sd}–${ed} ${startMonth} ${sy}`
    if (ey === sy) return `${sd} ${startMonth} – ${ed} ${t(`cal_month_${em}`)} ${sy}`
    return `${sd} ${startMonth} ${sy} – ${ed} ${t(`cal_month_${em}`)} ${ey}`
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
  .card {
    background: var(--surface-1, #f1efe9);
    border-radius: 12px;
    padding: 12px;
  }
  .card.cancelled {
    opacity: 0.72;
  }
  .chd {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: 6px;
  }
  .cdt {
    font-size: 11px;
    color: var(--text-secondary, #565550);
  }
  .ccd {
    font-size: 11px;
    font-weight: 600;
    padding: 1px 7px;
    border-radius: 8px;
    white-space: nowrap;
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
  .chp.status-completed {
    background: #eaf3de;
    color: #173404;
  }
  .chp.status-awaiting {
    background: #faeeda;
    color: #412402;
  }
  .chp.status-cancelled {
    background: #fcebeb;
    color: #501313;
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
  .wps {
    display: flex;
    gap: 3px;
    flex-wrap: wrap;
    margin-top: 10px;
  }
  .wp {
    font-size: 9px;
    line-height: 1.5;
    padding: 0 6px;
    border-radius: 7px;
    background: var(--surface-0, #f7f6f3);
    color: var(--text-muted, #8a887f);
    border: 1px solid var(--border, rgba(0, 0, 0, 0.13));
  }
</style>
