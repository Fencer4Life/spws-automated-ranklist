// Plan tests: 9.89, 9.90, 9.91
// See .claude/plans/spicy-humming-clover.md

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import CreateFencerModal from '../src/components/CreateFencerModal.svelte'

describe('CreateFencerModal', () => {
  const defaultProps = {
    open: true,
    scrapedName: 'KOWALSKI Jan',
    tournamentGender: 'M' as const,
    onconfirm: vi.fn(),
    onclose: vi.fn(),
  }

  // 9.89 — Pre-fills surname/firstName from scraped name
  it('pre-fills surname and firstName from scraped name', () => {
    const { container } = render(CreateFencerModal, { props: defaultProps })
    const surnameInput = container.querySelector('[data-field="surname-input"]') as HTMLInputElement
    const firstNameInput = container.querySelector('[data-field="first-name-input"]') as HTMLInputElement
    expect(surnameInput.value).toBe('KOWALSKI')
    expect(firstNameInput.value).toBe('Jan')
  })

  // 9.90 — Pre-selects gender from tournament gender
  it('pre-selects gender from tournament gender', () => {
    const { container } = render(CreateFencerModal, { props: defaultProps })
    const genderSelect = container.querySelector('[data-field="gender-select"]') as HTMLSelectElement
    expect(genderSelect.value).toBe('M')
  })

  // 9.91 — Confirm fires callback with form values
  it('confirm fires callback with form values', async () => {
    const onconfirm = vi.fn()
    const { container } = render(CreateFencerModal, { props: { ...defaultProps, onconfirm } })

    const confirmBtn = container.querySelector('[data-field="confirm-btn"]') as HTMLButtonElement
    await fireEvent.click(confirmBtn)

    expect(onconfirm).toHaveBeenCalledTimes(1)
    expect(onconfirm).toHaveBeenCalledWith('KOWALSKI', 'Jan', 'M', undefined)
  })
})
