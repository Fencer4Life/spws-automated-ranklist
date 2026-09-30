// =============================================================================
// The SPWS scoring formula — the single browser-side implementation
// =============================================================================
// doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html §08, step 8;
// ADR-102 (one module, generated into the published pages) and ADR-104 (the
// joined-bracket engine locked on 30 September 2026,
// doc/plans/joined-scoring-final-spec-2026-09-30.html, which replaced the
// place-and-medal engine of ADR-103 before it scored a result).
//
// THE FORMULA LIVES IN EXACTLY TWO PLACES
// -----------------------------------------------------------------------------
// Here, and in the SQL strategies (fn_score_evf_classic_v1_2025_2026,
// fn_score_spws_evf_joined_v1_2026_2027) with the whole-bracket cap in
// fn_score_joined_bracket. A client-side implementation is
// unavoidable because the scoring-table annex renders a 64 x 64 grid and
// re-renders on every rank-coefficient change, so a per-cell RPC is not viable.
// frontend/tests/scoring.test.ts is the pin between the two, with every
// expectation derived from the database.
//
// WHAT IS A PARAMETER AND WHAT IS THE ENGINE
// -----------------------------------------------------------------------------
// mp_value, the DE round and the podium coefficients are SEASON CONFIGURATION
// delivered by fn_public_scoring_params, one row per tournament type. They feed
// EVF classic and every bracket of 4 or more under the joined-bracket engine.
// Everything else about the joined-bracket engine — the meeting up to 3, the
// premium up to 15, 5% per category step and the 1-point cap — belongs to the
// engine version, and is therefore a constant here, exactly as it is in SQL.
//
// WHY THE JOINED-BRACKET ENGINE SCORES A WHOLE BRACKET
// -----------------------------------------------------------------------------
// Its cap — nobody scores more than the fencer directly ahead, minus 1 — makes
// a score depend on the fencer ahead, not only on N and the place. So
// scoreComponents gives one place WITHOUT the cap (the calculator, the premium
// table, the grid) and scoreBracket gives a finishing order WITH it.
// =============================================================================

export const CLASSIC_ENGINE = 'EVF_CLASSIC_V1_2025_2026'
/** The joined-bracket engine (ADR-104). */
export const JOINED_ENGINE = 'SPWS_EVF_JOINED_V1_2026_2027'

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
export type ScoreMethod = 'TABLE' | 'EVF_CLASSIC' | 'EVF_JOINED'

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
 * Where a fencer stands for the joined-bracket engine: d, the category steps
 * from the youngest category present in the bracket (0-4), and whether the
 * bracket is joined (two or more categories). Omitted, d = 0; `joined`
 * defaults to d > 0, since only a joined bracket has an older category.
 */
export interface JoinedPosition {
  categorySteps: number
  joined?: boolean
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

interface RawBreakdown {
  method: ScoreMethod
  placePoints: number | null
  deRounds: number | null
  deBonus: number | null
  podiumBonus: number | null
  categorySteps: number | null
  premium: number | null
}

const NO_PARTS = {
  placePoints: null,
  deRounds: null,
  deBonus: null,
  podiumBonus: null,
  categorySteps: null,
  premium: null,
}

/** N <= 3 under the joined-bracket engine: N - place + 1. */
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
    categorySteps: null,
    premium: null,
  }
}

/**
 * The range of the joined-bracket engine that scores a place in a bracket of n:
 * every row of a joined bracket of 4-15 is EVF_JOINED, the youngest category's
 * with a premium of 0, exactly as fn_score_spws_evf_joined_v1_2026_2027 stores it.
 */
export function joinedMethod(n: number, categorySteps = 0, joined = categorySteps > 0): ScoreMethod {
  if (n <= JOINED.meetingUpTo) return 'TABLE'
  if (joined && n <= JOINED.premiumUpTo) return 'EVF_JOINED'
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

function joinedPlace(
  params: ScoringParams,
  n: number,
  place: number,
  d: number,
  joined: boolean,
): RawBreakdown {
  if (!(Number.isInteger(d) && d >= 0 && d <= CATEGORY_STEPS_MAX)) {
    throw invalid(`category steps d must be a whole number from 0 to ${CATEGORY_STEPS_MAX}, got ${d}.`)
  }
  if (d > 0 && !joined) throw invalid(`category steps d = ${d} need a joined bracket; a single category has d = 0.`)
  const method = joinedMethod(n, d, joined)
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
  position?: JoinedPosition,
): ScoreComponents {
  // Engine first: an unknown engine is a programming error, not bad user input,
  // and should say so even when the place happens to be out of range too.
  if (engineCode !== CLASSIC_ENGINE && engineCode !== JOINED_ENGINE) {
    throw new Error(
      `Unknown scoring engine: ${engineCode}. An engine is assigned deliberately, never inferred.`,
    )
  }
  assertScoringInput(n, place)

  const d = position?.categorySteps ?? 0
  const raw: RawBreakdown =
    engineCode === CLASSIC_ENGINE
      ? evfClassic(params, n, place)
      : joinedPlace(params, n, place, d, position?.joined ?? d > 0)

  const parts = [raw.placePoints, raw.deBonus, raw.podiumBonus, raw.premium]
  const rawTotal = parts.reduce<number>((sum, v) => sum + (v ?? 0), 0)
  const r2 = (v: number | null) => (v === null ? null : round2(v))

  return {
    method: raw.method,
    placePoints: r2(raw.placePoints),
    deRounds: raw.deRounds,
    deBonus: r2(raw.deBonus),
    podiumBonus: r2(raw.podiumBonus),
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
  /**
   * How much the cap took off, before the coefficient, rounded to two decimals
   * as tbl_result.num_cap_reduction stores it: 0 where it did not bite, null
   * where no cap applies (SQL stores -1).
   */
  capReduction: number | null
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
  const joined = new Set(categories).size > 1
  const capApplies = joined && n > JOINED.meetingUpTo && n <= JOINED.premiumUpTo

  const lines: BracketLine[] = []
  let ahead: number | null = null
  categories.forEach((category, i) => {
    const place = i + 1
    const c = scoreComponents(params, JOINED_ENGINE, n, place, multiplier, {
      categorySteps: category - youngest,
      joined,
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
      capReduction: capApplies ? round2(c.rawTotal - total) : null,
      rawTotal: total,
      finalScore: round2(total * multiplier),
    })
    ahead = total
  })
  return lines
}
