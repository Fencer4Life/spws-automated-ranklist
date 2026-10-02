// Plan tests: 6.5, 6.6, 6.8, 6.10, 6.11, 6.12, 6.15, 6.16 — DrilldownModal component.
// See doc/archive/POC_development_plan.md §M6 test table.
// SS26.UI (design step 7, ADR-101): mode renamed KADRA -> RANKING; toggle
// labels renamed SPWS/EVF+ -> PPW/Ranking; the blue domestic section is now
// headed "SPWS" and the combined section "EVF+"; kadraDisabled prop removed
// (V0 no longer disables Ranking); the compact summary shows PPW/EVF+/Total
// together in Ranking mode; EVF/FIE and PZSz result bars are colored
// separately (no new subtotal).

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import DrilldownModal from '../src/components/DrilldownModal.svelte'
import type { ScoreRow, DrilldownContext, RankingRules } from '../src/lib/types'
import { setLocale } from '../src/lib/locale.svelte'
import { exportDrilldown } from '../src/lib/export'
import { isDomestic, isInternational } from '../src/lib/drilldown-counting'

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
  txt_tournament_name: 'V2 M EPEE',
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
    // UX proposal A: the rank moved into the headline; the line under the
    // name keeps category, season and birth year.
    const sub = container.querySelector('.subheader')
    expect(sub?.textContent).toContain('V2')
    expect(sub?.textContent).toContain('born 1969')
    expect(sub?.textContent).not.toContain('pts')
    expect(container.querySelector('.score-rank')?.textContent?.trim()).toBe('1')
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

  // SS26.UI: Ranking mode shows domestic + international (renamed from KADRA)
  it('RANKING mode shows all tournaments', () => {
    const scores = [
      makeScore({ id_result: 1, txt_tournament_code: 'PPW-01', enum_type: 'PPW' }),
      makeScore({ id_result: 2, txt_tournament_code: 'PEW-01', enum_type: 'PEW', id_tournament: 20 }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'RANKING' },
    })
    const codeTexts = Array.from(container.querySelectorAll('tbody td:first-child'))
      .map((td) => td.textContent?.trim())
    expect(codeTexts).toContain('PPW-01')
    expect(codeTexts).toContain('PEW-01')
  })

  // SS26.UI: a PZSz result also appears in Ranking mode's international column
  it('RANKING mode includes PZSz results alongside EVF/FIE ones', () => {
    const scores = [
      makeScore({ id_result: 1, txt_tournament_code: 'PPW-01', enum_type: 'PPW' }),
      makeScore({ id_result: 2, txt_tournament_code: 'PPS-01', enum_type: 'PPS', id_tournament: 30, num_final_score: 40 }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'RANKING' },
    })
    const codeTexts = Array.from(container.querySelectorAll('tbody td:first-child'))
      .map((td) => td.textContent?.trim())
    expect(codeTexts).toContain('PPS-01')
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

  // 6.6 — MPW marker. DD.STAR.01: the MPW counts, so it shows ★ like every
  // counted result; ✓ is gone.
  it('shows MPW with the star marker, never a check', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'MPW', num_final_score: 45, id_tournament: 20 }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW', context: CTX },
    })
    const markers = container.querySelectorAll('.chart-marker')
    const mpwMarker = Array.from(container.querySelectorAll('.chart-row'))
      .find((r) => r.querySelector('.chart-value')?.textContent?.trim() === '45')
      ?.querySelector('.chart-marker')
    expect(mpwMarker?.textContent).toContain('★')
    expect(Array.from(markers).some((m) => m.textContent?.includes('✓'))).toBe(false)
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

  // UX.DD.02 (proposal A): the line of sums under the charts is gone. The
  // total is said once, in the headline; SPWS and EVF+ stay in the chart
  // headings only. (Replaces the SS26.UI "PPW/EVF+/Total together" line.)
  it('UX.DD.02 — no totals line: the headline has the total, the chart headings the parts', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'MPW', num_final_score: 45, id_tournament: 20 }),
      makeScore({ id_result: 3, enum_type: 'PEW', num_final_score: 80, id_tournament: 30 }),
      makeScore({ id_result: 4, enum_type: 'MEW', num_final_score: 60, id_tournament: 40 }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'RANKING' },
    })
    expect(container.querySelector('.table-total')).toBeNull()
    expect(container.textContent).not.toContain('SPWS Total')
    expect(container.textContent).not.toContain('EVF+ Total')
    const headings = Array.from(container.querySelectorAll('.breakdown-col h4')).map((h) => h.textContent)
    expect(headings[0]).toContain('145') // SPWS: 100 + 45
    expect(headings[1]).toContain('140') // EVF+: 80 + 60
    expect(container.querySelector('.score-total')?.textContent?.trim()).toBe('285')
  })

  // SS26.UI: the scope toggle reads Ranking / PPW (design step 7, ADR-101),
  // Ranking first (UX proposal A).
  it('SS26.UI: the scope toggle reads Ranking | PPW', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', showEvfToggle: true, context: CTX },
    })
    const btns = [...container.querySelectorAll('.headline-row .toggle-btn')].map((b) => b.textContent!.trim())
    expect(btns).toEqual(['Ranking', 'PPW'])
  })

  // SS26.UI: V0 no longer disables Ranking in the drill-down (kadraDisabled
  // prop removed — this test replaces "disables +EVF toggle when
  // kadraDisabled is true").
  it('SS26.UI: the Ranking toggle button is never disabled', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', showEvfToggle: true, context: CTX },
    })
    const rankingBtn = Array.from(container.querySelectorAll<HTMLButtonElement>('.headline-row .toggle-btn'))
      .find((b) => b.textContent?.trim() === 'Ranking')!
    expect(rankingBtn.disabled).toBe(false)
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

  // R.26–R.29 (FR-66) — on a rolling ranking fn_fencer_scores_rolling returns
  // the carried previous-season rows first, each carrying ITS OWN season in
  // txt_season_code. The header must name the season being ranked.
  const carried = (id: number, code = 'SPWS-2025-2026') =>
    makeScore({ id_result: id, txt_season_code: code, bool_carried_over: true, txt_source_season_code: code })
  const current = (id: number) => makeScore({ id_result: id, txt_season_code: 'SPWS-2026-2027', bool_carried_over: false })

  it('R.26 — the header names the ranked season it was opened for, not a carried row\'s season', () => {
    const scores = [carried(1), carried(2), current(3)]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, context: CTX, mode: 'PPW', seasonCode: 'SPWS-2026-2027' },
    })
    const sub = container.querySelector('.subheader')?.textContent ?? ''
    expect(sub).toContain('SPWS-2026-2027')
    expect(sub).not.toContain('SPWS-2025-2026')
  })

  it('R.27 — without a ranked season, the header takes the first row that is not carried over', () => {
    const scores = [carried(1), current(2)]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, context: CTX, mode: 'PPW' },
    })
    const sub = container.querySelector('.subheader')?.textContent ?? ''
    expect(sub).toContain('SPWS-2026-2027')
    expect(sub).not.toContain('SPWS-2025-2026')
  })

  it('R.28 — with only carried rows and no ranked season, the header names no season rather than a wrong one', () => {
    const scores = [carried(1), carried(2)]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, context: CTX, mode: 'PPW' },
    })
    const sub = container.querySelector('.subheader')?.textContent ?? ''
    expect(sub).toContain('V2')
    expect(sub).not.toContain('SPWS-2025-2026')
  })

  it('R.29 — the ranked season is named even when every row is carried over', () => {
    const scores = [carried(1), carried(2)]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, context: CTX, mode: 'PPW', seasonCode: 'SPWS-2026-2027' },
    })
    const sub = container.querySelector('.subheader')?.textContent ?? ''
    expect(sub).toContain('SPWS-2026-2027')
    expect(sub).not.toContain('SPWS-2025-2026')
  })

  // 6.5 — subheader absent when no data
  it('B — subheader hidden when context is null and scores empty', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores: [], context: null },
    })
    expect(container.querySelector('.subheader')).toBeNull()
  })

  // 6.10 — the PPW view's total. UX proposal A: one headline figure,
  // labelled "pts total", in both views (replaces the "Total:" /
  // "EVF+ Total" lines under the charts).
  it('C — the headline carries the total, labelled pts total, in the PPW view', () => {
    const scores = [makeScore({ enum_type: 'PPW', num_final_score: 100 })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    expect(container.querySelector('.score-total')?.textContent?.trim()).toBe('100')
    expect(container.querySelector('.score-fig.big .score-lab')?.textContent?.trim()).toBe('pts total')
    expect(container.querySelector('.table-total')).toBeNull()
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

  // SS26.UI: the blue domestic section is headed "SPWS" (renamed from
  // "Domestic (PPW + MPW)" — design §06: "exactly two top-level sections:
  // blue SPWS and EVF+").
  it('F — domestic column heading contains SPWS', () => {
    const scores = [makeScore({ enum_type: 'PPW', num_final_score: 100 })]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    const h4 = container.querySelector('.breakdown-col h4')
    expect(h4?.textContent).toContain('SPWS')
  })

  // SS26.UI: international column only visible in RANKING mode (renamed from KADRA)
  it('G — international column only visible in RANKING mode', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'PEW', num_final_score: 80, id_tournament: 20 }),
    ]
    const { container: cPpw } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    expect(cPpw.querySelectorAll('.breakdown-col').length).toBe(1)

    const { container: cRanking } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'RANKING' },
    })
    expect(cRanking.querySelectorAll('.breakdown-col').length).toBe(2)
  })

  // SS26.UI: the international column heading is "EVF+" (renamed from
  // "International (EVF)")
  it('G2 — international column heading contains EVF+', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'PEW', num_final_score: 80, id_tournament: 20 }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'RANKING' },
    })
    const headings = Array.from(container.querySelectorAll('.breakdown-col h4')).map((h) => h.textContent)
    expect(headings.some((h) => h?.includes('EVF+'))).toBe(true)
  })

  // SS26.UI: an EVF/FIE result bar renders orange, a PZSz result bar renders
  // red, and both feed the one EVF+ total with no separate subtotal.
  it('G3 — EVF/FIE bars are orange and PZSz bars are red inside the one EVF+ chart', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'PEW', num_final_score: 80, id_tournament: 20 }),
      makeScore({ id_result: 3, enum_type: 'PPS', num_final_score: 40, id_tournament: 30 }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'RANKING' },
    })
    const intlCol = container.querySelectorAll('.breakdown-col')[1]
    const evfBars = intlCol.querySelectorAll('.chart-bar-evf')
    const pzszBars = intlCol.querySelectorAll('.chart-bar-pzsz')
    expect(evfBars.length).toBe(1)
    expect(pzszBars.length).toBe(1)
    // Only one EVF+ subtotal heading exists — no per-color subtotal.
    expect(intlCol.querySelectorAll('h4').length).toBe(1)
  })

  // SS26.UI: the EVF/PZSz provenance legend appears only when a PZSz result
  // is actually present.
  it('G4 — provenance legend appears only when a PZSz result is present', () => {
    const scoresNoPzsz = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'PEW', num_final_score: 80, id_tournament: 20 }),
    ]
    const { container: cNoPzsz } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores: scoresNoPzsz, mode: 'RANKING' },
    })
    expect(cNoPzsz.textContent).not.toContain('PZSz')

    const scoresWithPzsz = [...scoresNoPzsz, makeScore({ id_result: 3, enum_type: 'PPS', num_final_score: 40, id_tournament: 30 })]
    const { container: cWithPzsz } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores: scoresWithPzsz, mode: 'RANKING' },
    })
    expect(cWithPzsz.textContent).toContain('PZSz')
  })

  // 6.6 — tournament type legend. DD.TYPES.01 (A5): it explains the types
  // on screen, PSW/PPS/MPS included, and nothing else.
  it('H — the type legend lists exactly the types shown', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'PEW', num_final_score: 80, id_tournament: 20 }),
      makeScore({ id_result: 3, enum_type: 'PPS', num_final_score: 40, id_tournament: 30 }),
    ]
    const abbrs = (c: HTMLElement) =>
      Array.from(c.querySelectorAll('.type-legend strong')).map((el) => el.textContent?.trim())
    const { container: cRanking } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'RANKING' },
    })
    expect(abbrs(cRanking)).toEqual(['PPW', 'PEW', 'PPS'])
    expect(cRanking.querySelector('.type-legend')?.textContent).toContain('Polish Seniors Cup')
    const { container: cPpw } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    expect(abbrs(cPpw)).toEqual(['PPW'])
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

  // No plan ID — i18n (added post-plan). UX proposal A: the flags are
  // round images, not emoji.
  it('K — LangToggle flag buttons present in modal', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test' },
    })
    const labels = Array.from(container.querySelectorAll('.lang-toggle button')).map((b) => b.getAttribute('aria-label'))
    expect(labels).toEqual(['English', 'Polski'])
    expect(container.querySelectorAll('.lang-toggle .flag svg').length).toBe(2)
  })

  // 6.10 — toggle placement. UX proposal A: the frame (language, close) in
  // the top-right corner; the view switch and ODS at the right end of the
  // data row under the name.
  it('L — the view switch sits in the data row; the language switch and close in the top-right corner', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', showEvfToggle: true, context: CTX },
    })
    const dataRow = container.querySelector('.headline-row')
    const actions = container.querySelector('.modal-actions')
    expect(dataRow?.querySelector('.view-switch')).not.toBeNull()
    expect(actions?.querySelector('.view-switch')).toBeNull()
    expect(actions?.querySelector('.lang-toggle')).not.toBeNull()
    expect(actions?.querySelector('.btn-close')).not.toBeNull()
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
      props: { open: true, fencerName: 'Test', scores, mode: 'RANKING' },
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

  // SS26.UI: RANKING mode renders 2 card-lists, PPW renders 1 (renamed from KADRA)
  it('C.14: RANKING mode renders 2 card-lists, PPW mode renders 1', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 100 }),
      makeScore({ id_result: 2, enum_type: 'PEW', num_final_score: 80, id_tournament: 20 }),
    ]
    const { container: cRanking } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'RANKING' },
    })
    expect(cRanking.querySelectorAll('.card-list').length).toBe(2)

    const { container: cPpw } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW' },
    })
    expect(cPpw.querySelectorAll('.card-list').length).toBe(1)
  })
})

// ── Points order, greyed uncounted results, ★ for counted ────────────────────
// Plan: doc/plans/drilldown-points-order-and-uncounted-2026-10-01.html.
// KRZEMIŃSKI Mariusz, épée men V3, SPWS-2026-2027 rolling, LOCAL 2026-10-01:
// best 2 PPW + every MPW domestic, best 5 EVF+. SPWS 338 = 108.7 + 98 + 131.3.

const RULES_2026_27: RankingRules = {
  domestic: [{ types: ['PPW'], best: 2 }, { types: ['MPW'], always: true }],
  international: [{ types: ['PEW', 'MEW', 'MSW', 'PSW', 'PPS', 'MPS'], best: 5 }],
}

const krz = (
  id: number,
  code: string,
  type: ScoreRow['enum_type'],
  pts: number,
  date: string,
  place: number,
  n: number,
  loc: string,
  extra: Partial<ScoreRow> = {},
): ScoreRow =>
  makeScore({
    id_result: id,
    id_tournament: id,
    fencer_name: 'KRZEMIŃSKI Mariusz',
    enum_age_category: 'V3',
    txt_tournament_code: code,
    txt_tournament_name: 'V3 M EPEE',
    enum_type: type,
    num_final_score: pts,
    dt_tournament: date,
    int_place: place,
    int_participant_count: n,
    txt_location: loc,
    txt_season_code: 'SPWS-2025-2026',
    bool_carried_over: true,
    txt_source_season_code: 'SPWS-2025-2026',
    url_results: 'https://example.com/r/' + id,
    enum_score_method: 'EVF_CLASSIC',
    num_joined_premium: -1,
    num_cap_reduction: -1,
    int_category_steps: -1,
    ...extra,
  })

// In the order fn_fencer_scores_rolling returns them.
const KRZ: ScoreRow[] = [
  krz(1137, 'MPW-V3-M-EPEE-2025-2026', 'MPW', 131.27, '2026-06-20', 1, 10, 'Warszawa', { num_multiplier: 1.2 }),
  krz(3601, 'PPW1-V3-M-EPEE-2026-2027', 'PPW', 108.72, '2026-09-26', 1, 9, 'Opole', {
    bool_carried_over: false, txt_season_code: 'SPWS-2026-2027', txt_source_season_code: 'SPWS-2026-2027',
  }),
  krz(2447, 'PPW3-V3-M-EPEE-2025-2026', 'PPW', 98.0, '2025-12-13', 1, 8, 'Warszawa-Łomianki'),
  krz(2639, 'PPW4-V3-M-EPEE-2025-2026', 'PPW', 97.22, '2026-02-21', 1, 7, 'Gdańsk'),
  krz(2789, 'PPW5-V3-M-EPEE-2025-2026', 'PPW', 96.35, '2026-04-11', 1, 6, 'Gdańsk'),
  krz(814, 'IMSW-V3-M-EPEE-2025-2026', 'MSW', 54.03, '2025-11-12', 2, 4, 'Manama', { num_multiplier: 1.2 }),
  krz(1473, 'PEW4efs-V3-M-EPEE-2025-2026', 'PEW', 51.71, '2026-03-07', 12, 74, 'Napoli', { txt_tournament_name: 'EVF Grand Prix 4', url_results: null }),
  krz(1681, 'PEW6efs-V3-M-EPEE-2025-2026', 'PEW', 40.11, '2026-03-28', 3, 8, 'Jabłonna', { txt_tournament_name: 'EVF Grand Prix 6', url_results: null }),
  krz(1566, 'PEW62efs-V3-M-EPEE-2025-2026', 'PEW', 37.74, '2026-01-10', 2, 3, 'Guildford', { txt_tournament_name: 'EVF Grand Prix 3' }),
  krz(2228, 'PPW2-V3-M-EPEE-2025-2026', 'PPW', 17.79, '2025-10-25', 4, 5, 'Poznań', { txt_tournament_name: null }),
]

const KRZ_CTX: DrilldownContext = { ...CTX, rank: 2, birthYear: 1962, category: 'V3', totalScore: 521.6 }

const renderKrz = (mode: 'PPW' | 'RANKING' = 'RANKING', extra: Record<string, unknown> = {}) =>
  render(DrilldownModal, {
    props: {
      open: true, fencerName: 'KRZEMIŃSKI Mariusz', scores: KRZ, mode,
      context: KRZ_CTX, rankingRules: RULES_2026_27, seasonCode: 'SPWS-2026-2027', ...extra,
    },
  })

const tables = (c: HTMLElement) => Array.from(c.querySelectorAll('.table-section table'))
const cardLists = (c: HTMLElement) => Array.from(c.querySelectorAll('.table-section .card-list'))
const rowPoints = (el: Element, sel: string, cell: string) =>
  Array.from(el.querySelectorAll(sel)).map((r) => parseFloat(r.querySelector(cell)?.textContent ?? ''))
const chartCols = (c: HTMLElement) => Array.from(c.querySelectorAll('.breakdown-col'))
const chartValues = (col: Element) =>
  Array.from(col.querySelectorAll('.chart-row .chart-value')).map((v) => v.textContent?.trim())

describe('DrilldownModal — points order and uncounted results (DD)', () => {
  it('DD.SORT.01 — Zawody krajowe rows run by points, highest first', () => {
    const { container } = renderKrz()
    expect(rowPoints(tables(container)[0], 'tbody tr', 'td.total')).toEqual([131.3, 108.7, 98, 97.2, 96.4, 17.8])
  })

  it('DD.SORT.02 — Zawody EVF+ rows run by points, highest first', () => {
    const { container } = renderKrz()
    expect(rowPoints(tables(container)[1], 'tbody tr', 'td.total')).toEqual([54, 51.7, 40.1, 37.7])
  })

  it('DD.SORT.03 — the phone cards follow the same order; equal points put the newer result first', () => {
    const { container } = renderKrz()
    expect(rowPoints(cardLists(container)[0], '.result-card', '.card-points')).toEqual([131.3, 108.7, 98, 97.2, 96.4, 17.8])
    expect(rowPoints(cardLists(container)[1], '.result-card', '.card-points')).toEqual([54, 51.7, 40.1, 37.7])

    const tie = [
      makeScore({ id_result: 1, txt_tournament_code: 'PPW1-V2-M-EPEE-2025-2026', num_final_score: 50, dt_tournament: '2025-10-01' }),
      makeScore({ id_result: 2, txt_tournament_code: 'PPW3-V2-M-EPEE-2025-2026', num_final_score: 50, dt_tournament: '2026-03-01', id_tournament: 11 }),
    ]
    const { container: c2 } = render(DrilldownModal, { props: { open: true, fencerName: 'T', scores: tie, mode: 'PPW' } })
    const names = (sel: string) => Array.from(c2.querySelectorAll(sel)).map((e) => e.textContent?.trim())
    expect(names('tbody tr .tournament-name')).toEqual(['PPW3 · 2025/26', 'PPW1 · 2025/26'])
    expect(names('.card-tournament .tournament-name')).toEqual(['PPW3 · 2025/26', 'PPW1 · 2025/26'])
  })

  it('DD.SORT.04 / DD.BAR.01 — the SPWS bars run by points and show one decimal', () => {
    const { container } = renderKrz()
    expect(chartValues(chartCols(container)[0])).toEqual(['131.3', '108.7', '98', '97.2', '96.4', '17.8'])
  })

  it('DD.SORT.05 — the EVF+ bars run by points', () => {
    const { container } = renderKrz()
    expect(chartValues(chartCols(container)[1])).toEqual(['54', '51.7', '40.1', '37.7'])
  })

  it('DD.GREY.01 — domestic rows outside the best PPW are greyed; the MPW and the best PPW are not', () => {
    const { container } = renderKrz()
    const rows = Array.from(tables(container)[0].querySelectorAll('tbody tr'))
    expect(rows.map((r) => r.classList.contains('not-counted'))).toEqual([false, false, false, true, true, true])
    const cards = Array.from(cardLists(container)[0].querySelectorAll('.result-card'))
    expect(cards.map((r) => r.classList.contains('not-counted'))).toEqual([false, false, false, true, true, true])
  })

  it('DD.GREY.02 — EVF+ rows beyond the best five are greyed; the five are not', () => {
    const six = [1, 2, 3, 4, 5, 6].map((i) =>
      makeScore({ id_result: i, id_tournament: i, enum_type: 'PEW', num_final_score: 100 - i, txt_tournament_code: `PEW${i}ef-V2-M-EPEE-2025-2026` }),
    )
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'T', scores: six, mode: 'RANKING', rankingRules: RULES_2026_27 },
    })
    const rows = Array.from(tables(container)[1].querySelectorAll('tbody tr'))
    expect(rows.map((r) => r.classList.contains('not-counted'))).toEqual([false, false, false, false, false, true])
    const { container: ck } = renderKrz()
    expect(tables(ck)[1].querySelectorAll('tbody tr.not-counted').length).toBe(0)
  })

  it('DD.GREY.03 — uncounted bars are faded; counted bars are not', () => {
    const { container } = renderKrz()
    const rows = Array.from(chartCols(container)[0].querySelectorAll('.chart-row'))
    expect(rows.map((r) => r.classList.contains('not-counted'))).toEqual([false, false, false, true, true, true])
    expect(chartCols(container)[1].querySelectorAll('.chart-row.not-counted').length).toBe(0)
  })

  it('DD.GREY.04 — the PPW view greys the same domestic rows and hides EVF+', () => {
    const { container } = renderKrz('PPW')
    expect(tables(container).length).toBe(1)
    const rows = Array.from(tables(container)[0].querySelectorAll('tbody tr'))
    expect(rows.map((r) => r.classList.contains('not-counted'))).toEqual([false, false, false, true, true, true])
  })

  it('DD.GREY.05 — each printed total equals the sum of the rows not greyed', () => {
    // Rows print one decimal, so their visible sum may differ from the total
    // by up to 0.05 per row: 54 + 51.7 + 40.1 + 37.7 = 183.5, total 183.59 → 183.6.
    const nearCounted = (t: Element, total: number) => {
      const rows = Array.from(t.querySelectorAll('tbody tr:not(.not-counted)'))
      const sum = rows.reduce((a, r) => a + parseFloat(r.querySelector('td.total')?.textContent ?? '0'), 0)
      return Math.abs(sum - total) <= 0.05 * rows.length + 1e-9
    }
    // Without a ranklist row (context) the headline total is the counted one.
    const { container } = renderKrz('RANKING', { context: null })
    expect(nearCounted(tables(container)[0], 338)).toBe(true)
    expect(nearCounted(tables(container)[1], 183.6)).toBe(true)
    const headings = Array.from(container.querySelectorAll('.breakdown-col h4')).map((h) => h.textContent)
    expect(headings[0]).toContain('338')
    expect(headings[1]).toContain('183.6')
    expect(container.querySelector('.score-total')?.textContent?.trim()).toBe('521.6')
    const { container: cp } = renderKrz('PPW', { context: null })
    expect(cp.querySelector('.score-total')?.textContent?.trim()).toBe('338')
  })

  it('DD.GREY.06 — carried rows keep their look; a counted one has ★, an uncounted one is also greyed', () => {
    const { container } = renderKrz()
    const rows = Array.from(tables(container)[0].querySelectorAll('tbody tr'))
    const ppw3 = rows[2] // 98, carried, counted
    const ppw4 = rows[3] // 97.2, carried, not counted
    expect(ppw3.classList.contains('carried-row')).toBe(true)
    expect(ppw3.classList.contains('not-counted')).toBe(false)
    expect(ppw3.querySelector('td.total')?.textContent).toContain('★')
    expect(ppw4.classList.contains('carried-row')).toBe(true)
    expect(ppw4.classList.contains('not-counted')).toBe(true)
    expect(ppw4.querySelector('.carried-badge')?.textContent).toContain('↩')
    expect(ppw4.querySelector('td.total')?.textContent).not.toContain('★')
  })

  it('DD.GREY.07 — without bucket rules the older PEW/MEW counting decides the greying', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PEW', num_final_score: 90 }),
      makeScore({ id_result: 2, enum_type: 'PEW', num_final_score: 80, id_tournament: 11 }),
      makeScore({ id_result: 3, enum_type: 'PEW', num_final_score: 70, id_tournament: 12 }),
      makeScore({ id_result: 4, enum_type: 'PEW', num_final_score: 60, id_tournament: 13 }),
      makeScore({ id_result: 5, enum_type: 'MEW', num_final_score: 20, id_tournament: 14 }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'T', scores, mode: 'RANKING' },
    })
    const rows = Array.from(tables(container)[1].querySelectorAll('tbody tr'))
    expect(rows.map((r) => r.classList.contains('not-counted'))).toEqual([false, false, false, true, false])
    expect(container.querySelector('.score-total')?.textContent?.trim()).toBe('260')
  })

  it('DD.LOOK.01 — each table and its phone cards sit in one framed panel', () => {
    const { container } = renderKrz()
    const panels = Array.from(container.querySelectorAll('.table-section .table-panel'))
    expect(panels.length).toBe(2)
    for (const p of panels) {
      expect(p.querySelector('table')).not.toBeNull()
      expect(p.querySelector('.card-list')).not.toBeNull()
    }
    const { container: cp } = renderKrz('PPW')
    expect(cp.querySelectorAll('.table-section .table-panel').length).toBe(1)
  })

  it('DD.LEG.01 — no carried-over banner; the legend reads ★ counted and ↩ previous season', () => {
    const { container } = renderKrz()
    expect(container.querySelector('.rolling-info')).toBeNull()
    const legend = container.querySelector('.carried-legend')?.textContent ?? ''
    expect(legend).toContain('★ counted')
    expect(legend).toContain('↩ Result from the previous season')
    expect(legend).not.toContain('Best')
    setLocale('pl')
    const { container: cpl } = renderKrz()
    const legendPl = cpl.querySelector('.carried-legend')?.textContent ?? ''
    expect(legendPl).toContain('★ wliczany')
    expect(legendPl).toContain('↩ Wynik z poprzedniego sezonu')
    expect(cpl.textContent).not.toContain('Część wyników przeniesiona')
  })

  it('DD.STAR.01 — every counted result shows ★, the MPW included; no ✓ anywhere', () => {
    const { container } = renderKrz()
    for (const r of Array.from(container.querySelectorAll('.table-section tbody tr'))) {
      const counted = !r.classList.contains('not-counted')
      expect(r.querySelector('td.total')?.textContent?.includes('★')).toBe(counted)
    }
    for (const r of Array.from(container.querySelectorAll('.chart-row'))) {
      const counted = !r.classList.contains('not-counted')
      expect(r.querySelector('.chart-marker')?.textContent?.includes('★')).toBe(counted)
    }
    expect(container.textContent).not.toContain('✓')
  })

  it('DD.KEEP.01 — the language switch stays in the header and the ODS button still exports the drilldown', async () => {
    vi.mocked(exportDrilldown).mockClear()
    const { container } = renderKrz('RANKING', { showEvfToggle: true })
    expect(container.querySelector('.modal-actions .lang-toggle')).not.toBeNull()
    const btn = container.querySelector('.headline-row .ods-btn') as HTMLButtonElement
    expect(btn).not.toBeNull()
    await fireEvent.click(btn)
    expect(exportDrilldown).toHaveBeenCalledWith('KRZEMIŃSKI Mariusz', KRZ, 'RANKING')
  })

  it('DD.MODE.01 (A1) — the modal switch reports the chosen view to the page', async () => {
    const onmodechange = vi.fn()
    const { container } = renderKrz('RANKING', { showEvfToggle: true, onmodechange })
    const ppwBtn = Array.from(container.querySelectorAll('.headline-row .toggle-btn')).find((b) => b.textContent?.trim() === 'PPW')!
    await fireEvent.click(ppwBtn)
    expect(onmodechange).toHaveBeenCalledWith('PPW')
  })

  it('DD.FOOT.01 (A4) — the multiplier footer no longer describes the old raw-score formula', () => {
    const { container } = renderKrz()
    const footer = container.querySelector('.modal-footer')?.textContent ?? ''
    expect(footer).toContain('Mult —')
    expect(footer).not.toContain('raw score')
    expect(footer).not.toContain('podium bonus')
  })

  it('DD.NAME.01 (B1) — rows read event · season, a PEW row its own name; the code stays as the link tooltip', () => {
    const { container } = renderKrz()
    const first = tables(container)[0].querySelector('tbody tr')!
    const link = first.querySelector('a') as HTMLAnchorElement
    expect(link.textContent?.trim()).toBe('MPW · 2025/26')
    expect(link.title).toBe('MPW-V3-M-EPEE-2025-2026')
    expect(link.href).toContain('example.com/r/1137')
    const intlNames = Array.from(tables(container)[1].querySelectorAll('tbody tr .tournament-name')).map((e) => e.textContent?.trim())
    expect(intlNames).toEqual(['IMSW · 2025/26', 'EVF Grand Prix 4', 'EVF Grand Prix 6', 'EVF Grand Prix 3'])
    const napoli = tables(container)[1].querySelectorAll('tbody tr .tournament-name')[1] as HTMLElement
    expect(napoli.title).toBe('PEW4efs-V3-M-EPEE-2025-2026')
  })

  it('DD.JOIN.01 (B2) — a joined-bracket result shows its premium, in the table and the card', () => {
    const joined = makeScore({
      id_result: 9, txt_tournament_code: 'PPW1-V1-M-EPEE-2026-2027', num_final_score: 76.4,
      enum_score_method: 'EVF_JOINED', num_joined_premium: 6.6, num_cap_reduction: 0, int_category_steps: 1,
    })
    const classic = makeScore({ id_result: 10, id_tournament: 11, txt_tournament_code: 'PPW2-V1-M-EPEE-2026-2027', num_final_score: 50, enum_score_method: 'EVF_CLASSIC', num_joined_premium: -1, num_cap_reduction: -1 })
    const capped = makeScore({
      id_result: 11, id_tournament: 12, txt_tournament_code: 'PPW3-V1-M-EPEE-2026-2027', num_final_score: 40,
      enum_score_method: 'EVF_JOINED', num_joined_premium: 4.04, num_cap_reduction: 1.25, int_category_steps: 2,
    })
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'T', scores: [joined, classic, capped], mode: 'PPW' },
    })
    const notes = Array.from(container.querySelectorAll('tbody tr')).map((r) => r.querySelector('.joined-note')?.textContent?.trim() ?? null)
    expect(notes).toEqual(['joined bracket · premium +6.6', null, 'joined bracket · premium +4 · cap reduction −1.3'])
    expect(container.querySelectorAll('.card-list .joined-note').length).toBe(2)
    setLocale('pl')
    const { container: cpl } = render(DrilldownModal, {
      props: { open: true, fencerName: 'T', scores: [joined], mode: 'PPW' },
    })
    expect(cpl.querySelector('tbody .joined-note')?.textContent?.trim()).toBe('stawka łączona · premia +6.6')
  })

  // ── UX proposal A (doc/mockups/ranklist-controls-ux-2026-10-01.html) ──────

  it('UX.DD.01 — the headline shows the place and the total of the view shown', () => {
    const { container } = renderKrz('RANKING', { showEvfToggle: true })
    expect(container.querySelector('.score-rank')?.textContent?.trim()).toBe('2')
    expect(container.querySelector('.score-total')?.textContent?.trim()).toBe('521.6')
    const labs = Array.from(container.querySelectorAll('.score-lab')).map((l) => l.textContent?.trim())
    expect(labs).toEqual(['place', 'pts total'])
    const { container: cp } = renderKrz('PPW', { showEvfToggle: true, context: { ...KRZ_CTX, rank: 1, totalScore: 337.99 } })
    expect(cp.querySelector('.score-rank')?.textContent?.trim()).toBe('1')
    expect(cp.querySelector('.score-total')?.textContent?.trim()).toBe('338')
  })

  it('UX.DD.03 — name and meta, then the frame controls; under them the headline, the switch, then ODS', () => {
    const { container } = renderKrz('RANKING', { showEvfToggle: true })
    const header = container.querySelector('.modal-header')!
    expect(header.querySelector('h2')?.textContent).toBe('KRZEMIŃSKI Mariusz')
    expect(header.querySelector('.subheader')?.textContent?.replace(/\s+/g, ' ').trim()).toBe('V3 · SPWS-2026-2027 · born 1962')
    expect(container.querySelector('.btn-close')?.getAttribute('aria-label')).toBe('Close')
    const row = container.querySelector('.headline-row')!
    expect(row.firstElementChild?.classList.contains('score')).toBe(true)
    const tools = row.querySelector('.view-tools')!
    expect(Array.from(tools.children).map((c) => c.classList.contains('view-switch') ? 'switch' : c.classList.contains('ods-btn') ? 'ods' : '?'))
      .toEqual(['switch', 'ods'])
    const pressed = Array.from(tools.querySelectorAll('.toggle-btn')).map((b) => `${b.textContent?.trim()}=${b.getAttribute('aria-pressed')}`)
    expect(pressed).toEqual(['Ranking=true', 'PPW=false'])
    expect(tools.querySelector('.ods-btn')?.textContent?.trim()).toBe('ODS')
  })

  it('UX.DD.04 — Esc closes the drilldown, from the page and from inside the dialog', async () => {
    const onclose = vi.fn()
    const { container } = renderKrz('RANKING', { onclose })
    await fireEvent.keyDown(window, { key: 'Escape' })
    expect(onclose).toHaveBeenCalledTimes(1)
    await fireEvent.keyDown(container.querySelector('.btn-close')!, { key: 'Escape' })
    expect(onclose).toHaveBeenCalledTimes(2)
    await fireEvent.keyDown(window, { key: 'Enter' })
    expect(onclose).toHaveBeenCalledTimes(2)
    const onclose2 = vi.fn()
    render(DrilldownModal, { props: { open: false, onclose: onclose2 } })
    await fireEvent.keyDown(window, { key: 'Escape' })
    expect(onclose2).not.toHaveBeenCalled()
  })

  it('UX.DD.05 — the dialog is named after the fencer and the headline is announced', () => {
    const { container } = renderKrz()
    expect(container.querySelector('[role="dialog"]')?.getAttribute('aria-label')).toBe('KRZEMIŃSKI Mariusz')
    const score = container.querySelector('.score')!
    expect(score.getAttribute('aria-live')).toBe('polite')
    expect(score.getAttribute('aria-label')).toBe('place 2, 521.6 pts total')
  })

  it('UX.DD.06 — without a ranklist row the headline shows the counted total and no place', () => {
    const { container } = renderKrz('RANKING', { context: null })
    expect(container.querySelector('.score-rank')).toBeNull()
    expect(container.querySelector('.score-total')?.textContent?.trim()).toBe('521.6')
  })

  it('UX.DD.07 — every tournament with a results URL stays a link, in the table and the card', () => {
    const { container } = renderKrz()
    const withUrl = KRZ.filter((s) => s.url_results)
    for (const where of ['.table-section table', '.table-section .card-list']) {
      const links = Array.from(container.querySelectorAll<HTMLAnchorElement>(`${where} a.tournament-name`))
      expect(links.length).toBe(withUrl.length)
      for (const s of withUrl) {
        const a = links.find((l) => l.href === s.url_results)!
        expect(a).toBeDefined()
        expect(a.target).toBe('_blank')
        expect(a.title).toBe(s.txt_tournament_code)
      }
    }
  })

  // DD.BAR.02: a carried-over EVF+ result draws a striped bar, like a carried
  // SPWS result and like the legend's „Przeniesione (EVF)" swatch. The rule
  // that colours EVF/FIE bars orange used to override the stripes, so every
  // carried EVF+ bar was solid (KRZEMIŃSKI, LOCAL, 2026-10-01).
  it('DD.BAR.02 — carried EVF+ bars are striped, current ones solid; the same for PZSz', () => {
    const bg = (el: Element) => {
      const cs = getComputedStyle(el)
      return `${cs.backgroundImage} ${cs.background}`
    }
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PEW', num_final_score: 80, bool_carried_over: true, txt_source_season_code: 'SPWS-2025-2026' }),
      makeScore({ id_result: 2, enum_type: 'PEW', num_final_score: 70, id_tournament: 11 }),
      makeScore({ id_result: 3, enum_type: 'PPS', num_final_score: 40, id_tournament: 12, bool_carried_over: true, txt_source_season_code: 'SPWS-2025-2026' }),
    ]
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'T', scores, mode: 'RANKING', rankingRules: RULES_2026_27 },
    })
    const intl = chartCols(container)[1]
    const carriedEvf = intl.querySelector('.chart-bar.chart-bar-evf.international-carried')!
    const currentEvf = intl.querySelector('.chart-bar.chart-bar-evf:not(.international-carried)')!
    const carriedPzsz = intl.querySelector('.chart-bar.chart-bar-pzsz.international-carried')!
    expect(bg(carriedEvf)).toContain('repeating-linear-gradient')
    expect(bg(currentEvf)).not.toContain('repeating-linear-gradient')
    expect(bg(carriedPzsz)).toContain('repeating-linear-gradient')
  })
})

// DD.SECT — which section a result is listed in. On 2 Oct 2026 re-ingested
// Manama (IMSW) and Guildford (PEW62efs) tournaments were stored typed PPW and
// the drilldown listed them under domestic tournaments. The section follows
// enum_type, so these pin the UI half; supabase/tests/90 (TT.CODE) keeps a
// tournament's type in agreement with its code family.
describe('DrilldownModal — sections by tournament type', () => {
  // The roster pinned by supabase/tests/01 (1.1c enum_tournament_type values).
  const ALL_TYPES = ['PPW', 'MPW', 'PEW', 'MEW', 'MSW', 'PSW', 'PPS', 'MPS'] as const
  const DOMESTIC = ['PPW', 'MPW']

  function sectionCodes(container: HTMLElement, heading: string): string[] {
    const h3 = Array.from(container.querySelectorAll('.table-section h3')).find(
      (h) => h.textContent?.trim() === heading,
    )
    const panel = h3?.nextElementSibling
    if (!panel) return []
    return Array.from(panel.querySelectorAll('tbody tr')).map(
      (tr) => tr.querySelector('td')?.textContent?.trim().split(/\s/)[0] ?? '',
    )
  }

  it('DD.SECT.01 — an international result is listed under EVF+ tournaments, never under domestic', () => {
    const scores = ALL_TYPES.map((type, i) =>
      makeScore({ id_result: i + 1, id_tournament: 100 + i, txt_tournament_code: `${type}-T`, enum_type: type }),
    )
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'RANKING' },
    })
    const domestic = sectionCodes(container, 'Domestic Tournaments')
    const international = sectionCodes(container, 'EVF+ Tournaments')
    expect(domestic.sort()).toEqual(['MPW-T', 'PPW-T'])
    expect(international.sort()).toEqual(
      ALL_TYPES.filter((type) => !DOMESTIC.includes(type)).map((type) => `${type}-T`).sort(),
    )
  })

  it('DD.SECT.02 — every tournament type belongs to exactly one section', () => {
    for (const type of ALL_TYPES) {
      expect([isDomestic(type), isInternational(type)].filter(Boolean)).toHaveLength(1)
    }
  })
})
