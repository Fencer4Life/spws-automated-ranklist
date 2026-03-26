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
export type AppView = 'ranklist' | 'calendar'
export type Environment = 'CERT' | 'PROD'

export interface Season {
  id_season: number
  txt_code: string
  dt_start: string
  dt_end: string
  bool_active: boolean
}

export interface RankingPpwRow {
  rank: number
  id_fencer: number
  fencer_name: string
  ppw_score: number
  mpw_score: number
  total_score: number
}

export interface RankingKadraRow {
  rank: number
  id_fencer: number
  fencer_name: string
  ppw_total: number
  pew_total: number
  total_score: number
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

export type EventStatus = 'PLANNED' | 'SCHEDULED' | 'CHANGED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED'

export interface CalendarEvent {
  id_event: number
  txt_code: string
  txt_name: string
  id_season: number
  txt_season_code: string
  txt_location: string | null
  txt_country: string | null
  txt_venue_address: string | null
  url_invitation: string | null
  num_entry_fee: number | null
  dt_start: string | null
  dt_end: string | null
  url_event: string | null
  enum_status: EventStatus
  num_tournaments: number
  bool_has_international: boolean
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
  ranking_rules: RankingRules | null
}

export interface Filters {
  season: number | null
  weapon: WeaponType
  gender: GenderType
  category: AgeCategory
  mode: RankingMode
}
