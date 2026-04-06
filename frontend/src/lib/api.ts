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
  Organizer,
  CreateEventParams,
  UpdateEventParams,
  Tournament,
  CreateTournamentParams,
  UpdateTournamentParams,
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
  rolling?: boolean,
): Promise<RankingPpwRow[]> {
  const params: Record<string, unknown> = {
    p_weapon: weapon,
    p_gender: gender,
    p_category: category,
  }
  if (season != null) params.p_season = season
  if (rolling) params.p_rolling = true
  const { data, error } = await getClient().rpc('fn_ranking_ppw', params)
  if (error) throw error
  return data ?? []
}

export async function fetchRankingKadra(
  weapon: WeaponType,
  gender: GenderType,
  category: AgeCategory,
  season?: number | null,
  rolling?: boolean,
): Promise<RankingKadraRow[]> {
  const params: Record<string, unknown> = {
    p_weapon: weapon,
    p_gender: gender,
    p_category: category,
  }
  if (season != null) params.p_season = season
  if (rolling) params.p_rolling = true
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

export async function fetchFencerScoresRolling(
  fencerId: number,
  weapon: WeaponType,
  gender: GenderType,
  category: AgeCategory,
  season?: number | null,
): Promise<ScoreRow[]> {
  const params: Record<string, unknown> = {
    p_fencer_id: fencerId,
    p_weapon: weapon,
    p_gender: gender,
    p_category: category,
  }
  if (season != null) params.p_season = season
  const { data, error } = await getClient().rpc('fn_fencer_scores_rolling', params)
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

export async function createSeason(code: string, dtStart: string, dtEnd: string): Promise<number> {
  const { data, error } = await getClient().rpc('fn_create_season', {
    p_code: code,
    p_dt_start: dtStart,
    p_dt_end: dtEnd,
  })
  if (error) throw error
  return data as number
}

export async function updateSeason(id: number, code: string, dtStart: string, dtEnd: string): Promise<void> {
  const { error } = await getClient().rpc('fn_update_season', {
    p_id: id,
    p_code: code,
    p_dt_start: dtStart,
    p_dt_end: dtEnd,
  })
  if (error) throw error
}

export async function deleteSeason(id: number): Promise<void> {
  const { error } = await getClient().rpc('fn_delete_season', { p_id: id })
  if (error) throw error
}

export async function fetchOrganizers(): Promise<Organizer[]> {
  const { data, error } = await getClient()
    .from('tbl_organizer')
    .select('id_organizer, txt_code, txt_name')
    .order('txt_name')
  if (error) throw error
  return data ?? []
}

export async function createEvent(params: CreateEventParams): Promise<number> {
  const { data, error } = await getClient().rpc('fn_create_event', {
    p_code: params.code,
    p_name: params.name,
    p_id_season: params.seasonId,
    p_id_organizer: params.organizerId,
    p_location: params.location ?? null,
    p_dt_start: params.dtStart ?? null,
    p_dt_end: params.dtEnd ?? null,
    p_url_event: params.urlEvent ?? null,
    p_country: params.country ?? null,
    p_venue_address: params.venueAddress ?? null,
    p_invitation: params.invitation ?? null,
    p_entry_fee: params.entryFee ?? null,
    p_entry_fee_currency: params.entryFeeCurrency ?? null,
    p_weapons: params.weapons ?? null,
  })
  if (error) throw error
  return data as number
}

export async function updateEvent(id: number, params: UpdateEventParams): Promise<void> {
  const { error } = await getClient().rpc('fn_update_event', {
    p_id: id,
    p_name: params.name,
    p_location: params.location ?? null,
    p_dt_start: params.dtStart ?? null,
    p_dt_end: params.dtEnd ?? null,
    p_url_event: params.urlEvent ?? null,
    p_country: params.country ?? null,
    p_venue_address: params.venueAddress ?? null,
    p_invitation: params.invitation ?? null,
    p_entry_fee: params.entryFee ?? null,
    p_entry_fee_currency: params.entryFeeCurrency ?? null,
    p_id_organizer: params.organizerId ?? null,
    p_weapons: params.weapons ?? null,
  })
  if (error) throw error
}

export async function updateEventStatus(id: number, status: string): Promise<void> {
  const { error } = await getClient()
    .from('tbl_event')
    .update({ enum_status: status })
    .eq('id_event', id)
  if (error) throw error
}

export async function deleteEventCascade(id: number): Promise<void> {
  const { error } = await getClient().rpc('fn_delete_event_cascade', { p_id: id })
  if (error) throw error
}

export async function fetchMatchCandidates(): Promise<MatchCandidate[]> {
  const { data, error } = await getClient()
    .from('vw_match_candidates')
    .select('*')
    .order('id_match', { ascending: false })
    .limit(200)
  if (error) throw error
  return (data ?? []) as MatchCandidate[]
}

export async function fetchAllTournaments(eventIds: number[]): Promise<Tournament[]> {
  if (eventIds.length === 0) return []
  const { data, error } = await getClient()
    .from('tbl_tournament')
    .select('*')
    .in('id_event', eventIds)
    .order('dt_tournament')
  if (error) throw error
  return data ?? []
}

export async function fetchTournaments(eventId: number): Promise<Tournament[]> {
  const { data, error } = await getClient()
    .from('tbl_tournament')
    .select('*')
    .eq('id_event', eventId)
    .order('dt_tournament')
  if (error) throw error
  return data ?? []
}

export async function createTournament(params: CreateTournamentParams): Promise<number> {
  const { data, error } = await getClient().rpc('fn_create_tournament', {
    p_id_event: params.idEvent,
    p_code: params.code,
    p_name: params.name,
    p_type: params.type,
    p_weapon: params.weapon,
    p_gender: params.gender,
    p_age_category: params.ageCategory,
    p_dt_tournament: params.dtTournament ?? null,
    p_participant_count: params.participantCount ?? null,
    p_url_results: params.urlResults ?? null,
  })
  if (error) throw error
  return data as number
}

export async function updateTournament(id: number, params: UpdateTournamentParams): Promise<void> {
  const { error } = await getClient().rpc('fn_update_tournament', {
    p_id: id,
    p_url_results: params.urlResults ?? null,
    p_import_status: params.importStatus ?? null,
    p_status_reason: params.statusReason ?? null,
  })
  if (error) throw error
}

export async function deleteTournamentCascade(id: number): Promise<void> {
  const { error } = await getClient().rpc('fn_delete_tournament_cascade', { p_id: id })
  if (error) throw error
}
