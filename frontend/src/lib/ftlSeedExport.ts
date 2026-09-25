// FTL seed export — browser twin of python/pipeline/ftl_seed_export.py.
//
// The organizer downloads these files from a public WordPress page (ADR-090),
// which is static hosting: there is no server of ours between the page and
// Supabase, so the XML has to be built here. That makes this file a deliberate
// duplicate of the Python exporter rather than an accident, and the contract
// between them is exact — same canonical casing, same interleave, same marker
// placement, same attribute order, same filenames. tests/ftlSeedExport.test.ts
// asserts the XML byte for byte against ElementTree's real output, because
// "structurally equivalent" is not a property Fencing Time has been shown to
// accept; the validated reference files in doc/external_files/FTL_SRC/ are.
//
// Plan: doc/plans/ftl-xml-export-2026-09-12.html, build steps 7-9.
// Format: ADR-080 §1/§2, with §1's marker placement and §4's naming as amended
// on 2026-09-12.

// Fixed round-robin order for the mix-all interleave (ADR-080 §2).
export const MIXALL_SUBRANKING_ORDER = [
  'FV0',
  'FV1',
  'FV2',
  'FV3',
  'FV4',
  'MV0',
  'MV1',
  'MV2',
  'MV3',
  'MV4',
] as const

export const VCAT_ORDER = ['V0', 'V1', 'V2', 'V3', 'V4'] as const

// The order weapons are emitted in, so two downloads of the same entry list
// produce the same list of files in the same order.
export const WEAPON_ORDER = ['EPEE', 'FOIL', 'SABRE'] as const

export const WEAPON_FIE_CODE: Record<string, string> = { EPEE: 'E', FOIL: 'F', SABRE: 'S' }
export const WEAPON_PL_NAME: Record<string, string> = {
  EPEE: 'Szpada',
  FOIL: 'Floret',
  SABRE: 'Szabla',
}

// Polish reaches the operator only through TitreLong, which is what Fencing
// Time displays. Filenames stay ASCII and English (plan §8).
const GENDER_PL: Record<string, string> = { F: 'kobiety', M: 'mężczyźni' }
const GENDER_FILE_TOKEN: Record<string, string> = { F: 'WOMEN', M: 'MEN' }

const IMPORT_AS: Record<string, string> = {
  MIXALL: 'COMPETITION',
  DE: 'COMPETITION',
  ROSTER: 'PICKLIST',
}

/** One row of fn_ftl_export_entries — the public seed projection. */
export interface ExportEntryRow {
  txt_surname: string
  txt_first_name: string
  enum_gender: string
  enum_age_category: string
  enum_weapon: string
  /**
   * Dense 1-based position among the fencers who entered this weapon × gender
   * × category. NO LONGER the seed position (2026-09-24): it survives only to
   * order the unranked tail deterministically without publishing ts_created.
   */
  int_order: number
  /**
   * The fencer's TRUE rank in that sub-ranking, null when they hold no points.
   * Seeding tiers on this. Using int_order instead made a genuine 4th place —
   * ranks 1-3 had not entered — look like a category winner and seeded her
   * first.
   */
  int_rank: number | null
  /** Ranking points behind int_rank; orders the entries inside a tier. */
  num_rank_points?: number | null
}

/** One row of fn_ftl_roster — the organizer's pick-list for one weapon. */
export interface RosterRow {
  txt_surname: string
  txt_first_name: string
  enum_gender: string
  enum_age_category: string
  /** Alphabetical position, resolved server-side. */
  int_order: number
}

export interface SeedEntry {
  /** Tie-break within a tier, and the ordering of the unranked tail. */
  idx: number
  surname: string
  firstName: string
  /** True rank in the sub-ranking; null when the fencer holds no points. */
  rank: number | null
  /**
   * Ranking points, null when the fencer holds none. Orders the entries INSIDE
   * a tier (2026-09-26); the tier itself is still decided by `rank`. Optional
   * so a caller building entries by hand — several tests do — need not supply
   * a value the unranked tail never uses.
   */
  points?: number | null
}

export interface Tireur {
  id: number
  nom: string
  prenom: string
  sexe: string
  classement: number
}

export type SeedFileKind = 'MIXALL' | 'DE' | 'ROSTER'

export interface SeedFile {
  filename: string
  xml: string
  kind: SeedFileKind
  weapon: string
  title: string
  count: number
  importAs: string
}

export interface ManifestRow {
  filename: string
  kind: SeedFileKind
  weapon: string
  title: string
  count: number
  importAs: string
}

// ---------------------------------------------------------------------------
// Names
// ---------------------------------------------------------------------------

/**
 * The Polish alphabet, in its own order. Ł belongs between L and M, Ó between
 * O and P, and Ż is the last letter there is.
 */
const PL_ALPHABET = 'aąbcćdeęfghijklłmnńoópqrsśtuvwxyzźż'
const PL_WEIGHT = new Map([...PL_ALPHABET].map((c, i) => [c, i + 1]))

/**
 * Sort key for one name, as a list of per-character weights.
 *
 * NOT Intl.Collator, deliberately. This file and python/pipeline/ftl_seed_export.py
 * are asserted byte for byte against each other, and Python has no Intl; asking
 * two different collation libraries to agree on every name forever is a bet,
 * whereas an explicit alphabet written out in both files agrees by
 * construction. It is also why the rule is not computed in Postgres: the Python
 * exporter never calls fn_ftl_export_entries, it reads tbl_registration
 * directly and does the interleave itself.
 *
 * A plain code-point sort would be worse than merely imprecise — it puts Ł, Ń,
 * Ó, Ś, Ź and Ż after Z, which is the exact defect EntryList.svelte already
 * documents and works around for the entry list on screen.
 *
 * Weight 0 for anything that is not a letter, so a hyphen or an apostrophe
 * sorts before every letter and SPŁAWA-NEYMAN lands before SPŁAWACZ. An
 * unrecognised letter — a foreign entrant's name — sorts after the whole Polish
 * alphabet rather than silently colliding with a letter inside it.
 */
export function polishSortKey(value: string): number[] {
  const out: number[] = []
  for (const ch of value.toLowerCase()) {
    const weight = PL_WEIGHT.get(ch)
    if (weight !== undefined) out.push(weight)
    else if (/\p{L}/u.test(ch)) out.push(PL_ALPHABET.length + 1 + (ch.codePointAt(0) ?? 0))
    else out.push(0)
  }
  return out
}

/** Lexicographic, shorter prefix first — what Python's list comparison does. */
function compareSortKeys(a: number[], b: number[]): number {
  const shared = Math.min(a.length, b.length)
  for (let i = 0; i < shared; i++) {
    if (a[i] !== b[i]) return a[i] - b[i]
  }
  return a.length - b.length
}

/**
 * Python's str.title(), which is the rule the exporter has always used: every
 * letter that follows a non-letter starts a new word. That makes hyphens,
 * apostrophes and spaces all boundaries — "anna-maria" becomes "Anna-Maria"
 * and "d'arcy" becomes "D'Arcy". Implemented explicitly rather than with a
 * word-splitting helper because the twin has to agree with Python on real
 * names, not on the common case.
 */
function pythonTitle(value: string): string {
  return value
    .toLowerCase()
    .replace(/(^|[^\p{L}])(\p{L})/gu, (_m, before: string, letter: string) => before + letter.toUpperCase())
}

/**
 * Canonical seed/entry-list name form (ADR-080 §1): surname UPPERCASE, given
 * name Title case. This is where "STAŃCZYK MARCIN" and "LEAHEY john" are
 * fixed — on export, not in the database, because the registration is the
 * fencer's own declaration and we do not rewrite it.
 */
export function toCanonicalName(surname: string, firstName: string): [string, string] {
  return [surname.trim().toUpperCase(), pythonTitle(firstName.trim())]
}

/**
 * The surname carrying its (N) age-category marker (ADR-080 §1, amended
 * 2026-09-12). MID-NAME: Fencing Time renders "Nom Prenom", so this produces
 * "PRZYKŁADOWSKA (1) Anna", which is the form our own scraper reads back and
 * the form all 20 MPW 2026 events use in the wild. Appended to the given name
 * it did not round-trip through our own pipeline.
 */
export function formatNomWithMarker(surnameCanon: string, vcatDigit: string): string {
  return `${surnameCanon} (${vcatDigit})`
}

// ---------------------------------------------------------------------------
// The interleave (ADR-080 §2)
// ---------------------------------------------------------------------------

/**
 * Round-robin ("snake by rank") across the ten sub-rankings in the fixed
 * FV0..FV4, MV0..MV4 order: everyone holding TRUE rank 1, then every true rank
 * 2, and so on, with every unranked fencer after all of them.
 *
 * The tier is the rank the fencer actually holds, not their position among
 * those who entered (2026-09-24). Ranks 1-3 of EPEE FV0 did not enter PPW1, so
 * compacting the entrants made SZKLAR — genuinely 4th — into FV0's "first" and
 * seeded her ahead of every real category winner. Absent ranks are simply
 * omitted for that category: the true number 1 leads, and a true 4th goes down
 * with the other 4th places.
 *
 * WITHIN a tier the order is ranking POINTS, descending, across all ten
 * sub-rankings (2026-09-26). It used to be the fixed FV0..MV4 sequence, which
 * handed the first seed of every tier to a woman because 'F' sorts before 'M'.
 * The fixed order survives as the tie-break.
 *
 * Returns [entry, subRankingKey] pairs in seed order; the key carries both the
 * Sexe (its first character) and the (N) marker (its last).
 */
/**
 * Position of each sub-ranking in the fixed order, as a lookup. Keyed by plain
 * string because the interleave carries keys as strings, and doing this once
 * also keeps it out of the sort comparator.
 */
const SUBRANKING_RANK: Record<string, number> = Object.fromEntries(
  MIXALL_SUBRANKING_ORDER.map((k, i) => [k, i]),
)

export function interleaveMixall(
  subRankings: Record<string, SeedEntry[]>,
): Array<[SeedEntry, string]> {
  const result: Array<[SeedEntry, string]> = []
  const highest = Math.max(
    0,
    ...Object.values(subRankings).flatMap((es) => es.map((e) => e.rank ?? 0)),
  )
  for (let tier = 1; tier <= highest; tier++) {
    // Everybody at this tier, from every sub-ranking, then sorted by points.
    // A tier can hold more than one entry per bucket: fn_ranking_ppw gives two
    // fencers on the same score the same rank.
    const tierEntries: Array<[SeedEntry, string]> = []
    for (const key of MIXALL_SUBRANKING_ORDER) {
      for (const e of subRankings[key] ?? []) if (e.rank === tier) tierEntries.push([e, key])
    }
    // Highest points first. The sort must be TOTAL, or two downloads of one
    // entry list could differ and be impossible to reconcile against the
    // organizer's software — so equal points fall back to the fixed FV0..MV4
    // order this pass used to walk. Array#sort is stable, so the array order
    // built above survives as the final tie-break without being spelled out.
    tierEntries.sort(([a, ka], [b, kb]) => {
      const pa = a.points ?? Number.NEGATIVE_INFINITY
      const pb = b.points ?? Number.NEGATIVE_INFINITY
      if (pa !== pb) return pb - pa
      return (SUBRANKING_RANK[ka] ?? 0) - (SUBRANKING_RANK[kb] ?? 0)
    })
    result.push(...tierEntries)
  }
  for (const key of MIXALL_SUBRANKING_ORDER) {
    // == null on purpose: an absent rank and an explicit null are the same
    // thing here, and a caller building entries by hand supplies neither.
    for (const e of subRankings[key] ?? []) if (e.rank == null) result.push([e, key])
  }
  return result
}

/**
 * Seed order → FIE <Tireur> records. Seed position is both the ID and the
 * Classement, matching the validated reference file — but it is no longer the
 * order the records are written in: see the sort below.
 *
 * Every file kind passes through here (mix-all, DE and roster alike), which is
 * why this one function is the only place the ordering rule has to live.
 */
export function mixallTireurs(seedOrder: Array<[SeedEntry, string]>): Tireur[] {
  const numbered = seedOrder.map(([entry, key], i) => ({
    tireur: {
      id: i + 1,
      nom: formatNomWithMarker(entry.surname, key[key.length - 1]),
      prenom: entry.firstName,
      sexe: key[0],
      classement: i + 1,
    },
    // Keyed off the raw names, not the formatted Nom: the "(N)" marker is
    // appended above, and sorting on it would interleave categories instead of
    // names.
    surnameKey: polishSortKey(entry.surname),
    firstNameKey: polishSortKey(entry.firstName),
  }))
  // Array.prototype.sort is stable, as is Python's sorted(), so two entrants
  // with identical names keep seed order and the file stays deterministic.
  numbered.sort(
    (a, b) =>
      compareSortKeys(a.surnameKey, b.surnameKey) ||
      compareSortKeys(a.firstNameKey, b.firstNameKey),
  )
  return numbered.map((n) => n.tireur)
}

// ---------------------------------------------------------------------------
// Naming (plan §8, replacing ADR-080 §4)
// ---------------------------------------------------------------------------

/** 'PPW1-2026-2027' → ['PPW1', '2026/27']. */
export function eventStemAndSeason(eventCode: string): [string, string] {
  const m = /^(.*?)-(\d{4})-(\d{4})$/.exec(eventCode)
  if (!m) return [eventCode, '']
  return [m[1], `${m[2]}/${m[3].slice(-2)}`]
}

function titlePrefix(eventCode: string): string {
  const [stem, season] = eventStemAndSeason(eventCode)
  return `SPWS ${stem} ${season}`.trimEnd()
}

/** ['V0','V2','V4'] → 'V0–V4'; ['V2'] → 'V2'. Never "V2–V2". */
function vcatRange(vcats: string[]): string {
  const present = new Set(vcats)
  const live = VCAT_ORDER.filter((c) => present.has(c))
  if (live.length === 0) return ''
  return live.length === 1 ? live[0] : `${live[0]}–${live[live.length - 1]}`
}

/**
 * <event>_<WEAPON>_<PHASE>_<scope>.xml. Every name states the event, weapon,
 * phase, gender and category range, so that a file cannot be imported into the
 * wrong bracket because its name under-described it.
 */
export function exportFilename(
  eventCode: string,
  weapon: string,
  phase: string,
  scope: string,
): string {
  return `${eventCode}_${weapon}_${phase}_${scope}.xml`
}

export function mixallScope(genders: string[]): string {
  const present = new Set(genders)
  const tokens = (['F', 'M'] as const).filter((g) => present.has(g))
  const genderPart = tokens.map((g) => (g === 'F' ? 'W' : 'M')).join('+') || 'none'
  return `all-categories_${genderPart}`
}

export function mixallTitle(
  eventCode: string,
  weapon: string,
  genders: string[],
  vcats: string[],
): string {
  const present = new Set(genders)
  const phrase = (['F', 'M'] as const)
    .filter((g) => present.has(g))
    .map((g) => GENDER_PL[g])
    .join('+')
  return `${titlePrefix(eventCode)} · ${WEAPON_PL_NAME[weapon].toUpperCase()} · ELIMINACJE MIX — ${phrase}, ${vcatRange(vcats)}`
}

export function deScope(gender: string, vcat: string): string {
  return `${GENDER_FILE_TOKEN[gender]}_${vcat}`
}

export function deTitle(eventCode: string, weapon: string, gender: string, vcat: string): string {
  return `${titlePrefix(eventCode)} · ${WEAPON_PL_NAME[weapon].toUpperCase()} · DE ${GENDER_PL[gender]} ${vcat}`
}

export function rosterScope(weapon: string): string {
  return `all-known-${weapon.toLowerCase()}-fencers`
}

export function rosterTitle(weapon: string): string {
  return `SPWS · BAZA ZAWODNIKÓW — ${WEAPON_PL_NAME[weapon].toLowerCase()} (nie importować jako zawody)`
}

// ---------------------------------------------------------------------------
// The XML (ADR-080 §1)
// ---------------------------------------------------------------------------

/**
 * ElementTree's attribute escaping, reproduced exactly — ampersand first, then
 * the angle brackets and the quote, then the three whitespace characters as
 * numeric references. Getting this wrong would only show on a name or title
 * containing one of them, which is precisely the case nobody would notice.
 */
function escapeAttr(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/\r/g, '&#13;')
    .replace(/\n/g, '&#10;')
    .replace(/\t/g, '&#09;')
}

function attrs(pairs: Array<[string, string]>): string {
  return pairs.map(([k, v]) => ` ${k}="${escapeAttr(v)}"`).join('')
}

export interface FieXmlInput {
  rootId: string
  weaponCode: string
  genderCode: string
  title: string
  tireurs: Tireur[]
  dateFichierXml?: string
}

/**
 * One FIE <BaseCompetitionIndividuelle> document. No DateNaissance (Fencing
 * Time would infer and then enforce an age category from it, and the
 * authoritative birth year is not ours to publish), no Lateralite, Club and
 * Licence empty.
 */
export function buildFieXml(input: FieXmlInput): string {
  const root = attrs([
    ['Championnat', 'SPWS'],
    ['ID', input.rootId],
    ['Arme', input.weaponCode],
    ['Sexe', input.genderCode],
    ['Domaine', 'N'],
    ['Federation', 'POL'],
    ['Categorie', 'V'],
    ['TitreLong', input.title],
    ['Date', ''],
    ['DateFichierXML', input.dateFichierXml ?? ''],
  ])
  const tireurs = input.tireurs
    .map((t) =>
      `<Tireur${attrs([
        ['ID', String(t.id)],
        ['Nom', t.nom],
        ['Prenom', t.prenom],
        ['Sexe', t.sexe],
        // Club withdrawn 2026-09-24: the declared values were free text and
        // already unusable (one club under three spellings). The ATTRIBUTE
        // stays — the validated FIE reference files carry it — and is empty,
        // exactly as it was before ADR-080 amendment (f) added the field.
        ['Club', ''],
        ['Nation', 'POL'],
        ['Licence', ''],
        ['Statut', 'N'],
        ['Classement', String(t.classement)],
      ])} />`,
    )
    .join('')
  // ElementTree self-closes an element with no children, so an empty entry
  // list must render "<Tireurs />" and not "<Tireurs></Tireurs>".
  const tireursEl = tireurs ? `<Tireurs>${tireurs}</Tireurs>` : '<Tireurs />'
  const body = `<BaseCompetitionIndividuelle${root}>${tireursEl}</BaseCompetitionIndividuelle>`
  return `<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE BaseCompetitionIndividuelle>\n${body}`
}

// ---------------------------------------------------------------------------
// The file set
// ---------------------------------------------------------------------------

function subRankingsForWeapon(rows: ExportEntryRow[]): Record<string, SeedEntry[]> {
  const buckets: Record<string, SeedEntry[]> = {}
  for (const r of rows) {
    const key = `${r.enum_gender}${r.enum_age_category}`
    const [surname, firstName] = toCanonicalName(r.txt_surname, r.txt_first_name)
    ;(buckets[key] ??= []).push({
      idx: r.int_order,
      surname,
      firstName,
      rank: r.int_rank ?? null,
      // PostgREST returns NUMERIC as a string; Number() keeps the sort
      // numeric, so 99.5 cannot end up before 100 as text would.
      points: r.num_rank_points == null ? null : Number(r.num_rank_points),
    })
  }
  for (const entries of Object.values(buckets)) entries.sort((a, b) => a.idx - b.idx)
  return buckets
}

function seedFile(
  kind: SeedFileKind,
  filename: string,
  weapon: string,
  title: string,
  genderCode: string,
  tireurs: Tireur[],
  dateFichierXml: string,
): SeedFile {
  return {
    filename,
    xml: buildFieXml({
      rootId: filename.slice(0, -4), // root ID = filename stem
      weaponCode: WEAPON_FIE_CODE[weapon],
      genderCode,
      title,
      tireurs,
      dateFichierXml,
    }),
    kind,
    weapon,
    title,
    count: tireurs.length,
    importAs: IMPORT_AS[kind],
  }
}

/**
 * The event's whole competition file set: one mix-all pool per weapon with
 * registrants, plus one DE file per gender × category actually present in it.
 *
 * The DE split is MAXIMAL by design (plan §1, replacing ADR-080 §3's predicted
 * combining). Several files will hold one or two fencers; the manual tells the
 * organizer to combine them in Fencing Time, and we re-split by birth year when
 * the results come back, so their combining costs us nothing — while guessing
 * it wrong hands them a file whose name claims a category range it does not
 * hold, which is how MPW 2026's foil "V3, V4" came to contain 25 fencers from
 * V0 to V4 including the women.
 *
 * `rosters` is {weapon: rows from fn_ftl_roster}, and adds one pick-list per
 * weapon. A weapon with no entrants gets no roster even when rows exist for it:
 * a pick-list for a weapon nobody is fencing is one more file to import by
 * mistake.
 */
export function buildEventSeedFiles(
  rows: ExportEntryRow[],
  eventCode: string,
  dateFichierXml = '',
  rosters?: Record<string, RosterRow[]>,
): SeedFile[] {
  const out: SeedFile[] = []
  for (const weapon of WEAPON_ORDER) {
    const weaponRows = rows.filter((r) => r.enum_weapon === weapon)
    if (weaponRows.length === 0) continue

    const subRankings = subRankingsForWeapon(weaponRows)
    const liveKeys = MIXALL_SUBRANKING_ORDER.filter((k) => (subRankings[k] ?? []).length > 0)
    if (liveKeys.length === 0) continue

    const genders = liveKeys.map((k) => k[0])
    const vcats = liveKeys.map((k) => k.slice(1))
    const mixallName = exportFilename(eventCode, weapon, 'POOLS-MIXED', mixallScope(genders))
    out.push(
      seedFile(
        'MIXALL',
        mixallName,
        weapon,
        mixallTitle(eventCode, weapon, genders, vcats),
        // Nominal root Sexe; each Tireur carries the real one, because the
        // whole point of this file is that it is mixed.
        'M',
        mixallTireurs(interleaveMixall(subRankings)),
        dateFichierXml,
      ),
    )

    for (const key of liveKeys) {
      const gender = key[0]
      const vcat = key.slice(1)
      const entries = subRankings[key]
      out.push(
        seedFile(
          'DE',
          exportFilename(eventCode, weapon, 'DE', deScope(gender, vcat)),
          weapon,
          deTitle(eventCode, weapon, gender, vcat),
          gender,
          // A DE file is a standalone competition, so its seeding restarts at 1.
          mixallTireurs(entries.map((entry) => [entry, key] as [SeedEntry, string])),
          dateFichierXml,
        ),
      )
    }

    const rosterRows = rosters?.[weapon] ?? []
    if (rosterRows.length > 0) {
      const rosterName = exportFilename(eventCode, weapon, 'ROSTER', rosterScope(weapon))
      // The (N) marker rides on a pick-list name exactly as it does on a seeded
      // one. A roster has no seeding worth the name, but a fencer ticked in from
      // here returns on the results carrying the category digit the pipeline
      // reads — which is the whole reason ticking beats typing.
      const rosterTireurs = mixallTireurs(
        [...rosterRows]
          .sort((a, b) => a.int_order - b.int_order)
          .map((r) => {
            const [surname, firstName] = toCanonicalName(r.txt_surname, r.txt_first_name)
            return [
              // A pick-list has no seeding: every entry is unranked by
              // construction, so the tail ordering is the alphabetical int_order.
              { idx: r.int_order, surname, firstName, rank: null },
              `${r.enum_gender}${r.enum_age_category}`,
            ] as [SeedEntry, string]
          }),
      )
      out.push(
        seedFile(
          'ROSTER',
          rosterName,
          weapon,
          rosterTitle(weapon),
          // Nominal, as on the mix-all: a roster is every gender at once.
          'M',
          rosterTireurs,
          dateFichierXml,
        ),
      )
    }
  }
  return out
}

/**
 * The "what you are downloading" table from plan §9, built from the SeedFile
 * objects themselves so the count beside a filename is by construction the
 * number of fencers inside that exact file.
 */
export function exportManifest(files: SeedFile[]): ManifestRow[] {
  return files.map((f) => ({
    filename: f.filename,
    kind: f.kind,
    weapon: f.weapon,
    title: f.title,
    count: f.count,
    importAs: f.importAs,
  }))
}
