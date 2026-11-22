// FR-170 — the administrator's edit dialog (RFADM.02, 03, 06, 07, 13).
// Plan registration-form-names-year-country rev 10, release 4 (D2 A, D5 A).
// The dialog is opened only from the signed-in entry list (EntryList.test.ts,
// RFADM.01, 05, 08, 14); the API calls are pinned in api.registration.test.ts.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, fireEvent, waitFor } from '@testing-library/svelte'
import { setLocale } from '../src/lib/locale.svelte'
import { birthYearRange } from '../src/lib/birthYearRange'

vi.mock('../src/lib/api', () => ({
  updateRegistrationAsAdmin: vi.fn(),
}))
import { updateRegistrationAsAdmin } from '../src/lib/api'
import EntryEdit from '../src/components/EntryEdit.svelte'
import type { AdminEntryDetail, RegistrationEntry } from '../src/lib/types'

const mockUpdate = vi.mocked(updateRegistrationAsAdmin)

const NEWCOMER: RegistrationEntry = {
  id_registration: 9, id_event: 3, txt_surname: 'SMITH', txt_first_name: 'John', enum_gender: 'M',
  arr_weapons: ['EPEE'], enum_age_category: 'V0', txt_country: 'GBR',
}
const NEWCOMER_DETAIL: AdminEntryDetail = {
  id_registration: 9, int_birth_year: 1990, txt_club: 'London FC', txt_country: 'GBR', id_fencer: null, txt_name_source: 'EVF', roster_birth_year: null,
}
const LINKED: RegistrationEntry = {
  id_registration: 4, id_event: 3, txt_surname: 'NOWAK', txt_first_name: 'Piotr', enum_gender: 'M',
  arr_weapons: ['SABRE'], enum_age_category: 'V1', txt_country: null,
}
const LINKED_DETAIL: AdminEntryDetail = {
  id_registration: 4, int_birth_year: 1980, txt_club: null, txt_country: null, id_fencer: 12, txt_name_source: 'TYPED', roster_birth_year: 1984,
}

function open(entry = NEWCOMER, detail = NEWCOMER_DETAIL) {
  const onsaved = vi.fn()
  const oncancel = vi.fn()
  const view = render(EntryEdit, { props: { entry, detail, seasonEndYear: 2027, onsaved, oncancel } })
  const c = view.container
  const field = (name: string) => c.querySelector(`[name="${name}"]`) as HTMLInputElement
  const text = (sel: string) => (c.querySelector(sel)?.textContent ?? '').replace(/\s+/g, ' ').trim()
  const save = () => c.querySelector('button.ee-save') as HTMLButtonElement
  const cancel = () => c.querySelector('button.ee-cancel') as HTMLButtonElement
  const weapon = (w: string) => c.querySelector(`input[type="checkbox"][value="${w}"]`) as HTMLInputElement
  return { ...view, c, field, text, save, cancel, weapon, onsaved, oncancel }
}

beforeEach(() => {
  vi.clearAllMocks()
})
afterEach(() => setLocale('pl'))

describe('EntryEdit — how the name arrived (FR-173, RFAC.29)', () => {
  it('shows one line naming where the entry\'s name came from', () => {
    const v = open()
    expect(v.text('.ee-name-source')).toBe('Nazwisko: z rankingu EVF')
    v.unmount()
    const w = open(LINKED, LINKED_DETAIL)
    expect(w.text('.ee-name-source')).toBe('Nazwisko: wpisane ręcznie')
  })

  it('shows the line in English', () => {
    setLocale('en')
    const v = open()
    expect(v.text('.ee-name-source')).toBe('Name: from the EVF ranking')
  })
})

describe('EntryEdit — opens with the entry (RFADM.02)', () => {
  it('shows every declared field with the entry\'s values', () => {
    const v = open()
    expect(v.text('.ee-title')).toBe('Edytuj zgłoszenie')
    expect(v.field('surname').value).toBe('SMITH')
    expect(v.field('firstName').value).toBe('John')
    expect((v.c.querySelector('select[name="gender"]') as HTMLSelectElement).value).toBe('M')
    expect(v.field('birthYear').value).toBe('1990')
    expect(v.weapon('EPEE').checked).toBe(true)
    expect(v.weapon('FOIL').checked).toBe(false)
    expect(v.weapon('SABRE').checked).toBe(false)
    expect(v.field('club').value).toBe('London FC')
    expect(v.field('country').value).toBe('Wielka Brytania')
    expect(v.text('.cp-code')).toBe('GBR')
    expect(v.save().textContent?.trim()).toBe('Zapisz')
    expect(v.cancel().textContent?.trim()).toBe('Anuluj')
  })

  it('takes focus as it opens, so Escape lands on it', async () => {
    const v = open()
    await waitFor(() => expect(v.c.querySelector('[role="dialog"]')!.contains(document.activeElement)).toBe(true))
  })

  it('an entry without a country opens with an empty country box', () => {
    const v = open(LINKED, LINKED_DETAIL)
    expect(v.field('country').value).toBe('')
  })
})

describe('EntryEdit — a linked entry\'s name is locked (RFADM.03)', () => {
  it('locks the surname and given name of a linked entry, saying why', () => {
    const v = open(LINKED, LINKED_DETAIL)
    expect(v.field('surname').disabled).toBe(true)
    expect(v.field('firstName').disabled).toBe(true)
    expect(v.text('.ee-locked')).toBe('Imię i nazwisko z bazy zawodników')
  })

  it('leaves a newcomer\'s name editable, with no note', () => {
    const v = open()
    expect(v.field('surname').disabled).toBe(false)
    expect(v.field('firstName').disabled).toBe(false)
    expect(v.c.querySelector('.ee-locked')).toBeNull()
  })
})

describe('EntryEdit — saving (RFADM.04 from the dialog)', () => {
  it('saves a newcomer\'s edited values and reports the save', async () => {
    mockUpdate.mockResolvedValue(undefined)
    const v = open()
    await fireEvent.input(v.field('surname'), { target: { value: 'SMYTH' } })
    await fireEvent.click(v.weapon('FOIL'))
    await fireEvent.input(v.field('club'), { target: { value: '' } })
    await fireEvent.click(v.save())
    await waitFor(() => expect(v.onsaved).toHaveBeenCalledTimes(1))
    expect(mockUpdate).toHaveBeenCalledWith(9, {
      surname: 'SMYTH', firstName: 'John', gender: 'M', birthYear: 1990, weapons: ['EPEE', 'FOIL'], club: '', country: 'GBR',
    })
  })

  it('saves a linked entry without its name', async () => {
    mockUpdate.mockResolvedValue(undefined)
    const v = open(LINKED, LINKED_DETAIL)
    await fireEvent.click(v.save())
    await waitFor(() => expect(v.onsaved).toHaveBeenCalledTimes(1))
    expect(mockUpdate).toHaveBeenCalledWith(4, { gender: 'M', birthYear: 1980, weapons: ['SABRE'], club: '', country: '' })
  })

  it('keeps „Zapisz” off without a weapon, an empty name or a year outside the range', async () => {
    const v = open()
    await fireEvent.click(v.weapon('EPEE'))
    expect(v.save().disabled).toBe(true)
    await fireEvent.click(v.weapon('EPEE'))
    expect(v.save().disabled).toBe(false)
    await fireEvent.input(v.field('surname'), { target: { value: '  ' } })
    expect(v.save().disabled).toBe(true)
    await fireEvent.input(v.field('surname'), { target: { value: 'SMITH' } })
    await fireEvent.input(v.field('birthYear'), { target: { value: '1999' } })
    expect(v.save().disabled).toBe(true)
  })

  it('disables „Zapisz” while the save is in flight and sends it once', async () => {
    let finish!: () => void
    mockUpdate.mockReturnValue(new Promise<void>((r) => (finish = r)))
    const v = open()
    await fireEvent.click(v.save())
    expect(v.save().disabled).toBe(true)
    await fireEvent.click(v.save())
    expect(mockUpdate).toHaveBeenCalledTimes(1)
    finish()
    await waitFor(() => expect(v.onsaved).toHaveBeenCalledTimes(1))
  })
})

describe('EntryEdit — a refused save keeps the dialog with the reason (RFADM.06)', () => {
  it('a year refusal shows the range line', async () => {
    mockUpdate.mockRejectedValue({ code: '23514', message: 'REG_BIRTH_YEAR_OUT_OF_RANGE: 1990 outside 1906–1997' })
    const v = open()
    await fireEvent.click(v.save())
    // The dialog's own range, as the form shows it: computed, never a fixed year.
    const r = birthYearRange(2027)
    await waitFor(() => expect(v.text('.ee-error')).toBe(`Rok spoza zakresu ${r.min}–${r.max}`))
    expect(v.onsaved).not.toHaveBeenCalled()
    expect(v.field('surname').value).toBe('SMITH')
  })

  it('a duplicate entry says so', async () => {
    mockUpdate.mockRejectedValue({ code: '23505', message: 'duplicate key' })
    const v = open()
    await fireEvent.click(v.save())
    await waitFor(() => expect(v.text('.ee-error')).toBe('Takie zgłoszenie już istnieje.'))
    expect(v.onsaved).not.toHaveBeenCalled()
  })

  it('anything else says the save failed, and a second try can succeed', async () => {
    mockUpdate.mockRejectedValueOnce(new Error('network')).mockResolvedValueOnce(undefined)
    const v = open()
    await fireEvent.click(v.save())
    await waitFor(() => expect(v.text('.ee-error')).toBe('Nie udało się zapisać zmian. Spróbuj ponownie.'))
    await fireEvent.click(v.save())
    await waitFor(() => expect(v.onsaved).toHaveBeenCalledTimes(1))
  })
})

describe('EntryEdit — closing changes nothing (RFADM.07)', () => {
  it('„Anuluj” closes without saving', async () => {
    const v = open()
    await fireEvent.click(v.cancel())
    expect(v.oncancel).toHaveBeenCalledTimes(1)
    expect(mockUpdate).not.toHaveBeenCalled()
  })

  it('Escape closes without saving', async () => {
    const v = open()
    await fireEvent.keyDown(v.c.querySelector('[role="dialog"]') as Element, { key: 'Escape' })
    expect(v.oncancel).toHaveBeenCalledTimes(1)
    expect(mockUpdate).not.toHaveBeenCalled()
  })

  it('a click on the backdrop closes; a click inside does not', async () => {
    const v = open()
    await fireEvent.click(v.c.querySelector('[role="dialog"]') as Element)
    expect(v.oncancel).not.toHaveBeenCalled()
    await fireEvent.click(v.c.querySelector('.ee-backdrop') as Element)
    expect(v.oncancel).toHaveBeenCalledTimes(1)
    expect(mockUpdate).not.toHaveBeenCalled()
  })
})

describe('EntryEdit — the roster\'s year beside the declared one (RFADM.13)', () => {
  it('a linked entry shows the roster\'s year, with ≠ when it differs', () => {
    const v = open(LINKED, LINKED_DETAIL)
    expect(v.text('.ee-roster-year')).toBe('w bazie: 1984 ≠')
  })

  it('equal years show the roster\'s year without the mark', () => {
    const v = open(LINKED, { ...LINKED_DETAIL, roster_birth_year: 1980 })
    expect(v.text('.ee-roster-year')).toBe('w bazie: 1980')
  })

  it('a newcomer\'s entry shows no roster year', () => {
    const v = open()
    expect(v.c.querySelector('.ee-roster-year')).toBeNull()
  })
})

describe('EntryEdit — what the roster will get (RFADM.24)', () => {
  // Declared 1980, roster 1984, season 2026/27 (later year 2027): V1.
  it('a changed year of a linked entry shows the roster\'s old and new year', async () => {
    const v = open(LINKED, LINKED_DETAIL)
    await fireEvent.input(v.field('birthYear'), { target: { value: '1979' } })
    expect(v.text('.ee-roster-year')).toBe('w bazie: 1984 → 1979')
    expect(v.c.querySelector('.ee-roster-cat')).toBeNull()
  })

  it('a year that moves the fencer to another category says so', async () => {
    const v = open(LINKED, LINKED_DETAIL)
    await fireEvent.input(v.field('birthYear'), { target: { value: '1975' } })
    expect(v.text('.ee-roster-year')).toBe('w bazie: 1984 → 1975')
    expect(v.text('.ee-roster-cat')).toBe('Zmieni kategorię w bazie: V1 → V2; wyniki zawodnika zostaną przeliczone.')
  })

  it('an unchanged year shows no arrow and no category line', () => {
    const v = open(LINKED, LINKED_DETAIL)
    expect(v.text('.ee-roster-year')).toBe('w bazie: 1984 ≠')
    expect(v.c.querySelector('.ee-roster-cat')).toBeNull()
  })

  it('a year changed to the roster\'s own shows it without arrow or mark', async () => {
    const v = open(LINKED, LINKED_DETAIL)
    await fireEvent.input(v.field('birthYear'), { target: { value: '1984' } })
    expect(v.text('.ee-roster-year')).toBe('w bazie: 1984')
  })

  it('a newcomer\'s changed year says nothing about the roster', async () => {
    const v = open()
    await fireEvent.input(v.field('birthYear'), { target: { value: '1960' } })
    expect(v.c.querySelector('.ee-roster-year')).toBeNull()
    expect(v.c.querySelector('.ee-roster-cat')).toBeNull()
  })

  it('speaks English', async () => {
    setLocale('en')
    const v = open(LINKED, LINKED_DETAIL)
    await fireEvent.input(v.field('birthYear'), { target: { value: '1975' } })
    expect(v.text('.ee-roster-year')).toBe('on the roster: 1984 → 1975')
    expect(v.text('.ee-roster-cat')).toBe('Changes the category on the roster: V1 → V2; the fencer\'s results will be recalculated.')
  })
})

describe('EntryEdit — English (RFADM.02–13)', () => {
  it('speaks English', async () => {
    setLocale('en')
    mockUpdate.mockRejectedValue({ code: '23505', message: 'duplicate key' })
    const v = open(LINKED, LINKED_DETAIL)
    expect(v.text('.ee-title')).toBe('Edit entry')
    expect(v.text('.ee-locked')).toBe('Name from the fencer roster')
    expect(v.text('.ee-roster-year')).toBe('on the roster: 1984 ≠')
    expect(v.save().textContent?.trim()).toBe('Save')
    expect(v.cancel().textContent?.trim()).toBe('Cancel')
    await fireEvent.click(v.save())
    await waitFor(() => expect(v.text('.ee-error')).toBe('Such an entry already exists.'))
  })
})
