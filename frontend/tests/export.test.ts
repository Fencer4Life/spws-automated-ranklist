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
import { exportRankingPpw, exportRankingKadra, exportDrilldown } from '../src/lib/export'
import type { RankingPpwRow, RankingKadraRow, ScoreRow } from '../src/lib/types'

beforeEach(() => {
  vi.clearAllMocks()
})

describe('exportRankingPpw', () => {
  it('creates ODS file with correct columns', () => {
    const rows: RankingPpwRow[] = [
      { rank: 1, id_fencer: 1, fencer_name: 'SMITH John', ppw_score: 300, mpw_score: 80, total_score: 380 },
    ]
    exportRankingPpw(rows, 'test')

    expect(XLSX.utils.json_to_sheet).toHaveBeenCalledWith([
      { Rank: 1, Fencer: 'SMITH John', 'Best-4 PPW': 300, MPW: 80, Total: 380 },
    ])
    expect(XLSX.writeFile).toHaveBeenCalledWith(
      expect.any(Object),
      'test.ods',
      { bookType: 'ods' },
    )
  })
})

describe('exportRankingKadra', () => {
  it('creates ODS file with Kadra columns', () => {
    const rows: RankingKadraRow[] = [
      { rank: 1, id_fencer: 1, fencer_name: 'SMITH John', ppw_total: 400, pew_total: 200, total_score: 600 },
    ]
    exportRankingKadra(rows, 'kadra_test')

    expect(XLSX.utils.json_to_sheet).toHaveBeenCalledWith([
      { Rank: 1, Fencer: 'SMITH John', 'PPW Total': 400, 'PEW Total': 200, Total: 600 },
    ])
    expect(XLSX.writeFile).toHaveBeenCalledWith(
      expect.any(Object),
      'kadra_test.ods',
      { bookType: 'ods' },
    )
  })
})

describe('exportDrilldown', () => {
  const score: ScoreRow = {
    id_result: 1,
    id_fencer: 1,
    fencer_name: 'DOE Jane',
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

  it('KADRA mode includes all tournaments', () => {
    exportDrilldown('DOE Jane', [score, pewScore], 'KADRA')

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
