// Plan tests: 6.5, 6.6, 6.8, 6.10, 6.11, 6.12, 6.15, 6.16 — DrilldownModal component.
// See doc/archive/POC_development_plan.md §M6 test table.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render } from '@testing-library/svelte'
import DrilldownModal from '../src/components/DrilldownModal.svelte'
import type { ScoreRow, DrilldownContext } from '../src/lib/types'
import { setLocale } from '../src/lib/locale.svelte'

beforeEach(() => {
  setLocale('en')
})

vi.mock('../src/lib/export', () => ({
  exportDrilldown: vi.fn(),
}))

const makeScore = (overrides: Partial<ScoreRow> = {}): ScoreRow => ({
  id_result: 1,
  id_fencer: 1,
  fencer_name: 'TEST User',
  int_birth_year: null,
  id_tournament: 10,
  txt_tournament_code: 'PPW-01',
  txt_tournament_name: 'Test PPW',
  dt_tournament: '2024-10-15',
  enum_type: 'PPW',
  enum_weapon: 'EPEE',
  enum_gender: 'M',
  enum_age_category: 'V2',
  int_participant_count: 24,
  num_multiplier: 1.0,
  int_place: 3,
  num_place_pts: 85,
  num_de_bonus: 5,
  num_podium_bonus: 1,
  num_final_score: 91,
  ts_points_calc: null,
  id_season: 1,
  txt_season_code: '2024/25',
  url_results: null,
  txt_location: null,
  ...overrides,
})

const CTX: DrilldownContext = {
  rank: 1,
  birthYear: 1969,
  age: 56,
  category: 'V2',
  totalScore: 910,
  ppwBestCount: 4,
  pewBestCount: 3,
}

describe('DrilldownModal', () => {
  // 6.5 — modal visibility
  it('is hidden when open=false', () => {
    const { container } = render(DrilldownModal, { props: { open: false } })
    expect(container.querySelector('.modal-overlay')).toBeNull()
  })

  // 6.5 — modal shows fencer identity
  it('shows fencer name when open', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'SMITH John' },
    })
    expect(container.textContent).toContain('SMITH John')
  })

  // 6.6 — drill-down per-tournament breakdown header
  it('renders subheader with rank, category, and birth year', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 500 }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'ATANASSOW Aleksander', scores, context: CTX, mode: 'PPW' },
    })
    const sub = container.querySelector('.subheader')
    expect(sub?.textContent).toContain('Rank #1')
    expect(sub?.textContent).toContain('V2')
    expect(sub?.textContent).toContain('born 1969')
    expect(sub?.textContent).not.toContain('pts')
  })

  // 6.15 — PPW drill-down: domestic only
  it('PPW mode shows only domestic tournaments', () => {
    const scores = [
      makeScore({ id_result: 1, txt_tournament_code: 'PPW-01', enum_type: 'PPW' }),
      makeScore({ id_result: 2, txt_tournament_code: 'PEW-01', enum_type: 'PEW', id_tournament: 20 }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    const rows = container.querySelectorAll('tbody tr')
    expect(rows.length).toBe(1)
    expect(rows[0].textContent).toContain('PPW-01')
  })

  // 6.16 — Kadra drill-down: domestic + international
  it('KADRA mode shows all tournaments', () => {
    const scores = [
      makeScore({ id_result: 1, txt_tournament_code: 'PPW-01', enum_type: 'PPW' }),
      makeScore({ id_result: 2, txt_tournament_code: 'PEW-01', enum_type: 'PEW', id_tournament: 20 }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'KADRA' },
    })
    const codeTexts = Array.from(container.querySelectorAll('tbody td:first-child'))
      .map((td) => td.textContent?.trim())
    expect(codeTexts).toContain('PPW-01')
    expect(codeTexts).toContain('PEW-01')
  })

  // 6.6 — score markers (best-K)
  it('marks best-K PPW scores with star', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 120 }),
      makeScore({ id_result: 2, enum_type: 'PPW', num_final_score: 100, id_tournament: 11 }),
      makeScore({ id_result: 3, enum_type: 'PPW', num_final_score: 80, id_tournament: 12 }),
      makeScore({ id_result: 4, enum_type: 'PPW', num_final_score: 60, id_tournament: 13 }),
      makeScore({ id_result: 5, enum_type: 'PPW', num_final_score: 40, id_tournament: 14 }),
    ]
    const ctx = { ...CTX, ppwBestCount: 4 }
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW', context: ctx },
    })
    const markers = container.querySelectorAll('.chart-marker')
    const starCount = Array.from(markers).filter((m) => m.textContent?.includes('★')).length
    expect(starCount).toBe(4)
  })

  // 6.6 — MPW marker
  it('shows MPW with check marker', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'MPW', num_final_score: 45, id_tournament: 20 }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW', context: CTX },
    })
    const markers = container.querySelectorAll('.chart-marker')
    const checkCount = Array.from(markers).filter((m) => m.textContent?.includes('✓')).length
    expect(checkCount).toBe(1)
  })

  // 6.6 — domestic total in chart heading
  it('shows domestic total in chart heading', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 120 }),
      makeScore({ id_result: 2, enum_type: 'PPW', num_final_score: 100, id_tournament: 11 }),
      makeScore({ id_result: 3, enum_type: 'MPW', num_final_score: 45, id_tournament: 12 }),
    ]
    const ctx = { ...CTX, ppwBestCount: 4 }
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW', context: ctx },
    })
    const h4 = container.querySelector('.breakdown-col h4')
    expect(h4?.textContent).toContain('265')
  })

  // 6.6 — Kadra grand total in table-total
  it('KADRA mode shows grand total in table-total', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'MPW', num_final_score: 45, id_tournament: 20 }),
      makeScore({ id_result: 3, enum_type: 'PEW', num_final_score: 80, id_tournament: 30 }),
      makeScore({ id_result: 4, enum_type: 'MEW', num_final_score: 60, id_tournament: 40 }),
    ]
    const ctx = { ...CTX, ppwBestCount: 4, pewBestCount: 3 }
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'KADRA', context: ctx },
    })
    const tableTotal = container.querySelector('.table-total')
    expect(tableTotal?.textContent).toContain('285')
  })

  // 6.12 — V0 disables +EVF in drill-down
  it('disables +EVF toggle when kadraDisabled is true', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', kadraDisabled: true, showEvfToggle: true, context: CTX },
    })
    const btns = container.querySelectorAll('.toggle-btn')
    // [0]=🇬🇧, [1]=🇵🇱 (LangToggle in modal-actions), [2]=PPW, [3]=+EVF (toggle in subheader)
    const kadraBtn = btns[3] as HTMLButtonElement
    expect(kadraBtn.disabled).toBe(true)
  })

  // 6.8 — skeleton/loading indicator
  it('shows loading state', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', loading: true },
    })
    expect(container.textContent).toContain('Loading')
  })

  // 6.6 — tournament code linked
  it('tournament code link opens in new tab and does not point to a CSV download URL', () => {
    const scores = [
      makeScore({
        id_result: 1,
        enum_type: 'PPW',
        txt_tournament_code: 'PP2-V2-M-EPEE-2025-2026',
        url_results: 'https://www.fencingtimelive.com/events/results/0387CC20A25B4EBA9BDAFAB148E8C12B',
        num_final_score: 100,
      }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    const link = container.querySelector('tbody a') as HTMLAnchorElement
    expect(link).not.toBeNull()
    expect(link.target).toBe('_blank')
    expect(link.href).not.toContain('/download/')
    expect(link.href).toMatch(/^https?:\/\//)
  })

  // ── Comprehensive UI coverage ──────────────────────────────────────────────

  // 6.6 — season code in subheader
  it('A — subheader shows season code from scores', () => {
    const scores = [makeScore({ txt_season_code: '2024/25' })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, context: CTX, mode: 'PPW' },
    })
    expect(container.querySelector('.subheader')?.textContent).toContain('2024/25')
  })

  // 6.5 — subheader absent when no data
  it('B — subheader hidden when context is null and scores empty', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores: [], context: null },
    })
    expect(container.querySelector('.subheader')).toBeNull()
  })

  // 6.10 — PPW total label
  it('C — table-total shows PPW Total label in PPW mode', () => {
    const scores = [makeScore({ enum_type: 'PPW', num_final_score: 100 })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, context: CTX, mode: 'PPW' },
    })
    expect(container.querySelector('.table-total')?.textContent).toContain('PPW Total')
  })

  // 6.11 — +EVF total label
  it('D — table-total shows +EVF Total label in KADRA mode', () => {
    const scores = [makeScore({ enum_type: 'PPW', num_final_score: 100 })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, context: CTX, mode: 'KADRA' },
    })
    expect(container.querySelector('.table-total')?.textContent).toContain('+EVF Total')
  })

  // 6.6 — breakdown section heading
  it('E — Points Breakdown heading present when scores exist', () => {
    const scores = [makeScore({ enum_type: 'PPW', num_final_score: 100 })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    const h3 = Array.from(container.querySelectorAll('.breakdown-section h3'))
    expect(h3.some((el) => el.textContent?.includes('Points Breakdown'))).toBe(true)
  })

  // 6.15 — domestic column heading
  it('F — domestic column heading contains Domestic', () => {
    const scores = [makeScore({ enum_type: 'PPW', num_final_score: 100 })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    const h4 = container.querySelector('.breakdown-col h4')
    expect(h4?.textContent).toContain('Domestic')
  })

  // 6.16 — international column in Kadra only
  it('G — international column only visible in KADRA mode', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'PEW', num_final_score: 80, id_tournament: 20 }),
    ]
    const { container: cPpw } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    expect(cPpw.querySelectorAll('.breakdown-col').length).toBe(1)

    const { container: cKadra } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'KADRA' },
    })
    expect(cKadra.querySelectorAll('.breakdown-col').length).toBe(2)
  })

  // 6.6 — tournament type legend
  it('H — all 5 tournament type abbreviations present in legend', () => {
    const scores = [makeScore({ enum_type: 'PPW', num_final_score: 100 })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    const legend = container.querySelector('.type-legend')
    for (const abbr of ['PPW', 'MPW', 'PEW', 'MEW', 'MSW']) {
      expect(legend?.textContent).toContain(abbr)
    }
  })

  // 6.6 — breakdown table headers
  it('I — table headers present', () => {
    const scores = [makeScore({ enum_type: 'PPW', num_final_score: 100 })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    const headers = Array.from(container.querySelectorAll('th')).map((th) => th.textContent?.trim())
    for (const label of ['Tournament', 'Date', 'Type', 'Place', 'Mult', 'Points']) {
      expect(headers).toContain(label)
    }
  })

  // 6.6 — footer definitions
  it('J — footer contains N and Mult definitions', () => {
    const scores = [makeScore({ enum_type: 'PPW', num_final_score: 100 })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    const footer = container.querySelector('.modal-footer')
    expect(footer?.textContent).toContain('N —')
    expect(footer?.textContent).toContain('Mult —')
  })

  // No plan ID — i18n (added post-plan)
  it('K — LangToggle flag buttons present in modal', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test' },
    })
    const text = container.textContent ?? ''
    expect(text).toContain('🇬🇧')
    expect(text).toContain('🇵🇱')
  })

  // 6.10 — toggle placement
  it('L — PPW/Kadra toggle is in subheader (second row), LangToggle is in modal-actions (top row)', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', showEvfToggle: true, context: CTX },
    })
    const subheader = container.querySelector('.subheader')
    const actions = container.querySelector('.modal-actions')
    // LangToggle root also carries class="toggle", so use :not(.lang-toggle) to target PPW/Kadra toggle
    expect(subheader?.querySelector('.toggle:not(.lang-toggle)')).not.toBeNull()
    expect(actions?.querySelector('.toggle:not(.lang-toggle)')).toBeNull()
    expect(actions?.textContent).toContain('🇬🇧')
  })

  // 6.5 — close button
  it('M — close button present', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test' },
    })
    expect(container.querySelector('.btn-close')).not.toBeNull()
  })

  // R.19 — carried-over table rows have .carried-row class
  it('R.19: carried-over rows get .carried-row class', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100, bool_carried_over: false }),
      makeScore({ id_result: 2, enum_type: 'PPW', num_final_score: 80, id_tournament: 11, bool_carried_over: true, txt_source_season_code: '2024/25' }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW', context: CTX },
    })
    const carriedRows = container.querySelectorAll('tbody tr.carried-row')
    expect(carriedRows.length).toBe(1)
  })

  // R.20 — carried-over chart items have ↩ marker
  it('R.20: carried-over chart items show ↩ marker', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100, bool_carried_over: false }),
      makeScore({ id_result: 2, enum_type: 'PPW', num_final_score: 80, id_tournament: 11, bool_carried_over: true, txt_source_season_code: '2024/25' }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW', context: CTX },
    })
    const markers = Array.from(container.querySelectorAll('.chart-marker')).map(m => m.textContent)
    expect(markers.some(m => m?.includes('↩'))).toBe(true)
  })

  // R.21 — rolling info banner visible when any bool_carried_over=true
  it('R.21: rolling info banner shows when carried-over scores present', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100, bool_carried_over: false }),
      makeScore({ id_result: 2, enum_type: 'PPW', num_final_score: 80, id_tournament: 11, bool_carried_over: true, txt_source_season_code: '2024/25' }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW', context: CTX },
    })
    expect(container.querySelector('.rolling-info')).not.toBeNull()
  })

  // R.22 — non-carried scores render normally (regression)
  it('R.22: non-carried scores render without carried-row class', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100, bool_carried_over: false }),
      makeScore({ id_result: 2, enum_type: 'MPW', num_final_score: 45, id_tournament: 20, bool_carried_over: false }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW', context: CTX },
    })
    const carriedRows = container.querySelectorAll('tbody tr.carried-row')
    expect(carriedRows.length).toBe(0)
    expect(container.querySelector('.rolling-info')).toBeNull()
  })
})

// ── Card layout (mobile responsive view) ─────────────────────────────────────
// These verify the card-list elements that replace tables on mobile (<= 600px).
// Both table and cards are always in the DOM; CSS media queries control visibility.

describe('DrilldownModal — Card layout', () => {
  // C.1 — card container exists
  it('C.1: renders .card-list when domestic scores are present', () => {
    const scores = [makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    expect(container.querySelector('.card-list')).not.toBeNull()
  })

  // C.2 — correct card count
  it('C.2: renders one .result-card per domestic score', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'PPW', num_final_score: 80, id_tournament: 11 }),
      makeScore({ id_result: 3, enum_type: 'MPW', num_final_score: 45, id_tournament: 12 }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    const cards = container.querySelectorAll('.card-list .result-card')
    expect(cards.length).toBe(3)
  })

  // C.3 — tournament code text
  it('C.3: card shows tournament code text', () => {
    const scores = [makeScore({ txt_tournament_code: 'PPW-07' })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    expect(container.querySelector('.card-tournament')?.textContent).toContain('PPW-07')
  })

  // C.4 — tournament code as link
  it('C.4: card shows tournament code as link when url_results exists', () => {
    const scores = [makeScore({
      txt_tournament_code: 'PPW-07',
      url_results: 'https://example.com/results',
    })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    const link = container.querySelector('.card-tournament a') as HTMLAnchorElement
    expect(link).not.toBeNull()
    expect(link.target).toBe('_blank')
    expect(link.href).toContain('example.com')
  })

  // C.5 — location
  it('C.5: card shows location when txt_location is present', () => {
    const scores = [makeScore({ txt_location: 'Gdańsk' })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    expect(container.querySelector('.card-location')?.textContent).toBe('Gdańsk')
  })

  // C.6 — formatted date
  it('C.6: card shows formatted date', () => {
    const scores = [makeScore({ dt_tournament: '2025-02-21' })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    const dateEl = container.querySelector('.card-date')
    expect(dateEl?.textContent).toMatch(/21.*Feb.*25/)
  })

  // C.7 — type badge domestic
  it('C.7: card shows type badge with .domestic class for PPW', () => {
    const scores = [makeScore({ enum_type: 'PPW' })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    const badge = container.querySelector('.result-card .type-badge')
    expect(badge?.classList.contains('domestic')).toBe(true)
    expect(badge?.textContent).toBe('PPW')
  })

  // C.8 — type badge international
  it('C.8: card shows type badge with .international class for PEW', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'PEW', num_final_score: 80, id_tournament: 20 }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'KADRA' },
    })
    const badges = container.querySelectorAll('.result-card .type-badge')
    const intlBadge = Array.from(badges).find((b) => b.textContent === 'PEW')
    expect(intlBadge?.classList.contains('international')).toBe(true)
  })

  // C.9 — place and participant count
  it('C.9: card shows place/N', () => {
    const scores = [makeScore({ int_place: 3, int_participant_count: 24 })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    expect(container.querySelector('.card-place')?.textContent).toBe('3/24')
  })

  // C.10 — multiplier
  it('C.10: card shows multiplier', () => {
    const scores = [makeScore({ num_multiplier: 1.2 })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    expect(container.querySelector('.card-mult')?.textContent).toContain('1.2')
  })

  // C.11 — points and marker
  it('C.11: card shows points and star marker for best-K', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 120 }),
    ]
    const ctx = { ...CTX, ppwBestCount: 4 }
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW', context: ctx },
    })
    const pts = container.querySelector('.card-points')
    expect(pts?.textContent).toContain('120')
    expect(pts?.textContent).toContain('★')
  })

  // C.12 — carried class on card
  it('C.12: card has .carried class when bool_carried_over', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100, bool_carried_over: true, txt_source_season_code: '2023/24' }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW', context: CTX },
    })
    expect(container.querySelector('.result-card.carried')).not.toBeNull()
  })

  // C.13 — carried badge
  it('C.13: card shows carried badge with source season code', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100, bool_carried_over: true, txt_source_season_code: '2023/24' }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW', context: CTX },
    })
    const badge = container.querySelector('.card-carried-badge')
    expect(badge?.textContent).toContain('↩')
    expect(badge?.textContent).toContain('2023/24')
  })

  // C.14 — KADRA renders 2 card-lists, PPW renders 1
  it('C.14: KADRA mode renders 2 card-lists, PPW mode renders 1', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'PEW', num_final_score: 80, id_tournament: 20 }),
    ]
    const { container: cKadra } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'KADRA' },
    })
    expect(cKadra.querySelectorAll('.card-list').length).toBe(2)

    const { container: cPpw } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    expect(cPpw.querySelectorAll('.card-list').length).toBe(1)
  })
})
