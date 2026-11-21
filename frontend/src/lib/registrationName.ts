// FR-167 — the one written form of a declared name (ADR-079 amendment
// 2026-11-21). The form applies it when a name box is left and again on
// „Dalej”; the database applies the same rule to a newcomer's row whatever
// wrote it (fn_registration_canonical_names, migration 20261121000001). Both
// are pinned on the same cases: frontend/tests/registrationName.test.ts and
// supabase/tests/130_registration_names.sql.
//
// THE GIVEN NAME uses the rule the organizer's files have always used
// (pythonTitle, ADR-080 §1), so an entry reads the same on the list and in the
// file. THE TITLE is the Austrian and Hungarian habit of writing „dr” with the
// name; PROD held both forms, „DR SURNAME” and „Given Dr.”, on 21 Nov 2026. It is
// moved in front of the surname in one written form and is ignored wherever
// names are compared (surnameWithoutTitle).

/**
 * Python's str.title(), which is the rule the exporter has always used: every
 * letter that follows a non-letter starts a new word. That makes hyphens,
 * apostrophes and spaces all boundaries — "anna-maria" becomes "Anna-Maria"
 * and "d'arcy" becomes "D'Arcy". Implemented explicitly rather than with a
 * word-splitting helper because the twin has to agree with Python on real
 * names, not on the common case. Shared by the form and the exporter.
 */
export function pythonTitle(value: string): string {
  return value
    .toLowerCase()
    .replace(/(^|[^\p{L}])(\p{L})/gu, (_m, before: string, letter: string) => before + letter.toUpperCase())
}

// A title is a WHOLE word from this list, with or without its dot. „DRAGAN”,
// „Ingrid” and „Magda” only begin like one and are left alone.
const TITLE_FORMS: Record<string, string> = {
  dr: 'Dr.',
  ddr: 'DDr.',
  prof: 'Prof.',
  ing: 'Ing.',
  mag: 'Mag.',
  mgr: 'Mgr.',
  doc: 'Doc.',
  dipling: 'Dipl.-Ing.',
}

function titleForm(word: string): string | null {
  const key = word.toLowerCase().replace(/[.-]/g, '')
  if (!/^[a-z]+$/.test(key)) return null
  return TITLE_FORMS[key] ?? null
}

function words(value: string): string[] {
  return value.trim().split(/\s+/).filter((w) => w !== '')
}

// Takes titles off both ends of a box, in the order they stand, never the
// box's last word: a lone „DR” is somebody's name.
function takeTitles(parts: string[], into: string[]): string[] {
  const rest = [...parts]
  const front: string[] = []
  while (rest.length > 1 && titleForm(rest[0]) != null) front.push(titleForm(rest.shift() as string) as string)
  const back: string[] = []
  while (rest.length > 1 && titleForm(rest[rest.length - 1]) != null)
    back.unshift(titleForm(rest.pop() as string) as string)
  into.push(...front, ...back)
  return rest
}

/** The given name's written form: trimmed, doubled spaces collapsed, title case. */
export function canonicalGivenName(value: string): string {
  return pythonTitle(words(value).join(' '))
}

/**
 * Both boxes in their written form. Titles found at either end of either box
 * go in front of the surname; the surname is in capitals, the given name in
 * title case.
 */
export function normaliseNames(surname: string, firstName: string): { surname: string; firstName: string } {
  const titles: string[] = []
  const s = takeTitles(words(surname), titles)
  const f = takeTitles(words(firstName), titles)
  const bare = s.join(' ').toUpperCase()
  return {
    surname: [...titles, bare].filter((p) => p !== '').join(' '),
    firstName: canonicalGivenName(f.join(' ')),
  }
}

/** The surname with any title taken off: what every comparison uses. */
export function surnameWithoutTitle(surname: string): string {
  return takeTitles(words(surname), []).join(' ')
}
