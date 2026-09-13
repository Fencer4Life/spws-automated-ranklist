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
  /** Resolved position inside this weapon × gender × category, 1-based. */
  int_order: number
  /** Declared club (2026-09-13, ADR-080 amendment (f)); null when not given. */
  txt_club: string | null
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
  idx: number
  surname: string
  firstName: string
  /** Declared club; '' when not given (roster entries always pass ''). */
  club: string
}

export interface Tireur {
  id: number
  nom: string
  prenom: string
  sexe: string
  classement: number
  club: string
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
 * FV0..FV4, MV0..MV4 order: every sub-ranking's first-placed fencer, then every
 * second-placed, and so on, with empty sub-rankings skipped rather than padded.
 * Returns [entry, subRankingKey] pairs in seed order; the key carries both the
 * Sexe (its first character) and the (N) marker (its last).
 */
export function interleaveMixall(
  subRankings: Record<string, SeedEntry[]>,
): Array<[SeedEntry, string]> {
  const maxLen = Math.max(0, ...Object.values(subRankings).map((e) => e.length))
  const result: Array<[SeedEntry, string]> = []
  for (let rankIdx = 0; rankIdx < maxLen; rankIdx++) {
    for (const key of MIXALL_SUBRANKING_ORDER) {
      const entries = subRankings[key] ?? []
      if (rankIdx < entries.length) result.push([entries[rankIdx], key])
    }
  }
  return result
}

/**
 * Seed order → FIE <Tireur> records. Seed position is both the ID and the
 * Classement, matching the validated reference file.
 */
export function mixallTireurs(seedOrder: Array<[SeedEntry, string]>): Tireur[] {
  return seedOrder.map(([entry, key], i) => ({
    id: i + 1,
    nom: formatNomWithMarker(entry.surname, key[key.length - 1]),
    prenom: entry.firstName,
    sexe: key[0],
    classement: i + 1,
    club: entry.club,
  }))
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
        ['Club', t.club],
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
    ;(buckets[key] ??= []).push({ idx: r.int_order, surname, firstName, club: r.txt_club ?? '' })
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
              { idx: r.int_order, surname, firstName, club: '' },
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
