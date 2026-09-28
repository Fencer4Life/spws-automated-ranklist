// Plan tests: 6.13, 6.14 — ODS export functions.
// See doc/archive/POC_development_plan.md §M6 test table.

import { describe, it, expect, vi, beforeEach } from 'vitest'

// Mock XLSX
vi.mock('xlsx', () => ({
  utils: {
    json_to_sheet: vi.fn(() => ({})),
    book_new: vi.fn(() => ({ SheetNames: [], Sheets: {} })),
    book_append_sheet: vi.fn(),
  },
  writeFile: vi.fn(),
}))

import * as XLSX from 'xlsx'
import { exportRankingPpw, exportRankingFull, exportDrilldown } from '../src/lib/export'
import { setLocale } from '../src/lib/locale.svelte'
import type { RankingPpwRow, RankingFullRow, ScoreRow } from '../src/lib/types'

beforeEach(() => {
  vi.clearAllMocks()
})

// 6.13 — main ranking ODS export
describe('exportRankingPpw', () => {
  it('creates ODS file with correct columns', () => {
    const rows: RankingPpwRow[] = [
      { rank: 1, id_fencer: 1, fencer_name: 'SMITH John', ppw_score: 300, mpw_score: 80, total_score: 380 },
    ]
    exportRankingPpw(rows, 'test')

    expect(XLSX.utils.json_to_sheet).toHaveBeenCalledWith([
      { Rank: 1, Fencer: 'SMITH John', Points: 380 },
    ])
    expect(XLSX.writeFile).toHaveBeenCalledWith(
      expect.any(Object),
      'test.ods',
      { bookType: 'ods' },
    )
  })
})

// SS26.UI (design step 7, ADR-101): renamed from exportRankingKadra — columns
// are now SPWS/EVF+/Razem from fn_ranking_full, not PPW Total/PEW Total/Total.
describe('exportRankingFull', () => {
  it('creates ODS file with SPWS/EVF+/Razem columns', () => {
    const rows: RankingFullRow[] = [
      { rank: 1, id_fencer: 1, fencer_name: 'SMITH John', spws_total: 400, evf_plus_total: 200, total_score: 600 },
    ]
    exportRankingFull(rows, 'ranking_test')

    expect(XLSX.utils.json_to_sheet).toHaveBeenCalledWith([
      { Rank: 1, Fencer: 'SMITH John', SPWS: 400, 'EVF+': 200, Razem: 600 },
    ])
    expect(XLSX.writeFile).toHaveBeenCalledWith(
      expect.any(Object),
      'ranking_test.ods',
      { bookType: 'ods' },
    )
  })
})

// 6.14 — drill-down ODS export. Its headers follow the UI language
// (SE27.UI.08); these cases read the English ones.
describe('exportDrilldown', () => {
  beforeEach(() => setLocale('en'))
  const score: ScoreRow = {
    id_result: 1,
    id_fencer: 1,
    fencer_name: 'DOE Jane',
    int_birth_year: 1985,
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
    ts_points_calc: '2024-10-16T00:00:00Z',
    id_season: 1,
    txt_season_code: '2024/25',
    url_results: null,
    txt_location: null,
  }

  const pewScore: ScoreRow = {
    ...score,
    id_tournament: 20,
    txt_tournament_code: 'PEW-01',
    enum_type: 'PEW',
    num_final_score: 50,
  }

  it('PPW mode filters to domestic only', () => {
    exportDrilldown('DOE Jane', [score, pewScore], 'PPW')

    const jsonCall = (XLSX.utils.json_to_sheet as ReturnType<typeof vi.fn>).mock.calls[0][0]
    expect(jsonCall).toHaveLength(1)
    expect(jsonCall[0].Tournament).toBe('PPW-01')
  })

  it('RANKING mode includes all tournaments', () => {
    exportDrilldown('DOE Jane', [score, pewScore], 'RANKING')

    const jsonCall = (XLSX.utils.json_to_sheet as ReturnType<typeof vi.fn>).mock.calls[0][0]
    expect(jsonCall).toHaveLength(2)
  })

  it('writes ODS file with fencer name', () => {
    exportDrilldown('DOE Jane', [score], 'PPW')
    expect(XLSX.writeFile).toHaveBeenCalledWith(
      expect.any(Object),
      'DOE Jane - PPW.ods',
      { bookType: 'ods' },
    )
  })
})

// SE27.UI.08 (ADR-103, FR-140): the drill-down export names the method that
// scored each result and every stored component. A component the method does
// not use is stored as -1 (chk_result_components_match_method); the export
// shows it as „nie dotyczy”, never as a negative number of points. The export
// reaches fencers, so its headers follow the UI language: Polish by default.
describe('exportDrilldown — components by method (SE27.UI.08)', () => {
  beforeEach(() => setLocale('pl'))

  const base: ScoreRow = {
    id_result: 1,
    id_fencer: 1,
    fencer_name: 'DOE Jane',
    int_birth_year: 1965,
    id_tournament: 10,
    txt_tournament_code: 'PPW1-V2-M-EPEE-2026-2027',
    txt_tournament_name: 'Test PPW',
    dt_tournament: '2026-10-03',
    enum_type: 'PPW',
    enum_weapon: 'EPEE',
    enum_gender: 'M',
    enum_age_category: 'V2',
    int_participant_count: 8,
    num_multiplier: 1.0,
    int_place: 3,
    num_place_pts: -1,
    num_de_bonus: -1,
    num_podium_bonus: -1,
    num_final_score: 36.14,
    ts_points_calc: '2026-10-04T00:00:00Z',
    id_season: 2,
    txt_season_code: 'SPWS-2026-2027',
    url_results: null,
    txt_location: null,
    int_category_count: 4,
    int_category_place: 1,
    int_below_count: 5,
    num_field_pts: 3,
    num_below_pts: 17.5,
    num_medal_bonus: 20.64,
    enum_score_method: 'PLACE_MEDAL',
  }
  const rowOf = (s: ScoreRow) => {
    exportDrilldown('DOE Jane', [s], 'RANKING')
    return (XLSX.utils.json_to_sheet as ReturnType<typeof vi.fn>).mock.calls[0][0][0]
  }

  it('Polish headers, in order, with the component names of the calculator', () => {
    expect(Object.keys(rowOf(base))).toEqual([
      'Turniej', 'Data', 'Typ', 'Miejsce', 'Liczba zawodników (N)',
      'Zawodników w kategorii (K)', 'Miejsce w kategorii (m)', 'Zawodników poniżej (b)',
      'Współczynnik', 'Metoda',
      'Punkty za miejsce', 'Bonus za wygrane rundy', 'Bonus za podium',
      'Za liczebność', 'Zawodnicy poniżej w stawce', 'Premia medalowa',
      'Wynik',
    ])
  })

  it('a place-and-medal result shows its method, K, m, b and its three components', () => {
    const row = rowOf(base)
    expect(row['Metoda']).toBe('SPWS: miejsce i medal (stawka 4–31)')
    expect(row['Zawodników w kategorii (K)']).toBe(4)
    expect(row['Miejsce w kategorii (m)']).toBe(1)
    expect(row['Zawodników poniżej (b)']).toBe(5)
    expect(row['Za liczebność']).toBe(3)
    expect(row['Zawodnicy poniżej w stawce']).toBe(17.5)
    expect(row['Premia medalowa']).toBe(20.64)
    expect(row['Wynik']).toBe(36.14)
  })

  it('shows -1 as „nie dotyczy”', () => {
    const row = rowOf(base)
    expect(row['Punkty za miejsce']).toBe('nie dotyczy')
    expect(row['Bonus za wygrane rundy']).toBe('nie dotyczy')
    expect(row['Bonus za podium']).toBe('nie dotyczy')
  })

  it('an EVF classic result shows the classic components and „nie dotyczy” for the rest', () => {
    const row = rowOf({
      ...base,
      num_place_pts: 36.25, num_de_bonus: 20, num_podium_bonus: 6,
      num_field_pts: -1, num_below_pts: -1, num_medal_bonus: -1,
      int_category_count: -1, int_category_place: -1, int_below_count: -1,
      enum_score_method: 'EVF_CLASSIC',
    })
    expect(row['Metoda']).toBe('EVF klasyczny')
    expect(row['Punkty za miejsce']).toBe(36.25)
    expect(row['Bonus za wygrane rundy']).toBe(20)
    expect(row['Bonus za podium']).toBe(6)
    for (const col of ['Za liczebność', 'Zawodnicy poniżej w stawce', 'Premia medalowa',
      'Zawodników w kategorii (K)', 'Miejsce w kategorii (m)', 'Zawodników poniżej (b)']) {
      expect(row[col], col).toBe('nie dotyczy')
    }
  })

  it('a table result names the table', () => {
    const row = rowOf({
      ...base,
      int_participant_count: 3, num_place_pts: 1,
      num_field_pts: -1, num_below_pts: -1, num_medal_bonus: -1,
      enum_score_method: 'TABLE',
    })
    expect(row['Metoda']).toBe('Tabela (stawka 1–3)')
    expect(row['Punkty za miejsce']).toBe(1)
  })

  it('an unscored or pre-ADR-103 row leaves the new columns empty', () => {
    const legacy: ScoreRow = { ...base }
    for (const k of ['int_category_count', 'int_category_place', 'int_below_count',
      'num_field_pts', 'num_below_pts', 'num_medal_bonus', 'enum_score_method'] as const) {
      delete legacy[k]
    }
    const row = rowOf({ ...legacy, num_place_pts: 40, num_de_bonus: 10, num_podium_bonus: 0 })
    expect(row['Metoda']).toBe('')
    expect(row['Za liczebność']).toBe('')
    expect(row['Zawodników w kategorii (K)']).toBe('')
    expect(row['Punkty za miejsce']).toBe(40)
  })

  it('in English: the original header names, and "n/a"', () => {
    setLocale('en')
    const row = rowOf(base)
    expect(Object.keys(row)).toEqual([
      'Tournament', 'Date', 'Type', 'Place', 'Participants',
      'Category Size (K)', 'Category Place (m)', 'Below (b)',
      'Multiplier', 'Method',
      'Place Pts', 'DE Bonus', 'Podium Bonus',
      'Field Pts', 'Below Pts', 'Medal Bonus',
      'Final Score',
    ])
    expect(row['Place Pts']).toBe('n/a')
    expect(row.Method).toBe('SPWS place and medal (bracket of 4–31)')
  })
})
