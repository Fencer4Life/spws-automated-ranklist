// Plan tests: 9.100–9.113
// ADR-035: Birth year review tab

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import BirthYearReview from '../src/components/BirthYearReview.svelte'
import type { FencerListItem, FencerTournamentRow } from '../src/lib/types'

const MOCK_FENCERS: FencerListItem[] = [
  { id_fencer: 1, txt_surname: 'KOWALSKI', txt_first_name: 'Jan', int_birth_year: 1970, txt_club: 'WKS', enum_gender: 'M', bool_birth_year_estimated: false, txt_nationality: 'PL' },
  { id_fencer: 2, txt_surname: 'NOWAK', txt_first_name: 'Adam', int_birth_year: 1975, txt_club: null, enum_gender: 'M', bool_birth_year_estimated: true, txt_nationality: 'PL' },
  { id_fencer: 3, txt_surname: 'WIŚNIEWSKA', txt_first_name: 'Anna', int_birth_year: null, txt_club: 'AZS', enum_gender: 'F', bool_birth_year_estimated: false, txt_nationality: 'PL' },
  { id_fencer: 4, txt_surname: 'ZIELINSKA', txt_first_name: 'Maria', int_birth_year: 1968, txt_club: null, enum_gender: 'F', bool_birth_year_estimated: true, txt_nationality: 'PL' },
]

const MOCK_HISTORY: FencerTournamentRow[] = [
  { id_result: 10, txt_tournament_code: 'PP1-V2-M-EPEE-2024-25', txt_tournament_name: 'Test', dt_tournament: '2025-01-15', enum_type: 'PPW', enum_weapon: 'EPEE', enum_gender: 'M', enum_age_category: 'V2', int_place: 3, num_final_score: 45.5, int_participant_count: 12, txt_season_code: 'SPWS-2024-2025', txt_location: 'Kraków' },
  { id_result: 11, txt_tournament_code: 'PP2-V2-M-EPEE-2024-25', txt_tournament_name: null, dt_tournament: '2025-03-10', enum_type: 'PPW', enum_weapon: 'EPEE', enum_gender: 'M', enum_age_category: 'V2', int_place: 1, num_final_score: 80.0, int_participant_count: 15, txt_season_code: 'SPWS-2024-2025', txt_location: 'Warszawa' },
]

describe('BirthYearReview (ADR-035)', () => {
  const defaultProps = {
    fencers: MOCK_FENCERS,
    isAdmin: true,
    onupdatebirthyear: vi.fn(),
    onfetchhistory: vi.fn().mockResolvedValue(MOCK_HISTORY),
  }

  // 9.100 — Renders fencer list sorted by surname
  it('renders fencer list sorted by surname', () => {
    const { container } = render(BirthYearReview, { props: defaultProps })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    expect(rows.length).toBe(4)
    // Sorted: KOWALSKI, NOWAK, WIŚNIEWSKA, ZIELINSKA
    expect(rows[0].textContent).toContain('KOWALSKI')
    expect(rows[1].textContent).toContain('NOWAK')
    expect(rows[3].textContent).toContain('ZIELINSKA')
  })

  // 9.101 — Filter by Estimated shows only estimated
  it('filter by Estimated shows only estimated fencers', async () => {
    const { container } = render(BirthYearReview, { props: defaultProps })
    const filter = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filter, { target: { value: 'ESTIMATED' } })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    expect(rows.length).toBe(2) // NOWAK + ZIELINSKA
  })

  // 9.102 — Filter by Missing shows only null birth year
  it('filter by Missing shows only missing birth year', async () => {
    const { container } = render(BirthYearReview, { props: defaultProps })
    const filter = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filter, { target: { value: 'MISSING' } })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    expect(rows.length).toBe(1) // WIŚNIEWSKA
  })

  // 9.103 — Gender filter limits displayed fencers
  it('gender filter limits fencers', async () => {
    const { container } = render(BirthYearReview, { props: defaultProps })
    const gFilter = container.querySelector('[data-field="gender-filter"]') as HTMLSelectElement
    await fireEvent.change(gFilter, { target: { value: 'F' } })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    expect(rows.length).toBe(2) // WIŚNIEWSKA + ZIELINSKA
  })

  // 9.104 — Search box filters by name
  it('search box filters by name', async () => {
    const { container } = render(BirthYearReview, { props: defaultProps })
    const search = container.querySelector('[data-field="search-box"]') as HTMLInputElement
    await fireEvent.input(search, { target: { value: 'KOWAL' } })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    expect(rows.length).toBe(1)
    expect(rows[0].textContent).toContain('KOWALSKI')
  })

  // 9.105 — Click fencer expands form with read-only fields
  it('click fencer expands edit form with read-only fields', async () => {
    const { container } = render(BirthYearReview, { props: defaultProps })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    await fireEvent.click(rows[0].querySelector('.card-header')!)
    const form = container.querySelector('[data-field="edit-form"]')
    expect(form).not.toBeNull()
    // Read-only fields visible
    expect(form!.textContent).toContain('KOWALSKI')
    expect(form!.textContent).toContain('Jan')
  })

  // 9.106 — Edit form: editable birth year + accuracy dropdown
  it('edit form shows editable birth year and accuracy dropdown', async () => {
    const { container } = render(BirthYearReview, { props: defaultProps })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    await fireEvent.click(rows[0].querySelector('.card-header')!)
    const byInput = container.querySelector('[data-field="birth-year-input"]') as HTMLInputElement
    expect(byInput).not.toBeNull()
    expect(byInput.disabled).toBe(false)
    const estSelect = container.querySelector('[data-field="birth-year-estimated"]')
    expect(estSelect).not.toBeNull()
  })

  // 9.107 — Save calls onupdatebirthyear with correct args
  it('save calls onupdatebirthyear', async () => {
    const onupdatebirthyear = vi.fn()
    const { container } = render(BirthYearReview, { props: { ...defaultProps, onupdatebirthyear } })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    await fireEvent.click(rows[0].querySelector('.card-header')!)

    const byInput = container.querySelector('[data-field="birth-year-input"]') as HTMLInputElement
    await fireEvent.input(byInput, { target: { value: '1972' } })

    const saveBtn = container.querySelector('[data-field="save-btn"]')!
    await fireEvent.click(saveBtn)

    expect(onupdatebirthyear).toHaveBeenCalledTimes(1)
    expect(onupdatebirthyear).toHaveBeenCalledWith(1, 1972, false)
  })

  // 9.108 — Tournament history loads on expand
  it('tournament history loads on expand', async () => {
    const onfetchhistory = vi.fn().mockResolvedValue(MOCK_HISTORY)
    const { container } = render(BirthYearReview, { props: { ...defaultProps, onfetchhistory } })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    await fireEvent.click(rows[0].querySelector('.card-header')!)
    expect(onfetchhistory).toHaveBeenCalledWith(1)
  })

  // 9.109 ��� Tournament history grouped by season, shows category+weapon+place
  it('tournament history grouped by season with details', async () => {
    const { container } = render(BirthYearReview, { props: defaultProps })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    await fireEvent.click(rows[0].querySelector('.card-header')!)
    // Wait for async history load
    await new Promise(r => setTimeout(r, 10))
    const seasonGroups = container.querySelectorAll('[data-field="season-group"]')
    expect(seasonGroups.length).toBeGreaterThanOrEqual(1)
    const tournRows = container.querySelectorAll('[data-field="tournament-row"]')
    expect(tournRows.length).toBe(2)
    expect(tournRows[0].textContent).toContain('V2')
    expect(tournRows[0].textContent).toContain('EPEE')
  })

  // 9.110 — Birth year hint + auto-suggest from age categories
  it('birth year hint shown from tournament age categories', async () => {
    // Use fencer with missing birth year — should auto-suggest
    const onfetchhistory = vi.fn().mockResolvedValue(MOCK_HISTORY)
    const fencersWithMissing = [
      { id_fencer: 3, txt_surname: 'WIŚNIEWSKA', txt_first_name: 'Anna', int_birth_year: null, txt_club: 'AZS', enum_gender: 'F' as const, bool_birth_year_estimated: false, txt_nationality: 'PL' },
    ]
    const { container } = render(BirthYearReview, { props: { ...defaultProps, fencers: fencersWithMissing, onfetchhistory } })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    await fireEvent.click(rows[0].querySelector('.card-header')!)
    await new Promise(r => setTimeout(r, 10))
    const hint = container.querySelector('[data-field="birth-year-hint"]')
    expect(hint).not.toBeNull()
    expect(hint!.textContent).toContain('V2')
  })

  // 9.111 — Inconsistency flag when confirmed year contradicts categories
  it('inconsistency flag shown for birth year mismatch', async () => {
    // Fencer with confirmed birth year 1950 (age 75 in 2025 → V4) but competed in V2
    const onfetchhistory = vi.fn().mockResolvedValue(MOCK_HISTORY)
    const inconsistentFencer = [
      { id_fencer: 5, txt_surname: 'TESTOWY', txt_first_name: 'Jan', int_birth_year: 1950, txt_club: null, enum_gender: 'M' as const, bool_birth_year_estimated: false, txt_nationality: 'PL' },
    ]
    const { container } = render(BirthYearReview, { props: { ...defaultProps, fencers: inconsistentFencer, onfetchhistory } })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    await fireEvent.click(rows[0].querySelector('.card-header')!)
    await new Promise(r => setTimeout(r, 10))
    const flag = container.querySelector('[data-field="inconsistency-flag"]')
    expect(flag).not.toBeNull()
  })

  // 9.112 — Count badges reflect filter counts
  it('count badges reflect filter counts', () => {
    const { container } = render(BirthYearReview, { props: defaultProps })
    const estBadge = container.querySelector('[data-field="count-estimated"]')
    const missBadge = container.querySelector('[data-field="count-missing"]')
    const confBadge = container.querySelector('[data-field="count-confirmed"]')
    expect(estBadge!.textContent).toContain('2')   // NOWAK + ZIELINSKA
    expect(missBadge!.textContent).toContain('1')   // WIŚNIEWSKA
    expect(confBadge!.textContent).toContain('1')   // KOWALSKI
  })

  // 9.113 — Renders nothing when isAdmin=false
  it('renders nothing when isAdmin=false', () => {
    const { container } = render(BirthYearReview, { props: { ...defaultProps, isAdmin: false } })
    const review = container.querySelector('[data-field="birth-year-review"]')
    expect(review).toBeNull()
  })
})
