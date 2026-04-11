// Plan tests: 9.92, 9.93, 9.94
// See .claude/plans/spicy-humming-clover.md

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import FencerSearchModal from '../src/components/FencerSearchModal.svelte'
import type { FencerListItem } from '../src/lib/types'

const MOCK_FENCERS: FencerListItem[] = [
  { id_fencer: 1, txt_surname: 'KOWALSKI', txt_first_name: 'Jan', int_birth_year: 1970, txt_club: 'WKS', enum_gender: 'M' },
  { id_fencer: 2, txt_surname: 'NOWAK', txt_first_name: 'Adam', int_birth_year: 1975, txt_club: null, enum_gender: 'M' },
  { id_fencer: 3, txt_surname: 'WIŚNIEWSKA', txt_first_name: 'Anna', int_birth_year: 1980, txt_club: 'AZS', enum_gender: 'F' },
]

describe('FencerSearchModal', () => {
  const defaultProps = {
    open: true,
    scrapedName: 'KOWALSKI Jan',
    fencers: MOCK_FENCERS,
    onconfirm: vi.fn(),
    onclose: vi.fn(),
  }

  // 9.92 — Renders search input and fencer list
  it('renders search input and fencer list', () => {
    const { container } = render(FencerSearchModal, { props: defaultProps })
    const searchInput = container.querySelector('[data-field="fencer-search-input"]')
    expect(searchInput).not.toBeNull()
    const fencerOptions = container.querySelectorAll('[data-field="fencer-option"]')
    expect(fencerOptions.length).toBe(3)
  })

  // 9.93 — Filters fencers by search query
  it('filters fencers by search query', async () => {
    const { container } = render(FencerSearchModal, { props: defaultProps })
    const searchInput = container.querySelector('[data-field="fencer-search-input"]') as HTMLInputElement
    await fireEvent.input(searchInput, { target: { value: 'NOWAK' } })

    const fencerOptions = container.querySelectorAll('[data-field="fencer-option"]')
    expect(fencerOptions.length).toBe(1)
    expect(fencerOptions[0].textContent).toContain('NOWAK')
  })

  // 9.94 — Confirm fires callback with selected fencer id
  it('confirm fires callback with selected fencer id', async () => {
    const onconfirm = vi.fn()
    const { container } = render(FencerSearchModal, { props: { ...defaultProps, onconfirm } })

    // Select the first fencer radio
    const radios = container.querySelectorAll('input[type="radio"]')
    await fireEvent.click(radios[0])

    const confirmBtn = container.querySelector('[data-field="confirm-btn"]') as HTMLButtonElement
    await fireEvent.click(confirmBtn)

    expect(onconfirm).toHaveBeenCalledTimes(1)
    expect(onconfirm).toHaveBeenCalledWith(1)
  })
})
