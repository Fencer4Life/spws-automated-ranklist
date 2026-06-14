// Plan-test-ID 5.2: CreateFencerFromAliasModal
// Mirrors CreateFencerModal but adds:
//   - BY suggestion from (categoryHint, seasonEndYear) via estimateBirthYear
//   - hint text "Suggested {BY} for {V-cat} (range {lo}–{hi})"
//   - validation: confirm disabled unless surname/firstName non-empty AND
//     birthYear is finite + 1900..2030

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import CreateFencerFromAliasModal from '../src/components/CreateFencerFromAliasModal.svelte'

describe('CreateFencerFromAliasModal', () => {
  const baseProps = {
    open: true,
    alias: 'DUPONT Jean',
    fromFencerId: 1,
    categoryHint: null as string | null,
    seasonEndYear: null as number | null,
    onconfirm: vi.fn(),
    onclose: vi.fn(),
  }

  // 5.2.1 — renders only when open=true
  it('does not render when open=false', () => {
    const { container } = render(CreateFencerFromAliasModal, {
      props: { ...baseProps, open: false },
    })
    expect(container.querySelector('[data-field="create-fencer-from-alias-modal"]')).toBeNull()
  })

  // 5.2.2 — alias parsed: uppercase token = surname
  it('parses alias "DUPONT Jean" → surname=DUPONT, firstName=Jean', () => {
    const { container } = render(CreateFencerFromAliasModal, { props: baseProps })
    const surname = container.querySelector('[data-field="surname-input"]') as HTMLInputElement
    const first = container.querySelector('[data-field="first-name-input"]') as HTMLInputElement
    expect(surname.value).toBe('DUPONT')
    expect(first.value).toBe('Jean')
  })

  // 5.2.3 — V2 + 2024 → birthYearInput=1969 (midpoint), hint visible
  it('categoryHint=V2 + seasonEndYear=2024 → BY=1969, hint rendered', () => {
    const { container } = render(CreateFencerFromAliasModal, {
      props: { ...baseProps, categoryHint: 'V2', seasonEndYear: 2024 },
    })
    const by = container.querySelector('[data-field="birth-year-input"]') as HTMLInputElement
    expect(by.value).toBe('1969')
    const hint = container.querySelector('[data-field="by-hint"]') as HTMLElement
    expect(hint).not.toBeNull()
    expect(hint.textContent).toMatch(/V2/)
    expect(hint.textContent).toMatch(/1965/)
    expect(hint.textContent).toMatch(/1974/)
  })

  // 5.2.4 — null categoryHint → no BY pre-filled, no hint, confirm disabled
  it('categoryHint=null → BY empty, hint absent, confirm disabled', () => {
    const { container } = render(CreateFencerFromAliasModal, { props: baseProps })
    const by = container.querySelector('[data-field="birth-year-input"]') as HTMLInputElement
    expect(by.value).toBe('')
    expect(container.querySelector('[data-field="by-hint"]')).toBeNull()
    const confirm = container.querySelector('[data-field="confirm-btn"]') as HTMLButtonElement
    expect(confirm.disabled).toBe(true)
  })

  // 5.2.5 — confirm payload shape matches NewFencerData
  it('confirm fires onconfirm with NewFencerData shape', async () => {
    const onconfirm = vi.fn()
    const { container } = render(CreateFencerFromAliasModal, {
      props: {
        ...baseProps,
        categoryHint: 'V2',
        seasonEndYear: 2024,
        onconfirm,
      },
    })
    const confirm = container.querySelector('[data-field="confirm-btn"]') as HTMLButtonElement
    expect(confirm.disabled).toBe(false)
    await fireEvent.click(confirm)
    expect(onconfirm).toHaveBeenCalledTimes(1)
    expect(onconfirm).toHaveBeenCalledWith({
      txt_surname: 'DUPONT',
      txt_first_name: 'Jean',
      int_birth_year: 1969,
      enum_gender: 'M',
    })
  })

  // 5.2.6 — onclose fires on overlay click and × button
  it('overlay click + × button call onclose', async () => {
    const onclose = vi.fn()
    const { container } = render(CreateFencerFromAliasModal, {
      props: { ...baseProps, onclose },
    })
    const closeBtn = container.querySelector('.close-btn') as HTMLButtonElement
    await fireEvent.click(closeBtn)
    expect(onclose).toHaveBeenCalled()
  })

  // 5.2.7 — BY validation: out-of-range disables confirm
  it('BY outside 1900..2030 disables confirm', async () => {
    const { container } = render(CreateFencerFromAliasModal, {
      props: { ...baseProps, categoryHint: 'V2', seasonEndYear: 2024 },
    })
    const by = container.querySelector('[data-field="birth-year-input"]') as HTMLInputElement
    const confirm = container.querySelector('[data-field="confirm-btn"]') as HTMLButtonElement
    expect(confirm.disabled).toBe(false)

    await fireEvent.input(by, { target: { value: '1899' } })
    expect(confirm.disabled).toBe(true)

    await fireEvent.input(by, { target: { value: '2031' } })
    expect(confirm.disabled).toBe(true)

    await fireEvent.input(by, { target: { value: '1980' } })
    expect(confirm.disabled).toBe(false)
  })
})
