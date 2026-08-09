// EventCard.svelte — the single full-detail card the barrel drives.
// ADR-084 §8 field contract. Test IDs EC.1–EC.26.
//
// The contract is "optional rows render only when present", so the absences are
// asserted as deliberately as the presences: a card for an event with no fee
// must render NO fee line, not an empty one.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import type { CalendarEvent, EventStatus } from '../src/lib/types'
import EventCard from '../src/components/EventCard.svelte'

const TODAY = '2026-08-09'

let nextId = 1

function ev(partial: Partial<CalendarEvent> & { txt_code: string }): CalendarEvent {
  return {
    id_event: nextId++,
    txt_name: 'European Veterans Circuit',
    id_season: 1,
    txt_season_code: 'SPWS-2026-2027',
    id_organizer: null,
    txt_organizer_name: null,
    txt_location: null,
    txt_country: null,
    txt_venue_address: null,
    url_invitation: null,
    num_entry_fee: null,
    txt_entry_fee_currency: null,
    dt_start: '2026-09-19',
    dt_end: null,
    arr_weapons: [],
    url_event: null,
    enum_status: 'PLANNED' as EventStatus,
    num_tournaments: 1,
    bool_has_international: false,
    url_registration: null,
    dt_registration_deadline: null,
    url_event_2: null,
    url_event_3: null,
    url_event_4: null,
    url_event_5: null,
    ...partial,
  }
}

function card(partial: Partial<CalendarEvent> & { txt_code: string }, props = {}) {
  const { container } = render(EventCard, {
    props: { event: ev(partial), today: TODAY, ...props },
  })
  return container
}

describe('EventCard — identity', () => {
  // EC.1 — the full code, not the prefix the old list showed.
  it('EC.1: renders the full event code and name', () => {
    const c = card({ txt_code: 'PEW1f-2026-2027', txt_name: 'Budapest Open' })
    expect(c.querySelector('.ccd')!.textContent).toBe('PEW1f-2026-2027')
    expect(c.querySelector('.cnm')!.textContent).toBe('Budapest Open')
  })

  // EC.2 — a single-day event shows one date, spelled out.
  it('EC.2: renders a single date in full', () => {
    const c = card({ txt_code: 'A', dt_start: '2026-09-19' })
    expect(c.querySelector('.cdt')!.textContent!.trim()).toBe('19 września 2026')
  })

  // EC.3 — most competitions run a weekend, and "10–11 stycznia" answers a
  // question "10 stycznia" leaves open: whether to book two nights.
  it('EC.3: renders a same-month range', () => {
    const c = card({ txt_code: 'A', dt_start: '2027-01-10', dt_end: '2027-01-11' })
    expect(c.querySelector('.cdt')!.textContent!.trim()).toBe('10–11 stycznia 2027')
  })

  it('EC.4: renders a range that crosses a month', () => {
    const c = card({ txt_code: 'A', dt_start: '2027-01-30', dt_end: '2027-02-02' })
    expect(c.querySelector('.cdt')!.textContent!.trim()).toBe('30 stycznia – 2 lutego 2027')
  })

  // EC.5 — dt_end equal to dt_start is a single day, not a range.
  it('EC.5: collapses an equal start and end to one date', () => {
    const c = card({ txt_code: 'A', dt_start: '2026-09-19', dt_end: '2026-09-19' })
    expect(c.querySelector('.cdt')!.textContent!.trim()).toBe('19 września 2026')
  })

  // EC.6 — the type chip colours by bucket, mpw sharing ppw's palette.
  it('EC.6: classes the code chip by panel type', () => {
    expect(card({ txt_code: 'PEW1e-2026-2027' }).querySelector('.ccd')!.classList).toContain('pew')
    expect(card({ txt_code: 'MPW-2026-2027' }).querySelector('.ccd')!.classList).toContain('mpw')
    expect(card({ txt_code: 'MSW-2026' }).querySelector('.ccd')!.classList).toContain('int')
  })
})

describe('EventCard — location, flag and clipboard', () => {
  // EC.7 — if txt_location holds anything it appears. Classification picks the
  // line, never visibility.
  it('EC.7: shows a city with its flag', () => {
    const c = card({ txt_code: 'A', txt_location: 'Pabianice', txt_country: 'Polska' })
    expect(c.querySelector('.cct')!.textContent).toBe('Pabianice')
    expect(c.querySelector('.flag')!.getAttribute('aria-label')).toBe('Polska')
  })

  // EC.8 — the scraper wrote venue strings into the city column; those route to
  // the address line rather than being dropped.
  it('EC.8: routes a venue-shaped location to the address line', () => {
    const c = card({
      txt_code: 'A',
      txt_location: 'Sporthalle der Städtischen Berufsschule',
    })
    expect(c.querySelector('.cct')).toBeNull()
    expect(c.querySelector('.addrt')!.textContent).toContain('Sporthalle')
  })

  // EC.9 — "Venue - City" splits, with the city taking the flag line.
  it('EC.9: splits a "Venue - City" string across both lines', () => {
    const c = card({ txt_code: 'A', txt_location: 'Savoy Terrace - Buda' })
    expect(c.querySelector('.cct')!.textContent).toBe('Buda')
    expect(c.querySelector('.addrt')!.textContent).toBe('Savoy Terrace')
  })

  // EC.10 — no location at all means no line and no copy button.
  it('EC.10: omits both lines when there is no location', () => {
    const c = card({ txt_code: 'A' })
    expect(c.querySelector('.clo')).toBeNull()
    expect(c.querySelector('.addr')).toBeNull()
    expect(c.querySelector('.cpy')).toBeNull()
  })

  // EC.11 — an unrecognised country still shows the place, without a flag.
  it('EC.11: shows the city without a flag for an unmapped country', () => {
    const c = card({ txt_code: 'A', txt_location: 'Ruritania City', txt_country: 'Ruritania' })
    expect(c.querySelector('.cct')!.textContent).toBe('Ruritania City')
    expect(c.querySelector('.flag')).toBeNull()
  })

  // EC.12 — the clipboard carries venue, city AND country, because a pasted
  // string cannot see the flag the card shows.
  it('EC.12: copies the full composed address', async () => {
    const writeText = vi.fn().mockResolvedValue(undefined)
    Object.assign(navigator, { clipboard: { writeText } })
    const c = card({
      txt_code: 'A',
      txt_location: 'Nevers',
      txt_country: 'France',
      txt_venue_address: 'Complexe Sportif des Vauzelles',
    })
    await fireEvent.click(c.querySelector('.cpy')!)
    expect(writeText).toHaveBeenCalledWith('Complexe Sportif des Vauzelles, Nevers, Francja')
  })

  // EC.13 — with no venue the button rides the city line instead, so the
  // affordance follows whatever location the card has.
  it('EC.13: attaches the copy button to the city line when there is no venue', () => {
    const c = card({ txt_code: 'A', txt_location: 'Pabianice', txt_country: 'Polska' })
    expect(c.querySelector('.clo .cpy')).not.toBeNull()
    expect(c.querySelector('.addr')).toBeNull()
  })

  // EC.14 — an icon-only button is unlabelled to a screen reader without this.
  it('EC.14: gives the icon-only copy button an accessible name', () => {
    const c = card({ txt_code: 'A', txt_location: 'Pabianice' })
    expect(c.querySelector('.cpy')!.getAttribute('aria-label')).toBe('Kopiuj adres')
  })
})

describe('EventCard — fees', () => {
  // EC.15 — the tiers are independent, not a set: an event may fill the base
  // fee and _3w while leaving _2w null.
  it('EC.15: renders one line per non-null fee field', () => {
    const c = card({
      txt_code: 'PEW1efs-2026-2027',
      num_entry_fee: 45,
      num_entry_fee_3w: 90,
      txt_entry_fee_currency: 'EUR',
    })
    const rows = [...c.querySelectorAll('.fct.fee')]
    expect(rows).toHaveLength(2)
    expect(rows[0]!.textContent).toContain('45 EUR')
    expect(rows[1]!.textContent).toContain('90 EUR')
  })

  // EC.16 — no fee data means no fee row, not an empty one.
  it('EC.16: renders no fee row when there is no fee', () => {
    expect(card({ txt_code: 'A' }).querySelectorAll('.fct.fee')).toHaveLength(0)
  })

  // EC.17 — a tier can only exist where the tier does. A sabre-only event has
  // no two-weapon price, so a populated field there is a data error.
  it('EC.17: suppresses a tier the event has too few weapons for', () => {
    const c = card({
      txt_code: 'PEW12s-2026-2027',
      num_entry_fee: 40,
      num_entry_fee_2w: 70,
      num_entry_fee_3w: 90,
    })
    const rows = [...c.querySelectorAll('.fct.fee')]
    expect(rows).toHaveLength(1)
    expect(rows[0]!.textContent).toContain('40')
  })

  it('EC.18: allows a two-weapon tier on a two-weapon event but not a three', () => {
    const c = card({
      txt_code: 'PEW3ef-2026-2027',
      num_entry_fee_2w: 70,
      num_entry_fee_3w: 90,
    })
    const rows = [...c.querySelectorAll('.fct.fee')]
    expect(rows).toHaveLength(1)
    expect(rows[0]!.textContent).toContain('70')
  })

  // EC.19 — currency is stored, not assumed, with PLN as the fallback.
  it('EC.19: falls back to PLN when no currency is stored', () => {
    const c = card({ txt_code: 'PPW1-2026-2027', num_entry_fee: 120 })
    expect(c.querySelector('.fct.fee')!.textContent).toContain('120 PLN')
  })
})

describe('EventCard — registration block', () => {
  // EC.20 — the deadline renders dd/mm/yyyy.
  it('EC.20: renders the deadline as dd/mm/yyyy', () => {
    const c = card({
      txt_code: 'A',
      dt_start: '2026-09-19',
      dt_registration_deadline: '2026-09-06',
    })
    expect(c.querySelector('.registration-deadline')!.textContent!.trim()).toBe('06/09/2026')
  })

  // EC.21 — ADR-030's urgency, unchanged.
  it('EC.21: flags a deadline under seven days away', () => {
    const c = card({
      txt_code: 'A',
      dt_start: '2026-08-20',
      dt_registration_deadline: '2026-08-12',
    })
    expect(c.querySelector('.fct.deadline')!.classList).toContain('reg-urgent')
  })

  // EC.22 — THE RULE CHANGE (ADR-084 §9): the entry list outlives the
  // registration cutoff while the event is still ahead.
  it('EC.22: shows the entry list after the deadline but hides registration', () => {
    const c = card({
      txt_code: 'A',
      dt_start: '2026-09-19',
      dt_registration_deadline: '2026-08-01',
      url_registration: 'https://reg.test',
      url_entry_list: 'https://list.test',
    })
    expect(c.querySelector('.registration-link')).toBeNull()
    expect(c.querySelector('.entry-list-link')).not.toBeNull()
  })

  it('EC.23: hides the entry list on a cancelled event', () => {
    const c = card({
      txt_code: 'A',
      dt_start: '2026-09-19',
      enum_status: 'CANCELLED',
      url_entry_list: 'https://list.test',
    })
    expect(c.querySelector('.entry-list-link')).toBeNull()
    expect(c.querySelector('.cancelled-note')).not.toBeNull()
  })

  // EC.24 — ADR-079 §7: an SPWS-registration event opens the modal instead of
  // navigating; an external URL navigates normally.
  it('EC.24: opens the modal for SPWS registration instead of navigating', async () => {
    const onopenregistration = vi.fn()
    const { container } = render(EventCard, {
      props: {
        event: ev({
          txt_code: 'A',
          dt_start: '2026-09-19',
          url_registration: 'https://reg.test',
          bool_use_spws_registration: true,
        }),
        today: TODAY,
        onopenregistration,
      },
    })
    await fireEvent.click(container.querySelector('.registration-link')!)
    expect(onopenregistration).toHaveBeenCalledOnce()
  })
})

describe('EventCard — links and weapons', () => {
  // EC.25 — ADR-040: results are labelled by DAY, never by weapon, and a
  // single URL is just "Wyniki".
  it('EC.25: labels result links by day, and a lone URL plainly', () => {
    const single = card({
      txt_code: 'A',
      enum_status: 'COMPLETED',
      dt_end: '2026-01-11',
      url_event: 'https://r1.test',
    })
    expect([...single.querySelectorAll('.results-link')].map((a) => a.textContent!.trim())).toEqual([
      'Wyniki →',
    ])

    const many = card({
      txt_code: 'A',
      enum_status: 'COMPLETED',
      dt_end: '2026-01-11',
      url_event: 'https://r1.test',
      url_event_2: 'https://r2.test',
    })
    expect([...many.querySelectorAll('.results-link')].map((a) => a.textContent!.trim())).toEqual([
      'Dzień 1 →',
      'Dzień 2 →',
    ])
  })

  // EC.26 — weapons close the card as small pills, read from the code suffix.
  it('EC.26: renders weapon pills from the code suffix', () => {
    const c = card({ txt_code: 'PEW3ef-2026-2027' })
    expect([...c.querySelectorAll('.wp')].map((p) => p.textContent)).toEqual(['Szpada', 'Floret'])
    expect(card({ txt_code: 'PPW1-2026-2027' }).querySelectorAll('.wp')).toHaveLength(0)
  })

  // EC.27 — the two status chips: lifecycle state and owning registry.
  it('EC.27: renders the status and registry chips', () => {
    const c = card({ txt_code: 'PEW1e-2026-2027', enum_status: 'COMPLETED', dt_end: '2026-01-11' })
    const chips = [...c.querySelectorAll('.chp')].map((x) => x.textContent!.trim())
    expect(chips).toEqual(['Zakończone', 'EVF'])
  })

  it('EC.28: marks the next upcoming event on its chip', () => {
    const c = card({ txt_code: 'PPW1-2026-2027' }, { isNextUpcoming: true })
    expect(c.querySelector('.chp.next')!.textContent!.trim()).toBe('Najbliższe')
  })

  // EC.29 / EC.30 — the organiser's announcement. Carried over from the
  // timeline's two invitation-link tests during the ADR-084 triage: the card
  // rendered `url_invitation` from the start, but nothing asserted it, so the
  // coverage would have been lost silently when the timeline was deleted.
  it('EC.29: renders the invitation link when url_invitation is set', () => {
    const c = card({ txt_code: 'PPW1-2026-2027', url_invitation: 'https://host/komunikat.pdf' })
    const link = c.querySelector('.invitation-link') as HTMLAnchorElement
    expect(link).not.toBeNull()
    expect(link.getAttribute('href')).toBe('https://host/komunikat.pdf')
    expect(link.textContent!.trim()).toBe('Komunikat organizatora →')
  })

  it('EC.30: renders no invitation link when url_invitation is null', () => {
    const c = card({ txt_code: 'PPW1-2026-2027', url_invitation: null })
    expect(c.querySelector('.invitation-link')).toBeNull()
  })
})
