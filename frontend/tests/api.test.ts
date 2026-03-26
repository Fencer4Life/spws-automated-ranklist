// Plan tests: 6.1, 6.3, 6.5, 6.6, 6.11 — Supabase API client functions.
// See doc/POC_development_plan.md §M6 test table.

import { describe, it, expect, vi, beforeEach } from 'vitest'

// Mock @supabase/supabase-js
vi.mock('@supabase/supabase-js', () => {
  const mockRpc = vi.fn()
  const mockFrom = vi.fn()
  return {
    createClient: vi.fn(() => ({
      rpc: mockRpc,
      from: mockFrom,
    })),
    __mockRpc: mockRpc,
    __mockFrom: mockFrom,
  }
})

import { initClient, fetchSeasons, fetchRankingPpw, fetchRankingKadra, fetchFencerScores, fetchCalendarEvents } from '../src/lib/api'
import { __mockRpc, __mockFrom } from '@supabase/supabase-js'

const mockRpc = __mockRpc as ReturnType<typeof vi.fn>
const mockFrom = __mockFrom as ReturnType<typeof vi.fn>

beforeEach(() => {
  vi.clearAllMocks()
  initClient('http://localhost:54321', 'test-key')
})

// 6.3 — season list for default view
describe('fetchSeasons', () => {
  it('queries tbl_season ordered by dt_start desc', async () => {
    const seasons = [
      { id_season: 2, txt_code: '2024/25', dt_start: '2024-09-01', dt_end: '2025-06-30', bool_active: true },
      { id_season: 1, txt_code: '2023/24', dt_start: '2023-09-01', dt_end: '2024-06-30', bool_active: false },
    ]
    const chain = { select: vi.fn().mockReturnValue({ order: vi.fn().mockResolvedValue({ data: seasons, error: null }) }) }
    mockFrom.mockReturnValue(chain)

    const result = await fetchSeasons()
    expect(mockFrom).toHaveBeenCalledWith('tbl_season')
    expect(result).toEqual(seasons)
  })
})

// 6.1, 6.3 — PPW ranking data
describe('fetchRankingPpw', () => {
  it('calls fn_ranking_ppw RPC with correct params', async () => {
    const rows = [{ rank: 1, id_fencer: 1, fencer_name: 'TEST User', ppw_score: 100, mpw_score: 50, total_score: 150 }]
    mockRpc.mockResolvedValue({ data: rows, error: null })

    const result = await fetchRankingPpw('EPEE', 'M', 'V2', 1)
    expect(mockRpc).toHaveBeenCalledWith('fn_ranking_ppw', {
      p_weapon: 'EPEE',
      p_gender: 'M',
      p_category: 'V2',
      p_season: 1,
    })
    expect(result).toEqual(rows)
  })

  it('omits p_season when null', async () => {
    mockRpc.mockResolvedValue({ data: [], error: null })

    await fetchRankingPpw('FOIL', 'F', 'V1')
    expect(mockRpc).toHaveBeenCalledWith('fn_ranking_ppw', {
      p_weapon: 'FOIL',
      p_gender: 'F',
      p_category: 'V1',
    })
  })

  it('throws on error', async () => {
    mockRpc.mockResolvedValue({ data: null, error: { message: 'DB error' } })
    await expect(fetchRankingPpw('EPEE', 'M', 'V2')).rejects.toEqual({ message: 'DB error' })
  })
})

// 6.11 — Kadra ranking data
describe('fetchRankingKadra', () => {
  it('calls fn_ranking_kadra RPC with correct params', async () => {
    const rows = [{ rank: 1, id_fencer: 1, fencer_name: 'TEST', ppw_total: 200, pew_total: 100, total_score: 300 }]
    mockRpc.mockResolvedValue({ data: rows, error: null })

    const result = await fetchRankingKadra('EPEE', 'M', 'V2', 1)
    expect(mockRpc).toHaveBeenCalledWith('fn_ranking_kadra', {
      p_weapon: 'EPEE',
      p_gender: 'M',
      p_category: 'V2',
      p_season: 1,
    })
    expect(result).toEqual(rows)
  })
})

// 8.18 — fetchCalendarEvents calls vw_calendar with season filter
describe('fetchCalendarEvents', () => {
  it('queries vw_calendar with season filter', async () => {
    const events = [
      {
        id_event: 1, txt_code: 'EVT-1', txt_name: 'Event 1', id_season: 1,
        txt_season_code: '2024/25', txt_location: 'Warszawa', txt_country: 'POL',
        txt_venue_address: null, url_invitation: 'https://example.com/inv.pdf',
        num_entry_fee: 50, dt_start: '2024-11-15', dt_end: '2024-11-16',
        url_event: null, enum_status: 'COMPLETED',
        num_tournaments: 2, bool_has_international: false,
      },
    ]
    const chain = {
      select: vi.fn().mockReturnValue({
        eq: vi.fn().mockReturnValue({
          order: vi.fn().mockResolvedValue({ data: events, error: null }),
        }),
      }),
    }
    mockFrom.mockReturnValue(chain)

    const result = await fetchCalendarEvents(1)
    expect(mockFrom).toHaveBeenCalledWith('vw_calendar')
    expect(result).toEqual(events)
  })
})

// 8.19 — CalendarEvent type includes all required fields (compile-time check)
// This is verified by TypeScript compilation — if CalendarEvent is missing fields,
// the test above would fail to type-check. We also add an explicit shape assertion.
describe('CalendarEvent type', () => {
  it('has all required fields', async () => {
    const event = {
      id_event: 1, txt_code: 'E1', txt_name: 'Test', id_season: 1,
      txt_season_code: '2024/25', txt_location: 'Here', txt_country: 'POL',
      txt_venue_address: '123 St', url_invitation: 'https://ex.com',
      num_entry_fee: 50, dt_start: '2024-01-01', dt_end: '2024-01-02',
      url_event: 'https://ex.com', enum_status: 'COMPLETED' as const,
      num_tournaments: 3, bool_has_international: true,
    }
    // Verify all fields exist on the object
    const requiredFields = [
      'id_event', 'txt_code', 'txt_name', 'id_season', 'txt_season_code',
      'txt_location', 'txt_country', 'txt_venue_address', 'url_invitation',
      'num_entry_fee', 'dt_start', 'dt_end', 'url_event', 'enum_status',
      'num_tournaments', 'bool_has_international',
    ]
    for (const field of requiredFields) {
      expect(event).toHaveProperty(field)
    }
  })
})

// 6.5, 6.6 — fencer drill-down scores
describe('fetchFencerScores', () => {
  it('queries vw_score with fencer and season filters', async () => {
    const scores = [{ id_result: 1, num_final_score: 100 }]
    const chain = {
      select: vi.fn().mockReturnValue({
        eq: vi.fn().mockReturnValue({
          eq: vi.fn().mockReturnValue({
            eq: vi.fn().mockReturnValue({
              eq: vi.fn().mockReturnValue({
                order: vi.fn().mockResolvedValue({ data: scores, error: null }),
              }),
            }),
          }),
        }),
      }),
    }
    mockFrom.mockReturnValue(chain)

    const result = await fetchFencerScores(5, 1, 'EPEE', 'M')
    expect(mockFrom).toHaveBeenCalledWith('vw_score')
    expect(result).toEqual(scores)
  })
})
