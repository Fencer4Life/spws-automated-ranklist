// Plan-test-ID 5.4: FencerAliasManager unreviewed-first sort + amber highlight + auto-expand.
//
// New behavior added in Phase 5.5 (ADR-050+058+061):
//   * Sort: rows with int_unreviewed_alias_count > 0 first (DESC by count)
//   * Visual: class:has-unreviewed on row + 🔍 N badge
//   * Per-alias: class:unreviewed when alias ∉ json_user_confirmed_aliases
//   * On mount, auto-expand the first unreviewed-fencer row
//   * "Unreviewed only" filter checkbox

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import FencerAliasManager from '../src/components/FencerAliasManager.svelte'

const mkFencer = (over: Partial<any> = {}) => ({
  id_fencer: 1,
  txt_first_name: 'Adam',
  txt_surname: 'Kowalski',
  json_name_aliases: ['ALPHA', 'BETA'],
  json_revoked_aliases: [],
  alias_count: 2,
  ts_last_alias_added: '2026-04-30T00:00:00+00:00',
  json_user_confirmed_aliases: [],
  int_unreviewed_alias_count: 2,
  latest_category_hint: null,
  latest_season_end_year: null,
  ...over,
})

describe('FencerAliasManager — unreviewed-first sort + highlight (5.4)', () => {
  // 5.4.1 — A (unreviewed=2) renders BEFORE B (unreviewed=0)
  it('sorts fencers with unreviewed aliases first', () => {
    const A = mkFencer({ id_fencer: 100, txt_surname: 'ZULU',  int_unreviewed_alias_count: 2 })
    const B = mkFencer({ id_fencer: 101, txt_surname: 'ALPHA', int_unreviewed_alias_count: 0,
                          json_name_aliases: ['CONFIRMED'], json_user_confirmed_aliases: ['CONFIRMED'], alias_count: 1 })
    const { container } = render(FencerAliasManager, {
      props: { fencers: [B, A], isAdmin: true },
    })
    const rows = container.querySelectorAll('[data-field="fencer-row"]')
    expect(rows.length).toBe(2)
    // First row = A (ZULU, unreviewed=2). Even though alphabetical would put ALPHA first.
    expect(rows[0].textContent).toContain('ZULU')
    expect(rows[1].textContent).toContain('ALPHA')
  })

  // 5.4.2 — fencer with int_unreviewed_alias_count > 0 has class:has-unreviewed
  it('row gets has-unreviewed class when count > 0', () => {
    const f = mkFencer({ int_unreviewed_alias_count: 2 })
    const { container } = render(FencerAliasManager, {
      props: { fencers: [f], isAdmin: true },
    })
    const row = container.querySelector('[data-field="fencer-row"]') as HTMLElement
    expect(row.classList.contains('has-unreviewed')).toBe(true)
  })

  // 5.4.3 — 🔍 N badge present when unreviewed > 0
  it('renders 🔍 N badge when unreviewed > 0', () => {
    const f = mkFencer({ int_unreviewed_alias_count: 3 })
    const { container } = render(FencerAliasManager, {
      props: { fencers: [f], isAdmin: true },
    })
    const badge = container.querySelector('[data-field="unreviewed-badge"]') as HTMLElement
    expect(badge).not.toBeNull()
    expect(badge.textContent).toContain('3')
  })

  // 5.4.4 — fencer with no unreviewed aliases does NOT have the highlight
  it('row does NOT get has-unreviewed when count = 0', () => {
    const f = mkFencer({ int_unreviewed_alias_count: 0,
                         json_user_confirmed_aliases: ['ALPHA', 'BETA'] })
    const { container } = render(FencerAliasManager, {
      props: { fencers: [f], isAdmin: true },
    })
    const row = container.querySelector('[data-field="fencer-row"]') as HTMLElement
    expect(row.classList.contains('has-unreviewed')).toBe(false)
    expect(container.querySelector('[data-field="unreviewed-badge"]')).toBeNull()
  })

  // 5.4.5 — auto-expand first unreviewed fencer row on mount
  it('auto-expands the first unreviewed-fencer row on mount', () => {
    const A = mkFencer({ id_fencer: 100, txt_surname: 'ZULU',  int_unreviewed_alias_count: 2 })
    const B = mkFencer({ id_fencer: 101, txt_surname: 'ALPHA', int_unreviewed_alias_count: 0,
                          json_name_aliases: ['CONFIRMED'], json_user_confirmed_aliases: ['CONFIRMED'], alias_count: 1 })
    const { container } = render(FencerAliasManager, {
      props: { fencers: [B, A], isAdmin: true },
    })
    // Detail row should be present for A only (auto-expanded)
    const detail = container.querySelectorAll('[data-field="alias-detail-row"]')
    expect(detail.length).toBe(1)
    // The expanded row's preceding fencer-row should contain ZULU
    const expanded = container.querySelector('[data-field="fencer-row"].expanded')
    expect(expanded?.textContent).toContain('ZULU')
  })

  // 5.4.6 — per-alias chip in detail has class:unreviewed when not in user_confirmed
  it('per-alias chip has unreviewed class when not in json_user_confirmed_aliases', () => {
    const f = mkFencer({
      json_name_aliases: ['ALPHA', 'BETA'],
      json_user_confirmed_aliases: ['ALPHA'],
      int_unreviewed_alias_count: 1,
    })
    const { container } = render(FencerAliasManager, {
      props: { fencers: [f], isAdmin: true },
    })
    // Auto-expanded; both alias rows should be visible
    const aliasRows = container.querySelectorAll('[data-field="alias-row"]')
    expect(aliasRows.length).toBe(2)
    // ALPHA confirmed → no unreviewed class
    // BETA not confirmed → unreviewed class
    const alpha = Array.from(aliasRows).find((r) => r.textContent?.includes('ALPHA')) as HTMLElement
    const beta = Array.from(aliasRows).find((r) => r.textContent?.includes('BETA')) as HTMLElement
    expect(alpha.classList.contains('unreviewed')).toBe(false)
    expect(beta.classList.contains('unreviewed')).toBe(true)
  })

  // 5.4.7 — "unreviewed only" toggle hides fully-reviewed fencers
  it('unreviewed-only filter hides fencers with int_unreviewed_alias_count=0', async () => {
    const A = mkFencer({ id_fencer: 100, txt_surname: 'AAA', int_unreviewed_alias_count: 2 })
    const B = mkFencer({ id_fencer: 101, txt_surname: 'BBB', int_unreviewed_alias_count: 0,
                          json_name_aliases: ['CONFIRMED'], json_user_confirmed_aliases: ['CONFIRMED'], alias_count: 1 })
    const { container } = render(FencerAliasManager, {
      props: { fencers: [A, B], isAdmin: true },
    })
    expect(container.querySelectorAll('[data-field="fencer-row"]').length).toBe(2)

    const toggle = container.querySelector('[data-field="unreviewed-only"]') as HTMLInputElement
    expect(toggle).not.toBeNull()
    await fireEvent.click(toggle)

    const rowsAfter = container.querySelectorAll('[data-field="fencer-row"]')
    expect(rowsAfter.length).toBe(1)
    expect(rowsAfter[0].textContent).toContain('AAA')
  })

  // 5.4.8 — Keep button still calls onkeep (no callback regression)
  it('clicking Keep still calls onkeep(id, alias)', async () => {
    const onkeep = vi.fn()
    const f = mkFencer({ id_fencer: 100, json_name_aliases: ['ALPHA'],
                         json_user_confirmed_aliases: [],
                         int_unreviewed_alias_count: 1, alias_count: 1 })
    const { container } = render(FencerAliasManager, {
      props: { fencers: [f], isAdmin: true, onkeep },
    })
    const keepBtn = container.querySelector('[data-field="btn-keep"]') as HTMLButtonElement
    await fireEvent.click(keepBtn)
    expect(onkeep).toHaveBeenCalledWith(100, 'ALPHA')
  })
})
