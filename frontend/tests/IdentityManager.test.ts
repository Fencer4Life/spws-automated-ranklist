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

  // 9.68 — Renders queue with scraped_name, confidence, status
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

    // PENDING count badge visible
    const pendingBadge = container.querySelector('[data-field="count-PENDING"]')
    expect(pendingBadge).not.toBeNull()
    expect(pendingBadge!.textContent).toContain('2')
  })

  // 9.70 — Approve calls onapprove with match id and fencer id
  it('approve calls onapprove with match id and fencer id', async () => {
    const onapprove = vi.fn()
    const { container } = render(IdentityManager, { props: { ...defaultProps, onapprove } })

    const approveBtn = container.querySelector('[data-field="approve-btn"]')
    expect(approveBtn).not.toBeNull()
    await fireEvent.click(approveBtn!)

    expect(onapprove).toHaveBeenCalledTimes(1)
    // First PENDING candidate: id_match=2, id_fencer=101
    expect(onapprove).toHaveBeenCalledWith(2, 101)
  })

  // 9.71 — Create new fencer button opens CreateFencerModal
  it('create new fencer button opens modal', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })

    // Switch filter to ALL to see all candidates
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filterSelect, { target: { value: 'ALL' } })

    // Modal should not be open initially
    expect(container.querySelector('[data-field="create-fencer-modal"]')).toBeNull()

    const createBtns = container.querySelectorAll('[data-field="create-new-btn"]')
    expect(createBtns.length).toBeGreaterThan(0)
    await fireEvent.click(createBtns[0])

    // Modal should now be open
    expect(container.querySelector('[data-field="create-fencer-modal"]')).not.toBeNull()
  })

  // 9.72 — Dismiss calls ondismiss with match id
  it('dismiss calls ondismiss with match id', async () => {
    const ondismiss = vi.fn()
    const { container } = render(IdentityManager, { props: { ...defaultProps, ondismiss } })

    const dismissBtn = container.querySelector('[data-field="dismiss-btn"]')
    expect(dismissBtn).not.toBeNull()
    await fireEvent.click(dismissBtn!)

    expect(ondismiss).toHaveBeenCalledTimes(1)
    // First PENDING candidate: id_match=2
    expect(ondismiss).toHaveBeenCalledWith(2)
  })

  // 9.73 — Confidence color: green ≥95, yellow ≥50, red <50
  it('confidence color coding', () => {
    // Render with ALL filter to see all candidates
    const { container } = render(IdentityManager, { props: defaultProps })

    // Switch to ALL
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    fireEvent.change(filterSelect, { target: { value: 'ALL' } })

    const badges = container.querySelectorAll('[data-field="confidence-badge"]')
    // Check that confidence badges exist with color classes
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

  // 9.83 — "Assign fencer" button visible for <100% confidence rows
  it('assign fencer button visible for <100% confidence rows', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filterSelect, { target: { value: 'ALL' } })

    const assignBtns = container.querySelectorAll('[data-field="assign-btn"]')
    // Should appear for PENDING (2,4), UNMATCHED (3), AUTO_MATCHED (1) — not for APPROVED/100% (5)
    expect(assignBtns.length).toBeGreaterThanOrEqual(4)
  })

  // 9.84 — "Create new fencer" button visible for all non-APPROVED/100% rows
  it('create new fencer button visible for all actionable rows', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filterSelect, { target: { value: 'ALL' } })

    const createBtns = container.querySelectorAll('[data-field="create-new-btn"]')
    // Should appear for candidates 1,2,3,4 but not 5 (APPROVED + 100%)
    expect(createBtns.length).toBe(4)
  })

  // 9.85 — Gender column shows inline select for rows with linked fencer
  it('gender column shows inline select for rows with linked fencer', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filterSelect, { target: { value: 'ALL' } })

    const genderSelects = container.querySelectorAll('[data-field="gender-select"]')
    // Candidates 1,2,4,5 have linked fencers; candidate 3 has no fencer
    expect(genderSelects.length).toBe(4)
  })

  // 9.86 — Gender mismatch highlighted (fencer gender ≠ tournament gender)
  it('gender mismatch highlighted', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filterSelect, { target: { value: 'ALL' } })

    const mismatchCells = container.querySelectorAll('.gender-mismatch')
    // Candidate 4: fencer_gender=F, tournament_gender=M → mismatch
    expect(mismatchCells.length).toBeGreaterThanOrEqual(1)
  })

  // 9.87 — Approve button shown for AUTO_MATCHED rows
  it('approve button shown for AUTO_MATCHED rows', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filterSelect, { target: { value: 'AUTO_MATCHED' } })

    const approveBtns = container.querySelectorAll('[data-field="approve-btn"]')
    expect(approveBtns.length).toBeGreaterThanOrEqual(1)
  })

  // 9.88 — Dismiss button shown for AUTO_MATCHED rows
  it('dismiss button shown for AUTO_MATCHED rows', async () => {
    const { container } = render(IdentityManager, { props: defaultProps })
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filterSelect, { target: { value: 'AUTO_MATCHED' } })

    const dismissBtns = container.querySelectorAll('[data-field="dismiss-btn"]')
    expect(dismissBtns.length).toBeGreaterThanOrEqual(1)
  })
})
