// The archive the organizer actually carries to the venue.
// Plan IDs X8.30-X8.35.
//
// WHY THE INSTRUCTIONS GO INSIDE THE ZIP. The page is read once, at a desk, days
// before the event. The archive is opened at the venue, on a laptop, often with
// no usable wifi — which is exactly when "what was step 5 again?" gets asked.
// Both languages always travel, whatever the page was set to, because the person
// who downloads the files is frequently not the person who runs the software.

import { describe, it, expect } from 'vitest'
import { buildArchiveEntries } from '../src/lib/exportArchive'
import { buildEventSeedFiles, type ExportEntryRow } from '../src/lib/ftlSeedExport'

const rows: ExportEntryRow[] = [
  {
    txt_surname: 'Kowalski',
    txt_first_name: 'Jan',
    enum_gender: 'M',
    enum_age_category: 'V2',
    enum_weapon: 'EPEE',
    int_order: 1,
    int_rank: 1,
  },
]
const files = buildEventSeedFiles(rows, 'PPW1-2026-2027')
const meta = {
  eventCode: 'PPW1-2026-2027',
  eventName: 'I Puchar Polski Weteranów w Szermierce',
  eventLocation: 'Opole',
  takenAt: '2026-09-12 20:15',
}

describe('buildArchiveEntries', () => {
  it('X8.30 carries every generated XML file', () => {
    const names = buildArchiveEntries(files, meta).map((e) => e.name)
    for (const f of files) expect(names).toContain(f.filename)
  })

  it('X8.31 adds one instruction file per language, whatever the page is set to', () => {
    const names = buildArchiveEntries(files, meta).map((e) => e.name)
    expect(names).toContain('INSTRUKCJA.txt')
    expect(names).toContain('INSTRUCTIONS.txt')
  })

  it('X8.32 writes each instruction file in its own language', () => {
    const entries = buildArchiveEntries(files, meta)
    const pl = entries.find((e) => e.name === 'INSTRUKCJA.txt')!.text
    const en = entries.find((e) => e.name === 'INSTRUCTIONS.txt')!.text
    // Section headings are upper-cased: a plain-text file opened in Notepad has
    // no other way to show a heading.
    expect(pl).toContain('INSTRUKCJA KROK PO KROKU')
    expect(pl).toContain('Nie usuwaj cyfry z nazwiska')
    expect(en).toContain('STEP BY STEP')
    expect(en).toContain('Do not remove the digit from the surname')
    // and neither leaks into the other
    expect(pl).not.toContain('Step by step')
    expect(en).not.toContain('Nie usuwaj')
  })

  it('X8.33 names the event and the moment the list was taken', () => {
    const pl = buildArchiveEntries(files, meta).find((e) => e.name === 'INSTRUKCJA.txt')!.text
    expect(pl).toContain('I Puchar Polski Weteranów w Szermierce')
    expect(pl).toContain('OPOLE')
    expect(pl).toContain('PPW1-2026-2027')
    // The entry list moves until the deadline; a file with no timestamp cannot
    // be told apart from the one downloaded a week earlier.
    expect(pl).toContain('2026-09-12 20:15')
  })

  it('X8.34 lists every file with its count and what to do with it', () => {
    const pl = buildArchiveEntries(files, meta).find((e) => e.name === 'INSTRUKCJA.txt')!.text
    for (const f of files) {
      expect(pl).toContain(f.filename)
      expect(pl).toContain(f.title)
    }
    expect(pl).toContain('Wczytaj jako zawody')
  })

  it('X8.35 uses the invented example name, never a real fencer', () => {
    // This text is published. KAMIŃSKA Gabriela is a real person entered for a
    // live event, and Kowalski / Kowalska / Nowak are all real members too.
    const entries = buildArchiveEntries(files, meta)
    for (const e of entries.filter((x) => x.name.endsWith('.txt'))) {
      expect(e.text).toContain('PRZYKŁADOWSKA (1) Anna')
      expect(e.text).not.toContain('KAMIŃSKA')
    }
  })
})
