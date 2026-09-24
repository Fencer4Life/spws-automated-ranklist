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
  mixallTireurs,
  mixallTitle,
  polishSortKey,
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
  // The true rank defaults to the entry order, which is what these fixtures
  // meant before the two were separated (2026-09-24).
  rank: number | null = order,
): ExportEntryRow => ({
  txt_surname: surname,
  txt_first_name: first,
  enum_gender: gender,
  enum_age_category: cat,
  enum_weapon: weapon,
  int_order: order,
  int_rank: rank,
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
  it('X8.8 lays down every true rank 1, then every true rank 2, skipping empties', () => {
    const sub = {
      FV0: [
        { idx: 1, surname: 'PECZEK', firstName: 'Sandra', rank: 1 },
        { idx: 10, surname: 'SZMAJDZINSKA', firstName: 'Katarzyna', rank: 2 },
      ],
      FV1: [{ idx: 2, surname: 'KAMINSKA', firstName: 'Gabriela', rank: 1 }],
      FV2: [{ idx: 3, surname: 'WASILCZUK', firstName: 'Beata', rank: 1 }],
      FV3: [],
      FV4: [{ idx: 4, surname: 'BORKOWSKA', firstName: 'Halina', rank: 1 }],
      MV0: [{ idx: 5, surname: 'SPLAWA-NEYMAN', firstName: 'Maciej', rank: 1 }],
      MV1: [{ idx: 6, surname: 'SEKOWSKI', firstName: 'Maciej', rank: 1 }],
      MV2: [{ idx: 7, surname: 'JENDRYS', firstName: 'Marek', rank: 1 }],
      MV3: [{ idx: 8, surname: 'KRZEMINSKI', firstName: 'Mariusz', rank: 1 }],
      MV4: [{ idx: 9, surname: 'SZCZESNY', firstName: 'Jacek', rank: 1 }],
    }
    const order = interleaveMixall(sub)
    expect(order.map(([e]: [SeedEntry, string]) => e.idx)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    expect(order[3][1]).toBe('FV4') // FV3 skipped, so FV4 is fourth and not fifth
    expect(order[order.length - 1][1]).toBe('FV0') // the rank-2 entry keeps its key
  })

  it('X8.8b tiers on the true rank, so a 4th place is not seeded as a winner', () => {
    // PPW1 2026, EPEE. SZKLAR is 4th on the FV0 ranklist and ranks 1-3 did not
    // enter; compacting the entrants made her FV0's "first" and seeded her
    // ahead of every genuine category winner.
    const order = interleaveMixall({
      FV0: [{ idx: 1, surname: 'SZKLAR', firstName: 'Bozena', rank: 4 }],
      FV1: [{ idx: 1, surname: 'KAMINSKA', firstName: 'Gabriela', rank: 1 }],
      MV2: [{ idx: 1, surname: 'JENDRYS', firstName: 'Marek', rank: 2 }],
    })
    expect(order.map(([e]: [SeedEntry, string]) => e.surname)).toEqual([
      'KAMINSKA',
      'JENDRYS',
      'SZKLAR',
    ])
  })

  it('X8.8c puts every unranked fencer after every ranked one', () => {
    const order = interleaveMixall({
      FV0: [
        { idx: 1, surname: 'RANKED', firstName: 'Anna', rank: 9 },
        { idx: 2, surname: 'NEW', firstName: 'Ewa', rank: null },
      ],
      MV0: [{ idx: 1, surname: 'TOPMAN', firstName: 'Adam', rank: 1 }],
    })
    expect(order.map(([e]: [SeedEntry, string]) => e.surname)).toEqual([
      'TOPMAN',
      'RANKED',
      'NEW',
    ])
  })

  it('X8.9 returns nothing for an empty entry list', () => {
    expect(interleaveMixall({})).toEqual([])
  })
})

// ---------------------------------------------------------------------------
// Polish collation — the same assertions as the Python test's collation block.
//
// This cannot be Intl.Collator: the Python twin has no equivalent, and the two
// exporters are asserted byte for byte. The alphabet below is therefore the
// shared contract, written out in both files and agreeing by construction.
// Plan IDs X8.30-X8.34.
// ---------------------------------------------------------------------------
describe('polishSortKey', () => {
  const sorted = (names: string[]): string[] =>
    [...names].sort((a, b) => {
      const ka = polishSortKey(a)
      const kb = polishSortKey(b)
      for (let i = 0; i < Math.min(ka.length, kb.length); i++) {
        if (ka[i] !== kb[i]) return ka[i] - kb[i]
      }
      return ka.length - kb.length
    })

  it('X8.30 puts Ł between L and M, not after Z', () => {
    // A code-point sort returns Lis, Maj, Łuczak — the defect EntryList.svelte
    // documents at :127-130 and works around with a collator.
    expect(sorted(['Maj', 'Łuczak', 'Lis'])).toEqual(['Lis', 'Łuczak', 'Maj'])
  })

  it('X8.31 puts Ó between O and P, and Ż last of all', () => {
    expect(sorted(['Paw', 'Ósemka', 'Olek'])).toEqual(['Olek', 'Ósemka', 'Paw'])
    expect(sorted(['Żak', 'Zych', 'Źródło'])).toEqual(['Zych', 'Źródło', 'Żak'])
  })

  it('X8.32 sorts the full Polish alphabet into its own order', () => {
    const letters = [...'aąbcćdeęfghijklłmnńoópqrsśtuvwxyzźż']
    expect(sorted([...letters].reverse())).toEqual(letters)
  })

  it('X8.33 is case-insensitive, so a lower-case self-registration files with its peers', () => {
    expect(sorted(['kowalski', 'KOWALCZYK'])).toEqual(['KOWALCZYK', 'kowalski'])
  })

  it('X8.34 sorts a hyphen and an apostrophe before any letter', () => {
    // "Spława-Neyman" lands before "Spławacz": at the seventh character a
    // hyphen outranks a letter, which is what a reader scanning a column of
    // surnames expects.
    expect(sorted(['Spławacz', 'Spława-Neyman'])).toEqual(['Spława-Neyman', 'Spławacz'])
    expect(sorted(["O'Neill", 'Onacki'])).toEqual(["O'Neill", 'Onacki'])
  })
})

describe('mixallTireurs', () => {
  const entry = (surname: string, firstName: string): SeedEntry => ({
    idx: 1,
    rank: 1,
    surname,
    firstName,
  })

  it('X8.35 numbers by seed first, then writes the records out alphabetically', () => {
    const tireurs = mixallTireurs([
      [entry('ŻAK', 'Adam'), 'MV0'],
      [entry('LIS', 'Ewa'), 'FV1'],
      [entry('ŁUCZAK', 'Jan'), 'MV2'],
    ])
    expect(tireurs.map((t) => t.nom)).toEqual(['LIS (1)', 'ŁUCZAK (2)', 'ŻAK (0)'])
    // Seed 1 went to ŻAK and stays with ŻAK.
    expect(tireurs.map((t) => t.classement)).toEqual([2, 3, 1])
    expect(tireurs.map((t) => t.id)).toEqual([2, 3, 1])
  })

  it('X8.36 breaks a tie on the given name, then on seed order', () => {
    const tireurs = mixallTireurs([
      [entry('NOWAK', 'Piotr'), 'MV0'],
      [entry('NOWAK', 'Anna'), 'FV0'],
      // Same person twice by name: stable sort keeps the earlier seed first, so
      // two identical registrations still produce one deterministic file.
      [entry('NOWAK', 'Anna'), 'FV2'],
    ])
    expect(tireurs.map((t) => [t.nom, t.classement])).toEqual([
      ['NOWAK (0)', 2],
      ['NOWAK (2)', 3],
      ['NOWAK (0)', 1],
    ])
  })

  it('X8.37 ignores the (N) marker when ordering, so it sorts on the surname alone', () => {
    // The marker is appended to Nom after the key is taken. Sorting on the
    // formatted Nom would interleave categories instead of names.
    const tireurs = mixallTireurs([
      [entry('NOWAKOWSKI', 'Jan'), 'MV0'],
      [entry('NOWAK', 'Jan'), 'MV4'],
    ])
    expect(tireurs.map((t) => t.nom)).toEqual(['NOWAK (4)', 'NOWAKOWSKI (0)'])
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
    // Captured from build_fie_xml() in the venv on 2026-09-24, re-captured when
    // the declared club was withdrawn: a club is passed in below and the
    // exporter emits Club="" regardless, which is the point of the assertion. Attribute
    // order, the space before "/>", the XML declaration and the DOCTYPE are
    // all part of what Fencing Time has been proven to accept, so this is an
    // equality assertion and not a structural one.
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

  it('X8.14b renders Club="" when no club was declared, same as before this field existed', () => {
    const xml = buildFieXml({
      rootId: 'ID1',
      weaponCode: 'E',
      genderCode: 'M',
      title: 'T',
      tireurs: [{ id: 1, nom: 'KOWALSKI (2)', prenom: 'Jan', sexe: 'M', classement: 1 }],
    })
    expect(xml).toContain('Club=""')
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

  it('X8.17 lists the mix-all alphabetically while Classement keeps the interleave seed', () => {
    const files = buildEventSeedFiles(rows, 'PPW1-2026-2027')
    const mixall = files.find((f) => f.kind === 'MIXALL')!
    const noms = [...mixall.xml.matchAll(/Nom="([^"]*)"/g)].map((m) => m[1])
    // Written A→Ż so the organizer can find a name, which is the only check
    // anyone performs on the raw file.
    expect(noms).toEqual(['AAA (2)', 'KOWALSKI (0)', 'NOWAK (2)', 'PECZEK (0)'])
    // The seeding is untouched and simply no longer coincides with the order:
    // the interleave laid down FV0, MV0, MV2 for the rank-1 pass then MV2's
    // rank 2, i.e. PECZEK=1, KOWALSKI=2, NOWAK=3, AAA=4.
    const classements = [...mixall.xml.matchAll(/Classement="([^"]*)"/g)].map((m) => m[1])
    expect(classements).toEqual(['4', '2', '3', '1'])
    // ID tracks the seed, not the row number — as it does in Fencing Time's own
    // exports (doc/external_files/FTL_SRC/F-DzieciExport.xml).
    const ids = [...mixall.xml.matchAll(/<Tireur ID="([^"]*)"/g)].map((m) => m[1])
    expect(ids).toEqual(classements)
  })

  it('X8.18 restarts a DE file at seed 1 and stamps the real gender on its root', () => {
    const files = buildEventSeedFiles(rows, 'PPW1-2026-2027')
    const de = files.find((f) => f.filename.endsWith('_DE_MEN_V2.xml'))!
    expect(de.xml).toContain('Sexe="M" Domaine="N"')
    const noms = [...de.xml.matchAll(/Nom="([^"]*)"/g)].map((m) => m[1])
    expect(noms).toEqual(['AAA (2)', 'NOWAK (2)'])
    // Seeds still restart at 1 for the bracket; AAA is seeded second and says so.
    const classements = [...de.xml.matchAll(/Classement="([^"]*)"/g)].map((m) => m[1])
    expect(classements).toEqual(['2', '1'])
  })

  it('X8.19 builds the manifest from the files themselves', () => {
    const manifest = exportManifest(buildEventSeedFiles(rows, 'PPW1-2026-2027'))
    const mixall = manifest.find((m) => m.kind === 'MIXALL')!
    expect(mixall.count).toBe(4)
    expect(mixall.importAs).toBe('COMPETITION')
    expect(manifest.filter((m) => m.kind === 'DE').map((m) => m.count).sort()).toEqual([1, 1, 2])
  })

  it('X8.20b emits an empty club even when the projection still carries one', () => {
    // ADR-080 amendment (f) withdrawn 2026-09-24: 41 of PPW1's 90 registrations
    // declared a club and the free text was unusable — one Poznan club under
    // three spellings, a "Wawrszawa" typo, diacritics dropped. The attribute
    // stays because the validated FIE reference files carry it.
    const files = buildEventSeedFiles(
      [
        {
          txt_surname: 'Kowalski',
          txt_first_name: 'Jan',
          enum_gender: 'M',
          enum_age_category: 'V0',
          enum_weapon: 'EPEE',
          int_order: 1,
          int_rank: 1,
        },
      ],
      'PPW1-2026-2027',
      '',
    )
    const mixall = files.find((f) => f.kind === 'MIXALL')!
    expect(mixall.xml).toContain('Nom="KOWALSKI (0)" Prenom="Jan" Sexe="M" Club=""')
    expect(mixall.xml).not.toContain('AZS')
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

  it('X8.28 keeps the marker and lists the pick-list alphabetically', () => {
    const files = buildEventSeedFiles(entries, 'PPW1-2026-2027', '', {
      EPEE: [
        rosterRow('ZIELIŃSKI', 'PIOTR', 'M', 'V0', 1),
        rosterRow('nowak', 'anna', 'F', 'V3', 2),
        rosterRow('ŁUCZAK', 'Jan', 'M', 'V1', 3),
      ],
    })
    const roster = files.find((f) => f.kind === 'ROSTER')!
    const noms = [...roster.xml.matchAll(/Nom="([^"]*)"/g)].map((m) => m[1])
    // fn_ftl_roster already orders by surname, but under the database's
    // collation; re-keying here is what puts Ł between L and Z rather than
    // after it, and makes all three file kinds agree on one alphabet.
    expect(noms).toEqual(['ŁUCZAK (1)', 'NOWAK (3)', 'ZIELIŃSKI (0)'])
    expect(roster.count).toBe(3)
  })

  it('X8.29 omits rosters entirely when none are supplied', () => {
    const files = buildEventSeedFiles(entries, 'PPW1-2026-2027')
    expect(files.some((f) => f.kind === 'ROSTER')).toBe(false)
  })
})
