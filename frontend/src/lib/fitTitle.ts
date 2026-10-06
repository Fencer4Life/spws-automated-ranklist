// The calendar's title is its menu name, squeezed by MEASURED fit (D5).
// ADR-090 amendment 2026-10-06; FR-148 as amended. Plan:
// doc/plans/kalendarz-beben-strzalki-plan-2026-10-06.html §2.7.
//
// It unfolds to „Znajdź zawody" / "Competition Finder" wherever it fits and
// squeezes to „Zawody" ("Competitions", then "Events") only for lack of room.
// Fit is measured, not tied to a screen width: the room is what the bar
// actually leaves the title, so a wider phone font or a longer translation is
// handled without a breakpoint to retune.

/**
 * Index of the first candidate whose width fits the room, or of the last one
 * when none does. Candidates run from the longest name to the shortest.
 */
export function pickTitle(widths: readonly number[], room: number): number {
  const fits = widths.findIndex((w) => w <= room)
  return fits >= 0 ? fits : Math.max(0, widths.length - 1)
}

/**
 * The same choice made from the page: `copies` are hidden copies of each
 * candidate, set in the title's own font, and their measured widths are
 * compared with the room.
 */
export function fitIndex(copies: Iterable<Element>, room: number): number {
  return pickTitle([...copies].map((c) => c.getBoundingClientRect().width), room)
}

/** The candidates in order, with a repeated step dropped (Polish needs no third). */
export function titleCandidates(names: readonly string[]): string[] {
  return names.filter((name, i) => name !== names[i - 1])
}
