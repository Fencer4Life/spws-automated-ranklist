// FR-173 (RFAC.16–17, plan registration-name-list-under-surname rev 1, D12):
// after a pick from the name list the year grid opens on the category's
// decade, and the form can move the focus to the year box.
import { describe, it, expect } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import YearPicker from '../src/components/YearPicker.svelte'

const RANGE = { min: 1906, max: 1997 }
const decade = (c: HTMLElement) => c.querySelector('.reg-yeargrid-decade')?.textContent?.trim()

describe('RFAC.16 the grid opens on the hinted decade', () => {
  it('with a hint and no year, on the hinted decade', async () => {
    const { container } = render(YearPicker, { props: { year: null, range: RANGE, hintDecade: 1980 } })
    await fireEvent.focus(container.querySelector('input[name="birthYear"]') as HTMLInputElement)
    expect(decade(container)).toBe('1980 – 1989')
  })

  it("with a valid year, on the year's own decade, hint or not", async () => {
    const { container } = render(YearPicker, { props: { year: 1962, range: RANGE, hintDecade: 1980 } })
    await fireEvent.focus(container.querySelector('input[name="birthYear"]') as HTMLInputElement)
    expect(decade(container)).toBe('1960 – 1969')
  })

  it("without a hint, as before (a 50-year-old's decade)", async () => {
    const { container } = render(YearPicker, { props: { year: null, range: RANGE } })
    await fireEvent.focus(container.querySelector('input[name="birthYear"]') as HTMLInputElement)
    expect(decade(container)).toBe('1970 – 1979')
  })

  it('a hint outside the range is held to the range', async () => {
    const { container } = render(YearPicker, { props: { year: null, range: RANGE, hintDecade: 2010 } })
    await fireEvent.focus(container.querySelector('input[name="birthYear"]') as HTMLInputElement)
    expect(decade(container)).toBe('1990 – 1999')
  })
})

describe('RFAC.17 focusBox()', () => {
  it('focuses the year box and opens the grid', async () => {
    const { container, component } = render(YearPicker, { props: { year: null, range: RANGE, hintDecade: 1980 } })
    ;(component as unknown as { focusBox: () => void }).focusBox()
    await Promise.resolve()
    expect(document.activeElement).toBe(container.querySelector('input[name="birthYear"]'))
    expect(decade(container)).toBe('1980 – 1989')
  })
})
