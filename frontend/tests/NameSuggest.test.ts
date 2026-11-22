// FR-173 (RFAC.18–24, plan registration-name-list-under-surname rev 1): the
// name list under the registration form's SURNAME box. The component owns the
// surname input; the form keeps the value, the capitals and the pick.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'

vi.mock('../src/lib/api', () => ({ fetchNameSuggestions: vi.fn() }))
import { fetchNameSuggestions } from '../src/lib/api'
import { setLocale, t } from '../src/lib/locale.svelte'
import NameSuggest from '../src/components/NameSuggest.svelte'
import type { NameSuggestion } from '../src/lib/types'

const mockFetch = vi.mocked(fetchNameSuggestions)

const ROWS: NameSuggestion[] = [
  { surname: 'NOWAK', firstName: 'Anna', gender: 'F', country: 'POL', vcat: 'V2', club: 'AZS', source: 'ROSTER', entered: false },
  { surname: 'NOWAK', firstName: 'Jan', gender: 'M', country: 'POL', vcat: 'V3', club: null, source: 'ROSTER', entered: true },
  { surname: 'NOVÁK', firstName: 'Petr', gender: 'M', country: 'CZE', vcat: 'V2', club: null, source: 'EVF', entered: false },
  { surname: 'NOWICKA', firstName: 'Maria', gender: 'F', country: null, vcat: null, club: null, source: 'ENTRY', entered: false },
]

function setup(props: Partial<{ eventId: number | null }> = {}) {
  const oninput = vi.fn()
  const onblur = vi.fn()
  const onpick = vi.fn()
  const r = render(NameSuggest, { props: { value: '', eventId: 3, oninput, onblur, onpick, ...props } })
  const input = r.container.querySelector('input[name="surname"]') as HTMLInputElement
  return { ...r, input, oninput, onblur, onpick }
}

async function type(input: HTMLInputElement, text: string) {
  await fireEvent.input(input, { target: { value: text } })
}

async function settle() {
  await vi.advanceTimersByTimeAsync(200)
  await Promise.resolve()
}

const options = (c: HTMLElement) => [...c.querySelectorAll('[role="option"]')] as HTMLElement[]

beforeEach(() => {
  vi.useFakeTimers()
  mockFetch.mockReset()
  mockFetch.mockResolvedValue(ROWS)
  setLocale('pl')
})
afterEach(() => {
  vi.useRealTimers()
})

describe('RFAC.18 when the list asks', () => {
  it('asks nothing for one letter', async () => {
    const { input } = setup()
    await type(input, 'N')
    await settle()
    expect(mockFetch).not.toHaveBeenCalled()
  })

  it('asks once, 200 ms after the last of several keystrokes, with the event and the typed text', async () => {
    const { input } = setup()
    await type(input, 'NO')
    await vi.advanceTimersByTimeAsync(100)
    await type(input, 'NOW')
    await vi.advanceTimersByTimeAsync(199)
    expect(mockFetch).not.toHaveBeenCalled()
    await settle()
    expect(mockFetch).toHaveBeenCalledTimes(1)
    expect(mockFetch).toHaveBeenCalledWith(3, 'NOW')
  })

  it('asks nothing without an event', async () => {
    const { input } = setup({ eventId: null })
    await type(input, 'NOW')
    await settle()
    expect(mockFetch).not.toHaveBeenCalled()
  })
})

describe('RFAC.19 what a row shows', () => {
  it('name, category, country and source; the entered mark; never a year', async () => {
    const { input, container } = setup()
    await type(input, 'NOW')
    await settle()
    const rows = options(container)
    expect(rows).toHaveLength(4)
    expect(rows[0].textContent).toContain('NOWAK')
    expect(rows[0].textContent).toContain('Anna')
    expect(rows[0].textContent).toContain('V2')
    expect(rows[0].textContent).toContain('POL')
    expect(rows[0].textContent).toContain(t('reg_suggest_source_roster'))
    expect(rows[0].textContent).not.toContain(t('reg_suggest_entered'))
    expect(rows[1].textContent).toContain(t('reg_suggest_entered'))
    expect(rows[2].textContent).toContain(t('reg_suggest_source_evf'))
    expect(rows[3].textContent).toContain(t('reg_suggest_source_entry'))
    expect(container.querySelector('.reg-sg-list')?.textContent ?? '').not.toMatch(/\b(19|20)\d\d\b/)
    expect(container.textContent).toContain(t('reg_suggest_footer'))
  })
})

describe('RFAC.20 a pick', () => {
  it('a click picks the row, closes the list, and asks nothing more', async () => {
    const { input, container, onpick } = setup()
    await type(input, 'NOW')
    await settle()
    await fireEvent.click(options(container)[2])
    expect(onpick).toHaveBeenCalledWith(ROWS[2])
    expect(options(container)).toHaveLength(0)
    await settle()
    expect(mockFetch).toHaveBeenCalledTimes(1)
  })

  it('pressing on the list keeps the focus in the box', async () => {
    const { input, container } = setup()
    await type(input, 'NOW')
    await settle()
    const ev = new MouseEvent('mousedown', { bubbles: true, cancelable: true })
    options(container)[0].dispatchEvent(ev)
    expect(ev.defaultPrevented).toBe(true)
  })
})

describe('RFAC.21 the keyboard', () => {
  it('arrows move the highlight and wrap, Enter picks, Escape closes, ARIA follows', async () => {
    const { input, container, onpick } = setup()
    expect(input.getAttribute('role')).toBe('combobox')
    expect(input.getAttribute('aria-expanded')).toBe('false')
    await type(input, 'NOW')
    await settle()
    expect(input.getAttribute('aria-expanded')).toBe('true')
    expect(input.getAttribute('aria-controls')).toBe(container.querySelector('[role="listbox"]')?.id)
    await fireEvent.keyDown(input, { key: 'ArrowDown' })
    expect(input.getAttribute('aria-activedescendant')).toBe(options(container)[0].id)
    expect(options(container)[0].getAttribute('aria-selected')).toBe('true')
    await fireEvent.keyDown(input, { key: 'ArrowUp' })
    expect(input.getAttribute('aria-activedescendant')).toBe(options(container)[3].id)
    await fireEvent.keyDown(input, { key: 'ArrowDown' })
    expect(input.getAttribute('aria-activedescendant')).toBe(options(container)[0].id)
    await fireEvent.keyDown(input, { key: 'ArrowDown' })
    await fireEvent.keyDown(input, { key: 'Enter' })
    expect(onpick).toHaveBeenCalledWith(ROWS[1])
    await type(input, 'NOWA')
    await settle()
    expect(options(container)).toHaveLength(4)
    await fireEvent.keyDown(input, { key: 'Escape' })
    expect(options(container)).toHaveLength(0)
    expect(input.getAttribute('aria-expanded')).toBe('false')
  })

  it('Enter with no row highlighted picks nothing', async () => {
    const { input, onpick } = setup()
    await type(input, 'NOW')
    await settle()
    await fireEvent.keyDown(input, { key: 'Enter' })
    expect(onpick).not.toHaveBeenCalled()
  })
})

describe('RFAC.22 a late answer', () => {
  it('an answer to an earlier request is dropped', async () => {
    let first!: (rows: NameSuggestion[]) => void
    mockFetch
      .mockImplementationOnce(() => new Promise((res) => { first = res }))
      .mockImplementationOnce(() => Promise.resolve([ROWS[2]]))
    const { input, container } = setup()
    await type(input, 'NO')
    await settle()
    await type(input, 'NOV')
    await settle()
    first(ROWS)
    await Promise.resolve()
    await Promise.resolve()
    expect(options(container)).toHaveLength(1)
    expect(options(container)[0].textContent).toContain('NOVÁK')
  })
})

describe('RFAC.23 a failed request', () => {
  it('shows no list and no error, and typing goes on', async () => {
    mockFetch.mockRejectedValue(new Error('offline'))
    const { input, container, oninput } = setup()
    await type(input, 'NOW')
    await settle()
    expect(options(container)).toHaveLength(0)
    expect(container.querySelector('[role="listbox"]')).toBeNull()
    await type(input, 'NOWA')
    expect(oninput).toHaveBeenCalledTimes(2)
  })
})

describe('RFAC.24 the input', () => {
  it('keeps its name, switches off the browser list, and reports input and blur to the form', async () => {
    const { input, oninput, onblur, container } = setup()
    expect(input.getAttribute('name')).toBe('surname')
    expect(input.getAttribute('autocomplete')).toBe('off')
    await type(input, 'NOW')
    expect(oninput).toHaveBeenCalledTimes(1)
    await settle()
    await fireEvent.blur(input)
    expect(onblur).toHaveBeenCalledTimes(1)
    expect(options(container)).toHaveLength(0)
  })
})
