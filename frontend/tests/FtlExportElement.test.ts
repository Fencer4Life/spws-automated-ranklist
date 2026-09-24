// FtlExportElement — the custom-element wrapper for the FTL export page.
// Plan IDs X9.15-X9.20.
//
// The element owns everything the component deliberately does not: the
// capability token, the event list, which event is selected, and the re-read
// that happens on every download. Rendered here as a plain component rather
// than through customElements — the registration path is the one four existing
// embeds already use, and what is worth pinning is the new wiring.

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { render, waitFor } from '@testing-library/svelte'
import FtlExportElement from '../src/ce/FtlExportElement.svelte'
import { getLocale, setLocale } from '../src/lib/locale.svelte'
import { getAssetBase, setAssetBase } from '../src/lib/assetBase'
import * as api from '../src/lib/api'

const EVENTS = [
  {
    id_event: 85,
    txt_code: 'PEW5efs-2026-2027',
    txt_name: 'EVF Circuit – Łomianki (POL)',
    txt_location: 'Łomianki',
    dt_start: '2026-12-12',
    int_registrations: 14,
  },
  {
    id_event: 74,
    txt_code: 'PPW1-2026-2027',
    txt_name: 'I Puchar Polski Weteranów w Szermierce',
    txt_location: 'Opole',
    dt_start: '2026-09-26',
    int_registrations: 43,
  },
]

const ENTRIES = [
  {
    txt_surname: 'Kowalski',
    txt_first_name: 'Jan',
    enum_gender: 'M',
    enum_age_category: 'V2',
    enum_weapon: 'EPEE',
    int_order: 1,
    int_rank: 1,
  },
]

describe('FtlExportElement', () => {
  beforeEach(() => {
    setLocale('pl')
    vi.spyOn(api, 'initClient').mockReturnValue({} as never)
    vi.spyOn(api, 'fetchFtlExportEvents').mockResolvedValue(EVENTS)
    vi.spyOn(api, 'fetchFtlExportEntries').mockResolvedValue(ENTRIES)
    vi.spyOn(api, 'fetchFtlRoster').mockResolvedValue([])
  })
  afterEach(() => {
    vi.restoreAllMocks()
    setLocale('pl')
    // assetBase is a module-level singleton (see assetBase.ts on why), so a
    // base set by one case would otherwise leak into the next.
    setAssetBase('')
  })

  const base = {
    'supabase-cert-url': 'http://localhost:54321',
    'supabase-cert-key': 'anon-key',
  }

  // X9.15 — Without a token there is nothing to show, and that is the whole
  // point: the check is in Postgres, so the page simply receives nothing.
  it('asks for nothing at all when the link carries no token', async () => {
    render(FtlExportElement, { props: { ...base } })
    await waitFor(() => expect(api.fetchFtlExportEvents).not.toHaveBeenCalled())
  })

  // X9.16 — The link is /pliki-startowe/?k=<uuid>.
  it('passes the token from the token attribute to every call', async () => {
    render(FtlExportElement, { props: { ...base, token: 'tok-1' } })
    await waitFor(() => expect(api.fetchFtlExportEvents).toHaveBeenCalledWith('tok-1'))
    await waitFor(() =>
      expect(api.fetchFtlExportEntries).toHaveBeenCalledWith(74, 'tok-1'),
    )
  })

  // X9.17 — Nobody sends a link per event any more, so something has to choose.
  // The soonest event is the one an organizer is most likely to want, and the
  // list arrives ordered by date already.
  it('selects the soonest event when the link names none', async () => {
    const { container } = render(FtlExportElement, { props: { ...base, token: 'tok-1' } })
    await waitFor(() =>
      expect(container.querySelector('[data-field="ftl-event-line"]')?.textContent).toContain(
        'PPW1-2026-2027',
      ),
    )
  })

  // X9.18 — A deep link to one event still works; it just no longer traps you
  // on that event.
  it('honours an event attribute when the link names one', async () => {
    const { container } = render(FtlExportElement, {
      props: { ...base, token: 'tok-1', event: 'PEW5efs-2026-2027' },
    })
    await waitFor(() =>
      expect(container.querySelector('[data-field="ftl-event-line"]')?.textContent).toContain(
        'ŁOMIANKI',
      ),
    )
  })

  // X9.19 — One roster call per weapon that actually has entrants. A pick-list
  // for a weapon nobody is fencing is one more file to import by mistake.
  it('fetches a roster only for the weapons that have entrants', async () => {
    render(FtlExportElement, { props: { ...base, token: 'tok-1' } })
    await waitFor(() => expect(api.fetchFtlRoster).toHaveBeenCalledWith(74, 'EPEE', 'tok-1'))
    expect(api.fetchFtlRoster).toHaveBeenCalledTimes(1)
  })

  // X9.20 — Language. Polish is the default and stays it; a regional tag works;
  // a language we have no keys for is left alone rather than rendering key names.
  it('takes its initial language from the lang attribute', async () => {
    render(FtlExportElement, { props: { ...base, demo: true, lang: 'en-GB' } })
    expect(getLocale()).toBe('en')
  })

  it('ignores a language we do not carry, and defaults to Polish', async () => {
    render(FtlExportElement, { props: { ...base, demo: true, lang: 'hu' } })
    expect(getLocale()).toBe('pl')
  })

  // X9.21-X9.22 — asset-base. The WordPress page already passes this attribute,
  // but the element never declared it, so the base stayed empty and the embed's
  // SPWS mark resolved against weteraniszermierki.pl instead of the Pages
  // origin — a 404 on the one link back to the site. Found 2026-09-16.
  it('X9.21 resolves embed assets through asset-base when the host page sets one', async () => {
    render(FtlExportElement, {
      props: { ...base, demo: true, 'asset-base': 'https://spws.github.io/ranklist/' },
    })
    expect(getAssetBase()).toBe('https://spws.github.io/ranklist/')
  })

  it('X9.22 leaves bare asset names alone when no base is given', async () => {
    // register.html serves the same element from the Pages origin root, where a
    // bare name already resolves; setting a base there would be wrong.
    render(FtlExportElement, { props: { ...base, demo: true } })
    expect(getAssetBase()).toBe('')
  })
})
