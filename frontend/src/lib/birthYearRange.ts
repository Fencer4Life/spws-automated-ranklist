// FR-168 — the birth years a registration accepts (plan registration-form-
// names-year-country rev 10, release 2; tests RFYEAR.01–02 in
// frontend/tests/birthYearRange.test.ts).
//
// The youngest year is the season's later year minus 30, the V0 rule itself
// (birthYearToVcat gives no category under 30); the oldest is this year minus
// 120. The database refuses the same years on every write path
// (fn_registration_birth_year_range, supabase/tests/131_registration_birth_year.sql),
// and names the range in its refusal, which the form shows as its own line.

export interface YearRange {
  min: number
  max: number
}

export function birthYearRange(seasonEndYear: number | null | undefined, today: Date = new Date()): YearRange {
  const thisYear = today.getFullYear()
  return { min: thisYear - 120, max: (seasonEndYear ?? thisYear) - 30 }
}

export function inRange(year: number | null | undefined, r: YearRange): boolean {
  return year != null && Number.isInteger(year) && year >= r.min && year <= r.max
}

export function decadeOf(year: number): number {
  return year - (year % 10)
}

// What typing may leave in the box: digits only, four at most. A minus sign
// („-1972”, PROD entry 216) or a letter never reaches it.
export function cleanYearInput(typed: string): string {
  return typed.replace(/\D/g, '').slice(0, 4)
}

// The database's refusal of a year outside the range, as it reaches the form
// from an old cached page that did not know the range.
export function isYearRefusal(error: unknown): boolean {
  const message = (error as { message?: unknown } | null)?.message
  return typeof message === 'string' && message.includes('REG_BIRTH_YEAR_OUT_OF_RANGE')
}
