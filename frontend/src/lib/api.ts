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
  FencerListItem,
  FencerTournamentRow,
  CarryoverEngine,
  EuropeanEventType,
  CreateSeasonWithSkeletonsResult,
  FencerWithAliases,
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

export async function refreshActiveSeason(): Promise<void> {
  await getClient().rpc('fn_refresh_active_season')
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

export async function fetchPriorSeasonEvents(seasonIds: number[]): Promise<CalendarEvent[]> {
  if (seasonIds.length === 0) return []
  const { data, error } = await getClient()
    .from('vw_calendar')
    .select('*')
    .in('id_season', seasonIds)
    .order('txt_code', { ascending: true })
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
  const client = getClient()
  const { data, error } = await client.rpc('fn_export_scoring_config', {
    p_id_season: seasonId,
  })
  if (error) return null
  if (!data) return null
  // Phase 3 (ADR-045): merge the season's carry-over engine into the returned
  // config so ScoringConfigEditor's dropdown reflects the live tbl_season value.
  // The engine is not part of fn_export_scoring_config's payload (it lives on
  // tbl_season, not tbl_scoring_config).
  const { data: seasonRow } = await client
    .from('tbl_season')
    .select('enum_carryover_engine')
    .eq('id_season', seasonId)
    .single()
  const engine = (seasonRow as { enum_carryover_engine?: string } | null)?.enum_carryover_engine
  return { ...(data as ScoringConfig), engine: engine as ScoringConfig['engine'] }
}

export async function saveScoringConfig(config: Record<string, unknown>): Promise<void> {
  const { error } = await getClient().rpc('fn_import_scoring_config', {
    p_config: config,
  })
  if (error) throw error
}

// Phase 3 (ADR-045): patch tbl_season.enum_carryover_engine in isolation. Used
// by App.svelte's scoring-save handler to flip the engine without going through
// fn_update_season (which doesn't carry an engine param). Direct PostgREST
// PATCH on the table — RLS allows authenticated writes per existing policy.
export async function updateSeasonCarryoverEngine(seasonId: number, engine: string): Promise<void> {
  const { error } = await getClient()
    .from('tbl_season')
    .update({ enum_carryover_engine: engine })
    .eq('id_season', seasonId)
  if (error) throw error
}

// Phase 3 (ADR-044): patch tbl_season's carry-over fields directly. Same
// rationale as updateSeasonCarryoverEngine — fn_update_season is a 4-arg RPC
// we don't want to widen for these admin-form additions.
export async function updateSeasonCarryoverFields(
  seasonId: number,
  carryoverDays: number,
  europeanType: EuropeanEventType,
): Promise<void> {
  const { error } = await getClient()
    .from('tbl_season')
    .update({
      int_carryover_days: carryoverDays,
      enum_european_event_type: europeanType,
    })
    .eq('id_season', seasonId)
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

// ============================================================================
// Phase 3 — season-init wizard RPCs (ADR-044)
// ============================================================================

// Wizard step 2 calls this to pre-fill ScoringConfigEditor with the prior
// season's config. Returns NULL if no chronological prior exists (first-ever
// season) — the wizard then keeps ScoringConfigEditor's static defaults.
export async function copyPriorScoringConfig(dtStart: string): Promise<ScoringConfig | null> {
  const { data, error } = await getClient().rpc('fn_copy_prior_scoring_config', {
    p_dt_start: dtStart,
  })
  if (error) throw error
  return (data as ScoringConfig | null) ?? null
}

// The wizard's atomic commit (✓ Utwórz). Backend wraps season insert + scoring
// config overwrite + skeleton init in one transaction; any failure rolls
// everything back so partial state never persists.
export async function createSeasonWithSkeletons(payload: {
  code: string
  dt_start: string
  dt_end: string
  carryover_days: number
  european_type: EuropeanEventType
  carryover_engine: CarryoverEngine
  scoring_config: ScoringConfig
  show_evf: boolean
}): Promise<CreateSeasonWithSkeletonsResult> {
  const { data, error } = await getClient().rpc('fn_create_season_with_skeletons', {
    p_code: payload.code,
    p_dt_start: payload.dt_start,
    p_dt_end: payload.dt_end,
    p_carryover_days: payload.carryover_days,
    p_european_type: payload.european_type,
    p_carryover_engine: payload.carryover_engine,
    p_scoring_config: payload.scoring_config as unknown as Record<string, unknown>,
    p_show_evf: payload.show_evf,
  })
  if (error) throw error
  // RPC returns a single-row TABLE; PostgREST surfaces it as an array.
  const row = Array.isArray(data) ? data[0] : data
  return row as CreateSeasonWithSkeletonsResult
}

// EDIT form's "↶ Cofnij całość" link. Backend refuses if any skeleton has
// advanced past CREATED; otherwise deletes children → events → scoring_config
// → season in a single transaction.
export async function revertSeasonInit(seasonId: number): Promise<void> {
  const { error } = await getClient().rpc('fn_revert_season_init', {
    p_id_season: seasonId,
  })
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
    p_registration: params.registration ?? null,
    p_registration_deadline: params.registrationDeadline ?? null,
    p_url_event_2: params.urlEvent2 ?? null,
    p_url_event_3: params.urlEvent3 ?? null,
    p_url_event_4: params.urlEvent4 ?? null,
    p_url_event_5: params.urlEvent5 ?? null,
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
    p_registration: params.registration ?? null,
    p_registration_deadline: params.registrationDeadline ?? null,
    p_url_event_2: params.urlEvent2 ?? null,
    p_url_event_3: params.urlEvent3 ?? null,
    p_url_event_4: params.urlEvent4 ?? null,
    p_url_event_5: params.urlEvent5 ?? null,
    // Phase 3 (ADR-044) — fn_update_event v2 trailing params. NULL means
    // "leave unchanged" so legacy callers still see no change in behavior.
    p_code: params.code ?? null,
    p_id_prior_event: params.priorEventId ?? null,
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

export async function approveMatch(matchId: number, fencerId: number): Promise<void> {
  const { error } = await getClient().rpc('fn_approve_match', { p_match_id: matchId, p_fencer_id: fencerId })
  if (error) throw error
}

export async function dismissMatch(matchId: number, note?: string): Promise<void> {
  const { error } = await getClient().rpc('fn_dismiss_match', { p_match_id: matchId, p_note: note ?? null })
  if (error) throw error
}

export async function createFencerFromMatch(matchId: number, surname: string, firstName: string, birthYear?: number, gender?: GenderType, birthYearEstimated?: boolean): Promise<void> {
  const { error } = await getClient().rpc('fn_create_fencer_from_match', {
    p_match_id: matchId, p_surname: surname, p_first_name: firstName, p_birth_year: birthYear ?? null, p_gender: gender ?? null, p_birth_year_estimated: birthYearEstimated ?? true
  })
  if (error) throw error
}

export async function undismissMatch(matchId: number): Promise<void> {
  const { error } = await getClient().rpc('fn_undismiss_match', { p_match_id: matchId })
  if (error) throw error
}

export async function fetchAllFencers(): Promise<FencerListItem[]> {
  const { data, error } = await getClient()
    .from('tbl_fencer')
    .select('id_fencer, txt_surname, txt_first_name, int_birth_year, txt_club, enum_gender, bool_birth_year_estimated, txt_nationality')
    .order('txt_surname')
  if (error) throw error
  return data ?? []
}

export async function fetchFencerTournamentHistory(fencerId: number): Promise<FencerTournamentRow[]> {
  const { data, error } = await getClient()
    .from('vw_score')
    .select('id_result, txt_tournament_code, txt_tournament_name, dt_tournament, enum_type, enum_weapon, enum_gender, enum_age_category, int_place, num_final_score, int_participant_count, txt_season_code, txt_location')
    .eq('id_fencer', fencerId)
    .order('dt_tournament', { ascending: false })
  if (error) throw error
  return data ?? []
}

export async function updateFencerBirthYear(fencerId: number, birthYear: number, estimated: boolean): Promise<void> {
  const { error } = await getClient().rpc('fn_update_fencer_birth_year', {
    p_fencer_id: fencerId, p_birth_year: birthYear, p_estimated: estimated
  })
  if (error) throw error
}

export async function updateFencerGender(fencerId: number, gender: GenderType): Promise<void> {
  const { error } = await getClient().rpc('fn_update_fencer_gender', {
    p_fencer_id: fencerId, p_gender: gender
  })
  if (error) throw error
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
    p_code: params.code ?? null,
  })
  if (error) throw error
}

export async function deleteTournamentCascade(id: number): Promise<void> {
  const { error } = await getClient().rpc('fn_delete_tournament_cascade', { p_id: id })
  if (error) throw error
}

export type DispatchResult =
  | { ok: true; workflow: string; inputs: Record<string, string>; runs_url: string }
  | { ok: false; code: string; message: string }

// ADR-041: Server-side workflow dispatch via Supabase Edge Function.
// The PAT lives only as a Supabase env secret in the function's runtime —
// never in the browser. The caller's session JWT is auto-attached by
// supabase-js; the function verifies it before reaching the handler.
export async function requestDispatch(
  workflow: string, inputs: Record<string, string>
): Promise<DispatchResult> {
  const { data, error } = await getClient().functions.invoke('dispatch-workflow', {
    body: { workflow, inputs },
  })
  if (error) {
    return { ok: false, code: 'invoke_error', message: error.message ?? String(error) }
  }
  return data as DispatchResult
}

export async function triggerGitHubWorkflow(
  pat: string, repo: string, workflow: string, inputs: Record<string, string>
): Promise<void> {
  const resp = await fetch(
    `https://api.github.com/repos/${repo}/actions/workflows/${workflow}/dispatches`,
    {
      method: 'POST',
      headers: {
        Authorization: `token ${pat}`,
        Accept: 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ ref: 'main', inputs }),
    },
  )
  if (!resp.ok) {
    const text = await resp.text()
    throw new Error(`GitHub Actions trigger failed (${resp.status}): ${text}`)
  }
}

// ===========================================================================
// Phase 4 (ADR-050) — Fencer alias management
// ===========================================================================

export async function listFencerAliases(): Promise<FencerWithAliases[]> {
  const { data, error } = await getClient().rpc('fn_list_fencer_aliases')
  if (error) throw new Error(`fn_list_fencer_aliases: ${error.message}`)
  return (data ?? []) as FencerWithAliases[]
}

export interface AliasTransferResult {
  alias: string
  from_fencer: number
  to_fencer: number
  results_moved: number
  tournaments_recomputed: number
}

export async function transferFencerAlias(
  fromFencer: number, toFencer: number, alias: string,
): Promise<AliasTransferResult> {
  const { data, error } = await getClient().rpc('fn_transfer_fencer_alias', {
    p_from_fencer: fromFencer,
    p_to_fencer: toFencer,
    p_alias: alias,
  })
  if (error) throw new Error(`fn_transfer_fencer_alias: ${error.message}`)
  return data as AliasTransferResult
}

export interface NewFencerData {
  txt_surname: string
  txt_first_name: string
  int_birth_year: number
  enum_gender: GenderType
  txt_nationality?: string
  txt_club?: string
}

export interface AliasSplitResult {
  new_fencer_id: number
  transfer_result: AliasTransferResult
}

export async function splitFencerFromAlias(
  fromFencer: number, alias: string, newFencerData: NewFencerData,
): Promise<AliasSplitResult> {
  const { data, error } = await getClient().rpc('fn_split_fencer_from_alias', {
    p_from_fencer: fromFencer,
    p_alias: alias,
    p_new_fencer_data: newFencerData,
  })
  if (error) throw new Error(`fn_split_fencer_from_alias: ${error.message}`)
  return data as AliasSplitResult
}

export interface AliasDiscardResult {
  alias: string
  fencer: number
  results_deleted: number
  tournaments_recomputed: number
}

export async function discardFencerAliasAndResults(
  fromFencer: number, alias: string,
): Promise<AliasDiscardResult> {
  const { data, error } = await getClient().rpc('fn_discard_fencer_alias_and_results', {
    p_from_fencer: fromFencer,
    p_alias: alias,
  })
  if (error) throw new Error(`fn_discard_fencer_alias_and_results: ${error.message}`)
  return data as AliasDiscardResult
}

// Phase 5 — operator clicks Keep ➜ alias is appended to
// json_user_confirmed_aliases so the staging verdict logic stops
// surfacing it as ❌ on subsequent runs.
export async function confirmFencerAlias(
  idFencer: number, alias: string,
): Promise<unknown> {
  const { data, error } = await getClient().rpc('fn_confirm_fencer_alias', {
    p_id_fencer: idFencer,
    p_alias: alias,
  })
  if (error) throw new Error(`fn_confirm_fencer_alias: ${error.message}`)
  return data
}
