// =============================================================================
// The SPWS scoring formula — the single browser-side implementation
// =============================================================================
// doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html §08, step 8;
// ADR-102 (one module, generated into the published pages), ADR-103 (the
// place-and-medal engine, released and to be deleted) and the joined-bracket
// engine locked on 30 September 2026
// (doc/plans/joined-scoring-final-spec-2026-09-30.html), which replaces it.
//
// THE FORMULA LIVES IN EXACTLY TWO PLACES
// -----------------------------------------------------------------------------
// Here, and in the SQL strategies (fn_score_evf_classic_v1_2025_2026 /
// fn_score_spws_place_medal_v1_2026_2027). The joined-bracket engine has no SQL
// strategy yet; until it does, its pin is the spec's reference implementation.
// A client-side implementation is
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
// therefore a constant here, exactly as it is in SQL. The same holds for the
// joined-bracket engine: the meeting up to 3, the premium up to 15, 5% per
// category step and the 1-point cap are constants of the engine version.
//
// WHY THE JOINED-BRACKET ENGINE SCORES A WHOLE BRACKET
// -----------------------------------------------------------------------------
// Its cap — nobody scores more than the fencer directly ahead, minus 1 — makes
// a score depend on the fencer ahead, not only on N and the place. So
// scoreComponents gives one place WITHOUT the cap (the calculator, the premium
// table, the grid) and scoreBracket gives a finishing order WITH it.
// =============================================================================

export const CLASSIC_ENGINE = 'EVF_CLASSIC_V1_2025_2026'
export const PLACE_MEDAL_ENGINE = 'SPWS_PLACE_MEDAL_V1_2026_2027'
/** The joined-bracket engine. Its SQL strategy and final code arrive with ADR-104. */
export const JOINED_ENGINE = 'SPWS_EVF_JOINED_V1_2026_2027'

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

/** The constants of the joined-bracket engine (spec A5). Not settings. */
export const JOINED = {
  /** A bracket of up to this many fencers is a meeting: N - place + 1. */
  meetingUpTo: 3,
  /** A joined bracket up to this size pays the premium; from one more, plain EVF. */
  premiumUpTo: 15,
  /** The premium per category step: EVF x (1 + perStep x d). */
  perStep: 0.05,
  /** Nobody scores more than the fencer directly ahead, minus this. */
  capGap: 1,
} as const

/** The oldest category index, V4; the youngest, V0, is 0. */
const CATEGORY_STEPS_MAX = 4

/** The range that scored a result — tbl_result.enum_score_method. */
export type ScoreMethod = 'TABLE' | 'PLACE_MEDAL' | 'EVF_CLASSIC' | 'EVF_JOINED'

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
 * Where a fencer stands for the joined-bracket engine: d, the category steps
 * from the youngest category present in the bracket (0-4). Omitted, d = 0.
 */
export interface JoinedPosition {
  categorySteps: number
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
  /** d under EVF_JOINED. */
  categorySteps: number | null
  /** What EVF_JOINED adds to EVF, before the cap. */
  premium: number | null
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
  categorySteps: number | null
  premium: number | null
}

const NO_PARTS = {
  placePoints: null,
  deRounds: null,
  deBonus: null,
  podiumBonus: null,
  fieldPoints: null,
  belowCount: null,
  belowPoints: null,
  medalBonus: null,
  categorySteps: null,
  premium: null,
}

/** N <= 3, under both 2026/2027 engines: N - place + 1. */
function meeting(n: number, place: number): RawBreakdown {
  return { ...NO_PARTS, method: 'TABLE', placePoints: n - place + 1 }
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
    categorySteps: null,
    premium: null,
  }
}

function placeMedal(
  params: ScoringParams,
  n: number,
  place: number,
  position: BracketPosition,
): RawBreakdown {
  const method = placeMedalMethod(n)
  if (method === 'TABLE') return meeting(n, place)
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
    ...NO_PARTS,
    method,
    fieldPoints: Math.log2(n),
    belowCount: b,
    belowPoints: PLACE_MEDAL.perBelow * b,
    medalBonus: medalBonus(m, k),
  }
}

/** The range of the joined-bracket engine that scores a bracket of n at d. */
export function joinedMethod(n: number, categorySteps = 0): ScoreMethod {
  if (n <= JOINED.meetingUpTo) return 'TABLE'
  if (categorySteps > 0 && n <= JOINED.premiumUpTo) return 'EVF_JOINED'
  return 'EVF_CLASSIC'
}

/**
 * The two values an older category can score in a joined bracket of 4-15, and
 * the larger, which it gets before the cap. They are equal at exactly 20 EVF
 * points: above, 5% per step is more; below, d points are.
 */
export function joinedAlternatives(
  evf: number,
  categorySteps: number,
): { byPercent: number; byPoints: number; candidate: number } {
  const byPercent = evf * (1 + JOINED.perStep * categorySteps)
  const byPoints = evf + categorySteps
  return { byPercent, byPoints, candidate: Math.max(byPercent, byPoints) }
}

function joinedPlace(params: ScoringParams, n: number, place: number, d: number): RawBreakdown {
  if (!(Number.isInteger(d) && d >= 0 && d <= CATEGORY_STEPS_MAX)) {
    throw invalid(`category steps d must be a whole number from 0 to ${CATEGORY_STEPS_MAX}, got ${d}.`)
  }
  const method = joinedMethod(n, d)
  if (method === 'TABLE') return meeting(n, place)
  const evf = evfClassic(params, n, place)
  if (method === 'EVF_CLASSIC') return evf
  const base = (evf.placePoints ?? 0) + (evf.deBonus ?? 0) + (evf.podiumBonus ?? 0)
  return {
    ...evf,
    method,
    categorySteps: d,
    premium: joinedAlternatives(base, d).candidate - base,
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
  position?: BracketPosition | JoinedPosition,
): ScoreComponents {
  // Engine first: an unknown engine is a programming error, not bad user input,
  // and should say so even when the place happens to be out of range too.
  if (engineCode !== CLASSIC_ENGINE && engineCode !== PLACE_MEDAL_ENGINE && engineCode !== JOINED_ENGINE) {
    throw new Error(
      `Unknown scoring engine: ${engineCode}. An engine is assigned deliberately, never inferred.`,
    )
  }
  assertScoringInput(n, place)

  let raw: RawBreakdown
  if (engineCode === CLASSIC_ENGINE) {
    raw = evfClassic(params, n, place)
  } else if (engineCode === JOINED_ENGINE) {
    if (position && !('categorySteps' in position)) {
      throw invalid('the joined-bracket engine reads d (categorySteps), not a place-and-medal position.')
    }
    raw = joinedPlace(params, n, place, position?.categorySteps ?? 0)
  } else {
    if (position && !('categoryCount' in position)) {
      throw invalid('the place-and-medal engine reads K, m and b, not d.')
    }
    raw = placeMedal(
      params,
      n,
      place,
      position ?? { categoryCount: n, categoryPlace: place, belowCount: n - place },
    )
  }

  const parts = [
    raw.placePoints,
    raw.deBonus,
    raw.podiumBonus,
    raw.fieldPoints,
    raw.belowPoints,
    raw.medalBonus,
    raw.premium,
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
    categorySteps: raw.categorySteps,
    premium: r2(raw.premium),
    rawTotal,
    finalScore: round2(rawTotal * multiplier),
  }
}

/** One place of a bracket scored by scoreBracket. */
export interface BracketLine extends ScoreComponents {
  place: number
  /** The fencer's category index: 0 = V0 ... 4 = V4. */
  category: number
  /** The unrounded score before the cap. rawTotal is after it. */
  uncappedTotal: number
  /** The unrounded ceiling — the fencer directly ahead minus 1 — or null where no cap applies. */
  capAt: number | null
  /** True when the cap lowered this score. */
  capped: boolean
}

/**
 * A whole bracket under the joined-bracket engine, in finishing order: one
 * category index per place. d is counted from the youngest category present.
 * The cap applies only in a joined bracket of 4-15, is taken on unrounded
 * scores before the coefficient, and the final rounds once, after it.
 */
export function scoreBracket(
  params: ScoringParams,
  categories: readonly number[],
  multiplier: number,
): BracketLine[] {
  if (categories.length === 0) throw invalid('a bracket has no fencers.')
  for (const c of categories) {
    if (!(Number.isInteger(c) && c >= 0 && c <= CATEGORY_STEPS_MAX)) {
      throw invalid(`a category is a whole number from 0 (V0) to ${CATEGORY_STEPS_MAX} (V4), got ${c}.`)
    }
  }
  const n = categories.length
  const youngest = Math.min(...categories)
  const capApplies = new Set(categories).size > 1 && n > JOINED.meetingUpTo && n <= JOINED.premiumUpTo

  const lines: BracketLine[] = []
  let ahead: number | null = null
  categories.forEach((category, i) => {
    const place = i + 1
    const c = scoreComponents(params, JOINED_ENGINE, n, place, multiplier, {
      categorySteps: category - youngest,
    })
    const capAt = capApplies && ahead !== null ? ahead - JOINED.capGap : null
    const total = capAt !== null && c.rawTotal > capAt ? capAt : c.rawTotal
    lines.push({
      ...c,
      place,
      category,
      uncappedTotal: c.rawTotal,
      capAt,
      capped: total < c.rawTotal,
      rawTotal: total,
      finalScore: round2(total * multiplier),
    })
    ahead = total
  })
  return lines
}
