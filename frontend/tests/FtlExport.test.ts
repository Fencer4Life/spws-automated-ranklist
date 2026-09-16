// The FTL export surface — plan doc/plans/ftl-export-page-2026-09-12.html.
// Plan IDs X9.1-X9.14.
//
// WHAT THIS SCREEN IS FOR. The organizer of a Polish veterans' event runs
// Fencing Time on a laptop at the venue, usually on the morning of the
// competition, often in a hurry, sometimes without reading Polish. Everything
// here is shaped by that: the file list is generated from the same objects that
// produced the XML so the counts cannot drift, the instruction is eight numbered
// steps rather than a column of two-word labels, the two mistakes that damage an
// event (importing the pick-list as a competition, deleting the digit in a
// surname) are on the page and not only in a manual, and one button produces the
// whole bundle because a browser will not start twenty-eight downloads.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent, waitFor } from '@testing-library/svelte'
import FtlExport from '../src/components/FtlExport.svelte'
import type { ExportEntryRow } from '../src/lib/ftlSeedExport'
import type { FtlExportEvent } from '../src/lib/types'
import { setLocale } from '../src/lib/locale.svelte'

const entry = (
  surname: string,
  first: string,
  gender: 'M' | 'F',
  cat: string,
  weapon: string,
  order: number,
): ExportEntryRow => ({
  txt_surname: surname,
  txt_first_name: first,
  enum_gender: gender,
  enum_age_category: cat,
  enum_weapon: weapon,
  int_order: order,
  txt_club: null,
})

const ROWS: ExportEntryRow[] = [
  entry('Peczek', 'Sandra', 'F', 'V0', 'EPEE', 1),
  entry('Kowalski', 'jan', 'M', 'V0', 'EPEE', 1),
  entry('NOWAK', 'PIOTR', 'M', 'V2', 'EPEE', 1),
  entry('Nowicki', 'Adam', 'M', 'V2', 'EPEE', 2),
  entry('Zielinski', 'Marek', 'M', 'V1', 'SABRE', 1),
]

const EVENTS: FtlExportEvent[] = [
  {
    id_event: 74,
    txt_code: 'PPW1-2026-2027',
    txt_name: 'I Puchar Polski Weteranów w Szermierce',
    txt_location: 'Opole',
    dt_start: '2026-09-26',
    int_registrations: 43,
  },
  {
    id_event: 85,
    txt_code: 'PEW5efs-2026-2027',
    txt_name: 'EVF Circuit – Łomianki (POL)',
    txt_location: 'Łomianki',
    dt_start: '2026-12-12',
    int_registrations: 14,
  },
]

const props = (over: Record<string, unknown> = {}) => ({
  events: EVENTS,
  selectedId: 74,
  entries: ROWS,
  rosters: {},
  loading: false,
  notFound: false,
  takenAt: '2026-09-12 20:15',
  onselect: vi.fn(),
  onrefresh: vi.fn(async () => ({ entries: ROWS, rosters: {} })),
  ...over,
})

function stubDownloads(): { clicked: string[]; restore: () => void } {
  const clicked: string[] = []
  const originalCreate = URL.createObjectURL
  const originalRevoke = URL.revokeObjectURL
  URL.createObjectURL = vi.fn(() => 'blob:stub')
  URL.revokeObjectURL = vi.fn()
  const spy = vi
    .spyOn(HTMLAnchorElement.prototype, 'click')
    .mockImplementation(function (this: HTMLAnchorElement) {
      clicked.push(this.download)
    })
  return {
    clicked,
    restore: () => {
      spy.mockRestore()
      URL.createObjectURL = originalCreate
      URL.revokeObjectURL = originalRevoke
    },
  }
}

describe('FtlExport', () => {
  beforeEach(() => setLocale('pl'))

  // -------------------------------------------------------------------------
  // Choosing an event
  // -------------------------------------------------------------------------

  // X9.1 — The association always has more than one event taking entries, and
  // the page must not depend on whoever sent the link having picked correctly.
  it('offers a card for every event with entries', () => {
    const { container } = render(FtlExport, { props: props() })
    const cards = [...container.querySelectorAll('[data-field="ftl-event-card"]')]
    expect(cards).toHaveLength(2)
    expect(cards[0].textContent).toContain('PPW1-2026-2027')
    expect(cards[0].textContent).toContain('43')
    expect(cards[1].textContent).toContain('Łomianki')
  })

  // X9.2 — A dropdown hid the second event behind a click; a card does not.
  it('marks the selected event and reports a change', async () => {
    const onselect = vi.fn()
    const { container } = render(FtlExport, { props: props({ onselect }) })
    const cards = [...container.querySelectorAll('[data-field="ftl-event-card"]')]
    expect(cards[0].className).toContain('on')
    await fireEvent.click(cards[1])
    expect(onselect).toHaveBeenCalledWith(85)
  })

  // X9.3 — One event is the common case for a small association; a picker with
  // a single option is furniture.
  it('hides the picker when only one event qualifies', () => {
    const { container } = render(FtlExport, { props: props({ events: [EVENTS[0]] }) })
    expect(container.querySelector('[data-field="ftl-event-card"]')).toBeNull()
  })

  // X9.4 — The city is what an organizer recognises; the code is what they quote
  // back to us when something is wrong.
  it('names the event, the city and the code in the header', () => {
    const { container } = render(FtlExport, { props: props() })
    const header = container.querySelector('[data-field="ftl-event-line"]')!
    expect(header.textContent).toContain('I Puchar Polski Weteranów w Szermierce')
    expect(header.textContent).toContain('OPOLE')
    expect(header.textContent).toContain('PPW1-2026-2027')
  })

  // -------------------------------------------------------------------------
  // The file list
  // -------------------------------------------------------------------------

  // X9.5 — Twenty-eight flat rows pushed the instruction off the screen.
  it('groups the files into one collapsed section per weapon', async () => {
    const { container } = render(FtlExport, { props: props() })
    const groups = [...container.querySelectorAll('[data-field="ftl-weapon-group"]')]
    expect(groups).toHaveLength(2) // épée and sabre; nobody entered foil
    expect(container.querySelectorAll('[data-field="ftl-filename"]')).toHaveLength(0)
    await fireEvent.click(groups[0].querySelector('[data-field="ftl-weapon-head"]')!)
    expect(container.querySelectorAll('[data-field="ftl-filename"]').length).toBeGreaterThan(0)
  })

  // X9.6 — The header has to carry enough that the set can be judged without
  // opening anything.
  it('summarises each weapon in its own header', () => {
    const { container } = render(FtlExport, { props: props() })
    const head = container.querySelector('[data-field="ftl-weapon-head"]')!
    expect(head.textContent).toContain('SZPADA')
    expect(head.textContent).toContain('4') // 1 mix-all + 3 DE
  })

  // X9.7 — The manifest IS the file list, generated from the SeedFile objects,
  // so a row cannot describe a file that was not produced.
  it('lists every generated file with its own fencer count', async () => {
    const { container } = render(FtlExport, { props: props() })
    await fireEvent.click(container.querySelector('[data-field="ftl-weapon-head"]')!)
    const names = [...container.querySelectorAll('[data-field="ftl-filename"]')].map(
      (el) => el.textContent,
    )
    expect(names).toEqual([
      'PPW1-2026-2027_EPEE_POOLS-MIXED_all-categories_W+M.xml',
      'PPW1-2026-2027_EPEE_DE_WOMEN_V0.xml',
      'PPW1-2026-2027_EPEE_DE_MEN_V0.xml',
      'PPW1-2026-2027_EPEE_DE_MEN_V2.xml',
    ])
    const counts = [...container.querySelectorAll('[data-field="ftl-count"]')].map((el) =>
      el.textContent?.trim(),
    )
    expect(counts).toEqual(['4', '1', '1', '2'])
  })

  // X9.8 — The one destructive mistake available here is importing the pick-list
  // as a competition, so the row says so in the row itself.
  it('marks the roster row as a pick-list, not a competition', async () => {
    const { container } = render(FtlExport, {
      props: props({
        rosters: {
          EPEE: [
            {
              txt_surname: 'Aaa',
              txt_first_name: 'Adam',
              enum_gender: 'M',
              enum_age_category: 'V2',
              int_order: 1,
            },
          ],
        },
      }),
    })
    await fireEvent.click(container.querySelector('[data-field="ftl-weapon-head"]')!)
    const purposes = [...container.querySelectorAll('[data-field="ftl-purpose"]')].map((el) =>
      el.textContent?.trim(),
    )
    expect(purposes[purposes.length - 1]).toContain('NIE wczytuj jako zawody')
    expect(purposes.slice(0, -1).every((p) => p?.startsWith('Wczytaj jako zawody'))).toBe(true)
  })

  // -------------------------------------------------------------------------
  // The instruction
  // -------------------------------------------------------------------------

  // X9.9 — This is the deliverable. It replaced a four-word table column.
  it('renders the eight numbered steps', () => {
    const { container } = render(FtlExport, { props: props() })
    const steps = [...container.querySelectorAll('[data-field="ftl-step"]')]
    expect(steps).toHaveLength(8)
    expect(steps[1].textContent).toContain('Import Events')
    expect(steps[4].textContent).toContain('Re-Import Competitors from XML File')
    expect(steps[5].textContent).toContain('Event Competitors')
  })

  // X9.10 — An organizer who tidies "(1)" out of a name breaks how results are
  // read back, and would be doing it to be helpful. The example is invented:
  // this page is public, and the real fencers make poor placeholders.
  it('warns not to remove the category digit, using a name that is nobody', () => {
    const { getByText, queryByText } = render(FtlExport, { props: props() })
    expect(getByText(/PRZYKŁADOWSKA \(1\) Anna/)).toBeTruthy()
    expect(queryByText(/KAMIŃSKA/)).toBeNull()
  })

  // -------------------------------------------------------------------------
  // Downloading
  // -------------------------------------------------------------------------

  // X9.11 — The defect this replaced: files were built on page load, so a page
  // opened at 08:00 handed over the 08:00 entry list at 10:00 with no sign.
  it('re-reads the entry list before building the bundle', async () => {
    const onrefresh = vi.fn(async () => ({ entries: ROWS, rosters: {} }))
    const dl = stubDownloads()
    const { getByText } = render(FtlExport, { props: props({ onrefresh }) })
    await fireEvent.click(getByText('Pobierz wszystko (.zip)'))
    await waitFor(() => expect(dl.clicked).toEqual(['PPW1-2026-2027_FTL.zip']))
    expect(onrefresh).toHaveBeenCalledTimes(1)
    dl.restore()
  })

  // X9.12 — And for "re-download just the épée pools" on the morning.
  it('re-reads before a single-file download too', async () => {
    const onrefresh = vi.fn(async () => ({ entries: ROWS, rosters: {} }))
    const dl = stubDownloads()
    const { container } = render(FtlExport, { props: props({ onrefresh }) })
    await fireEvent.click(container.querySelector('[data-field="ftl-weapon-head"]')!)
    await fireEvent.click(container.querySelector('[data-field="ftl-download-one"]') as HTMLElement)
    await waitFor(() =>
      expect(dl.clicked).toEqual(['PPW1-2026-2027_EPEE_POOLS-MIXED_all-categories_W+M.xml']),
    )
    expect(onrefresh).toHaveBeenCalledTimes(1)
    dl.restore()
  })

  // -------------------------------------------------------------------------
  // States and language
  // -------------------------------------------------------------------------

  // X9.13 — An organizer who does not read Polish is not an edge case on the
  // EVF circuit. Polish stays the default.
  it('switches language from the flags, Polish first', async () => {
    const { container, getByText } = render(FtlExport, { props: props() })
    expect(getByText(/Pliki XML do pobrania/)).toBeTruthy()
    await fireEvent.click(container.querySelector('[data-field="ftl-lang-en"]')!)
    expect(getByText(/XML files to download/)).toBeTruthy()
    await fireEvent.click(container.querySelector('[data-field="ftl-lang-pl"]')!)
    expect(getByText(/Pliki XML do pobrania/)).toBeTruthy()
  })

  // X9.14 — Empty, loading and missing are all normal and none is an error.
  it('has an honest state for empty, loading and unknown', () => {
    const empty = render(FtlExport, { props: props({ entries: [] }) })
    expect(empty.getByText(/nikt się jeszcze nie zapisał/)).toBeTruthy()
    expect(empty.container.querySelector('[data-field="ftl-download-all"]')).toBeNull()

    const loading = render(FtlExport, { props: props({ loading: true, entries: [] }) })
    expect(loading.getByText('Wczytywanie listy startowej…')).toBeTruthy()

    const gone = render(FtlExport, { props: props({ notFound: true, entries: [], events: [] }) })
    expect(gone.getByText('Nie znaleziono takich zawodów.')).toBeTruthy()
  })

  // X9.15 — A missing or revoked token looks exactly like "no events", because
  // the refusal happens in Postgres and returns no rows. The line therefore has
  // to be true in both cases: "nobody has entered yet" would be an active
  // falsehood for someone holding a stale link.
  it('says something true and uninformative when there are no events at all', () => {
    const { container, getByText } = render(
      FtlExport,
      { props: props({ events: [], entries: [], selectedId: null }) },
    )
    expect(container.querySelector('[data-field="ftl-no-events"]')).not.toBeNull()
    expect(getByText(/sprawdź, czy masz aktualny link/)).toBeTruthy()
  })

  // X9.21-X9.23 — The SPWS mark. The WordPress page hides the theme's header,
  // navigation and footer (ADR-090 §7), so this is the ONLY route back to
  // weteraniszermierki.pl from the download page — required, not decorative,
  // exactly as on the calendar embed. CalendarEmbed.test.ts guards the same
  // thing for <spws-calendar>; the two assertions are deliberately parallel.
  it('X9.21 links the SPWS mark to the association site', () => {
    const { container } = render(FtlExport, { props: props() })
    const home = container.querySelector('.ftl-top a.embed-home') as HTMLAnchorElement
    expect(home).not.toBeNull()
    expect(home.getAttribute('href')).toBe('https://weteraniszermierki.pl')
    expect(home.querySelector('img.embed-logo')).not.toBeNull()
  })

  it('X9.22 labels the mark in the active language', () => {
    const { container } = render(FtlExport, { props: props() })
    const home = container.querySelector('.ftl-top a.embed-home') as HTMLAnchorElement
    expect(home.getAttribute('aria-label')).toBe('Przejdź do strony SPWS')
  })

  it('X9.23 keeps the language toggle on the row beside the mark', () => {
    // The mark is inserted as the row's first child; the toggle must not be
    // displaced by it, or an organizer who does not read Polish loses the flags.
    const { container } = render(FtlExport, { props: props() })
    const top = container.querySelector('.ftl-top')!
    expect(top.querySelector('a.embed-home')).not.toBeNull()
    expect(top.querySelector('[data-field="ftl-lang-pl"]')).not.toBeNull()
    expect(top.querySelector('[data-field="ftl-lang-en"]')).not.toBeNull()
  })
})
