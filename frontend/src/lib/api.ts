import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import type {
  Season,
  RankingPpwRow,
  RankingKadraRow,
  ScoreRow,
  TournamentDetail,
  CalendarEvent,
  WeaponType,
  GenderType,
  AgeCategory,
  RankingRules,
  ScoringConfig,
} from './types'

let client: SupabaseClient | null = null

export function initClient(url: string, key: string): SupabaseClient {
  client = createClient(url, key)
  return client
}

export function getClient(): SupabaseClient {
  if (!client) throw new Error('Supabase client not initialized. Call initClient first.')
  return client
}

export async function fetchSeasons(): Promise<Season[]> {
  const { data, error } = await getClient()
    .from('tbl_season')
    .select('id_season, txt_code, dt_start, dt_end, bool_active')
    .order('dt_start', { ascending: false })
  if (error) throw error
  return data ?? []
}

export async function fetchRankingPpw(
  weapon: WeaponType,
  gender: GenderType,
  category: AgeCategory,
  season?: number | null,
): Promise<RankingPpwRow[]> {
  const params: Record<string, unknown> = {
    p_weapon: weapon,
    p_gender: gender,
    p_category: category,
  }
  if (season != null) params.p_season = season
  const { data, error } = await getClient().rpc('fn_ranking_ppw', params)
  if (error) throw error
  return data ?? []
}

export async function fetchRankingKadra(
  weapon: WeaponType,
  gender: GenderType,
  category: AgeCategory,
  season?: number | null,
): Promise<RankingKadraRow[]> {
  const params: Record<string, unknown> = {
    p_weapon: weapon,
    p_gender: gender,
    p_category: category,
  }
  if (season != null) params.p_season = season
  const { data, error } = await getClient().rpc('fn_ranking_kadra', params)
  if (error) throw error
  return data ?? []
}

export async function fetchFencerScores(
  fencerId: number,
  seasonId: number,
  weapon: WeaponType,
  gender: GenderType,
): Promise<ScoreRow[]> {
  const { data, error } = await getClient()
    .from('vw_score')
    .select('*')
    .eq('id_fencer', fencerId)
    .eq('id_season', seasonId)
    .eq('enum_weapon', weapon)
    .eq('enum_gender', gender)
    .order('num_final_score', { ascending: false })
  if (error) throw error
  return data ?? []
}

export async function fetchRankingRules(seasonId: number): Promise<RankingRules | null> {
  const { data, error } = await getClient()
    .from('tbl_scoring_config')
    .select('json_ranking_rules')
    .eq('id_season', seasonId)
    .single()
  if (error) return null
  return (data?.json_ranking_rules as RankingRules | null) ?? null
}

export async function fetchCalendarEvents(seasonId: number): Promise<CalendarEvent[]> {
  const { data, error } = await getClient()
    .from('vw_calendar')
    .select('*')
    .eq('id_season', seasonId)
    .order('dt_start', { ascending: true })
  if (error) throw error
  return data ?? []
}

export async function fetchTournamentDetail(
  tournamentId: number,
): Promise<TournamentDetail | null> {
  const { data, error } = await getClient()
    .from('tbl_tournament')
    .select('url_results')
    .eq('id_tournament', tournamentId)
    .single()
  if (error) return null

  const { data: eventData } = await getClient()
    .from('tbl_tournament')
    .select('id_event')
    .eq('id_tournament', tournamentId)
    .single()

  let txt_location: string | null = null
  if (eventData?.id_event) {
    const { data: ev } = await getClient()
      .from('tbl_event')
      .select('txt_location')
      .eq('id_event', eventData.id_event)
      .single()
    txt_location = ev?.txt_location ?? null
  }

  return { url_results: data?.url_results ?? null, txt_location }
}

export async function fetchScoringConfig(seasonId: number): Promise<ScoringConfig | null> {
  const { data, error } = await getClient().rpc('fn_export_scoring_config', {
    p_id_season: seasonId,
  })
  if (error) return null
  return (data as ScoringConfig | null) ?? null
}

export async function saveScoringConfig(config: Record<string, unknown>): Promise<void> {
  const { error } = await getClient().rpc('fn_import_scoring_config', {
    p_config: config,
  })
  if (error) throw error
}
