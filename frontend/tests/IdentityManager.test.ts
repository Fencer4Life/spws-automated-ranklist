// Plan tests: 9.68, 9.69, 9.70, 9.71, 9.72, 9.73, 9.77, 9.83–9.88
// See .claude/plans/spicy-humming-clover.md

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import IdentityManager from '../src/components/IdentityManager.svelte'
import type { MatchCandidate, FencerListItem } from '../src/lib/types'

const MOCK_CANDIDATES: MatchCandidate[] = [
  {
    id_match: 1, id_result: 10, txt_scraped_name: 'KOWALSKI Jan',
    id_fencer: 100, txt_fencer_name: 'KOWALSKI Jan', num_confidence: 97,
    enum_status: 'AUTO_MATCHED', txt_admin_note: null,
    txt_tournament_code: 'PP1-V2-M-EPEE', enum_type: 'PPW',
    enum_tournament_gender: 'M', enum_fencer_gender: 'M',
  },
  {
    id_match: 2, id_result: 11, txt_scraped_name: 'NOWAK Adam',
    id_fencer: 101, txt_fencer_name: 'NOWAK Adam', num_confidence: 78,
    enum_status: 'PENDING', txt_admin_note: null,
    txt_tournament_code: 'PP1-V1-M-FOIL', enum_type: 'PPW',
    enum_tournament_gender: 'M', enum_fencer_gender: 'M',
  },
  {
    id_match: 3, id_result: 12, txt_scraped_name: 'WIŚNIEWSKI Piotr',
    id_fencer: null, txt_fencer_name: null, num_confidence: 30,
    enum_status: 'UNMATCHED', txt_admin_note: null,
    txt_tournament_code: 'PP1-V0-F-SABRE', enum_type: 'PPW',
    enum_tournament_gender: 'F', enum_fencer_gender: null,
  },
  {
    id_match: 4, id_result: 13, txt_scraped_name: 'ZIELINSKI Marek',
    id_fencer: 102, txt_fencer_name: 'ZIELINSKI Marek', num_confidence: 65,
    enum_status: 'PENDING', txt_admin_note: null,
    txt_tournament_code: 'PP1-V2-M-EPEE', enum_type: 'PPW',
    enum_tournament_gender: 'M', enum_fencer_gender: 'F',
  },
  {
    id_match: 5, id_result: 14, txt_scraped_name: 'APPROVED Full',
    id_fencer: 103, txt_fencer_name: 'APPROVED Full', num_confidence: 100,
    enum_status: 'APPROVED', txt_admin_note: null,
    txt_tournament_code: 'PP1-V2-M-EPEE', enum_type: 'PPW',
    enum_tournament_gender: 'M', enum_fencer_gender: 'M',
  },
]

const MOCK_FENCERS: FencerListItem[] = [
  { id_fencer: 100, txt_surname: 'KOWALSKI', txt_first_name: 'Jan', int_birth_year: 1970, txt_club: 'WKS', enum_gender: 'M' },
  { id_fencer: 101, txt_surname: 'NOWAK', txt_first_name: 'Adam', int_birth_year: 1975, txt_club: null, enum_gender: 'M' },
  { id_fencer: 102, txt_surname: 'ZIELINSKI', txt_first_name: 'Marek', int_birth_year: 1980, txt_club: null, enum_gender: 'F' },
]

describe('IdentityManager (T9.7)', () => {
  const defaultProps = {
    candidates: MOCK_CANDIDATES,
    fencers: MOCK_FENCERS,
    isAdmin: true,
    onapprove: vi.fn(),
    onassign: vi.fn(),
    oncreatenew: vi.fn(),
    ondismiss: vi.fn(),
    onupdategender: vi.fn(),
  }

  // 9.68 — Renders candidate cards with scraped_name, confidence, status
  it('renders queue with scraped_name, confidence, status', () => {
    const { container } = render(IdentityManager, { props: defaultProps })
    const queue = container.querySelector('[data-field="identity-queue"]')
    expect(queue).not.toBeNull()

    const rows = container.querySelectorAll('[data-field="candidate-row"]')
    // Default filter is PENDING, so only 2 PENDING rows shown
    expect(rows.length).toBe(2)
    expect(rows[0].textContent).toContain('NOWAK Adam')
    expect(rows[0].textContent).toContain('78')
    expect(rows[1].textContent).toContain('ZIELINSKI Marek')
  })

  // 9.69 — Default filter PENDING, shows count badge
  it('default filter PENDING with count badge', () => {
    const { container } = render(IdentityManager, { props: defaultProps })
    const filter = container.querySelector('[data-field="status-filter"]')
    expect(filter).not.toBeNull()

    const pendingBadge = container.querySelector('[data-field="count-PENDING"]')
    expect(pendingBadge).not.toBeNull()
    expect(pendingBadge!.textContent).toContain('2')
  })

  // 9.70 — Expanding card and clicking save with suggested match calls onapprove
  it('approve calls onapprove with match id and fencer id', async () => {
    const onapprove = vi.fn()
    const { container } = render(IdentityManager, { props: { ...defaultProps, onapprove } })

    // Click edit button on first PENDING row (NOWAK Adam, id_match=2)
    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    expect(editBtns.length).toBeGreaterThan(0)
    await fireEvent.click(editBtns[0])

    // Edit form should be open with SUGGESTED choice (has fencer match)
    const editForm = container.querySelector('[data-field="edit-form"]')
    expect(editForm).not.toBeNull()

    // Click save — should call onapprove since suggested match is selected
    const saveBtn = container.querySelector('[data-field="save-btn"]')!
    await fireEvent.click(saveBtn)

    expect(onapprove).toHaveBeenCalledTimes(1)
    expect(onapprove).toHaveBeenCalledWith(2, 101)
  })

  // 9.71 — Switching to "Create new" in the fencer dropdown
  it('create new fencer option available in edit form', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })

    // Open edit on first PENDING row
    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    await fireEvent.click(editBtns[0])

    // Fencer choice dropdown should exist with NEW option
    const choiceSelect = container.querySelector('[data-field="fencer-choice"]') as HTMLSelectElement
    expect(choiceSelect).not.toBeNull()
    const options = choiceSelect.querySelectorAll('option')
    const newOption = [...options].find(o => o.value === 'NEW')
    expect(newOption).toBeDefined()
  })

  // 9.72 — Dismiss calls ondismiss with match id
  it('dismiss calls ondismiss with match id', async () => {
    const ondismiss = vi.fn()
    const { container } = render(IdentityManager, { props: { ...defaultProps, ondismiss } })

    // Open edit on first PENDING row
    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    await fireEvent.click(editBtns[0])

    const dismissBtn = container.querySelector('[data-field="dismiss-btn"]')
    expect(dismissBtn).not.toBeNull()
    await fireEvent.click(dismissBtn!)

    expect(ondismiss).toHaveBeenCalledTimes(1)
    expect(ondismiss).toHaveBeenCalledWith(2)
  })

  // 9.73 — Confidence color: green ≥95, yellow ≥50, red <50
  it('confidence color coding', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })

    // Switch to ALL to see all candidates
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filterSelect, { target: { value: 'ALL' } })

    const badges = container.querySelectorAll('[data-field="confidence-badge"]')
    const allBadges = [...badges]
    const greenBadge = allBadges.find(b => b.classList.contains('confidence-high'))
    const yellowBadge = allBadges.find(b => b.classList.contains('confidence-medium'))
    const redBadge = allBadges.find(b => b.classList.contains('confidence-low'))

    expect(greenBadge).toBeDefined()   // 97% → green
    expect(yellowBadge).toBeDefined()  // 78% or 65% → yellow
    expect(redBadge).toBeDefined()     // 30% → red
  })

  // 9.77 — Only visible when isAdmin=true
  it('renders nothing when isAdmin=false', () => {
    const { container } = render(IdentityManager, { props: { ...defaultProps, isAdmin: false } })
    const queue = container.querySelector('[data-field="identity-queue"]')
    expect(queue).toBeNull()
  })

  // 9.83 — Edit form opens with fencer choice dropdown for <100% rows
  it('edit form opens with fencer choice dropdown', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filterSelect, { target: { value: 'ALL' } })

    // Edit buttons exist for non-read-only rows, not for 100% APPROVED
    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    expect(editBtns.length).toBe(4) // candidates 1,2,3,4 — not 5 (100% APPROVED)

    await fireEvent.click(editBtns[0])
    const choiceSelect = container.querySelector('[data-field="fencer-choice"]')
    expect(choiceSelect).not.toBeNull()
  })

  // 9.84 — Surname field always editable and forces uppercase
  it('surname field always editable and forces uppercase', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })

    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    await fireEvent.click(editBtns[0])

    const surnameInput = container.querySelector('[data-field="surname-input"]') as HTMLInputElement
    expect(surnameInput).not.toBeNull()
    expect(surnameInput.disabled).toBe(false)
    // Value should be uppercase
    expect(surnameInput.value).toBe(surnameInput.value.toUpperCase())
  })

  // 9.85 — Gender select shown in edit form
  it('gender select shown in edit form', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })

    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    await fireEvent.click(editBtns[0])

    const genderSelect = container.querySelector('[data-field="gender-select"]')
    expect(genderSelect).not.toBeNull()
  })

  // 9.86 — Gender mismatch highlighted in collapsed card
  it('gender mismatch highlighted', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filterSelect, { target: { value: 'ALL' } })

    const mismatchIcons = container.querySelectorAll('.mismatch-icon')
    // Candidate 4: fencer_gender=F, tournament_gender=M → mismatch
    expect(mismatchIcons.length).toBeGreaterThanOrEqual(1)
  })

  // 9.87 — Edit button shown for AUTO_MATCHED rows
  it('edit button shown for AUTO_MATCHED rows', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filterSelect, { target: { value: 'AUTO_MATCHED' } })

    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    expect(editBtns.length).toBeGreaterThanOrEqual(1)
  })

  // 9.88 — Dismiss button shown in edit form for AUTO_MATCHED rows
  it('dismiss button shown in edit form for AUTO_MATCHED rows', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filterSelect, { target: { value: 'AUTO_MATCHED' } })

    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    await fireEvent.click(editBtns[0])

    const dismissBtn = container.querySelector('[data-field="dismiss-btn"]')
    expect(dismissBtn).not.toBeNull()
  })
})
