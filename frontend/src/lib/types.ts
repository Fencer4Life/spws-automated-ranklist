export type WeaponType = 'EPEE' | 'FOIL' | 'SABRE'
export type GenderType = 'M' | 'F'
export type AgeCategory = 'V0' | 'V1' | 'V2' | 'V3' | 'V4'
export type TournamentType = 'PPW' | 'MPW' | 'PEW' | 'MEW' | 'MSW' | 'PSW'

export interface RankingBucket {
  types: string[]
  best?: number
  always?: boolean
}

export interface RankingRules {
  domestic: RankingBucket[]
  international: RankingBucket[]
}
export type RankingMode = 'PPW' | 'KADRA'
export type AppView = 'ranklist' | 'calendar' | 'admin_seasons' | 'admin_events' | 'admin_fencers'
export type FencerTab = 'identities' | 'birth_year_review'
export type BirthYearFilter = 'ALL' | 'ESTIMATED' | 'MISSING' | 'CONFIRMED'
export type Environment = 'CERT' | 'PROD'

export interface Season {
  id_season: number
  txt_code: string
  dt_start: string
  dt_end: string
  bool_active: boolean
  // Phase 3 admin-editable fields. Optional in the runtime payload because
  // older seed exports / view rows may not surface them yet; UI gracefully
  // falls back to defaults (366 / null / EVENT_FK_MATCHING).
  int_carryover_days?: number
  enum_european_event_type?: EuropeanEventType
  enum_carryover_engine?: CarryoverEngine
}

export interface RankingPpwRow {
  rank: number
  id_fencer: number
  fencer_name: string
  ppw_score: number
  mpw_score: number
  total_score: number
  bool_has_carryover?: boolean
}

export interface RankingKadraRow {
  rank: number
  id_fencer: number
  fencer_name: string
  ppw_total: number
  pew_total: number
  total_score: number
  bool_has_carryover?: boolean
}

export interface ScoreRow {
  id_result: number
  id_fencer: number
  fencer_name: string
  int_birth_year: number | null
  id_tournament: number
  txt_tournament_code: string
  txt_tournament_name: string | null
  dt_tournament: string | null
  enum_type: TournamentType
  enum_weapon: WeaponType
  enum_gender: GenderType
  enum_age_category: AgeCategory
  int_participant_count: number | null
  num_multiplier: number | null
  int_place: number
  num_place_pts: number | null
  num_de_bonus: number | null
  num_podium_bonus: number | null
  num_final_score: number | null
  ts_points_calc: string | null
  id_season: number
  txt_season_code: string
  url_results: string | null
  txt_location: string | null
  bool_carried_over?: boolean
  txt_source_season_code?: string
}

export interface TournamentDetail {
  url_results: string | null
  txt_location: string | null
}

export interface DrilldownContext {
  rank: number
  birthYear: number | null
  age: number | null
  category: AgeCategory
  totalScore: number
  ppwBestCount: number
  pewBestCount: number
}

export type EventStatus = 'CREATED' | 'PLANNED' | 'SCHEDULED' | 'CHANGED' | 'IN_PROGRESS' | 'SCORED' | 'COMPLETED' | 'CANCELLED'

export type CarryoverEngine = 'EVENT_FK_MATCHING' | 'EVENT_CODE_MATCHING'

// Ordered for display purposes (default first, legacy last). When a new engine
// is added to the SQL enum `enum_event_carryover_engine`, append it here too.
export const CARRYOVER_ENGINE_VALUES: CarryoverEngine[] = ['EVENT_FK_MATCHING', 'EVENT_CODE_MATCHING']

export type EuropeanEventType = 'IMEW' | 'DMEW' | null

export interface SkeletonByKind {
  PPW?: number
  PEW?: number
  MPW?: number
  MSW?: number
  IMEW?: number
  DMEW?: number
}

export interface InitSeasonResult {
  skeletons_created: number
  by_kind: SkeletonByKind
}

export interface CreateSeasonWithSkeletonsResult {
  id_season: number
  skeletons_created: number
}

export interface CalendarEvent {
  id_event: number
  txt_code: string
  txt_name: string
  id_season: number
  txt_season_code: string
  id_organizer: number | null
  txt_organizer_name: string | null
  txt_location: string | null
  txt_country: string | null
  txt_venue_address: string | null
  url_invitation: string | null
  num_entry_fee: number | null
  txt_entry_fee_currency: string | null
  dt_start: string | null
  dt_end: string | null
  arr_weapons: WeaponType[]
  url_event: string | null
  enum_status: EventStatus
  num_tournaments: number
  bool_has_international: boolean
  url_registration: string | null
  dt_registration_deadline: string | null
  url_event_2: string | null
  url_event_3: string | null
  url_event_4: string | null
  url_event_5: string | null
}

export interface ScoringConfig {
  season_code: string
  mp_value: number
  podium_gold: number
  podium_silver: number
  podium_bronze: number
  ppw_multiplier: number
  ppw_best_count: number
  ppw_total_rounds: number
  mpw_multiplier: number
  mpw_droppable: boolean
  pew_multiplier: number
  pew_best_count: number
  mew_multiplier: number
  mew_droppable: boolean
  msw_multiplier: number
  psw_multiplier: number
  min_participants_evf: number
  min_participants_ppw: number
  show_evf_toggle: boolean
  ranking_rules: RankingRules | null
  // Phase 3 — selected carry-over engine for the season. Lives on
  // tbl_season.enum_carryover_engine but is exposed alongside the scoring
  // config so the ScoringConfigEditor's engine dropdown can read/write it.
  // Optional because legacy seasons predate the field; default is FK.
  engine?: CarryoverEngine
}

export type ImportStatus = 'PLANNED' | 'PENDING' | 'IMPORTED' | 'SCORED' | 'REJECTED'

export interface Tournament {
  id_tournament: number
  id_event: number
  txt_code: string
  txt_name: string | null
  enum_type: TournamentType
  enum_weapon: WeaponType
  enum_gender: GenderType
  enum_age_category: AgeCategory
  dt_tournament: string | null
  int_participant_count: number | null
  num_multiplier: number | null
  url_results: string | null
  enum_import_status: ImportStatus
  txt_import_status_reason: string | null
}

export interface CreateTournamentParams {
  idEvent: number
  code: string
  name: string
  type: TournamentType
  weapon: WeaponType
  gender: GenderType
  ageCategory: AgeCategory
  dtTournament?: string
  participantCount?: number
  urlResults?: string
}

export interface UpdateTournamentParams {
  code?: string
  urlResults?: string
  importStatus?: ImportStatus
  statusReason?: string
}

export interface Organizer {
  id_organizer: number
  txt_code: string
  txt_name: string
}

export interface CreateEventParams {
  code: string
  name: string
  seasonId: number
  organizerId: number
  location?: string
  dtStart?: string
  dtEnd?: string
  urlEvent?: string
  country?: string
  venueAddress?: string
  invitation?: string
  entryFee?: number
  entryFeeCurrency?: string
  weapons?: WeaponType[]
  registration?: string
  registrationDeadline?: string
  urlEvent2?: string | null
  urlEvent3?: string | null
  urlEvent4?: string | null
  urlEvent5?: string | null
}

export interface UpdateEventParams {
  name: string
  location?: string
  dtStart?: string
  dtEnd?: string
  urlEvent?: string | null
  country?: string
  venueAddress?: string
  invitation?: string
  entryFee?: number
  entryFeeCurrency?: string
  organizerId?: number
  weapons?: WeaponType[]
  registration?: string
  registrationDeadline?: string
  urlEvent2?: string | null
  urlEvent3?: string | null
  urlEvent4?: string | null
  urlEvent5?: string | null
  // Phase 3 (ADR-044): the v2 fn_update_event signature accepts these.
  // NULL on either means "leave unchanged" — matches organizerId semantics
  // and preserves backward-compat for callers still on the 19-arg shape.
  code?: string
  priorEventId?: number | null
}

export type MatchStatus = 'PENDING' | 'AUTO_MATCHED' | 'UNMATCHED' | 'APPROVED' | 'NEW_FENCER' | 'DISMISSED'

export interface MatchCandidate {
  id_match: number
  id_result: number
  txt_scraped_name: string
  id_fencer: number | null
  txt_fencer_name: string | null
  num_confidence: number | null
  enum_status: MatchStatus
  txt_admin_note: string | null
  txt_tournament_code: string | null
  enum_type: TournamentType | null
  enum_tournament_gender: GenderType | null
  enum_fencer_gender: GenderType | null
}

export interface FencerListItem {
  id_fencer: number
  txt_surname: string
  txt_first_name: string
  int_birth_year: number | null
  txt_club: string | null
  enum_gender: GenderType | null
  bool_birth_year_estimated: boolean
  txt_nationality: string | null
}

export interface FencerTournamentRow {
  id_result: number
  txt_tournament_code: string
  txt_tournament_name: string | null
  dt_tournament: string | null
  enum_type: TournamentType
  enum_weapon: WeaponType
  enum_gender: GenderType
  enum_age_category: AgeCategory
  int_place: number
  num_final_score: number | null
  int_participant_count: number | null
  txt_season_code: string
  txt_location: string | null
}

export interface FencerCandidate {
  id_fencer: number
  txt_surname: string
  txt_first_name: string
  int_birth_year: number | null
  txt_club: string | null
  num_confidence: number
  bool_age_match: boolean
}

export interface Filters {
  season: number | null
  weapon: WeaponType
  gender: GenderType
  category: AgeCategory
  mode: RankingMode
}
