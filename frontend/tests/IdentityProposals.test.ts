// Plan tests: 9.212–9.218
// ADR-093: pending birth-year proposals from public registrations.
//
// A confirmed birth year can no longer be changed by the public — it can only
// be PROPOSED (migration 20260912000003). That makes this list the point where
// the correction actually lands: until an administrator sees it and decides,
// a genuine fencer's declaration sits unapplied. A proposal nobody can see is
// a correction that never happens.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import IdentityProposals from '../src/components/IdentityProposals.svelte'
import type { IdentityProposal } from '../src/lib/types'

const MOCK: IdentityProposal[] = [
  {
    idOverride: 1,
    idFencer: 30,
    surname: 'BUJKO',
    firstName: 'Paulina',
    birthYearBefore: 1979,
    birthYearAfter: 1982,
    tsCreated: '2026-09-12T10:00:00Z',
  },
  {
    idOverride: 2,
    idFencer: 280,
    surname: 'STAŃCZYK',
    firstName: 'Marcin',
    birthYearBefore: 1980,
    birthYearAfter: 1979,
    tsCreated: '2026-09-12T11:30:00Z',
  },
]

describe('IdentityProposals (ADR-093)', () => {
  const props = (over = {}) => ({
    proposals: MOCK,
    isAdmin: true,
    deciding: null as number | null,
    onapply: vi.fn(),
    onreject: vi.fn(),
    ...over,
  })

  // 9.212 — Silent when there is nothing to decide. This panel sits above a
  // screen an administrator visits for other reasons, so an empty frame every
  // day would train them to scroll past the one day it matters.
  it('renders nothing at all when there are no pending proposals', () => {
    const { container } = render(IdentityProposals, { props: props({ proposals: [] }) })
    expect(container.querySelector('[data-field="proposals-panel"]')).toBeNull()
  })

  // 9.213 — Both years, every row. "A birth year changed" is not actionable;
  // "1979 → 1982" is.
  it('lists each proposal with the stored year and the declared one', () => {
    const { container } = render(IdentityProposals, { props: props() })
    const rows = container.querySelectorAll('[data-field="proposal-row"]')
    expect(rows.length).toBe(2)
    expect(rows[0].textContent).toContain('BUJKO')
    expect(rows[0].textContent).toContain('1979')
    expect(rows[0].textContent).toContain('1982')
    expect(rows[1].textContent).toContain('STAŃCZYK')
  })

  // 9.214 — The declared name is shown, not looked up. tbl_registration is
  // purged after ingestion (ADR-079), which is why the override row carries
  // its own copy — the evidence has to outlive the registration that caused it.
  it('shows the declared name carried on the proposal itself', () => {
    const { container } = render(IdentityProposals, { props: props() })
    const rows = container.querySelectorAll('[data-field="proposal-row"]')
    expect(rows[0].textContent).toContain('Paulina')
  })

  // 9.215 — Apply identifies the proposal, never the fencer. Two proposals can
  // name the same fencer, and applying "the one for BUJKO" would be ambiguous.
  it('apply passes the proposal id', async () => {
    const p = props()
    const { container } = render(IdentityProposals, { props: p })
    const btns = container.querySelectorAll('[data-field="proposal-apply"]')
    await fireEvent.click(btns[1] as HTMLButtonElement)
    expect(p.onapply).toHaveBeenCalledWith(2)
    expect(p.onreject).not.toHaveBeenCalled()
  })

  // 9.216 — Reject is the attacker's path and must be equally reachable.
  it('reject passes the proposal id', async () => {
    const p = props()
    const { container } = render(IdentityProposals, { props: p })
    const btns = container.querySelectorAll('[data-field="proposal-reject"]')
    await fireEvent.click(btns[0] as HTMLButtonElement)
    expect(p.onreject).toHaveBeenCalledWith(1)
    expect(p.onapply).not.toHaveBeenCalled()
  })

  // 9.217 — Both buttons lock while a decision is in flight. The server closes
  // the row on the first call and raises on the second, so a double click would
  // surface an error for work that actually succeeded.
  it('disables both actions on the row being decided', () => {
    const { container } = render(IdentityProposals, { props: props({ deciding: 1 }) })
    const rows = container.querySelectorAll('[data-field="proposal-row"]')
    const first = rows[0].querySelector('[data-field="proposal-apply"]') as HTMLButtonElement
    const second = rows[1].querySelector('[data-field="proposal-apply"]') as HTMLButtonElement
    expect(first.disabled).toBe(true)
    expect(second.disabled).toBe(false)
  })

  // 9.218 — Never rendered to a non-admin. Applying is administrator-only in
  // the database too (fn_apply_identity_override has no anon grant), so this is
  // the second of two independent controls, not the only one.
  it('renders nothing for a non-admin', () => {
    const { container } = render(IdentityProposals, { props: props({ isAdmin: false }) })
    expect(container.querySelector('[data-field="proposals-panel"]')).toBeNull()
  })
})
