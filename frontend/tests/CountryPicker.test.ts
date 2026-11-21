// RFCTRY.05 — the country pick-list (FR-169, plan registration-form-names-
// year-country rev 10, release 3). A pick-list, never free text: it finds a
// country by its Polish name, its English name or its code, and only a pick
// changes the code.
import { describe, it, expect, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import { setLocale } from '../src/lib/locale.svelte'
import CountryPicker from '../src/components/CountryPicker.svelte'

beforeEach(() => setLocale('pl'))

function setup(code = 'POL') {
  let current = code
  const r = render(CountryPicker, { props: { code, onpick: (c: string) => (current = c) } })
  const box = r.container.querySelector('input[name="country"]') as HTMLInputElement
  const options = () => [...r.container.querySelectorAll('.cp-opt')].map((o) => o.textContent?.replace(/\s+/g, ' ').trim())
  return { ...r, box, options, picked: () => current }
}

describe('RFCTRY.05 the country pick-list', () => {
  it('shows the chosen country by name, with its code beside it', () => {
    const { box, container } = setup()
    expect(box.value).toBe('Polska')
    expect(container.querySelector('.cp-code')?.textContent).toBe('POL')
  })

  it.each([
    ['wiel', 'Wielka Brytania GBR'],
    ['brit', 'Wielka Brytania GBR'],
    ['gbr', 'Wielka Brytania GBR'],
    ['niem', 'Niemcy GER'],
    ['germ', 'Niemcy GER'],
    ['szwajc', 'Szwajcaria SUI'],
    ['wegry', 'Węgry HUN'],
    ['great', 'Wielka Brytania GBR'],
    ['anglia', 'Wielka Brytania GBR'],
    ['holand', 'Holandia NED'],
    ['czech rep', 'Czechy CZE'],
  ])('„%s” finds %s', async (typed, found) => {
    const { box, options } = setup()
    await fireEvent.focus(box)
    await fireEvent.input(box, { target: { value: typed } })
    expect(options()).toContain(found)
  })

  it('a pick sets the code and shows its name', async () => {
    const { box, container, picked } = setup()
    await fireEvent.focus(box)
    await fireEvent.input(box, { target: { value: 'wiel' } })
    const gbr = [...container.querySelectorAll('.cp-opt')].find((o) => o.textContent?.includes('GBR')) as HTMLButtonElement
    await fireEvent.click(gbr)
    expect(picked()).toBe('GBR')
    expect(box.value).toBe('Wielka Brytania')
    expect(container.querySelector('.cp-list')).toBeNull()
  })

  it('text that names no country is never taken: leaving the box restores the chosen one', async () => {
    const { box, picked } = setup()
    await fireEvent.focus(box)
    await fireEvent.input(box, { target: { value: 'Atlantyda' } })
    await fireEvent.blur(box)
    expect(picked()).toBe('POL')
    expect(box.value).toBe('Polska')
  })

  it('Enter picks the first country found', async () => {
    const { box, picked } = setup()
    await fireEvent.focus(box)
    await fireEvent.input(box, { target: { value: 'gbr' } })
    await fireEvent.keyDown(box, { key: 'Enter' })
    expect(picked()).toBe('GBR')
  })

  it('names follow the page language', async () => {
    setLocale('en')
    const { box } = setup('GER')
    expect(box.value).toBe('Germany')
  })
})
