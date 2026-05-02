// Phase 4 (ADR-050) — FencerAliasManager component tests (Option A: expandable table).
// Plan IDs P4.UI.5 – P4.UI.10.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import FencerAliasManager from '../src/components/FencerAliasManager.svelte'

const mkFencer = (over: Partial<any> = {}) => ({
  id_fencer: 1,
  txt_first_name: 'Adam',
  txt_surname: 'Kowalski',
  json_name_aliases: ['KOWALSKI ADAM', 'A. KOWALSKI'],
  json_revoked_aliases: [],
  alias_count: 2,
  ts_last_alias_added: '2026-04-30T00:00:00+00:00',
  ...over,
})

describe('FencerAliasManager (Option A — expandable table)', () => {
  // P4.UI.5
  it('renders fencer rows when isAdmin', () => {
    const { container } = render(FencerAliasManager, {
      props: { fencers: [mkFencer()], isAdmin: true },
    })
    expect(container.querySelector('[data-field="alias-manager"]')).not.toBeNull()
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    expect(rows.length).toBe(1)
    // Action buttons live inside the alias-detail-row, hidden until expand
    expect(container.querySelectorAll('[data-field="alias-detail-row"]').length).toBe(0)
  })

  // P4.UI.6
  it('hides UI when isAdmin = false', () => {
    const { container } = render(FencerAliasManager, {
      props: { fencers: [mkFencer()], isAdmin: false },
    })
    expect(container.querySelector('[data-field="alias-manager"]')).toBeNull()
  })

  // P4.UI.7
  it('default-filters to fencers with alias_count > 0', () => {
    const fencers = [
      mkFencer({ id_fencer: 1, alias_count: 2 }),
      mkFencer({ id_fencer: 2, txt_surname: 'NoAlias', alias_count: 0, json_name_aliases: [] }),
    ]
    const { container } = render(FencerAliasManager, {
      props: { fencers, isAdmin: true },
    })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    expect(rows.length).toBe(1)
  })

  // P4.UI.8
  it('expands a row on click and shows alias detail with action buttons', async () => {
    const { container } = render(FencerAliasManager, {
      props: { fencers: [mkFencer()], isAdmin: true },
    })
    const row = container.querySelector('[data-field="fencer-row"]') as HTMLElement
    await fireEvent.click(row)
    const detail = container.querySelector('[data-field="alias-detail-row"]')
    expect(detail).not.toBeNull()
    expect(container.querySelectorAll('[data-field="btn-keep"]').length).toBe(2)
    expect(container.querySelectorAll('[data-field="btn-transfer"]').length).toBe(2)
    expect(container.querySelectorAll('[data-field="btn-create"]').length).toBe(2)
    expect(container.querySelectorAll('[data-field="btn-discard"]').length).toBe(2)
  })

  // P4.UI.9
  it('emits the four action callbacks with fencer id and alias on click', async () => {
    const onkeep = vi.fn()
    const ontransfer = vi.fn()
    const oncreate = vi.fn()
    const ondiscard = vi.fn()
    const { container } = render(FencerAliasManager, {
      props: {
        fencers: [mkFencer()], isAdmin: true,
        onkeep, ontransfer, oncreate, ondiscard,
      },
    })
    await fireEvent.click(container.querySelector('[data-field="fencer-row"]') as HTMLElement)

    await fireEvent.click(container.querySelectorAll('[data-field="btn-keep"]')[0] as HTMLButtonElement)
    await fireEvent.click(container.querySelectorAll('[data-field="btn-transfer"]')[0] as HTMLButtonElement)
    await fireEvent.click(container.querySelectorAll('[data-field="btn-create"]')[0] as HTMLButtonElement)
    await fireEvent.click(container.querySelectorAll('[data-field="btn-discard"]')[0] as HTMLButtonElement)

    expect(onkeep).toHaveBeenCalledWith(1, 'KOWALSKI ADAM')
    expect(ontransfer).toHaveBeenCalledWith(1, 'KOWALSKI ADAM')
    expect(oncreate).toHaveBeenCalledWith(1, 'KOWALSKI ADAM')
    expect(ondiscard).toHaveBeenCalledWith(1, 'KOWALSKI ADAM')
  })

  // P4.UI.10
  it('totalAliases count badge sums alias_count across fencers', () => {
    const fencers = [
      mkFencer({ id_fencer: 1, alias_count: 2 }),
      mkFencer({ id_fencer: 2, alias_count: 3, json_name_aliases: ['A', 'B', 'C'] }),
    ]
    const { container } = render(FencerAliasManager, {
      props: { fencers, isAdmin: true },
    })
    const totalBadge = container.querySelector('[data-field="total-aliases"]')
    expect(totalBadge?.textContent?.trim()).toContain('5')
  })

  // P4.UI.11 — collapse on second click
  it('collapses an expanded row on second click', async () => {
    const { container } = render(FencerAliasManager, {
      props: { fencers: [mkFencer()], isAdmin: true },
    })
    const row = container.querySelector('[data-field="fencer-row"]') as HTMLElement
    await fireEvent.click(row)
    expect(container.querySelector('[data-field="alias-detail-row"]')).not.toBeNull()
    await fireEvent.click(row)
    expect(container.querySelector('[data-field="alias-detail-row"]')).toBeNull()
  })
})
