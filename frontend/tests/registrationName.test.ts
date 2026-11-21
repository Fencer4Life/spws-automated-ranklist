// FR-167 — the name form of a registration (RFNAME.01–08). The cases are the
// ones PROD actually held on 21 Nov 2026 plus the edges the rule must not trip
// on. The database's twin (supabase/tests/130_registration_names.sql) pins the
// same cases, so the form and the table cannot disagree about a name.

import { describe, it, expect } from 'vitest'
import { canonicalGivenName, normaliseNames, surnameWithoutTitle } from '../src/lib/registrationName'

describe('RFNAME.01 — a given name in any case is written in title case', () => {
  it.each([
    ['anna', 'Anna'],
    ['ANNA', 'Anna'],
    ['aNNA', 'Anna'],
    ['DZMITRY', 'Dzmitry'],
    ['dmytro', 'Dmytro'],
  ])('%s → %s', (typed, written) => {
    expect(canonicalGivenName(typed)).toBe(written)
  })
})

describe('RFNAME.02 — double, hyphenated and apostrophe names keep every part', () => {
  it.each([
    ['eszter zsuzsanna', 'Eszter Zsuzsanna'],
    ['ESZTER ZSUZSANNA', 'Eszter Zsuzsanna'],
    ['anna-maria', 'Anna-Maria'],
    ["o'neil", "O'Neil"],
    ['maria adelaide', 'Maria Adelaide'],
  ])('%s → %s', (typed, written) => {
    expect(canonicalGivenName(typed)).toBe(written)
  })
})

describe('RFNAME.03 — accented letters keep their marks', () => {
  it.each([
    ['łukasz', 'Łukasz'],
    ['ŻANETA', 'Żaneta'],
    ['ernőné', 'Ernőné'],
    ['LÁSZLÓ', 'László'],
  ])('%s → %s', (typed, written) => {
    expect(canonicalGivenName(typed)).toBe(written)
  })
})

describe('RFNAME.04 — spaces, and the surname in capitals', () => {
  it('trims and collapses both boxes and writes the surname in capitals', () => {
    expect(normaliseNames('  van der  bruggen ', '  jan   paweł ')).toEqual({
      surname: 'VAN DER BRUGGEN',
      firstName: 'Jan Paweł',
    })
  })

  it('leaves an already written name exactly as it is', () => {
    expect(normaliseNames('KOWALSKA', 'Anna')).toEqual({ surname: 'KOWALSKA', firstName: 'Anna' })
  })
})

describe('RFNAME.05 — each title has one written form, in front of the surname', () => {
  it.each([
    ['dr kovács', 'Dr. KOVÁCS'],
    ['DR VERESS', 'Dr. VERESS'],
    ['Dr. Kovács', 'Dr. KOVÁCS'],
    ['ddr huber', 'DDr. HUBER'],
    ['prof nowak', 'Prof. NOWAK'],
    ['ing. novák', 'Ing. NOVÁK'],
    ['mag gruber', 'Mag. GRUBER'],
    ['mgr kowalski', 'Mgr. KOWALSKI'],
    ['doc svoboda', 'Doc. SVOBODA'],
    ['dipl-ing maier', 'Dipl.-Ing. MAIER'],
    ['Dipl.-Ing. maier', 'Dipl.-Ing. MAIER'],
  ])('%s → %s', (typed, written) => {
    expect(normaliseNames(typed, 'Péter').surname).toBe(written)
  })
})

describe('RFNAME.06 — combined titles keep their order', () => {
  it('Prof. Dr.', () => {
    expect(normaliseNames('prof dr kovács', 'péter')).toEqual({ surname: 'Prof. Dr. KOVÁCS', firstName: 'Péter' })
  })
})

describe('RFNAME.07 — a title anywhere moves in front of the surname', () => {
  it('at the end of the given-name box', () => {
    expect(normaliseNames('ORSOLYA', 'Szabó Dr.')).toEqual({ surname: 'Dr. ORSOLYA', firstName: 'Szabó' })
  })

  it('at the start of the given-name box', () => {
    expect(normaliseNames('KOVÁCS', 'dr péter')).toEqual({ surname: 'Dr. KOVÁCS', firstName: 'Péter' })
  })

  it('at the end of the surname box', () => {
    expect(normaliseNames('KOVÁCS DR', 'Péter')).toEqual({ surname: 'Dr. KOVÁCS', firstName: 'Péter' })
  })

  it('never empties a box: a lone word stays a name', () => {
    expect(normaliseNames('DR', 'Ing')).toEqual({ surname: 'DR', firstName: 'Ing' })
  })

  it('the surname without its title is the bare surname', () => {
    expect(surnameWithoutTitle('Prof. Dr. KOVÁCS')).toBe('KOVÁCS')
    expect(surnameWithoutTitle('KOWALSKA')).toBe('KOWALSKA')
  })
})

describe('RFNAME.08 — a word that only begins like a title is a name', () => {
  it.each([
    ['DRAGAN', 'Ingrid'],
    ['MAGDA', 'Doctor'],
    ['DRAGAN-MAGDA', 'Ingeborg'],
  ])('%s %s is left alone', (surname, firstName) => {
    const out = normaliseNames(surname, firstName)
    expect(out.surname).toBe(surname)
    expect(out.firstName).toBe(firstName)
  })
})
