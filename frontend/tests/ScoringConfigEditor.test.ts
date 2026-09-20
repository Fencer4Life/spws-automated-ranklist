// Plan tests: 8.62, 8.63, 8.64, 8.65, 8.66, 8.67, 8.68, 8.69, 8.70, 8.71, 8.72, 8.73, 8.74, 8.75
// See doc/archive/m8_implementation_plan.md §T8.8.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import ScoringConfigEditor from '../src/components/ScoringConfigEditor.svelte'
import type { ScoringConfig } from '../src/lib/types'

const MOCK_CONFIG: ScoringConfig = {
  season_code: 'SPWS-2024-2025',
  mp_value: 50,
  podium_gold: 3,
  podium_silver: 2,
  podium_bronze: 1,
  ppw_multiplier: 1.0,
  ppw_best_count: 4,
  ppw_total_rounds: 5,
  mpw_multiplier: 1.2,
  mpw_droppable: false,
  pew_multiplier: 1.0,
  pew_best_count: 3,
  mew_multiplier: 1.2,
  mew_droppable: false,
  msw_multiplier: 2.0,
  psw_multiplier: 2.0,
  pps_multiplier: 1.0,
  mps_multiplier: 1.1,
  min_participants_evf: 5,
  min_participants_ppw: 1,
  show_evf_toggle: false,
  ranking_rules: {
    domestic: [
      { types: ['PPW'], best: 4 },
      { types: ['MPW'], always: true },
    ],
    international: [
      { types: ['PPW'], best: 4 },
      { types: ['MPW'], always: true },
      { types: ['PEW'], best: 3 },
      { types: ['MEW'], always: true },
    ],
  },
}

describe('ScoringConfigEditor (T8.8)', () => {
  const defaultProps = {
    config: MOCK_CONFIG,
    seasonCode: 'SPWS-2024-2025',
    onsave: vi.fn(),
    oncancel: vi.fn(),
  }

  // 8.64 — Displays MP value in base params section
  it('displays MP value in base params section', () => {
    const { container } = render(ScoringConfigEditor, { props: defaultProps })
    const mpInput = container.querySelector('input[data-field="mp_value"]') as HTMLInputElement
    expect(mpInput).not.toBeNull()
    expect(mpInput.value).toBe('50')
  })

  // 8.65 — Displays podium bonuses (gold/silver/bronze)
  it('displays podium bonuses', () => {
    const { container } = render(ScoringConfigEditor, { props: defaultProps })
    const goldInput = container.querySelector('input[data-field="podium_gold"]') as HTMLInputElement
    const silverInput = container.querySelector('input[data-field="podium_silver"]') as HTMLInputElement
    const bronzeInput = container.querySelector('input[data-field="podium_bronze"]') as HTMLInputElement
    expect(goldInput?.value).toBe('3')
    expect(silverInput?.value).toBe('2')
    expect(bronzeInput?.value).toBe('1')
  })

  // 8.66 — Displays 8 tournament multipliers in a 3/3/2 grid (PPS/MPS added,
  // pulled forward from delivery step 6 per
  // doc/plans/did-you-plan-to-optimized-penguin.md)
  it('displays 8 tournament multipliers', () => {
    const { container } = render(ScoringConfigEditor, { props: defaultProps })
    const ppwMult = container.querySelector('input[data-field="ppw_multiplier"]') as HTMLInputElement
    const mpwMult = container.querySelector('input[data-field="mpw_multiplier"]') as HTMLInputElement
    const pewMult = container.querySelector('input[data-field="pew_multiplier"]') as HTMLInputElement
    const mewMult = container.querySelector('input[data-field="mew_multiplier"]') as HTMLInputElement
    const mswMult = container.querySelector('input[data-field="msw_multiplier"]') as HTMLInputElement
    const pswMult = container.querySelector('input[data-field="psw_multiplier"]') as HTMLInputElement
    const ppsMult = container.querySelector('input[data-field="pps_multiplier"]') as HTMLInputElement
    const mpsMult = container.querySelector('input[data-field="mps_multiplier"]') as HTMLInputElement
    expect(ppwMult?.value).toBe('1')
    expect(mpwMult?.value).toBe('1.2')
    expect(pewMult?.value).toBe('1')
    expect(mewMult?.value).toBe('1.2')
    expect(mswMult?.value).toBe('2')
    expect(pswMult?.value).toBe('2')
    expect(ppsMult?.value).toBe('1')
    expect(mpsMult?.value).toBe('1.1')
  })

  // Part 3 — expected-rounds label clarifies "DE rounds" (PL default locale)
  it('labels expected rounds as DE rounds (rund pucharowych)', () => {
    const { getByText } = render(ScoringConfigEditor, { props: defaultProps })
    expect(getByText('Oczekiwana liczba rund pucharowych')).not.toBeNull()
  })

  // 8.67 — Displays intake rules (min participants, total rounds)
  it('displays intake rules', () => {
    const { container } = render(ScoringConfigEditor, { props: defaultProps })
    const minEvf = container.querySelector('input[data-field="min_participants_evf"]') as HTMLInputElement
    const minPpw = container.querySelector('input[data-field="min_participants_ppw"]') as HTMLInputElement
    const rounds = container.querySelector('input[data-field="ppw_total_rounds"]') as HTMLInputElement
    expect(minEvf?.value).toBe('5')
    expect(minPpw?.value).toBe('1')
    expect(rounds?.value).toBe('5')
  })

  // 8.68 — Displays ranking rule buckets (domestic + international pools)
  it('displays ranking rule buckets', () => {
    const { container } = render(ScoringConfigEditor, { props: defaultProps })
    const domesticSection = container.querySelector('.rules-domestic')
    const intlSection = container.querySelector('.rules-international')
    expect(domesticSection).not.toBeNull()
    expect(intlSection).not.toBeNull()
    // Domestic: 2 buckets, International: 4 buckets
    const domesticBuckets = domesticSection!.querySelectorAll('.bucket-row')
    const intlBuckets = intlSection!.querySelectorAll('.bucket-row')
    expect(domesticBuckets.length).toBe(2)
    expect(intlBuckets.length).toBe(4)
  })

  // 8.69 — Can edit multiplier value and see change reflected
  it('can edit a multiplier value', async () => {
    const { container } = render(ScoringConfigEditor, { props: defaultProps })
    const ppwMult = container.querySelector('input[data-field="ppw_multiplier"]') as HTMLInputElement
    await fireEvent.input(ppwMult, { target: { value: '1.5' } })
    expect(ppwMult.value).toBe('1.5')
  })

  // 8.70 — Can add a new bucket to domestic pool
  it('can add a new bucket to domestic pool', async () => {
    const { container } = render(ScoringConfigEditor, { props: defaultProps })
    const domesticSection = container.querySelector('.rules-domestic')
    const addBtn = domesticSection!.querySelector('.add-bucket-btn')
    expect(addBtn).not.toBeNull()
    await fireEvent.click(addBtn!)
    // Type picker appears — select PPW type and confirm
    const picker = domesticSection!.querySelector('.new-bucket-picker')
    expect(picker).not.toBeNull()
    const typeButtons = picker!.querySelectorAll('.picker-type-btn')
    expect(typeButtons.length).toBeGreaterThan(0)
    await fireEvent.click(typeButtons[0]) // select first type (PPW)
    const confirmBtn = picker!.querySelector('.picker-confirm')
    await fireEvent.click(confirmBtn!)
    const buckets = domesticSection!.querySelectorAll('.bucket-row')
    expect(buckets.length).toBe(3)
  })

  // 8.71 — Can remove a bucket from a pool
  it('can remove a bucket from a pool', async () => {
    const { container } = render(ScoringConfigEditor, { props: defaultProps })
    const domesticSection = container.querySelector('.rules-domestic')
    const removeBtn = domesticSection!.querySelector('.remove-bucket-btn')
    expect(removeBtn).not.toBeNull()
    await fireEvent.click(removeBtn!)
    const buckets = domesticSection!.querySelectorAll('.bucket-row')
    expect(buckets.length).toBe(1)
  })

  // 8.72 — "Zapisz i przelicz" calls onsave with updated config
  it('calls onsave when save button clicked', async () => {
    const onsave = vi.fn()
    const { container } = render(ScoringConfigEditor, {
      props: { ...defaultProps, onsave },
    })
    const saveBtn = container.querySelector('.config-save-btn')
    expect(saveBtn).not.toBeNull()
    await fireEvent.click(saveBtn!)
    expect(onsave).toHaveBeenCalled()
  })

  // 8.73 — "Anuluj" reverts to last saved state
  it('calls oncancel when cancel button clicked', async () => {
    const oncancel = vi.fn()
    const { container } = render(ScoringConfigEditor, {
      props: { ...defaultProps, oncancel },
    })
    const cancelBtn = container.querySelector('.config-cancel-btn')
    expect(cancelBtn).not.toBeNull()
    await fireEvent.click(cancelBtn!)
    expect(oncancel).toHaveBeenCalled()
  })

  // 8.74 — "Eksport JSON" downloads config as .json file
  it('has an export JSON button', () => {
    const { container } = render(ScoringConfigEditor, { props: defaultProps })
    const exportBtn = container.querySelector('.config-export-btn')
    expect(exportBtn).not.toBeNull()
    expect(exportBtn!.textContent).toContain('Eksport JSON')
  })

  // 8.75 — Season banner shows correct season code
  it('shows season code in banner', () => {
    const { container } = render(ScoringConfigEditor, { props: defaultProps })
    const banner = container.querySelector('.config-banner')
    expect(banner).not.toBeNull()
    expect(banner!.textContent).toContain('SPWS-2024-2025')
  })

  // ========================================================================
  // Phase 3 (ph3.37a–ph3.37e) — Section 4b carry-over engine dropdown
  // ========================================================================

  // ph3.37a — engine dropdown lists ALL values of enum_event_carryover_engine
  // (extensible by design: when a new engine is added to CARRYOVER_ENGINE_VALUES
  //  in types.ts, it auto-appears in the dropdown).
  it('ph3.37a: engine dropdown lists all CARRYOVER_ENGINE_VALUES', () => {
    const { container } = render(ScoringConfigEditor, { props: defaultProps })
    const select = container.querySelector('select[data-field="engine-select"]') as HTMLSelectElement
    expect(select).not.toBeNull()
    const optionValues = Array.from(select.options).map((o) => o.value)
    expect(optionValues).toEqual(['EVENT_FK_MATCHING', 'EVENT_CODE_MATCHING'])
  })

  // ph3.37b — defaults to EVENT_FK_MATCHING when config has no engine set
  // (new season, prior to first save). When config carries an engine value,
  // the dropdown reflects it instead.
  it('ph3.37b: defaults engine to FK when config.carryover_engine is undefined', () => {
    const configNoEngine = { ...MOCK_CONFIG }
    delete (configNoEngine as { carryover_engine?: string }).carryover_engine
    const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config: configNoEngine } })
    const select = container.querySelector('select[data-field="engine-select"]') as HTMLSelectElement
    expect(select.value).toBe('EVENT_FK_MATCHING')
  })

  it('ph3.37b: engine dropdown reflects existing config.engine value', () => {
    const codeConfig: ScoringConfig = { ...MOCK_CONFIG, carryover_engine: 'EVENT_CODE_MATCHING' }
    const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config: codeConfig } })
    const select = container.querySelector('select[data-field="engine-select"]') as HTMLSelectElement
    expect(select.value).toBe('EVENT_CODE_MATCHING')
  })

  // ph3.37c — selecting EVENT_CODE_MATCHING surfaces the (legacy) tag + warning hint
  it('ph3.37c: selecting EVENT_CODE_MATCHING shows the (legacy) tag', async () => {
    const codeConfig: ScoringConfig = { ...MOCK_CONFIG, carryover_engine: 'EVENT_CODE_MATCHING' }
    const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config: codeConfig } })
    const tag = container.querySelector('[data-field="engine-legacy-tag"]')
    expect(tag).not.toBeNull()
    expect(tag!.textContent).toContain('legacy')
  })

  // ph3.37d — onsave payload includes the `engine` field so App.svelte's handler
  // can patch tbl_season.enum_carryover_engine separately from the scoring config.
  it('ph3.37d: onsave payload includes the engine field', async () => {
    const onsave = vi.fn()
    const codeConfig: ScoringConfig = { ...MOCK_CONFIG, carryover_engine: 'EVENT_CODE_MATCHING' }
    const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config: codeConfig, onsave } })

    // Flip the dropdown to FK
    const select = container.querySelector('select[data-field="engine-select"]') as HTMLSelectElement
    await fireEvent.change(select, { target: { value: 'EVENT_FK_MATCHING' } })

    const saveBtn = container.querySelector('.config-save-btn') as HTMLButtonElement
    await fireEvent.click(saveBtn)
    expect(onsave).toHaveBeenCalled()
    const payload = onsave.mock.calls[0][0]
    expect(payload.carryover_engine).toBe('EVENT_FK_MATCHING')
  })

  // SS26.CARRY (design step 7, ADR-101): carryover_engine and engine_code
  // are independently settable — changing the scoring engine must never
  // touch the carry-over engine, and vice versa. Both remain distinct
  // fields all the way through the onsave payload.
  describe('SS26.CARRY — carryover_engine and engine_code stay independent', () => {
    it('changing the scoring engine leaves carryover_engine untouched', async () => {
      const onsave = vi.fn()
      const config: ScoringConfig = { ...MOCK_CONFIG, carryover_engine: 'EVENT_CODE_MATCHING', engine_code: 'CLASSIC_V1' }
      const { container } = render(ScoringConfigEditor, {
        props: { ...defaultProps, config, onsave, scoringEngines: [{ code: 'CLASSIC_V1', label: 'Classic' }, { code: 'FIELD_SCALED_V1', label: 'Field-scaled' }] },
      })
      const scoringSelect = container.querySelector('select[data-field="scoring-engine-select"]') as HTMLSelectElement
      await fireEvent.change(scoringSelect, { target: { value: 'FIELD_SCALED_V1' } })

      const saveBtn = container.querySelector('.config-save-btn') as HTMLButtonElement
      await fireEvent.click(saveBtn)
      const payload = onsave.mock.calls[0][0]
      expect(payload.engine_code).toBe('FIELD_SCALED_V1')
      expect(payload.carryover_engine).toBe('EVENT_CODE_MATCHING')
    })

    it('changing the carry-over engine leaves engine_code untouched', async () => {
      const onsave = vi.fn()
      const config: ScoringConfig = { ...MOCK_CONFIG, carryover_engine: 'EVENT_FK_MATCHING', engine_code: 'CLASSIC_V1' }
      const { container } = render(ScoringConfigEditor, {
        props: { ...defaultProps, config, onsave, scoringEngines: [{ code: 'CLASSIC_V1', label: 'Classic' }] },
      })
      const carryoverSelect = container.querySelector('select[data-field="engine-select"]') as HTMLSelectElement
      await fireEvent.change(carryoverSelect, { target: { value: 'EVENT_CODE_MATCHING' } })

      const saveBtn = container.querySelector('.config-save-btn') as HTMLButtonElement
      await fireEvent.click(saveBtn)
      const payload = onsave.mock.calls[0][0]
      expect(payload.carryover_engine).toBe('EVENT_CODE_MATCHING')
      expect(payload.engine_code).toBe('CLASSIC_V1')
    })
  })

  // ph3.37e — opening editor on an existing season's 🎯 button shows the
  // dropdown with that season's current engine value (verifies prop wiring
  // through the existing config flow, not a regression).
  it('ph3.37e: existing season editor shows current engine in dropdown', () => {
    const fkConfig: ScoringConfig = { ...MOCK_CONFIG, carryover_engine: 'EVENT_FK_MATCHING' }
    const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config: fkConfig } })
    const select = container.querySelector('select[data-field="engine-select"]') as HTMLSelectElement
    expect(select.value).toBe('EVENT_FK_MATCHING')
  })

  // ==========================================================================
  // SS26.LOCK.11 — governance lock (2026-09-19): server-authoritative
  // scoring_admin_locked, not a season date, disables every field; the save
  // button stays visible and clickable but shows the Polish explanation
  // instead of calling onsave.
  // ==========================================================================

  const LOCKED_CONFIG: ScoringConfig = { ...MOCK_CONFIG, scoring_admin_locked: true }

  it('SS26.LOCK.11: renders every field disabled when scoring_admin_locked', () => {
    const { container } = render(ScoringConfigEditor, {
      props: { ...defaultProps, config: LOCKED_CONFIG, readonly: true },
    })
    const fields = [
      'mp_value', 'ppw_total_rounds', 'podium_gold', 'podium_silver', 'podium_bronze',
      'ppw_multiplier', 'mpw_multiplier', 'pew_multiplier', 'mew_multiplier',
      'msw_multiplier', 'psw_multiplier', 'pps_multiplier', 'mps_multiplier',
      'min_participants_ppw', 'min_participants_evf', 'engine-select', 'scoring-engine-select',
    ]
    for (const f of fields) {
      const el = container.querySelector(`[data-field="${f}"]`) as HTMLInputElement | HTMLSelectElement
      expect(el, `field ${f} should exist`).not.toBeNull()
      expect(el.disabled, `field ${f} should be disabled`).toBe(true)
    }
  })

  it('SS26.LOCK.11: save button stays visible when locked', () => {
    const { container } = render(ScoringConfigEditor, {
      props: { ...defaultProps, config: LOCKED_CONFIG, readonly: true },
    })
    const saveBtn = container.querySelector('.config-save-btn') as HTMLButtonElement
    expect(saveBtn).not.toBeNull()
    expect(saveBtn.disabled).toBe(false)
  })

  it('SS26.LOCK.11: clicking save while locked shows the exact Polish explanation and calls no RPC', async () => {
    const onsave = vi.fn()
    const { container, getByText } = render(ScoringConfigEditor, {
      props: { ...defaultProps, config: LOCKED_CONFIG, readonly: true, onsave },
    })
    const saveBtn = container.querySelector('.config-save-btn') as HTMLButtonElement
    await fireEvent.click(saveBtn)
    expect(onsave).not.toHaveBeenCalled()
    expect(
      getByText(
        'Konfiguracja punktacji jest zablokowana, ponieważ sezon zawiera już obliczone wyniki. Zmiana wymaga zatwierdzonej aktualizacji konfiguracji i ponownego przeliczenia całego sezonu poza panelem administracyjnym.',
      ),
    ).not.toBeNull()
  })

  it('SS26.LOCK.11: no locked notice and normal save when unlocked', async () => {
    const onsave = vi.fn()
    const { container, queryByText } = render(ScoringConfigEditor, {
      props: { ...defaultProps, onsave },
    })
    expect(queryByText('Konfiguracja punktacji zablokowana')).toBeNull()
    const saveBtn = container.querySelector('.config-save-btn') as HTMLButtonElement
    await fireEvent.click(saveBtn)
    expect(onsave).toHaveBeenCalled()
  })
})
