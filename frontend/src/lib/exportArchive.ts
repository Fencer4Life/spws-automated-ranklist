// What goes inside the organizer's .zip, besides the XML.
//
// The download page is read once, at a desk, days before the event. The archive
// is opened at the venue, on a laptop, often with no usable wifi — which is
// exactly when "what was step 5 again?" gets asked. So the instructions travel
// with the files rather than staying on the page, and both languages always go,
// whatever the page happened to be set to: the person who downloads the files is
// frequently not the person who runs the software on the day.
//
// One self-contained text file per language rather than a separate manifest:
// the organizer opens one thing and has the file list, what each file is for,
// and the eight steps. Plan §9, ADR-080 amendment (g).

import { tIn, type Locale } from './locale.svelte'
import type { SeedFile } from './ftlSeedExport'
import type { ZipEntry } from './zip'

export interface ArchiveMeta {
  eventCode: string
  eventName: string
  eventLocation: string
  /** When the entry list behind these files was read, as shown on the page. */
  takenAt: string
}

const STEP_COUNT = 8

/** Wrap a paragraph at 78 columns — plain text opened in Notepad has no reflow. */
function wrap(text: string, indent = '   '): string {
  const words = text.split(/\s+/)
  const lines: string[] = []
  let line = ''
  for (const word of words) {
    if (line && (line + ' ' + word).length > 78 - indent.length) {
      lines.push(indent + line)
      line = word
    } else {
      line = line ? `${line} ${word}` : word
    }
  }
  if (line) lines.push(indent + line)
  return lines.join('\n')
}

function rule(char = '='): string {
  return char.repeat(78)
}

function instructionText(locale: Locale, files: SeedFile[], meta: ArchiveMeta): string {
  const T = (key: string, vars?: Record<string, string | number>) => tIn(locale, key, vars)
  const out: string[] = []

  out.push(rule())
  out.push(`SPWS — ${T('ftl_title')}`)
  out.push(
    `${meta.eventName}  ${meta.eventLocation.toUpperCase()}  ${meta.eventCode}`.replace(/\s+/g, ' '),
  )
  out.push(`${T('ftl_archive_taken_at')}: ${meta.takenAt}`)
  out.push(rule())
  out.push('')
  out.push(wrap(T('ftl_intro'), ''))
  out.push('')

  // The file list, grouped the way the page groups it.
  out.push(rule('-'))
  out.push(T('ftl_file_count', { count: files.length }).toUpperCase())
  out.push(rule('-'))
  for (const f of files) {
    out.push('')
    out.push(f.filename)
    const kind =
      f.kind === 'MIXALL'
        ? T('ftl_kind_mixall')
        : f.kind === 'ROSTER'
          ? T('ftl_kind_roster')
          : T('ftl_kind_de')
    out.push(`   ${kind} · ${f.count} ${T('ftl_col_fencers').toLowerCase()}`)
    out.push(wrap(f.title))
    out.push(
      `   >> ${f.importAs === 'PICKLIST' ? T('ftl_import_picklist') : T('ftl_import_competition')}`,
    )
  }
  out.push('')

  out.push(rule('-'))
  out.push(T('ftl_howto_title').toUpperCase())
  out.push(rule('-'))
  out.push(wrap(T('ftl_howto_lead'), ''))
  for (let i = 1; i <= STEP_COUNT; i++) {
    out.push('')
    out.push(`${i}. ${T(`ftl_step${i}_h`)}`)
    out.push(wrap(T(`ftl_step${i}_b`)))
    if (i === 8) out.push(wrap(T('ftl_contact_fallback')))
  }
  out.push('')
  return out.join('\n')
}

/**
 * Every entry the archive carries: the generated XML, plus one instruction file
 * per language.
 */
export function buildArchiveEntries(files: SeedFile[], meta: ArchiveMeta): ZipEntry[] {
  return [
    ...files.map((f) => ({ name: f.filename, text: f.xml })),
    { name: 'INSTRUKCJA.txt', text: instructionText('pl', files, meta) },
    { name: 'INSTRUCTIONS.txt', text: instructionText('en', files, meta) },
  ]
}
