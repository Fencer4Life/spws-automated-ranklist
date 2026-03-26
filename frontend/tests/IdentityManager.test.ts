// Plan tests: 9.68, 9.69, 9.70, 9.71, 9.72, 9.73, 9.77
// See .claude/plans/rosy-bouncing-kitten.md §T9.7.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import IdentityManager from '../src/components/IdentityManager.svelte'
import type { MatchCandidate } from '../src/lib/types'

const MOCK_CANDIDATES: MatchCandidate[] = [
  {
    id_match: 1, id_result: 10, txt_scraped_name: 'KOWALSKI Jan',
    id_fencer: 100, txt_fencer_name: 'KOWALSKI Jan', num_confidence: 97,
    enum_status: 'AUTO_MATCHED', txt_admin_note: null,
    txt_tournament_code: 'PP1-V2-M-EPEE', enum_type: 'PPW',
  },
  {
    id_match: 2, id_result: 11, txt_scraped_name: 'NOWAK Adam',
    id_fencer: 101, txt_fencer_name: 'NOWAK Adam', num_confidence: 78,
    enum_status: 'PENDING', txt_admin_note: null,
    txt_tournament_code: 'PP1-V1-M-FOIL', enum_type: 'PPW',
  },
  {
    id_match: 3, id_result: 12, txt_scraped_name: 'WIŚNIEWSKI Piotr',
    id_fencer: null, txt_fencer_name: null, num_confidence: 30,
    enum_status: 'UNMATCHED', txt_admin_note: null,
    txt_tournament_code: 'PP1-V0-F-SABRE', enum_type: 'PPW',
  },
  {
    id_match: 4, id_result: 13, txt_scraped_name: 'ZIELINSKI Marek',
    id_fencer: 102, txt_fencer_name: 'ZIELINSKI Marek', num_confidence: 65,
    enum_status: 'PENDING', txt_admin_note: null,
    txt_tournament_code: 'PP1-V2-M-EPEE', enum_type: 'PPW',
  },
]

describe('IdentityManager (T9.7)', () => {
  const defaultProps = {
    candidates: MOCK_CANDIDATES,
    isAdmin: true,
    onapprove: vi.fn(),
    oncreatenew: vi.fn(),
    ondismiss: vi.fn(),
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

  // 9.71 — Create new fencer calls oncreatenew with match id
  it('create new fencer calls oncreatenew', async () => {
    const oncreatenew = vi.fn()
    // Show UNMATCHED candidates (which have "New fencer" button)
    const { container } = render(IdentityManager, { props: { ...defaultProps, oncreatenew } })

    // Switch filter to ALL to see UNMATCHED candidates
    const filterSelect = container.querySelector('[data-field="status-filter"]') as HTMLSelectElement
    await fireEvent.change(filterSelect, { target: { value: 'ALL' } })

    const createBtns = container.querySelectorAll('[data-field="create-new-btn"]')
    expect(createBtns.length).toBeGreaterThan(0)
    await fireEvent.click(createBtns[0])

    expect(oncreatenew).toHaveBeenCalledTimes(1)
    // UNMATCHED candidate: id_match=3
    expect(oncreatenew).toHaveBeenCalledWith(3)
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
})
