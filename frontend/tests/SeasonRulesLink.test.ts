// SR.LINK — the „Reguły rankingu na sezon …” pill pinned to the bottom of the
// screen (doc/mockups/ranking-rules-modal-2026-10-01.html, revision 2, approved
// 2026-10-01). The pill names the season chosen in the dropdown, follows it,
// and opens that season's rules; a season without stored rules has no pill.
// The birth-year strip under the filters stays exactly as it was.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import { tick } from 'svelte'
import { setLocale } from '../src/lib/locale.svelte'

const { SEASONS, RULES } = vi.hoisted(() => ({
  SEASONS: [
    { id_season: 4, txt_code: 'SPWS-2026-2027', dt_start: '2026-07-13', dt_end: '2027-07-15', bool_active: true, enum_ranking_publication: 'FULL' },
    { id_season: 3, txt_code: 'SPWS-2025-2026', dt_start: '2025-08-01', dt_end: '2026-07-11', bool_active: false, enum_ranking_publication: 'PPW_ONLY' },
    { id_season: 1, txt_code: 'SPWS-2023-2024', dt_start: '2023-01-01', dt_end: '2024-07-15', bool_active: false, enum_ranking_publication: 'PPW_ONLY' },
  ],
  RULES: {
    4: { domestic: [{ best: 2, types: ['PPW'] }, { types: ['MPW'], always: true }], entry_types: ['PPW', 'MPW'],
         international: [{ best: 5, types: ['PEW', 'MEW', 'MSW', 'PSW', 'PPS', 'MPS'] }] },
    3: { domestic: [{ best: 4, types: ['PPW'] }, { types: ['MPW'], always: true }],
         international: [{ best: 4, types: ['PPW'] }, { types: ['MPW'], always: true }, { best: 3, types: ['PEW', 'MEW', 'MSW'] }] },
    1: null,
  } as Record<number, unknown>,
}))

vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  refreshActiveSeason: vi.fn().mockResolvedValue(undefined),
  fetchSeasons: vi.fn().mockResolvedValue(SEASONS),
  fetchScoringEngines: vi.fn().mockResolvedValue([]),
  fetchRankingPpw: vi.fn().mockResolvedValue([]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  fetchRankingFull: vi.fn().mockResolvedValue([]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchFencerScoresRolling: vi.fn().mockResolvedValue([]),
  fetchRankingRules: vi.fn((id: number) => Promise.resolve(RULES[id] ?? null)),
  fetchSeasonCoefficients: vi.fn().mockResolvedValue({ PPW: 1, MPW: 1.2, PEW: 1, MEW: 1.3, MSW: 1.4, PSW: 1.1, PPS: 1.1, MPS: 1.3 }),
  fetchScoringConfig: vi.fn().mockResolvedValue(null),
  fetchCalendarEvents: vi.fn().mockResolvedValue([]),
  fetchAllCalendarEvents: vi.fn().mockResolvedValue([]),
}))
vi.mock('../src/lib/admin-auth.svelte', () => import('./helpers/fakeAdminAuth.svelte'))

import App from '../src/App.svelte'
import { fetchSeasonCoefficients } from '../src/lib/api'

const text = (el: Element | null) => (el?.textContent ?? '').replace(/\s+/g, ' ').trim()

async function renderApp() {
  const view = render(App, { props: { 'supabase-cert-url': 'https://cert.supabase.co', 'supabase-cert-key': 'cert-key-123' } })
  await vi.waitFor(() => expect(view.container.querySelector('.category-subtitle')).not.toBeNull())
  return view
}
async function chooseSeason(container: HTMLElement, id: number) {
  await fireEvent.change(container.querySelector('.season-select')!, { target: { value: String(id) } })
  await tick()
}

describe('SR.LINK — the chosen season\'s rules, one click from the list', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setLocale('pl')
  })

  it('SR.LINK.01 the strip is unchanged; the pill named after the chosen season sits outside it', async () => {
    const { container } = await renderApp()
    await vi.waitFor(() => expect(container.querySelector('.rules-float')).not.toBeNull())
    const strip = container.querySelector('.category-subtitle')!
    expect(text(strip)).toBe('kat. 1 — roczniki: 1987, 1986, .. 1978')
    expect(strip.querySelector('button')).toBeNull()
    const pill = container.querySelector('.rules-float')!
    expect(strip.contains(pill)).toBe(false)
    expect(pill.classList.contains('rules-link')).toBe(true)
    expect(text(pill)).toBe('Reguły rankingu na sezon 2026/2027')
  })

  it('SR.LINK.02 the link follows the season dropdown', async () => {
    const { container } = await renderApp()
    await vi.waitFor(() => expect(container.querySelector('.rules-link')).not.toBeNull())
    await chooseSeason(container, 3)
    await vi.waitFor(() => expect(text(container.querySelector('.rules-link'))).toBe('Reguły rankingu na sezon 2025/2026'))
  })

  it('SR.LINK.03 a season with no stored rules has no link, and the birth years stay', async () => {
    const { container } = await renderApp()
    await vi.waitFor(() => expect(container.querySelector('.rules-link')).not.toBeNull())
    await chooseSeason(container, 1)
    await vi.waitFor(() => expect(container.querySelector('.rules-link')).toBeNull())
    expect(text(container.querySelector('.category-subtitle'))).toContain('roczniki')
  })

  it('SR.LINK.04 the link opens the chosen season\'s rules with that season\'s coefficients', async () => {
    const { container } = await renderApp()
    await chooseSeason(container, 3)
    await vi.waitFor(() => expect(text(container.querySelector('.rules-link'))).toBe('Reguły rankingu na sezon 2025/2026'))
    await fireEvent.click(container.querySelector('.rules-link')!)
    await vi.waitFor(() => expect(container.querySelector('.rules-overlay')).not.toBeNull())
    expect(text(container.querySelector('.rules-title'))).toBe('Reguły rankingu na sezon 2025/2026')
    expect(container.querySelectorAll('.pool').length).toBe(1)
    expect(fetchSeasonCoefficients).toHaveBeenCalledWith('SPWS-2025-2026')
    await vi.waitFor(() => expect(container.querySelectorAll('.coef').length).toBe(2))
  })

  it('SR.LINK.05 closing returns to the list unchanged', async () => {
    const { container } = await renderApp()
    await vi.waitFor(() => expect(container.querySelector('.rules-link')).not.toBeNull())
    await fireEvent.click(container.querySelector('.rules-link')!)
    await vi.waitFor(() => expect(container.querySelector('.rules-overlay')).not.toBeNull())
    await fireEvent.click(container.querySelector('.rules-close')!)
    await vi.waitFor(() => expect(container.querySelector('.rules-overlay')).toBeNull())
    expect(container.querySelector('.filter-bar')).not.toBeNull()
    expect(text(container.querySelector('.rules-link'))).toBe('Reguły rankingu na sezon 2026/2027')
  })

  it('SR.LINK.06 the list ends with room for the pill while it shows, and not without it', async () => {
    const { container } = await renderApp()
    await vi.waitFor(() => expect(container.querySelector('.rules-float')).not.toBeNull())
    expect(container.querySelector('.rules-float-space')?.getAttribute('aria-hidden')).toBe('true')
    await chooseSeason(container, 1)
    await vi.waitFor(() => expect(container.querySelector('.rules-float')).toBeNull())
    expect(container.querySelector('.rules-float-space')).toBeNull()
  })
})
