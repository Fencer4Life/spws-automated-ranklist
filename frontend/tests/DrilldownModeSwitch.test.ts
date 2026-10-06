// DD.MODE.02 (A1, plan drilldown-points-order-and-uncounted-2026-10-01): the
// drilldown's PPW | Ranking switch used to change only the modal, so its
// header kept the rank from the list behind it — KRZEMIŃSKI read "#2" in the
// PPW view, where he is #1 (LOCAL, 2026-10-01). The switch now switches the
// page too: the list, the rank in the header and the modal show one view.
// UX proposal A moved the rank into the headline (.score-rank) beside the
// total (.score-total), and the switch into the data row (.headline-row).

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'

const { scoreRow } = vi.hoisted(() => ({
  scoreRow: (id: number, type: string, pts: number) => ({
    id_result: id,
    id_fencer: 222,
    fencer_name: 'KRZEMIŃSKI Mariusz',
    int_birth_year: 1962,
    id_tournament: 100 + id,
    txt_tournament_code: `${type}1-V3-M-EPEE-2026-2027`,
    txt_tournament_name: 'V3 M EPEE',
    dt_tournament: '2026-09-26',
    enum_type: type,
    enum_weapon: 'EPEE',
    enum_gender: 'M',
    enum_age_category: 'V3',
    int_participant_count: 9,
    num_multiplier: 1,
    int_place: 1,
    num_place_pts: null,
    num_de_bonus: null,
    num_podium_bonus: null,
    num_final_score: pts,
    ts_points_calc: null,
    id_season: 4,
    txt_season_code: 'SPWS-2026-2027',
    url_results: null,
    txt_location: 'Opole',
    bool_carried_over: false,
  }),
}))

vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  fetchSeasons: vi.fn().mockResolvedValue([
    { id_season: 4, txt_code: 'SPWS-2026-2027', dt_start: '2026-07-13', dt_end: '2027-07-15', bool_active: true, enum_ranking_publication: 'FULL' },
  ]),
  fetchScoringEngines: vi.fn().mockResolvedValue([]),
  fetchRankingPpw: vi.fn().mockResolvedValue([
    { rank: 1, id_fencer: 222, fencer_name: 'KRZEMIŃSKI Mariusz', ppw_score: 206.7, mpw_score: 131.3, total_score: 338 },
  ]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  fetchRankingFull: vi.fn().mockResolvedValue([
    { rank: 2, id_fencer: 222, fencer_name: 'KRZEMIŃSKI Mariusz', spws_total: 338, evf_plus_total: 183.6, total_score: 521.6 },
  ]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchFencerScoresRolling: vi.fn().mockResolvedValue([scoreRow(1, 'PPW', 108.72), scoreRow(2, 'PEW', 51.71)]),
  fetchRankingRules: vi.fn().mockResolvedValue(null),
  fetchScoringConfig: vi.fn().mockResolvedValue({
    show_evf_toggle: true,
    show_evf_toggle_calendar: true,
    default_ranking_mode: 'RANKING',
  }),
  fetchCalendarEvents: vi.fn().mockResolvedValue([]),
  fetchAllCalendarEvents: vi.fn().mockResolvedValue([]),
}))

vi.mock('../src/lib/admin-auth.svelte', () => import('./helpers/fakeAdminAuth.svelte'))

import App from '../src/App.svelte'
import { fetchRankingPpw } from '../src/lib/api'

describe('DD.MODE.02 — the drilldown switch switches the page too', () => {
  it('switching the modal to PPW reloads the PPW list and shows the PPW rank', async () => {
    const { container } = render(App, {
      props: { 'supabase-cert-url': 'https://cert.supabase.co', 'supabase-cert-key': 'cert-key-123' },
    })
    await vi.waitFor(() => expect(container.querySelector('tr.data-row')).not.toBeNull())
    await fireEvent.click(container.querySelector('tr.data-row')!)
    await vi.waitFor(() => expect(container.querySelector('.score-rank')?.textContent?.trim()).toBe('2'))

    const ppwBtn = Array.from(container.querySelectorAll('.headline-row .toggle-btn')).find(
      (b) => b.textContent?.trim() === 'PPW',
    )!
    await fireEvent.click(ppwBtn)

    await vi.waitFor(() => expect(fetchRankingPpw).toHaveBeenCalled())
    await vi.waitFor(() => expect(container.querySelector('.score-rank')?.textContent?.trim()).toBe('1'))
    expect(container.querySelector('.score-total')?.textContent?.trim()).toBe('338')
    expect(container.querySelector('.filter-bar .toggle-btn.active')?.textContent?.trim()).toBe('PPW')
    // The modal stays open, now in the PPW view: no EVF+ table.
    expect(container.querySelector('.modal-overlay')).not.toBeNull()
    expect(container.querySelectorAll('.table-section table').length).toBe(1)
  })
})
