// =============================================================================
// The SPWS scoring formula — the single browser-side implementation
// =============================================================================
// doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html §08, step 8;
// ADR-102 (one module, generated into the published pages) and ADR-103 (the
// 2026/2027 engine).
//
// THE FORMULA LIVES IN EXACTLY TWO PLACES
// -----------------------------------------------------------------------------
// Here, and in the SQL strategies (fn_score_evf_classic_v1_2025_2026 /
// fn_score_spws_place_medal_v1_2026_2027). A client-side implementation is
// unavoidable because the scoring-table annex renders a 64 x 64 grid and
// re-renders on every rank-coefficient change, so a per-cell RPC is not viable.
// frontend/tests/scoring.test.ts is the pin between the two, with every
// expectation derived from the database.
//
// WHAT IS A PARAMETER AND WHAT IS THE ENGINE
// -----------------------------------------------------------------------------
// mp_value, the DE round and the podium coefficients are SEASON CONFIGURATION
// delivered by fn_public_scoring_params, one row per tournament type. They feed
// EVF classic, and the 2026/2027 engine's range from 32. Everything else about
// the 2026/2027 engine — log2 N, 3.5 per fencer below, the 13/7/3 medal, the
// table up to 3 and the switch at 32 — belongs to the engine version, and is
// therefore a constant here, exactly as it is in SQL.
// =============================================================================

export const CLASSIC_ENGINE = 'EVF_CLASSIC_V1_2025_2026'
export const PLACE_MEDAL_ENGINE = 'SPWS_PLACE_MEDAL_V1_2026_2027'

/** The constants of SPWS_PLACE_MEDAL_V1_2026_2027 (ADR-103 §1). Not settings. */
export const PLACE_MEDAL = {
  /** N <= tableUpTo scores N - place + 1. */
  tableUpTo: 3,
  /** From this bracket size the engine is EVF classic. */
  evfFrom: 32,
  /** Points for each fencer with a worse result in the bracket. */
  perBelow: 3.5,
  /** Gold, silver, bronze within the own category, times the cube root of K. */
  medal: [13, 7, 3] as const,
}

/** The range that scored a result — tbl_result.enum_score_method. */
export type ScoreMethod = 'TABLE' | 'PLACE_MEDAL' | 'EVF_CLASSIC'

/** One tournament type's parameters, as fn_public_scoring_params publishes them. */
export interface ScoringParams {
  engineCode: string
  engineLabel: string
  mpValue: number
  deRound: number
  podiumGold: number
  podiumSilver: number
  podiumBronze: number
}

/**
 * Where a fencer stands in a joined bracket (ADR-103 §5): K fencers of the own
 * category, place m among them, and b fencers with a strictly worse place in
 * the whole bracket. Omitted, the bracket is one category: K = N, m = place,
 * b = N - place.
 */
export interface BracketPosition {
  categoryCount: number
  categoryPlace: number
  belowCount: number
}

/**
 * The components of one score, rounded to two decimals as tbl_result stores
 * them. A component the method does not use is null here; SQL stores it as -1.
 */
export interface ScoreComponents {
  method: ScoreMethod
  /** EVF place points, or the table's points under TABLE. */
  placePoints: number | null
  deRounds: number | null
  deBonus: number | null
  podiumBonus: number | null
  /** log2 N under PLACE_MEDAL. */
  fieldPoints: number | null
  belowCount: number | null
  belowPoints: number | null
  medalBonus: number | null
  /** The unrounded sum before the multiplier, for display at one decimal. */
  rawTotal: number
  /** ROUND(raw sum x multiplier, 2) — what fn_calc_tournament_scores stores. */
  finalScore: number
}

/**
 * Two decimals, matching Postgres ROUND(numeric, 2), which rounds half away
 * from zero. The epsilon guards binary-representation cases (0.145 stored just
 * below the tie) rather than changing the rounding rule.
 */
function round2(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100
}

function isPowerOfTwo(n: number): boolean {
  return (n & (n - 1)) === 0
}

function invalid(message: string): Error {
  return new Error(`Invalid scoring input: ${message}`)
}

/**
 * Rejects input that is not a result. A place greater than the field is corrupt
 * data, and zero is the one value that would hide it. SQL raises with the same
 * meaning (fn_assert_scoring_input), so preview and persistence agree.
 */
function assertScoringInput(n: number, place: number): void {
  if (!Number.isFinite(n) || !Number.isFinite(place)) {
    throw invalid('entries and place must be numbers.')
  }
  if (n < 1) throw invalid(`a field of ${n} has no results.`)
  if (place < 1) throw invalid(`place ${place} is below first.`)
  if (place > n) {
    throw invalid(
      `place ${place} exceeds the field of ${n}. A place larger than the field is corrupt data, not a weak result.`,
    )
  }
}

/** Rounds won in direct elimination under EVF classic. */
export function deRoundsWon(n: number, place: number): number {
  if (n <= 1) return 0
  return Math.max(
    0,
    Math.floor(Math.log2(n)) - Math.ceil(Math.log2(place)) + (isPowerOfTwo(n) ? 0 : 1),
  )
}

/** EVF classic podium bonus, scaled by the cube root of the whole field. */
export function podiumBonus(
  n: number,
  place: number,
  gold: number,
  silver: number,
  bronze: number,
): number {
  const coefficient = place === 1 ? gold : place === 2 ? silver : place === 3 ? bronze : 0
  return coefficient * 3 * Math.cbrt(n)
}

/**
 * The 2026/2027 category medal: 13, 7 or 3 x the cube root of K for places
 * 1, 2 or 3 of the own category — only when K exceeds the place, so the last
 * of a category earns none (§8 ust. 5).
 */
export function medalBonus(categoryPlace: number, categoryCount: number): number {
  if (categoryPlace > 3 || categoryCount <= categoryPlace) return 0
  return PLACE_MEDAL.medal[categoryPlace - 1] * Math.cbrt(categoryCount)
}

/** The range of the 2026/2027 engine that scores a bracket of n. */
export function placeMedalMethod(n: number): ScoreMethod {
  if (n <= PLACE_MEDAL.tableUpTo) return 'TABLE'
  if (n >= PLACE_MEDAL.evfFrom) return 'EVF_CLASSIC'
  return 'PLACE_MEDAL'
}

interface RawBreakdown {
  method: ScoreMethod
  placePoints: number | null
  deRounds: number | null
  deBonus: number | null
  podiumBonus: number | null
  fieldPoints: number | null
  belowCount: number | null
  belowPoints: number | null
  medalBonus: number | null
}

function evfClassic(params: ScoringParams, n: number, place: number): RawBreakdown {
  const mp = params.mpValue
  const rounds = deRoundsWon(n, place)
  return {
    method: 'EVF_CLASSIC',
    placePoints: n === 1 ? mp : mp - (mp - 1) * (Math.log(place) / Math.log(n)),
    deRounds: rounds,
    deBonus: rounds * params.deRound,
    podiumBonus: podiumBonus(n, place, params.podiumGold, params.podiumSilver, params.podiumBronze),
    fieldPoints: null,
    belowCount: null,
    belowPoints: null,
    medalBonus: null,
  }
}

function placeMedal(
  params: ScoringParams,
  n: number,
  place: number,
  position: BracketPosition,
): RawBreakdown {
  const method = placeMedalMethod(n)
  if (method === 'TABLE') {
    return {
      method,
      placePoints: n - place + 1,
      deRounds: null,
      deBonus: null,
      podiumBonus: null,
      fieldPoints: null,
      belowCount: null,
      belowPoints: null,
      medalBonus: null,
    }
  }
  if (method === 'EVF_CLASSIC') return evfClassic(params, n, place)

  const { categoryCount: k, categoryPlace: m, belowCount: b } = position
  if (!(k >= 1 && k <= n)) {
    throw invalid(`a bracket of ${n} needs the own category's fencer count K between 1 and ${n}, got ${k}.`)
  }
  if (!(m >= 1 && m <= k && m <= place)) {
    throw invalid(`category place m ${m} must be between 1 and K = ${k} and not better than place ${place}.`)
  }
  if (!(b >= 0 && b <= n - place)) {
    throw invalid(`${b} fencers below place ${place} of ${n} is impossible.`)
  }
  return {
    method,
    placePoints: null,
    deRounds: null,
    deBonus: null,
    podiumBonus: null,
    fieldPoints: Math.log2(n),
    belowCount: b,
    belowPoints: PLACE_MEDAL.perBelow * b,
    medalBonus: medalBonus(m, k),
  }
}

/**
 * The whole score for one result.
 *
 * `engineCode` is passed separately from `params.engineCode` so the published
 * calculator's SPWS/EVF toggle can show the other engine's numbers for the same
 * parameters. That toggle is a human comparison control; it is NOT how the
 * system selects an engine — a tournament type is assigned exactly one.
 *
 * The final score rounds ONCE, from the unrounded components, exactly as
 * fn_calc_tournament_scores does.
 */
export function scoreComponents(
  params: ScoringParams,
  engineCode: string,
  n: number,
  place: number,
  multiplier: number,
  position?: BracketPosition,
): ScoreComponents {
  // Engine first: an unknown engine is a programming error, not bad user input,
  // and should say so even when the place happens to be out of range too.
  if (engineCode !== CLASSIC_ENGINE && engineCode !== PLACE_MEDAL_ENGINE) {
    throw new Error(
      `Unknown scoring engine: ${engineCode}. An engine is assigned deliberately, never inferred.`,
    )
  }
  assertScoringInput(n, place)

  const raw =
    engineCode === CLASSIC_ENGINE
      ? evfClassic(params, n, place)
      : placeMedal(
          params,
          n,
          place,
          position ?? { categoryCount: n, categoryPlace: place, belowCount: n - place },
        )

  const parts = [
    raw.placePoints,
    raw.deBonus,
    raw.podiumBonus,
    raw.fieldPoints,
    raw.belowPoints,
    raw.medalBonus,
  ]
  const rawTotal = parts.reduce<number>((sum, v) => sum + (v ?? 0), 0)
  const r2 = (v: number | null) => (v === null ? null : round2(v))

  return {
    method: raw.method,
    placePoints: r2(raw.placePoints),
    deRounds: raw.deRounds,
    deBonus: r2(raw.deBonus),
    podiumBonus: r2(raw.podiumBonus),
    fieldPoints: r2(raw.fieldPoints),
    belowCount: raw.belowCount,
    belowPoints: r2(raw.belowPoints),
    medalBonus: r2(raw.medalBonus),
    rawTotal,
    finalScore: round2(rawTotal * multiplier),
  }
}
