// R.30 (FR-66): a drilldown opened from a rolling ranking names the season
// being ranked. fn_fencer_scores_rolling returns the carried previous-season
// rows first, each with its own season in txt_season_code; before the first
// event of a new season EVERY row is carried. The modal used to label itself
// with scores[0]'s season, so SPWS-2026-2027's drilldown read "SPWS-2025-2026"
// (observed on LOCAL, 2026-09-28). App now hands the modal the season it was
// opened for.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'

const { carriedRow } = vi.hoisted(() => ({
  carriedRow: (id: number, code: string) => ({
    id_result: id,
    id_fencer: 283,
    fencer_name: 'GANSZCZYK Marcin',
    int_birth_year: 1974,
    id_tournament: 100 + id,
    txt_tournament_code: `${code}-${id}`,
    txt_tournament_name: code,
    dt_tournament: '2026-02-21',
    enum_type: 'PPW',
    enum_weapon: 'SABRE',
    enum_gender: 'M',
    enum_age_category: 'V2',
    int_participant_count: 10,
    num_multiplier: 1,
    int_place: 1,
    num_place_pts: 100,
    num_de_bonus: 0,
    num_podium_bonus: 9.39,
    num_final_score: 109.39,
    ts_points_calc: null,
    id_season: 3,
    txt_season_code: 'SPWS-2025-2026',
    url_results: null,
    txt_location: 'Gdańsk',
    bool_carried_over: true,
    txt_source_season_code: 'SPWS-2025-2026',
  }),
}))

vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  refreshActiveSeason: vi.fn().mockResolvedValue(undefined),
  fetchSeasons: vi.fn().mockResolvedValue([
    { id_season: 4, txt_code: 'SPWS-2026-2027', dt_start: '2026-07-13', dt_end: '2027-07-15', bool_active: true, enum_ranking_publication: 'FULL' },
    { id_season: 3, txt_code: 'SPWS-2025-2026', dt_start: '2025-07-01', dt_end: '2026-07-12', bool_active: false, enum_ranking_publication: 'FULL' },
  ]),
  fetchScoringEngines: vi.fn().mockResolvedValue([]),
  fetchRankingPpw: vi.fn().mockResolvedValue([
    { rank: 1, id_fencer: 283, fencer_name: 'GANSZCZYK Marcin', ppw_score: 186.41, mpw_score: 117.6, total_score: 304.01, bool_has_carryover: true },
  ]),
  fetchRankingKadra: vi.fn().mockResolvedValue([]),
  fetchRankingFull: vi.fn().mockResolvedValue([]),
  fetchFencerScores: vi.fn().mockResolvedValue([]),
  fetchFencerScoresRolling: vi.fn().mockResolvedValue([carriedRow(1, 'PPW4'), carriedRow(2, 'PPW2')]),
  fetchRankingRules: vi.fn().mockResolvedValue(null),
  fetchScoringConfig: vi.fn().mockResolvedValue(null),
  fetchCalendarEvents: vi.fn().mockResolvedValue([]),
  fetchAllCalendarEvents: vi.fn().mockResolvedValue([]),
}))

vi.mock('../src/lib/admin-auth.svelte', () => import('./helpers/fakeAdminAuth.svelte'))

import App from '../src/App.svelte'
import { fetchFencerScoresRolling } from '../src/lib/api'

describe('R.30 — the drilldown names the season being ranked', () => {
  it('a rolling drilldown whose rows are all carried over still names the selected season', async () => {
    const { container } = render(App, {
      props: { 'supabase-cert-url': 'https://cert.supabase.co', 'supabase-cert-key': 'cert-key-123' },
    })
    await vi.waitFor(() => expect(container.querySelector('tr.data-row')).not.toBeNull())
    await fireEvent.click(container.querySelector('tr.data-row')!)
    await vi.waitFor(() => expect(fetchFencerScoresRolling).toHaveBeenCalled())
    await vi.waitFor(() => expect(container.querySelector('.subheader')).not.toBeNull())
    const sub = container.querySelector('.subheader')!.textContent ?? ''
    expect(sub).toContain('SPWS-2026-2027')
    expect(sub).not.toContain('SPWS-2025-2026')
  })
})
