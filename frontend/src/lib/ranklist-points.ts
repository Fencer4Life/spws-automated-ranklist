// How the main ranklist shows points (ADR-114).
//
// Every number is whole, a half rounding up. In the column that orders the list
// (Razem, Points), neighbours that would show the same whole number while their
// exact totals differ show a small decimal, so two ranks never look equal for no
// visible reason. The drilldown and the ODS download keep their own decimals.
// Plan: doc/plans/ranklist-whole-points-2026-10-18.html; tests:
// tests/ranklistPoints.test.ts (RT.ROUND.01–05).

export type Decimals = 0 | 1 | 2

/** A whole number, a half rounding up; an empty value is a dash. */
export function wholePoints(v: number | null | undefined): string {
  return v == null ? '—' : String(Math.round(Number(v)))
}

/**
 * Decimals each row's total shows, for totals in list order. The list is sorted
 * and rounding never reorders, so rows showing the same whole number are always
 * neighbours: one pass over the runs finds every close call. A run whose exact
 * totals are not all equal shows one decimal on every row, or two when one would
 * still show two different totals as equal. A run of exact ties stays whole: the
 * ranking functions number equal totals with no tie-break, which no decimal explains.
 */
export function closeCallDecimals(totals: readonly number[]): Decimals[] {
  const out: Decimals[] = totals.map(() => 0)
  let start = 0
  while (start < totals.length) {
    let end = start
    while (end + 1 < totals.length && Math.round(totals[end + 1]) === Math.round(totals[start])) end++
    const distinct = new Set(totals.slice(start, end + 1))
    if (distinct.size > 1) {
      const tenths = new Set([...distinct].map((v) => Math.round(v * 10)))
      const decimals: Decimals = tenths.size === distinct.size ? 1 : 2
      for (let i = start; i <= end; i++) out[i] = decimals
    }
    start = end + 1
  }
  return out
}

/** The whole part and the decimal digits of a total shown with 1 or 2 decimals. */
export function splitPoints(v: number, decimals: 1 | 2): { whole: string; frac: string } {
  const scale = 10 ** decimals
  const units = Math.round(v * scale)
  return {
    whole: String(Math.floor(units / scale)),
    frac: String(units % scale).padStart(decimals, '0'),
  }
}
