export type WeaponType = 'EPEE' | 'FOIL' | 'SABRE'
export type GenderType = 'M' | 'F'
export type AgeCategory = 'V0' | 'V1' | 'V2' | 'V3' | 'V4'
export type TournamentType = 'PPW' | 'MPW' | 'PEW' | 'MEW' | 'MSW'
export type RankingMode = 'PPW' | 'KADRA'

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

export interface Filters {
  season: number | null
  weapon: WeaponType
  gender: GenderType
  category: AgeCategory
  mode: RankingMode
}
