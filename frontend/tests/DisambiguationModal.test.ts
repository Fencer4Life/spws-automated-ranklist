// Plan tests: 9.74, 9.75, 9.76
// See .claude/plans/rosy-bouncing-kitten.md §T9.7.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import DisambiguationModal from '../src/components/DisambiguationModal.svelte'
import type { FencerCandidate } from '../src/lib/types'

const MOCK_FENCER_CANDIDATES: FencerCandidate[] = [
  {
    id_fencer: 200, txt_surname: 'KRAWCZYK', txt_first_name: 'Paweł',
    int_birth_year: 1954, txt_club: 'KS Wrocław', num_confidence: 88,
    bool_age_match: true,
  },
  {
    id_fencer: 201, txt_surname: 'KRAWCZYK', txt_first_name: 'Paweł',
    int_birth_year: 1989, txt_club: 'AZS Kraków', num_confidence: 85,
    bool_age_match: false,
  },
]

describe('DisambiguationModal (T9.7)', () => {
  const defaultProps = {
    open: true,
    scrapedName: 'KRAWCZYK Paweł',
    fencerCandidates: MOCK_FENCER_CANDIDATES,
    onconfirm: vi.fn(),
    onclose: vi.fn(),
  }

  // 9.74 — Renders fencer candidates with radio buttons
  it('renders fencer candidates with radio buttons', () => {
    const { container } = render(DisambiguationModal, { props: defaultProps })
    const modal = container.querySelector('[data-field="disambiguation-modal"]')
    expect(modal).not.toBeNull()

    const options = container.querySelectorAll('[data-field="fencer-option"]')
    expect(options.length).toBe(2)

    // Each option has a radio input
    const radios = container.querySelectorAll('input[type="radio"]')
    expect(radios.length).toBe(2)

    // Shows scraped name in header
    expect(modal!.textContent).toContain('KRAWCZYK Paweł')
  })

  // 9.75 — Shows birth_year and age_category match indicator
  it('shows birth_year and age match indicator per fencer', () => {
    const { container } = render(DisambiguationModal, { props: defaultProps })

    const birthYears = container.querySelectorAll('[data-field="fencer-birth-year"]')
    expect(birthYears.length).toBe(2)
    expect(birthYears[0].textContent).toContain('1954')
    expect(birthYears[1].textContent).toContain('1989')

    const ageMatches = container.querySelectorAll('[data-field="fencer-age-match"]')
    expect(ageMatches.length).toBe(2)
    // First candidate matches age category
    expect(ageMatches[0].classList.contains('age-match')).toBe(true)
    // Second does not
    expect(ageMatches[1].classList.contains('age-no-match')).toBe(true)
  })

  // 9.76 — Selecting fencer + confirm calls onconfirm with fencer id
  it('selecting fencer and confirm calls onconfirm', async () => {
    const onconfirm = vi.fn()
    const { container } = render(DisambiguationModal, { props: { ...defaultProps, onconfirm } })

    // Select first fencer (radio)
    const radios = container.querySelectorAll('input[type="radio"]') as NodeListOf<HTMLInputElement>
    await fireEvent.click(radios[0])

    // Click confirm
    const confirmBtn = container.querySelector('[data-field="confirm-btn"]') as HTMLButtonElement
    expect(confirmBtn).not.toBeNull()
    await fireEvent.click(confirmBtn)

    expect(onconfirm).toHaveBeenCalledTimes(1)
    expect(onconfirm).toHaveBeenCalledWith(200)
  })
})
