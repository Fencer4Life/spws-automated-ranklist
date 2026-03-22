import type { Season, RankingPpwRow, RankingKadraRow, ScoreRow, DrilldownContext } from './types'

export const MOCK_SEASONS: Season[] = [
  { id_season: 2, txt_code: '2024/25', dt_start: '2024-09-01', dt_end: '2025-06-30', bool_active: true },
  { id_season: 1, txt_code: '2023/24', dt_start: '2023-09-01', dt_end: '2024-06-30', bool_active: false },
]

// PPW ranking: best-4 PPW + conditional MPW
export const MOCK_PPW_ROWS: RankingPpwRow[] = [
  { rank: 1, id_fencer: 1, fencer_name: 'ATANASSOW Aleksander', ppw_score: 420, mpw_score: 45, total_score: 465 },
  { rank: 2, id_fencer: 4, fencer_name: 'DUDEK Andrzej',        ppw_score: 380, mpw_score: 55, total_score: 435 },
  { rank: 3, id_fencer: 2, fencer_name: 'BARAŃSKI Marek',       ppw_score: 310, mpw_score: 70, total_score: 380 },
  { rank: 4, id_fencer: 3, fencer_name: 'BAZAK Jacek',          ppw_score: 280, mpw_score: 0,  total_score: 280 },
  { rank: 5, id_fencer: 5, fencer_name: 'CIEŚLIK Marek',        ppw_score: 250, mpw_score: 40, total_score: 290 },
  { rank: 6, id_fencer: 6, fencer_name: 'FIAŁKOWSKI Jerzy',     ppw_score: 220, mpw_score: 35, total_score: 255 },
  { rank: 7, id_fencer: 7, fencer_name: 'GĘZIKIEWICZ Marcin',   ppw_score: 195, mpw_score: 30, total_score: 225 },
  { rank: 8, id_fencer: 8, fencer_name: 'HAŚKO Robert',         ppw_score: 170, mpw_score: 25, total_score: 195 },
  { rank: 9, id_fencer: 9, fencer_name: 'JABŁOŃSKI Krzysztof',  ppw_score: 150, mpw_score: 20, total_score: 170 },
  { rank: 10, id_fencer: 10, fencer_name: 'KOŃCZYŁO Tomasz',    ppw_score: 130, mpw_score: 15, total_score: 145 },
  { rank: 11, id_fencer: 11, fencer_name: 'LEWANDOWSKI Piotr',  ppw_score: 110, mpw_score: 10, total_score: 120 },
  { rank: 12, id_fencer: 12, fencer_name: 'MŁYNEK Janusz',      ppw_score: 90, mpw_score: 0,   total_score: 90 },
]

// Kadra ranking: domestic (PPW+MPW) + international (best-3 PEW + conditional MEW)
export const MOCK_KADRA_ROWS: RankingKadraRow[] = [
  { rank: 1, id_fencer: 1, fencer_name: 'ATANASSOW Aleksander', ppw_total: 465, pew_total: 490, total_score: 955 },
  { rank: 2, id_fencer: 4, fencer_name: 'DUDEK Andrzej',        ppw_total: 435, pew_total: 195, total_score: 630 },
  { rank: 3, id_fencer: 2, fencer_name: 'BARAŃSKI Marek',       ppw_total: 380, pew_total: 120, total_score: 500 },
  { rank: 4, id_fencer: 5, fencer_name: 'CIEŚLIK Marek',        ppw_total: 290, pew_total: 85,  total_score: 375 },
  { rank: 5, id_fencer: 3, fencer_name: 'BAZAK Jacek',          ppw_total: 280, pew_total: 0,   total_score: 280 },
  { rank: 6, id_fencer: 6, fencer_name: 'FIAŁKOWSKI Jerzy',     ppw_total: 255, pew_total: 0,   total_score: 255 },
  { rank: 7, id_fencer: 7, fencer_name: 'GĘZIKIEWICZ Marcin',   ppw_total: 225, pew_total: 0,   total_score: 225 },
  { rank: 8, id_fencer: 8, fencer_name: 'HAŚKO Robert',         ppw_total: 195, pew_total: 0,   total_score: 195 },
  { rank: 9, id_fencer: 9, fencer_name: 'JABŁOŃSKI Krzysztof',  ppw_total: 170, pew_total: 0,   total_score: 170 },
  { rank: 10, id_fencer: 10, fencer_name: 'KOŃCZYŁO Tomasz',    ppw_total: 145, pew_total: 0,   total_score: 145 },
  { rank: 11, id_fencer: 11, fencer_name: 'LEWANDOWSKI Piotr',  ppw_total: 120, pew_total: 0,   total_score: 120 },
  { rank: 12, id_fencer: 12, fencer_name: 'MŁYNEK Janusz',      ppw_total: 90, pew_total: 0,    total_score: 90 },
]

export const MOCK_DRILLDOWN: Record<number, DrilldownContext> = {
  1:  { rank: 1,  birthYear: 1969, age: 56, category: 'V2', totalScore: 955, ppwBestCount: 4, pewBestCount: 3 },
  4:  { rank: 2,  birthYear: 1972, age: 53, category: 'V2', totalScore: 630, ppwBestCount: 4, pewBestCount: 3 },
  2:  { rank: 3,  birthYear: 1965, age: 60, category: 'V2', totalScore: 500, ppwBestCount: 4, pewBestCount: 3 },
  3:  { rank: 4,  birthYear: 1974, age: 51, category: 'V2', totalScore: 280, ppwBestCount: 4, pewBestCount: 3 },
  5:  { rank: 5,  birthYear: 1970, age: 55, category: 'V2', totalScore: 375, ppwBestCount: 4, pewBestCount: 3 },
  6:  { rank: 6,  birthYear: 1968, age: 57, category: 'V2', totalScore: 255, ppwBestCount: 4, pewBestCount: 3 },
  7:  { rank: 7,  birthYear: 1991, age: 34, category: 'V2', totalScore: 225, ppwBestCount: 4, pewBestCount: 3 },
  8:  { rank: 8,  birthYear: 1966, age: 59, category: 'V2', totalScore: 195, ppwBestCount: 4, pewBestCount: 3 },
  9:  { rank: 9,  birthYear: 1971, age: 54, category: 'V2', totalScore: 170, ppwBestCount: 4, pewBestCount: 3 },
  10: { rank: 10, birthYear: 1973, age: 52, category: 'V2', totalScore: 145, ppwBestCount: 4, pewBestCount: 3 },
  11: { rank: 11, birthYear: 1975, age: 50, category: 'V2', totalScore: 120, ppwBestCount: 4, pewBestCount: 3 },
  12: { rank: 12, birthYear: 1951, age: 74, category: 'V2', totalScore: 90,  ppwBestCount: 4, pewBestCount: 3 },
}

function makeScore(overrides: Partial<ScoreRow>): ScoreRow {
  return {
    id_result: 1,
    id_fencer: 1,
    fencer_name: 'ATANASSOW Aleksander',
    int_birth_year: null,
    id_tournament: 1,
    txt_tournament_code: 'PPW-01',
    txt_tournament_name: 'PPW Warszawa',
    dt_tournament: '2024-10-12',
    enum_type: 'PPW',
    enum_weapon: 'EPEE',
    enum_gender: 'M',
    enum_age_category: 'V2',
    int_participant_count: 28,
    num_multiplier: 1.0,
    int_place: 1,
    num_place_pts: 80,
    num_de_bonus: 5,
    num_podium_bonus: 3,
    num_final_score: 88,
    ts_points_calc: null,
    id_season: 2,
    txt_season_code: '2024/25',
    ...overrides,
  }
}

// ATANASSOW: PPW=[120,105,100,95,60] best4=420, MPW=45(included), PEW=[120,100,90,65] best3=310, MEW=180(included)
// Domestic: 420+45=465, International: 310+180=490, Grand Total: 955
export const MOCK_SCORES: Record<number, ScoreRow[]> = {
  1: [
    makeScore({ id_result: 1,  id_tournament: 1,  txt_tournament_code: 'VW-PPW1', txt_tournament_name: 'Grand Prix Warszawy',  dt_tournament: '2024-09-28', int_place: 1, int_participant_count: 32, num_final_score: 120 }),
    makeScore({ id_result: 2,  id_tournament: 2,  txt_tournament_code: 'VW-PPW2', txt_tournament_name: 'Memoriał Krakowski',   dt_tournament: '2024-11-16', int_place: 2, int_participant_count: 28, num_final_score: 105 }),
    makeScore({ id_result: 3,  id_tournament: 3,  txt_tournament_code: 'VW-PPW3', txt_tournament_name: 'Turniej Gdański',      dt_tournament: '2025-01-18', int_place: 3, int_participant_count: 24, num_final_score: 95 }),
    makeScore({ id_result: 4,  id_tournament: 4,  txt_tournament_code: 'VW-PPW4', txt_tournament_name: 'Puchar Poznania',      dt_tournament: '2025-02-22', int_place: 2, int_participant_count: 26, num_final_score: 100 }),
    makeScore({ id_result: 5,  id_tournament: 5,  txt_tournament_code: 'VW-PPW5', txt_tournament_name: 'Open Wrocław',         dt_tournament: '2025-03-08', int_place: 5, int_participant_count: 22, num_final_score: 60 }),
    makeScore({ id_result: 6,  id_tournament: 6,  txt_tournament_code: 'VW-MPW1', txt_tournament_name: 'Mistrzostwa Polski Weteranów', dt_tournament: '2025-02-15', enum_type: 'MPW', int_place: 2, int_participant_count: 40, num_multiplier: 1.2, num_final_score: 45 }),
    makeScore({ id_result: 7,  id_tournament: 10, txt_tournament_code: 'EVF-PEW1', txt_tournament_name: 'Keszthely Veterans Cup',     dt_tournament: '2024-10-19', enum_type: 'PEW', int_place: 5, int_participant_count: 48, num_final_score: 120 }),
    makeScore({ id_result: 8,  id_tournament: 11, txt_tournament_code: 'EVF-PEW2', txt_tournament_name: 'Vienna Fencing Open',        dt_tournament: '2025-01-11', enum_type: 'PEW', int_place: 8, int_participant_count: 42, num_final_score: 100 }),
    makeScore({ id_result: 9,  id_tournament: 12, txt_tournament_code: 'EVF-PEW3', txt_tournament_name: 'Prague Veterans Open',       dt_tournament: '2025-02-08', enum_type: 'PEW', int_place: 10, int_participant_count: 38, num_final_score: 90 }),
    makeScore({ id_result: 10, id_tournament: 13, txt_tournament_code: 'EVF-PEW4', txt_tournament_name: 'Berlin Veterans Trophy',     dt_tournament: '2025-03-01', enum_type: 'PEW', int_place: 15, int_participant_count: 55, num_final_score: 65 }),
    makeScore({ id_result: 11, id_tournament: 14, txt_tournament_code: 'EVF-MEW1', txt_tournament_name: 'EVF European Championships', dt_tournament: '2025-05-10', enum_type: 'MEW', int_place: 3, int_participant_count: 45, num_multiplier: 2.0, num_final_score: 180 }),
  ],
  4: [
    makeScore({ id_fencer: 4, fencer_name: 'DUDEK Andrzej', id_result: 12, id_tournament: 1, txt_tournament_code: 'VW-PPW1', txt_tournament_name: 'Grand Prix Warszawy', dt_tournament: '2024-09-28', int_place: 3, int_participant_count: 32, num_final_score: 110 }),
    makeScore({ id_fencer: 4, fencer_name: 'DUDEK Andrzej', id_result: 13, id_tournament: 2, txt_tournament_code: 'VW-PPW2', txt_tournament_name: 'Memoriał Krakowski',  dt_tournament: '2024-11-16', int_place: 1, int_participant_count: 28, num_final_score: 115 }),
    makeScore({ id_fencer: 4, fencer_name: 'DUDEK Andrzej', id_result: 14, id_tournament: 3, txt_tournament_code: 'VW-PPW3', txt_tournament_name: 'Turniej Gdański',     dt_tournament: '2025-01-18', int_place: 4, int_participant_count: 24, num_final_score: 80 }),
    makeScore({ id_fencer: 4, fencer_name: 'DUDEK Andrzej', id_result: 15, id_tournament: 4, txt_tournament_code: 'VW-PPW4', txt_tournament_name: 'Puchar Poznania',     dt_tournament: '2025-02-22', int_place: 2, int_participant_count: 26, num_final_score: 95 }),
    makeScore({ id_fencer: 4, fencer_name: 'DUDEK Andrzej', id_result: 16, id_tournament: 5, txt_tournament_code: 'VW-PPW5', txt_tournament_name: 'Open Wrocław',        dt_tournament: '2025-03-08', int_place: 6, int_participant_count: 22, num_final_score: 55 }),
    makeScore({ id_fencer: 4, fencer_name: 'DUDEK Andrzej', id_result: 17, id_tournament: 6, txt_tournament_code: 'VW-MPW1', txt_tournament_name: 'Mistrzostwa Polski Weteranów', dt_tournament: '2025-02-15', enum_type: 'MPW', int_place: 3, int_participant_count: 40, num_multiplier: 1.2, num_final_score: 55 }),
    makeScore({ id_fencer: 4, fencer_name: 'DUDEK Andrzej', id_result: 18, id_tournament: 10, txt_tournament_code: 'EVF-PEW1', txt_tournament_name: 'Keszthely Veterans Cup', dt_tournament: '2024-10-19', enum_type: 'PEW', int_place: 3, int_participant_count: 48, num_final_score: 110 }),
    makeScore({ id_fencer: 4, fencer_name: 'DUDEK Andrzej', id_result: 19, id_tournament: 11, txt_tournament_code: 'EVF-PEW2', txt_tournament_name: 'Vienna Fencing Open',    dt_tournament: '2025-01-11', enum_type: 'PEW', int_place: 12, int_participant_count: 42, num_final_score: 85 }),
  ],
  2: [
    makeScore({ id_fencer: 2, fencer_name: 'BARAŃSKI Marek', id_result: 20, id_tournament: 1, txt_tournament_code: 'VW-PPW1', txt_tournament_name: 'Grand Prix Warszawy', dt_tournament: '2024-09-28', int_place: 5, int_participant_count: 32, num_final_score: 85 }),
    makeScore({ id_fencer: 2, fencer_name: 'BARAŃSKI Marek', id_result: 21, id_tournament: 2, txt_tournament_code: 'VW-PPW2', txt_tournament_name: 'Memoriał Krakowski',  dt_tournament: '2024-11-16', int_place: 3, int_participant_count: 28, num_final_score: 90 }),
    makeScore({ id_fencer: 2, fencer_name: 'BARAŃSKI Marek', id_result: 22, id_tournament: 3, txt_tournament_code: 'VW-PPW3', txt_tournament_name: 'Turniej Gdański',     dt_tournament: '2025-01-18', int_place: 2, int_participant_count: 24, num_final_score: 75 }),
    makeScore({ id_fencer: 2, fencer_name: 'BARAŃSKI Marek', id_result: 23, id_tournament: 4, txt_tournament_code: 'VW-PPW4', txt_tournament_name: 'Puchar Poznania',     dt_tournament: '2025-02-22', int_place: 4, int_participant_count: 26, num_final_score: 70 }),
    makeScore({ id_fencer: 2, fencer_name: 'BARAŃSKI Marek', id_result: 24, id_tournament: 6, txt_tournament_code: 'VW-MPW1', txt_tournament_name: 'Mistrzostwa Polski Weteranów', dt_tournament: '2025-02-15', enum_type: 'MPW', int_place: 4, int_participant_count: 40, num_multiplier: 1.2, num_final_score: 70 }),
  ],
}
