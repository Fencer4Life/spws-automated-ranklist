import { describe, it, expect, vi } from 'vitest'
import { render } from '@testing-library/svelte'
import DrilldownModal from '../src/components/DrilldownModal.svelte'
import type { ScoreRow, DrilldownContext } from '../src/lib/types'

vi.mock('../src/lib/export', () => ({
  exportDrilldown: vi.fn(),
}))

const makeScore = (overrides: Partial<ScoreRow> = {}): ScoreRow => ({
  id_result: 1,
  id_fencer: 1,
  fencer_name: 'TEST User',
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
  it('is hidden when open=false', () => {
    const { container } = render(DrilldownModal, { props: { open: false } })
    expect(container.querySelector('.modal-overlay')).toBeNull()
  })

  it('shows fencer name when open', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'SMITH John' },
    })
    expect(container.textContent).toContain('SMITH John')
  })

  it('renders subheader with rank, category, birth year, and total', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'ATANASSOW Aleksander', context: CTX, mode: 'KADRA' },
    })
    const sub = container.querySelector('.subheader')
    expect(sub?.textContent).toContain('Rank #1')
    expect(sub?.textContent).toContain('V2')
    expect(sub?.textContent).toContain('born 1969')
    expect(sub?.textContent).toContain('age 56')
    expect(sub?.textContent).toContain('910 pts')
  })

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

  it('shows summary rows with correct sums', () => {
    const scores = [
      makeScore({ id_result: 1, enum_type: 'PPW', num_final_score: 120 }),
      makeScore({ id_result: 2, enum_type: 'PPW', num_final_score: 100, id_tournament: 11 }),
      makeScore({ id_result: 3, enum_type: 'MPW', num_final_score: 45, id_tournament: 12 }),
    ]
    const ctx = { ...CTX, ppwBestCount: 4 }
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', scores, mode: 'PPW', context: ctx },
    })
    const summaries = container.querySelectorAll('.breakdown-summary')
    expect(summaries[0]?.textContent).toContain('220+45 = 265')
  })

  it('KADRA mode shows grand total', () => {
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
    const grandTotal = container.querySelector('.grand-total')
    expect(grandTotal?.textContent).toContain('Grand Total: 285')
  })

  it('disables Kadra toggle when kadraDisabled is true', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', kadraDisabled: true },
    })
    const btns = container.querySelectorAll('.toggle-btn')
    const kadraBtn = btns[1] as HTMLButtonElement
    expect(kadraBtn.disabled).toBe(true)
  })

  it('shows loading state', () => {
    const { container } = render(DrilldownModal, {
      props: { open: true, fencerName: 'Test', loading: true },
    })
    expect(container.textContent).toContain('Loading')
  })
})
