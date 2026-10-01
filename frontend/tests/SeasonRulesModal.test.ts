// SR.MODAL — the season's ranking rules, opened from the ranklist
// (doc/mockups/ranking-rules-modal-2026-10-01.html, answered A on 2026-10-01).
// The modal draws the CHOSEN season's own definition — its ranking buckets,
// entry types, publication and coefficients — never a hard-coded rule.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import { tick } from 'svelte'
import SeasonRulesModal from '../src/components/SeasonRulesModal.svelte'
import { setLocale } from '../src/lib/locale.svelte'
import { setAssetBase } from '../src/lib/assetBase'
import type { RankingRules, Season } from '../src/lib/types'

const SEASON_2027: Season = {
  id_season: 4, txt_code: 'SPWS-2026-2027', dt_start: '2026-07-13', dt_end: '2027-07-15',
  bool_active: true, enum_ranking_publication: 'FULL',
}
const SEASON_2026: Season = {
  id_season: 3, txt_code: 'SPWS-2025-2026', dt_start: '2025-08-01', dt_end: '2026-07-11',
  bool_active: false, enum_ranking_publication: 'PPW_ONLY',
}
const RULES_2027: RankingRules = {
  domestic: [{ best: 2, types: ['PPW'] }, { types: ['MPW'], always: true }],
  entry_types: ['PPW', 'MPW'],
  international: [{ best: 5, types: ['PEW', 'MEW', 'MSW', 'PSW', 'PPS', 'MPS'] }],
}
const RULES_2026: RankingRules = {
  domestic: [{ best: 4, types: ['PPW'] }, { types: ['MPW'], always: true }],
  international: [{ best: 4, types: ['PPW'] }, { types: ['MPW'], always: true }, { best: 3, types: ['PEW', 'MEW', 'MSW'] }],
}
const COEF_2027 = { PPW: 1, MPW: 1.2, PEW: 1, MEW: 1.3, MSW: 1.4, PSW: 1.1, PPS: 1.1, MPS: 1.3 }

function show(props: Record<string, unknown> = {}) {
  return render(SeasonRulesModal, {
    props: { open: true, season: SEASON_2027, rules: RULES_2027, coefficients: COEF_2027, onclose: vi.fn(), ...props },
  })
}
const q = (c: HTMLElement, sel: string) => c.querySelector(sel) as HTMLElement | null
const all = (c: HTMLElement, sel: string) => Array.from(c.querySelectorAll(sel)) as HTMLElement[]
const text = (el: Element | null) => (el?.textContent ?? '').replace(/\s+/g, ' ').trim()

describe('SR.MODAL — the chosen season\'s ranking rules', () => {
  beforeEach(() => setLocale('pl'))

  it('SR.MODAL.01 names the chosen season: title, code, state, and that it holds in every weapon', () => {
    const { container } = show()
    expect(text(q(container, '.rules-title'))).toBe('Reguły rankingu na sezon 2026/2027')
    const meta = text(q(container, '.rules-meta'))
    expect(meta).toContain('SPWS-2026-2027')
    expect(meta).toContain('sezon aktywny')
    expect(meta).toContain('w każdej broni, płci i kategorii')
    expect(q(container, '[role="dialog"]')?.getAttribute('aria-label')).toBe('Reguły rankingu na sezon 2026/2027')
  })

  it('SR.MODAL.02 a full-ranking season: SPWS + EVF+ = Razem, and one card per pool', () => {
    const { container } = show()
    expect(all(container, '.rules-band .band-key').map(text)).toEqual(['SPWS', 'EVF+', 'Razem'])
    expect(text(q(container, '.rules-band'))).toContain('2 najlepsze PPW + MPW')
    expect(text(q(container, '.rules-band'))).toContain('5 najlepszych')
    expect(all(container, '.pool').map((p) => text(p.querySelector('.pool-key')))).toEqual(['SPWS', 'EVF+'])
  })

  it('SR.MODAL.03 each bucket row: its types, its rule and one ★ per counted result (MPW too)', () => {
    const { container } = show()
    const [spws, evf] = all(container, '.pool')
    const rows = all(spws, '.bucket')
    expect(rows.map((r) => text(r.querySelector('.bucket-types')))).toEqual(['PPW', 'MPW'])
    expect(text(rows[0].querySelector('.bucket-rule'))).toBe('2 najlepsze wyniki')
    expect(rows[0].querySelectorAll('.slot').length).toBe(2)
    expect(text(rows[1].querySelector('.bucket-rule'))).toBe('każdy wynik — zawsze wliczany')
    expect(rows[1].querySelectorAll('.slot').length).toBe(1)
    const intl = all(evf, '.bucket')
    expect(intl.length).toBe(1)
    expect(all(intl[0], '.type-chip').map(text)).toEqual(['PEW', 'MEW', 'MSW', 'PSW', 'PPS', 'MPS'])
    expect(text(intl[0].querySelector('.bucket-rule'))).toBe('5 najlepszych wyników łącznie')
    expect(intl[0].querySelectorAll('.slot').length).toBe(5)
  })

  it('SR.MODAL.04 a PPW-only season: one „Punkty” box and the SPWS card only', () => {
    const { container } = show({ season: SEASON_2026, rules: RULES_2026, coefficients: { PPW: 1, MPW: 1.2 } })
    expect(text(q(container, '.rules-title'))).toBe('Reguły rankingu na sezon 2025/2026')
    expect(text(q(container, '.rules-meta'))).toContain('sezon zakończony')
    expect(all(container, '.rules-band .band-key').map(text)).toEqual(['Punkty'])
    expect(text(q(container, '.rules-band'))).toContain('4 najlepsze PPW + MPW')
    expect(text(container)).toContain('W tym sezonie publikowany jest tylko ranking PPW.')
    expect(all(container, '.pool').length).toBe(1)
    expect(all(container, '.pool .bucket')[0].querySelectorAll('.slot').length).toBe(4)
  })

  it('SR.MODAL.05 who is ranked comes from entry_types, and is absent without them', () => {
    const { container } = show()
    expect(text(q(container, '[data-fact="entry"]'))).toContain('wystartowali w PPW lub MPW')
    const old = show({ season: SEASON_2026, rules: RULES_2026, coefficients: null })
    expect(q(old.container, '[data-fact="entry"]')).toBeNull()
  })

  it('SR.MODAL.06 the rolling-ranking line shows for the active season only', () => {
    const { container } = show()
    expect(q(container, '[data-fact="rolling"]')).not.toBeNull()
    const past = show({ season: SEASON_2026, rules: RULES_2026 })
    expect(q(past.container, '[data-fact="rolling"]')).toBeNull()
  })

  it('SR.MODAL.07 the coefficients of the types shown, or no line when they did not load', () => {
    const { container } = show()
    expect(all(container, '.coef').map(text)).toEqual(['PPW ×1', 'MPW ×1.2', 'PEW ×1', 'MEW ×1.3', 'MSW ×1.4', 'PSW ×1.1', 'PPS ×1.1', 'MPS ×1.3'])
    const ppwOnly = show({ season: SEASON_2026, rules: RULES_2026, coefficients: { PPW: 1, MPW: 1.2, MEW: 2 } })
    expect(all(ppwOnly.container, '.coef').map(text)).toEqual(['PPW ×1', 'MPW ×1.2'])
    const none = show({ coefficients: null })
    expect(q(none.container, '[data-fact="coefficients"]')).toBeNull()
  })

  it('SR.MODAL.08 Polish counts read „1 najlepszy wynik”, „3 najlepsze wyniki”, „12 najlepszych wyników”', () => {
    const rules: RankingRules = {
      domestic: [{ best: 1, types: ['PPW'] }, { best: 3, types: ['MPW'] }],
      international: [{ best: 12, types: ['PEW'] }],
    }
    const { container } = show({ rules })
    expect(all(container, '.bucket-rule').map(text)).toEqual(['1 najlepszy wynik', '3 najlepsze wyniki', '12 najlepszych wyników'])
  })

  it('SR.MODAL.09 in English', async () => {
    const { container } = show()
    setLocale('en')
    await tick()
    expect(text(q(container, '.rules-title'))).toBe('Ranking rules for the 2026/2027 season')
    expect(text(all(container, '.bucket-rule')[0])).toBe('best 2 results')
    expect(all(container, '.rules-band .band-key').map(text)).toEqual(['SPWS', 'EVF+', 'Total'])
  })

  it('SR.MODAL.10 ✕, Esc and a click outside close it; a click inside does not', async () => {
    const onclose = vi.fn()
    const { container } = show({ onclose })
    await fireEvent.click(q(container, '.rules-panel')!)
    expect(onclose).not.toHaveBeenCalled()
    await fireEvent.click(q(container, '.rules-close')!)
    expect(onclose).toHaveBeenCalledTimes(1)
    await fireEvent.keyDown(window, { key: 'Escape' })
    expect(onclose).toHaveBeenCalledTimes(2)
    await fireEvent.click(q(container, '.rules-overlay')!)
    expect(onclose).toHaveBeenCalledTimes(3)
  })

  it('SR.MODAL.11 the language flags sit in the corner, and the scoring table is linked', () => {
    const { container } = show()
    expect(q(container, '.rules-head .lang-toggle')).not.toBeNull()
    const annex = q(container, 'a.rules-annex') as HTMLAnchorElement
    expect(annex.getAttribute('href')).toBe('tabela-punktacji.html?lang=pl')
  })

  it('SR.MODAL.13 embedded in another site, the scoring-table link resolves against the asset base', () => {
    setAssetBase('https://fencer4life.github.io/spws-automated-ranklist/')
    try {
      const { container } = show()
      expect(q(container, 'a.rules-annex')?.getAttribute('href'))
        .toBe('https://fencer4life.github.io/spws-automated-ranklist/tabela-punktacji.html?lang=pl')
    } finally {
      setAssetBase('')
    }
  })

  it('SR.MODAL.12 closed, or with no rules, it renders nothing', () => {
    expect(q(show({ open: false }).container, '.rules-overlay')).toBeNull()
    expect(q(show({ rules: null }).container, '.rules-overlay')).toBeNull()
  })
})
