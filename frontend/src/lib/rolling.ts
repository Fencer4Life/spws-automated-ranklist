// ADR-018/021 rolling carry-over — decide when the ranklist view should request
// rolling (prior-season results carried for declared-but-uncompleted positions).
//
// Rolling applies to the season that is "live or upcoming": the ACTIVE season
// (results-so-far + carry for uncompleted) AND any FUTURE season (no results of
// its own yet → its ranklist IS the carry-over preview). A PAST season shows its
// own final results, never rolling. Without this, a freshly-provisioned future
// season (e.g. a promoted skeleton, ADR-077) renders an empty ranklist because
// it has zero own results and carry-over was never requested.

export interface RollingSeason {
  dt_end?: string | null
  bool_active?: boolean
}

export function shouldUseRolling(
  season: RollingSeason | null | undefined,
  today: string = new Date().toISOString().slice(0, 10),
): boolean {
  if (!season) return false
  if (season.bool_active) return true
  // Future season: end date today or later → upcoming, show carry-over preview.
  const end = season.dt_end ?? null
  return end != null && end >= today
}
