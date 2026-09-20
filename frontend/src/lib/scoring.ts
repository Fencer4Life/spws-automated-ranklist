// =============================================================================
// The SPWS scoring formula — the single browser-side implementation
// =============================================================================
// doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html §08, step 8.
//
// WHAT THIS REPLACES
// -----------------------------------------------------------------------------
// The formula used to be written three times in browser JavaScript:
//   doc/tools/kalkulator-punktow-za-wynik-spws.v2.html   fN/rundy/parts/total
//   doc/tools/WP-kalkulator-punktow-za-wynik-spws.html   byte-identical copy
//   doc/tools/Tabela-punktacji-SPWS_2026-2027.html       firstPlaceBase/…/totalScore
// They had already drifted — the annex floored at MIN_PARTICIPANTS = 4 while the
// calculator accepted N = 1. All three now derive from this module.
//
// THE FORMULA LIVES IN EXACTLY TWO PLACES
// -----------------------------------------------------------------------------
// Here, and in the SQL strategies (fn_score_evf_classic_v1_2025_2026 /
// fn_score_spws_field_scaled_v1_2026_2027). A client-side implementation is
// unavoidable because the scoring-table annex renders up to 300 x 300 cells and
// re-renders on every rank-coefficient change, so a per-cell RPC — or a ~1 MB
// grid per change — is not viable. frontend/tests/scoring.test.ts is the pin
// between the two, with every expectation derived from the database.
//
// WHAT IS A PARAMETER AND WHAT IS THE ENGINE
// -----------------------------------------------------------------------------
// mp_value, the podium coefficients, base_slope and de_round are SEASON
// CONFIGURATION delivered by fn_public_scoring_params — not constants baked in
// here (§04, reversed 19 September 2026). The engine owns only the SHAPE of the
// base: flat mpValue, or min(mpValue, baseSlope * log2(max(2, N))). That is the
// whole difference between the two engines.
//
// TWO UNRELATED TENS. baseSlope is base points per bracket round; deRound is
// points per DE round won. They coincide at 10 today and are not the same
// quantity, so they are separate parameters and must stay that way.
// =============================================================================

export const CLASSIC_ENGINE = 'EVF_CLASSIC_V1_2025_2026'
export const FIELD_SCALED_ENGINE = 'SPWS_FIELD_SCALED_V1_2026_2027'

/** One season's scoring parameters, as fn_public_scoring_params publishes them. */
export interface ScoringParams {
  engineCode: string
  engineLabel: string
  mpValue: number
  baseSlope: number
  deRound: number
  podiumGold: number
  podiumSilver: number
  podiumBronze: number
}

export interface ScoreComponents {
  /** The first-place base the engine's shape produced for this field size. */
  base: number
  placePoints: number
  deBonus: number
  podiumBonus: number
  finalScore: number
}

/**
 * Two decimals, matching Postgres ROUND(numeric, 2), which rounds half away
 * from zero. Every input here is a positive quantity derived from logarithms
 * and cube roots, so exact .005 ties do not arise in practice; the epsilon
 * nudge guards the binary-representation cases (0.145 stored just below the
 * tie) rather than changing the rounding rule.
 */
function round2(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100
}

function isPowerOfTwo(n: number): boolean {
  return (n & (n - 1)) === 0
}

/**
 * The first-place base. This is the ONLY thing that differs between engines.
 *
 * The classic engine awards a flat base no matter how large the field, so
 * winning a field of two scored the same as winning a field of a hundred. The
 * field-scaled engine replaces that constant with a function of the field:
 * baseSlope points per bracket round, capped at the same mpValue. The two meet
 * at N = 32, because 10 * log2(32) = 50, and are identical above it.
 *
 * max(2, n) keeps log2(1) = 0 from producing a base of zero. It also means a
 * one-competitor walkover inherits the N = 2 base — 19 points against the
 * classic engine's 59. That re-pricing is deliberate and is asserted by
 * SS26.NEW; see §04.
 */
export function engineBase(
  engineCode: string,
  n: number,
  mpValue: number,
  baseSlope: number,
): number {
  if (engineCode === CLASSIC_ENGINE) return mpValue
  if (engineCode === FIELD_SCALED_ENGINE) {
    return Math.min(mpValue, baseSlope * Math.log2(Math.max(2, n)))
  }
  throw new Error(
    `Unknown scoring engine: ${engineCode}. An engine is assigned deliberately, never inferred.`,
  )
}

/**
 * Rejects input that is not a result. A place greater than the field is corrupt
 * data, and zero is the one value that would hide it — it sorts to the bottom
 * and reads as an ordinary weak result. SQL raises here too, with the same
 * meaning, so preview and persistence agree (§04, decided 19 September 2026).
 */
function assertScoringInput(n: number, place: number): void {
  if (!Number.isFinite(n) || !Number.isFinite(place)) {
    throw new Error('Invalid scoring input: entries and place must be numbers.')
  }
  if (n < 1) {
    throw new Error(`Invalid scoring input: a field of ${n} has no results.`)
  }
  if (place < 1) {
    throw new Error(`Invalid scoring input: place ${place} is below first.`)
  }
  if (place > n) {
    throw new Error(
      `Invalid scoring input: place ${place} exceeds the field of ${n}. ` +
        'A place larger than the field is corrupt data, not a weak result.',
    )
  }
}

/** Rounds won in direct elimination. Unchanged between engines. */
export function deBonus(n: number, place: number, deRound: number): number {
  if (n <= 1) return 0
  const rounds = Math.max(
    0,
    Math.floor(Math.log2(n)) - Math.ceil(Math.log2(place)) + (isPowerOfTwo(n) ? 0 : 1),
  )
  return rounds * deRound
}

/**
 * Podium bonus, scaled by the cube root of the field. Note there is no
 * place > n branch: the SQL writer lacked one, so N = 2 with place = 3 awarded
 * a bronze bonus for a place that cannot exist. Rejecting the input in
 * assertScoringInput closes that branch rather than reproducing the leak.
 */
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
 * The whole score for one result.
 *
 * `engineCode` is passed separately from `params.engineCode` so the published
 * calculator's EVF/SPWS toggle can show the other engine's numbers for the same
 * season parameters. That toggle is a human comparison control on a page; it is
 * NOT how the system selects an engine. A season is assigned exactly one engine
 * and nothing chooses an algorithm at calculation time (§03).
 *
 * The final score rounds ONCE, from the unrounded components, exactly as
 * fn_preview_tournament_score does. Summing the rounded components instead
 * would drift away from the stored score.
 */
export function scoreComponents(
  params: ScoringParams,
  engineCode: string,
  n: number,
  place: number,
  multiplier: number,
): ScoreComponents {
  // Engine first: an unknown engine is a programming error, not bad user input,
  // and should say so even when the place happens to be out of range too.
  const base = engineBase(engineCode, n, params.mpValue, params.baseSlope)
  assertScoringInput(n, place)

  const placePoints =
    n === 1 ? base : base - (base - 1) * (Math.log(place) / Math.log(n))
  const de = deBonus(n, place, params.deRound)
  const podium = podiumBonus(
    n,
    place,
    params.podiumGold,
    params.podiumSilver,
    params.podiumBronze,
  )

  return {
    base: round2(base),
    placePoints: round2(placePoints),
    deBonus: round2(de),
    podiumBonus: round2(podium),
    finalScore: round2((placePoints + de + podium) * multiplier),
  }
}
