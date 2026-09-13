// FTL seed export — the browser-side twin of python/pipeline/ftl_seed_export.py
// (plan doc/plans/ftl-xml-export-2026-09-12.html, build step 8).
//
// WHY A TWIN AND NOT A SHARED IMPLEMENTATION. The organizer downloads these
// files from a public WordPress page, which is a static host with no server of
// ours behind it — nothing can run the Python. The two implementations are
// therefore deliberate duplicates, and this file exists to keep them honest:
// every assertion here is the same assertion, on the same input, as one in
// python/tests/test_ftl_seed_export.py or test_ftl_seed_orchestration.py. If
// they ever disagree, a seed file generated in the browser stops round-tripping
// through the scraper that reads the results back.
//
// Plan IDs X8.1-X8.16.

import { describe, it, expect } from 'vitest'
import {
  buildEventSeedFiles,
  buildFieXml,
  deTitle,
  exportFilename,
  exportManifest,
  formatNomWithMarker,
  interleaveMixall,
  mixallTitle,
  rosterTitle,
  toCanonicalName,
  type ExportEntryRow,
  type RosterRow,
  type SeedEntry,
} from '../src/lib/ftlSeedExport'

const row = (
  surname: string,
  first: string,
  gender: 'M' | 'F',
  cat: string,
  weapon: string,
  order: number,
): ExportEntryRow => ({
  txt_surname: surname,
  txt_first_name: first,
  enum_gender: gender,
  enum_age_category: cat,
  enum_weapon: weapon,
  int_order: order,
})

// ---------------------------------------------------------------------------
// Canonical name casing (ADR-080 §1)
// ---------------------------------------------------------------------------
describe('toCanonicalName', () => {
  it('X8.1 uppercases the surname and title-cases the given name', () => {
    expect(toCanonicalName('Kowalski', 'jan')).toEqual(['KOWALSKI', 'Jan'])
  })

  it('X8.2 fixes a legacy all-caps given name', () => {
    // The entry list holds "STAŃCZYK MARCIN" and "LEAHEY john" today; both are
    // fixed here rather than in the database.
    expect(toCanonicalName('SPŁAWA-NEYMAN', 'MACIEJ')).toEqual(['SPŁAWA-NEYMAN', 'Maciej'])
  })

  it('X8.3 title-cases each segment of a hyphenated given name', () => {
    // Python's str.title() treats any non-letter as a word boundary, and the
    // twin has to agree on that or the two exporters disagree on a real name.
    expect(toCanonicalName('nowak', 'anna-maria')).toEqual(['NOWAK', 'Anna-Maria'])
  })

  it('X8.4 treats an apostrophe as a boundary too, as str.title() does', () => {
    expect(toCanonicalName("o'neill", "d'arcy")).toEqual(["O'NEILL", "D'Arcy"])
  })

  it('X8.5 trims whitespace', () => {
    expect(toCanonicalName('  Kowalski  ', '  Jan  ')).toEqual(['KOWALSKI', 'Jan'])
  })
})

// ---------------------------------------------------------------------------
// The (N) marker (ADR-080 §1 as amended 2026-09-12)
// ---------------------------------------------------------------------------
describe('formatNomWithMarker', () => {
  it('X8.6 puts the digit after the surname, not after the given name', () => {
    // Fencing Time renders "Nom Prenom", so this reads back as
    // "KOWALSKI (2) Jan" — the form the scraper's split_name_marker matches.
    expect(formatNomWithMarker('KOWALSKI', '2')).toBe('KOWALSKI (2)')
  })

  it('X8.7 treats V0 as a real category rather than an absent marker', () => {
    expect(formatNomWithMarker('PĘCZEK', '0')).toBe('PĘCZEK (0)')
  })
})

// ---------------------------------------------------------------------------
// The interleave (ADR-080 §2) — the same worked example as the Python test
// ---------------------------------------------------------------------------
describe('interleaveMixall', () => {
  it('X8.8 lays down every sub-ranking rank 1, then every rank 2, skipping empties', () => {
    const sub = {
      FV0: [
        { idx: 1, surname: 'PECZEK', firstName: 'Sandra' },
        { idx: 10, surname: 'SZMAJDZINSKA', firstName: 'Katarzyna' },
      ],
      FV1: [{ idx: 2, surname: 'KAMINSKA', firstName: 'Gabriela' }],
      FV2: [{ idx: 3, surname: 'WASILCZUK', firstName: 'Beata' }],
      FV3: [],
      FV4: [{ idx: 4, surname: 'BORKOWSKA', firstName: 'Halina' }],
      MV0: [{ idx: 5, surname: 'SPLAWA-NEYMAN', firstName: 'Maciej' }],
      MV1: [{ idx: 6, surname: 'SEKOWSKI', firstName: 'Maciej' }],
      MV2: [{ idx: 7, surname: 'JENDRYS', firstName: 'Marek' }],
      MV3: [{ idx: 8, surname: 'KRZEMINSKI', firstName: 'Mariusz' }],
      MV4: [{ idx: 9, surname: 'SZCZESNY', firstName: 'Jacek' }],
    }
    const order = interleaveMixall(sub)
    expect(order.map(([e]: [SeedEntry, string]) => e.idx)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    expect(order[3][1]).toBe('FV4') // FV3 skipped, so FV4 is fourth and not fifth
    expect(order[order.length - 1][1]).toBe('FV0') // the rank-2 entry keeps its key
  })

  it('X8.9 returns nothing for an empty entry list', () => {
    expect(interleaveMixall({})).toEqual([])
  })
})

// ---------------------------------------------------------------------------
// Naming (plan §8)
// ---------------------------------------------------------------------------
describe('naming', () => {
  it('X8.10 builds the mix-all filename and title from plan §8 verbatim', () => {
    expect(exportFilename('PPW1-2026-2027', 'EPEE', 'POOLS-MIXED', 'all-categories_W+M')).toBe(
      'PPW1-2026-2027_EPEE_POOLS-MIXED_all-categories_W+M.xml',
    )
    expect(mixallTitle('PPW1-2026-2027', 'EPEE', ['F', 'M'], ['V0', 'V1', 'V2', 'V3', 'V4'])).toBe(
      'SPWS PPW1 2026/27 · SZPADA · ELIMINACJE MIX — kobiety+mężczyźni, V0–V4',
    )
  })

  it('X8.11 states the range actually present, not the whole domain', () => {
    expect(mixallTitle('PPW1-2026-2027', 'SABRE', ['M'], ['V2', 'V3'])).toBe(
      'SPWS PPW1 2026/27 · SZABLA · ELIMINACJE MIX — mężczyźni, V2–V3',
    )
    expect(mixallTitle('PPW1-2026-2027', 'FOIL', ['F'], ['V2'])).toBe(
      'SPWS PPW1 2026/27 · FLORET · ELIMINACJE MIX — kobiety, V2',
    )
  })

  it('X8.12 names a DE file for exactly the one bracket it holds', () => {
    expect(exportFilename('PPW1-2026-2027', 'EPEE', 'DE', 'MEN_V2')).toBe(
      'PPW1-2026-2027_EPEE_DE_MEN_V2.xml',
    )
    expect(deTitle('PPW1-2026-2027', 'EPEE', 'M', 'V2')).toBe(
      'SPWS PPW1 2026/27 · SZPADA · DE mężczyźni V2',
    )
  })

  it('X8.13 warns in the roster title that it is not a competition', () => {
    expect(rosterTitle('EPEE')).toBe(
      'SPWS · BAZA ZAWODNIKÓW — szpada (nie importować jako zawody)',
    )
  })
})

// ---------------------------------------------------------------------------
// The XML — byte-for-byte against Python's ElementTree output
// ---------------------------------------------------------------------------
describe('buildFieXml', () => {
  it('X8.14 matches the Python exporter byte for byte, escaping included', () => {
    // Captured from build_fie_xml() in the venv on 2026-09-12. Attribute order,
    // the space before "/>", the XML declaration and the DOCTYPE are all part
    // of what Fencing Time has been proven to accept, so this is an equality
    // assertion and not a structural one.
    const xml = buildFieXml({
      rootId: 'ID1',
      weaponCode: 'E',
      genderCode: 'M',
      title: 'Tytuł "x" & <y>',
      tireurs: [
        { id: 1, nom: 'ŁĘCKI (2)', prenom: 'Krzysztof', sexe: 'M', classement: 1 },
      ],
      dateFichierXml: '2026-09-12',
    })
    expect(xml).toBe(
      '<?xml version="1.0" encoding="UTF-8"?>\n' +
        '<!DOCTYPE BaseCompetitionIndividuelle>\n' +
        '<BaseCompetitionIndividuelle Championnat="SPWS" ID="ID1" Arme="E" Sexe="M" ' +
        'Domaine="N" Federation="POL" Categorie="V" ' +
        'TitreLong="Tytuł &quot;x&quot; &amp; &lt;y&gt;" Date="" DateFichierXML="2026-09-12">' +
        '<Tireurs><Tireur ID="1" Nom="ŁĘCKI (2)" Prenom="Krzysztof" Sexe="M" Club="" ' +
        'Nation="POL" Licence="" Statut="N" Classement="1" /></Tireurs>' +
        '</BaseCompetitionIndividuelle>',
    )
  })

  it('X8.15 self-closes an empty Tireurs element, as ElementTree does', () => {
    const xml = buildFieXml({
      rootId: 'x',
      weaponCode: 'E',
      genderCode: 'M',
      title: 'T',
      tireurs: [],
    })
    expect(xml).toContain('<Tireurs />')
    expect(xml).not.toContain('DateNaissance')
    expect(xml).not.toContain('Lateralite')
  })
})

// ---------------------------------------------------------------------------
// The whole file set, from the projection the page actually reads
// ---------------------------------------------------------------------------
describe('buildEventSeedFiles', () => {
  const rows: ExportEntryRow[] = [
    row('Peczek', 'Sandra', 'F', 'V0', 'EPEE', 1),
    row('Kowalski', 'jan', 'M', 'V0', 'EPEE', 1),
    row('NOWAK', 'PIOTR', 'M', 'V2', 'EPEE', 1),
    row('Aaa', 'Adam', 'M', 'V2', 'EPEE', 2),
  ]

  it('X8.16 emits one mix-all per weapon and one DE per gender × category present', () => {
    const files = buildEventSeedFiles(rows, 'PPW1-2026-2027')
    expect(new Set(files.map((f) => f.filename))).toEqual(
      new Set([
        'PPW1-2026-2027_EPEE_POOLS-MIXED_all-categories_W+M.xml',
        'PPW1-2026-2027_EPEE_DE_WOMEN_V0.xml',
        'PPW1-2026-2027_EPEE_DE_MEN_V0.xml',
        'PPW1-2026-2027_EPEE_DE_MEN_V2.xml',
      ]),
    )
  })

  it('X8.17 seeds the mix-all by the interleave and carries the marker on Nom', () => {
    const files = buildEventSeedFiles(rows, 'PPW1-2026-2027')
    const mixall = files.find((f) => f.kind === 'MIXALL')!
    const noms = [...mixall.xml.matchAll(/Nom="([^"]*)"/g)].map((m) => m[1])
    // Fixed order FV0, MV0, MV2 for the rank-1 pass, then MV2's rank 2.
    expect(noms).toEqual(['PECZEK (0)', 'KOWALSKI (0)', 'NOWAK (2)', 'AAA (2)'])
    const classements = [...mixall.xml.matchAll(/Classement="([^"]*)"/g)].map((m) => m[1])
    expect(classements).toEqual(['1', '2', '3', '4'])
  })

  it('X8.18 restarts a DE file at seed 1 and stamps the real gender on its root', () => {
    const files = buildEventSeedFiles(rows, 'PPW1-2026-2027')
    const de = files.find((f) => f.filename.endsWith('_DE_MEN_V2.xml'))!
    expect(de.xml).toContain('Sexe="M" Domaine="N"')
    const noms = [...de.xml.matchAll(/Nom="([^"]*)"/g)].map((m) => m[1])
    expect(noms).toEqual(['NOWAK (2)', 'AAA (2)'])
    const classements = [...de.xml.matchAll(/Classement="([^"]*)"/g)].map((m) => m[1])
    expect(classements).toEqual(['1', '2'])
  })

  it('X8.19 builds the manifest from the files themselves', () => {
    const manifest = exportManifest(buildEventSeedFiles(rows, 'PPW1-2026-2027'))
    const mixall = manifest.find((m) => m.kind === 'MIXALL')!
    expect(mixall.count).toBe(4)
    expect(mixall.importAs).toBe('COMPETITION')
    expect(manifest.filter((m) => m.kind === 'DE').map((m) => m.count).sort()).toEqual([1, 1, 2])
  })

  it('X8.20 ignores a weapon nobody entered', () => {
    const files = buildEventSeedFiles(
      [row('Kowalski', 'Jan', 'M', 'V0', 'EPEE', 1)],
      'PPW1-2026-2027',
    )
    expect(files.every((f) => f.weapon === 'EPEE')).toBe(true)
  })
})

// ---------------------------------------------------------------------------
// The roster file — the twin of the Python exporter's _roster_seed_file.
// Plan IDs X8.26-X8.29.
// ---------------------------------------------------------------------------
const rosterRow = (
  surname: string,
  first: string,
  gender: 'M' | 'F',
  cat: string,
  order: number,
): RosterRow => ({
  txt_surname: surname,
  txt_first_name: first,
  enum_gender: gender,
  enum_age_category: cat,
  int_order: order,
})

describe('roster files', () => {
  const entries: ExportEntryRow[] = [
    row('Kowalski', 'Jan', 'M', 'V0', 'EPEE', 1),
    row('Nowak', 'Anna', 'F', 'V2', 'SABRE', 1),
  ]

  it('X8.26 adds one pick-list per weapon that has both entrants and roster rows', () => {
    const files = buildEventSeedFiles(entries, 'PPW1-2026-2027', '', {
      EPEE: [rosterRow('Aaa', 'Adam', 'M', 'V2', 1)],
      SABRE: [rosterRow('Bbb', 'Beata', 'F', 'V1', 1)],
      // Nobody entered foil, so there is no competition to tick anybody into.
      FOIL: [rosterRow('Ccc', 'Cezary', 'M', 'V0', 1)],
    })
    expect(new Set(files.filter((f) => f.kind === 'ROSTER').map((f) => f.filename))).toEqual(
      new Set([
        'PPW1-2026-2027_EPEE_ROSTER_all-known-epee-fencers.xml',
        'PPW1-2026-2027_SABRE_ROSTER_all-known-sabre-fencers.xml',
      ]),
    )
  })

  it('X8.27 marks it a pick-list and warns in the title itself', () => {
    const files = buildEventSeedFiles(entries, 'PPW1-2026-2027', '', {
      EPEE: [rosterRow('Aaa', 'Adam', 'M', 'V2', 1)],
    })
    const roster = files.find((f) => f.kind === 'ROSTER')!
    expect(roster.title).toBe('SPWS · BAZA ZAWODNIKÓW — szpada (nie importować jako zawody)')
    expect(roster.importAs).toBe('PICKLIST')
  })

  it('X8.28 keeps the marker and the roster order, exactly as Python does', () => {
    const files = buildEventSeedFiles(entries, 'PPW1-2026-2027', '', {
      EPEE: [
        rosterRow('ZIELIŃSKI', 'PIOTR', 'M', 'V0', 2),
        rosterRow('nowak', 'anna', 'F', 'V3', 1),
      ],
    })
    const roster = files.find((f) => f.kind === 'ROSTER')!
    const noms = [...roster.xml.matchAll(/Nom="([^"]*)"/g)].map((m) => m[1])
    // int_order wins over the array order it arrived in.
    expect(noms).toEqual(['NOWAK (3)', 'ZIELIŃSKI (0)'])
    expect(roster.count).toBe(2)
  })

  it('X8.29 omits rosters entirely when none are supplied', () => {
    const files = buildEventSeedFiles(entries, 'PPW1-2026-2027')
    expect(files.some((f) => f.kind === 'ROSTER')).toBe(false)
  })
})
