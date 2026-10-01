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

  // 8.70 — Can add a new bucket to domestic pool. MOCK_CONFIG already uses
  // PPW and MPW, and a type may sit in one bucket only (ADM27.RULES.11), so the
  // config here leaves MPW free.
  it('can add a new bucket to domestic pool', async () => {
    const config: ScoringConfig = { ...MOCK_CONFIG, ranking_rules: { domestic: [{ types: ['PPW'], best: 4 }], international: [] } }
    const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config } })
    const domesticSection = container.querySelector('.rules-domestic')
    const addBtn = domesticSection!.querySelector('.add-bucket-btn')
    expect(addBtn).not.toBeNull()
    await fireEvent.click(addBtn!)
    // Type picker appears — select MPW and confirm
    const picker = domesticSection!.querySelector('.new-bucket-picker')
    expect(picker).not.toBeNull()
    const mpw = Array.from(picker!.querySelectorAll('.picker-type-btn')).find((b) => b.textContent === 'MPW')
    expect(mpw).toBeDefined()
    await fireEvent.click(mpw!)
    const confirmBtn = picker!.querySelector('.picker-confirm')
    await fireEvent.click(confirmBtn!)
    const buckets = domesticSection!.querySelectorAll('.bucket-row')
    expect(buckets.length).toBe(2)
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

  // ==========================================================================
  // SE27.UI.02–07 — an engine per tournament type (ADR-103 §2, mockup
  // doc/mockups/se27_scoring_config_per_type.html revision 2, approved
  // 2026-09-28). The season engine becomes the default; each type card
  // carries its own engine selector and names its joined-bracket module;
  // read-only panels list each engine's fixed rules. ADR-104 removed the
  // place-and-medal engine: the second engine here is the joined engine that
  // replaces it. Its texts are those of the mockup's revision 3, approved on
  // 1 October 2026 (JB27.UI.02).
  // ==========================================================================

  const CLASSIC = 'EVF_CLASSIC_V1_2025_2026'
  const JOINED = 'SPWS_EVF_JOINED_V1_2026_2027'
  // The shape fetchScoringEngines returns: tbl_scoring_engine's code, label
  // and joined-bracket module, in id order.
  const ENGINES = [
    { code: CLASSIC, label: 'EVF klasyczny (do sezonu 2025/2026)', module: 'PER_CATEGORY_RENUMBER' },
    { code: JOINED, label: 'SPWS — punkty EVF i premia w stawce łączonej (od sezonu 2026/2027)', module: 'JOINED_BRACKET_CATEGORY_PLACE' },
  ]
  const ALL_TYPES = ['PPW', 'MPW', 'PPS', 'MPS', 'PEW', 'MEW', 'MSW', 'PSW']
  // fn_export_scoring_config's type_engines for SPWS-2026-2027: the RESOLVED
  // engine of every type (ADR-103 amendment of 2026-09-28).
  const TYPE_ENGINES_2026: Record<string, string> = {
    PPW: JOINED, MPW: JOINED,
    PPS: CLASSIC, MPS: CLASSIC, PEW: CLASSIC, MEW: CLASSIC, MSW: CLASSIC, PSW: CLASSIC,
  }
  const CONFIG_2026: ScoringConfig = {
    ...MOCK_CONFIG,
    season_code: 'SPWS-2026-2027',
    engine_code: JOINED,
    type_engines: TYPE_ENGINES_2026,
  }
  const props2026 = { ...defaultProps, seasonCode: 'SPWS-2026-2027', config: CONFIG_2026, scoringEngines: ENGINES }

  const typeSelect = (c: HTMLElement, tp: string) =>
    c.querySelector(`select[data-field="type-engine-${tp}"]`) as HTMLSelectElement
  const typeModule = (c: HTMLElement, tp: string) =>
    c.querySelector(`[data-field="type-module-${tp}"]`) as HTMLElement

  describe('SE27.UI.02 — every type card has an engine selector showing its resolved engine', () => {
    it('renders one selector per type, listing every released engine', () => {
      const { container } = render(ScoringConfigEditor, { props: props2026 })
      for (const tp of ALL_TYPES) {
        const select = typeSelect(container, tp)
        expect(select, `selector for ${tp}`).not.toBeNull()
        expect(Array.from(select.options).map((o) => o.value)).toEqual([CLASSIC, JOINED])
      }
    })

    it('shows each type\'s engine from type_engines', () => {
      const { container } = render(ScoringConfigEditor, { props: props2026 })
      for (const tp of ALL_TYPES) {
        expect(typeSelect(container, tp).value, tp).toBe(TYPE_ENGINES_2026[tp])
      }
    })

    it('labels the options with the short engine names of the mockup', () => {
      const { container } = render(ScoringConfigEditor, { props: props2026 })
      const labels = Array.from(typeSelect(container, 'PPW').options).map((o) => o.textContent?.trim())
      expect(labels).toEqual(['EVF klasyczny', 'SPWS 2026/2027'])
    })

    it('falls back to the engine\'s own label for an engine it has no short name for', () => {
      const engines = [...ENGINES, { code: 'FUTURE_V1', label: 'Przyszły silnik', module: 'PER_CATEGORY_RENUMBER' }]
      const { container } = render(ScoringConfigEditor, { props: { ...props2026, scoringEngines: engines } })
      const labels = Array.from(typeSelect(container, 'PPW').options).map((o) => o.textContent?.trim())
      expect(labels).toContain('Przyszły silnik')
    })

    it('without type_engines, every card shows the season default and follows it', async () => {
      const config: ScoringConfig = { ...MOCK_CONFIG, engine_code: CLASSIC }
      const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config, scoringEngines: ENGINES } })
      for (const tp of ALL_TYPES) expect(typeSelect(container, tp).value, tp).toBe(CLASSIC)
      const seasonSelect = container.querySelector('select[data-field="scoring-engine-select"]') as HTMLSelectElement
      await fireEvent.change(seasonSelect, { target: { value: JOINED } })
      for (const tp of ALL_TYPES) expect(typeSelect(container, tp).value, tp).toBe(JOINED)
    })
  })

  describe('SE27.UI.03 — every card names its joined-bracket module', () => {
    it('PPW and MPW name the module of their engine', () => {
      const { container } = render(ScoringConfigEditor, { props: props2026 })
      for (const tp of ['PPW', 'MPW']) {
        const text = typeModule(container, tp).textContent ?? ''
        expect(text).toContain('JOINED_BRACKET_CATEGORY_PLACE')
        // JB27.UI.02: the bracket's category order is stored, not K, m and b.
        expect(text).toContain('Stawka łączona: miejsce w całej stawce i kolejność kategorii')
      }
    })

    it('a classic domestic type names PER_CATEGORY_RENUMBER', () => {
      const config: ScoringConfig = {
        ...MOCK_CONFIG,
        engine_code: CLASSIC,
        type_engines: Object.fromEntries(ALL_TYPES.map((tp) => [tp, CLASSIC])),
      }
      const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config, scoringEngines: ENGINES } })
      const text = typeModule(container, 'PPW').textContent ?? ''
      expect(text).toContain('PER_CATEGORY_RENUMBER')
      expect(text).toContain('Rozdzielenie na kategorie')
    })

    it('the module follows the card\'s engine selector', async () => {
      const { container } = render(ScoringConfigEditor, { props: props2026 })
      await fireEvent.change(typeSelect(container, 'MPW'), { target: { value: CLASSIC } })
      expect(typeModule(container, 'MPW').textContent).toContain('PER_CATEGORY_RENUMBER')
    })

    it('PZSz and international cards name no module, whatever the engine', async () => {
      const { container } = render(ScoringConfigEditor, { props: props2026 })
      const expected: Record<string, string> = {
        PPS: 'Jedna stawka seniorów, bez podziału',
        MPS: 'Jedna stawka seniorów, bez podziału',
        PEW: 'Wyniki kategorii publikowane przez EVF',
        MEW: 'Wyniki kategorii publikowane przez EVF',
        MSW: 'Wyniki kategorii publikowane przez FIE',
        PSW: 'Wyniki kategorii publikowane przez organizatora',
      }
      for (const [tp, text] of Object.entries(expected)) {
        const shown = typeModule(container, tp).textContent ?? ''
        expect(shown, tp).toContain('—')
        expect(shown, tp).toContain(text)
        expect(shown, tp).not.toContain('PER_CATEGORY_RENUMBER')
      }
      await fireEvent.change(typeSelect(container, 'PPS'), { target: { value: JOINED } })
      expect(typeModule(container, 'PPS').textContent).not.toContain('JOINED_BRACKET_CATEGORY_PLACE')
    })
  })

  describe('SE27.UI.04 — a read-only panel lists each engine\'s fixed rules', () => {
    it('EVF classic: log place scale, 10 per elimination round, podium × 3 × ∛N, its module', () => {
      const { container } = render(ScoringConfigEditor, { props: props2026 })
      const panel = container.querySelector(`[data-field="engine-panel-${CLASSIC}"]`) as HTMLElement
      expect(panel).not.toBeNull()
      const text = panel.textContent ?? ''
      expect(text).toContain('mp − (mp − 1) × ln(miejsce) / ln N')
      expect(text).toContain('10 pkt')
      expect(text).toContain('× 3 × ∛N')
      expect(text).toContain('PER_CATEGORY_RENUMBER')
      expect(panel.querySelectorAll('input, select').length).toBe(0)
    })

    // JB27.UI.02 (ADR-104 §8, mockup revision 3): the joined engine's fixed
    // rules, in the annex's words. None of them is a setting: they belong to
    // the engine version, like EVF classic's.
    it('JB27.UI.02 the joined engine: 3-2-1 up to 3, EVF from 4 and from 16, the premium, the cap, its module', () => {
      const { container } = render(ScoringConfigEditor, { props: props2026 })
      const panel = container.querySelector(`[data-field="engine-panel-${JOINED}"]`) as HTMLElement
      expect(panel).not.toBeNull()
      expect(panel.querySelector('h4')?.textContent).toContain(JOINED)
      expect(panel.querySelector('h4')?.textContent).toContain('stałe silnika — tylko do odczytu')
      const rows = Array.from(panel.querySelectorAll('tr')).map((tr) =>
        Array.from(tr.querySelectorAll('td')).map((td) => td.textContent ?? ''))
      expect(rows).toEqual([
        ['Stawka 1–3', 'N − miejsce + 1 (3, 2, 1)'],
        ['Jedna kategoria od 4, każda stawka od 16', 'algorytm EVF dla całej stawki (wartość bazowa i podium powyżej)'],
        ['Stawka łączona 4–15, najmłodsza kategoria', 'algorytm EVF'],
        ['Stawka łączona 4–15, starsza kategoria',
          'większa z wartości EVF × (1 + 0,05 · d) oraz EVF + d; d — liczba kroków od najmłodszej kategorii obecnej w stawce'],
        ['Limit',
          'co najmniej 1 pkt mniej niż zawodnik, który zajął miejsce bezpośrednio przed nim (dowolnej kategorii); współczynnik typu mnoży wynik po limicie'],
        ['Moduł stawki łączonej',
          'JOINED_BRACKET_CATEGORY_PLACE — miejsce i N całej stawki; kolejność kategorii stawki zapisana przy turnieju'],
      ])
      expect(panel.querySelectorAll('input, select').length).toBe(0)
    })

    it('JB27.UI.02 the panels follow the order of the engine registry: EVF classic, then the joined engine', () => {
      const { container } = render(ScoringConfigEditor, { props: props2026 })
      const order = Array.from(container.querySelectorAll('[data-field^="engine-panel-"]'))
        .map((el) => el.getAttribute('data-field'))
      expect(order).toEqual([`engine-panel-${CLASSIC}`, `engine-panel-${JOINED}`])
    })

    it('JB27.UI.02 the joined panel stays shown, read-only, on a locked season', () => {
      const locked: ScoringConfig = { ...CONFIG_2026, scoring_admin_locked: true }
      const { container } = render(ScoringConfigEditor, { props: { ...props2026, config: locked, readonly: true } })
      const panel = container.querySelector(`[data-field="engine-panel-${JOINED}"]`) as HTMLElement
      expect(panel).not.toBeNull()
      expect(panel.textContent).toContain('EVF × (1 + 0,05 · d)')
    })

    it('JB27.CLEAN.06 no panel describes the removed place-and-medal engine', () => {
      const { container } = render(ScoringConfigEditor, { props: props2026 })
      expect(container.querySelector('[data-field="engine-panel-SPWS_PLACE_MEDAL_V1_2026_2027"]')).toBeNull()
      const text = container.textContent ?? ''
      for (const gone of ['Stawka 4–31', 'Stawka od 32', '13 / 7 / 3 × ∛K', 'premia medalowa']) {
        expect(text, gone).not.toContain(gone)
      }
    })

    it('an engine without known fixed rules gets no panel', () => {
      const engines = [...ENGINES, { code: 'FUTURE_V1', label: 'Przyszły silnik', module: 'PER_CATEGORY_RENUMBER' }]
      const { container } = render(ScoringConfigEditor, { props: { ...props2026, scoringEngines: engines } })
      expect(container.querySelector('[data-field="engine-panel-FUTURE_V1"]')).toBeNull()
    })
  })

  describe('SE27.UI.05 — the save sends the engine each card shows as type_engines', () => {
    it('an unchanged form sends the loaded type_engines and engine_code', async () => {
      const onsave = vi.fn()
      const { container } = render(ScoringConfigEditor, { props: { ...props2026, onsave } })
      await fireEvent.click(container.querySelector('.config-save-btn') as HTMLButtonElement)
      const payload = onsave.mock.calls[0][0]
      expect(payload.type_engines).toEqual(TYPE_ENGINES_2026)
      expect(payload.engine_code).toBe(JOINED)
    })

    it('changing one card changes only that type', async () => {
      const onsave = vi.fn()
      const { container } = render(ScoringConfigEditor, { props: { ...props2026, onsave } })
      await fireEvent.change(typeSelect(container, 'PPS'), { target: { value: JOINED } })
      await fireEvent.click(container.querySelector('.config-save-btn') as HTMLButtonElement)
      const payload = onsave.mock.calls[0][0]
      expect(payload.type_engines).toEqual({ ...TYPE_ENGINES_2026, PPS: JOINED })
      expect(payload.engine_code).toBe(JOINED)
    })

    it('changing the season default keeps every card on the engine it shows', async () => {
      const onsave = vi.fn()
      const { container } = render(ScoringConfigEditor, { props: { ...props2026, onsave } })
      const seasonSelect = container.querySelector('select[data-field="scoring-engine-select"]') as HTMLSelectElement
      await fireEvent.change(seasonSelect, { target: { value: CLASSIC } })
      for (const tp of ALL_TYPES) expect(typeSelect(container, tp).value, tp).toBe(TYPE_ENGINES_2026[tp])
      await fireEvent.click(container.querySelector('.config-save-btn') as HTMLButtonElement)
      const payload = onsave.mock.calls[0][0]
      expect(payload.engine_code).toBe(CLASSIC)
      expect(payload.type_engines).toEqual(TYPE_ENGINES_2026)
    })

    it('a config without type_engines sends none until a card is changed', async () => {
      const onsave = vi.fn()
      const config: ScoringConfig = { ...MOCK_CONFIG, engine_code: CLASSIC }
      const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config, onsave, scoringEngines: ENGINES } })
      const save = container.querySelector('.config-save-btn') as HTMLButtonElement
      await fireEvent.click(save)
      expect(onsave.mock.calls[0][0].type_engines).toBeUndefined()
      await fireEvent.change(typeSelect(container, 'PPW'), { target: { value: JOINED } })
      await fireEvent.click(save)
      expect(onsave.mock.calls[1][0].type_engines).toEqual({ PPW: JOINED })
    })

    it('the live config a wizard captures carries type_engines too', async () => {
      const onchange = vi.fn()
      const { container } = render(ScoringConfigEditor, { props: { ...props2026, onchange } })
      await fireEvent.change(typeSelect(container, 'PSW'), { target: { value: JOINED } })
      const last = onchange.mock.calls[onchange.mock.calls.length - 1][0]
      expect(last.type_engines).toEqual({ ...TYPE_ENGINES_2026, PSW: JOINED })
    })

    it('the type engines never touch the carry-over engine', async () => {
      const onsave = vi.fn()
      const config: ScoringConfig = { ...CONFIG_2026, carryover_engine: 'EVENT_CODE_MATCHING' }
      const { container } = render(ScoringConfigEditor, { props: { ...props2026, config, onsave } })
      await fireEvent.change(typeSelect(container, 'PEW'), { target: { value: JOINED } })
      await fireEvent.click(container.querySelector('.config-save-btn') as HTMLButtonElement)
      expect(onsave.mock.calls[0][0].carryover_engine).toBe('EVENT_CODE_MATCHING')
    })
  })

  describe('SE27.UI.06 — the lock covers the per-type engines', () => {
    it('every type selector is disabled when scoring_admin_locked', () => {
      const config: ScoringConfig = { ...CONFIG_2026, scoring_admin_locked: true }
      const { container } = render(ScoringConfigEditor, { props: { ...props2026, config, readonly: true } })
      for (const tp of ALL_TYPES) expect(typeSelect(container, tp).disabled, tp).toBe(true)
    })

    it('a locked save calls no RPC, whatever the type selectors hold', async () => {
      const onsave = vi.fn()
      const config: ScoringConfig = { ...CONFIG_2026, scoring_admin_locked: true }
      const { container } = render(ScoringConfigEditor, { props: { ...props2026, config, readonly: true, onsave } })
      await fireEvent.click(container.querySelector('.config-save-btn') as HTMLButtonElement)
      expect(onsave).not.toHaveBeenCalled()
      expect(container.querySelector('[data-field="locked-notice"]')).not.toBeNull()
    })
  })

  describe('SE27.UI.07 — labels say what each setting feeds', () => {
    it('names the EVF base value, the season default and the per-type section', () => {
      const { getByText } = render(ScoringConfigEditor, { props: props2026 })
      expect(getByText('Wartość bazowa EVF (mp)')).not.toBeNull()
      // JB27.UI.02: on the joined engine the EVF base value feeds every bracket
      // of 4 or more in PPW and MPW, so it feeds every type.
      expect(getByText('algorytm EVF — każdy typ zawodów; w PPW i MPW każda stawka od 4 zawodników')).not.toBeNull()
      expect(getByText('Silnik domyślny sezonu')).not.toBeNull()
      expect(getByText('dla typów bez własnego silnika')).not.toBeNull()
      expect(getByText('Premia za podium EVF')).not.toBeNull()
      expect(getByText('Typy zawodów — silnik i współczynnik')).not.toBeNull()
    })

    it('the EVF hint follows the cards', async () => {
      const config: ScoringConfig = {
        ...MOCK_CONFIG,
        engine_code: CLASSIC,
        type_engines: Object.fromEntries(ALL_TYPES.map((tp) => [tp, CLASSIC])),
      }
      const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config, scoringEngines: ENGINES } })
      const hint = () => container.querySelector('[data-field="mp-hint"]')?.textContent
      expect(hint()).toBe('algorytm EVF — każdy typ zawodów')
      await fireEvent.change(typeSelect(container, 'PPW'), { target: { value: JOINED } })
      expect(hint()).toBe('algorytm EVF — każdy typ zawodów; w PPW każda stawka od 4 zawodników')
      await fireEvent.change(typeSelect(container, 'MPW'), { target: { value: JOINED } })
      expect(hint()).toBe('algorytm EVF — każdy typ zawodów; w PPW i MPW każda stawka od 4 zawodników')
    })

    // An engine this build does not know feeds nothing the hint can vouch for,
    // so the hint lists the types it can.
    it('JB27.UI.02 a type on an unknown engine drops out of the EVF hint', async () => {
      const engines = [...ENGINES, { code: 'FUTURE_V1', label: 'Przyszły silnik', module: 'PER_CATEGORY_RENUMBER' }]
      const { container } = render(ScoringConfigEditor, { props: { ...props2026, scoringEngines: engines } })
      await fireEvent.change(typeSelect(container, 'PSW'), { target: { value: 'FUTURE_V1' } })
      expect(container.querySelector('[data-field="mp-hint"]')?.textContent)
        .toBe('algorytm EVF — PPW, MPW, PPS, MPS, PEW, MEW, MSW; w PPW i MPW każda stawka od 4 zawodników')
    })
  })

  // ADM27 (doc/plans/admin-ui-ranking-buckets-and-skeletons-2026-09-28.html,
  // Part 2 · A): the editor refuses the buckets fn_validate_ranking_rules_write
  // refuses on the server, and flags loaded ones the ranking cannot use.
  describe('ADM27 — ranking buckets the ranking can use', () => {
    const VALID: ScoringConfig = {
      ...MOCK_CONFIG,
      ranking_rules: {
        domestic: [{ types: ['PPW'], best: 2 }, { types: ['MPW'], always: true }],
        international: [{ types: ['PEW', 'MEW', 'MSW'], best: 4 }],
      },
    }

    function pool(container: HTMLElement, name: 'domestic' | 'international'): Element {
      return container.querySelector(name === 'domestic' ? '.rules-domestic' : '.rules-international')!
    }

    async function openPicker(container: HTMLElement, name: 'domestic' | 'international'): Promise<HTMLButtonElement[]> {
      await fireEvent.click(pool(container, name).querySelector('.add-bucket-btn')!)
      return Array.from(pool(container, name).querySelectorAll('.picker-type-btn')) as HTMLButtonElement[]
    }

    it('ADM27.RULES.10 each pool\'s picker offers only its own types, PPS and MPS included', async () => {
      const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config: { ...MOCK_CONFIG, ranking_rules: null } } })
      expect((await openPicker(container, 'domestic')).map((b) => b.textContent)).toEqual(['PPW', 'MPW'])
      await fireEvent.click(pool(container, 'domestic').querySelector('.picker-cancel')!)
      expect((await openPicker(container, 'international')).map((b) => b.textContent))
        .toEqual(['PEW', 'MEW', 'MSW', 'PSW', 'PPS', 'MPS'])
    })

    it('ADM27.RULES.10 PPS and MPS carry the PZSz colour in the picker', async () => {
      const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config: { ...MOCK_CONFIG, ranking_rules: null } } })
      const buttons = await openPicker(container, 'international')
      const pps = buttons.find((b) => b.textContent === 'PPS')!
      expect(pps.classList.contains('pzs')).toBe(true)
      expect(pps.classList.contains('international')).toBe(false)
    })

    it('ADM27.RULES.11 a type already in a bucket cannot be picked again', async () => {
      const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config: VALID } })
      const intl = await openPicker(container, 'international')
      const byText = (tp: string) => intl.find((b) => b.textContent === tp)!
      expect(byText('PEW').disabled).toBe(true)
      expect(byText('MSW').disabled).toBe(true)
      expect(byText('PSW').disabled).toBe(false)
      expect(byText('PPS').disabled).toBe(false)
    })

    it('ADM27.RULES.11 "best" cannot go below 1', () => {
      const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, config: VALID } })
      const best = pool(container, 'domestic').querySelector('.bucket-rule input[type="number"]') as HTMLInputElement
      expect(best.min).toBe('1')
    })

    it('ADM27.RULES.12 a loaded bucket the ranking cannot use shows why', () => {
      // MOCK_CONFIG is 2024/25-shaped: its international pool repeats PPW and MPW.
      const { container } = render(ScoringConfigEditor, { props: defaultProps })
      const rows = Array.from(pool(container, 'international').querySelectorAll('.bucket-row'))
      const warning = (row: Element) => row.querySelector('[data-field="bucket-warning"]')?.textContent ?? null
      expect(warning(rows[0])).toContain('PPW')
      expect(warning(rows[0])).toContain('puli międzynarodowej')
      expect(warning(rows[1])).toContain('MPW')
      expect(warning(rows[2])).toBeNull()
      expect(warning(rows[3])).toBeNull()
      expect(pool(container, 'domestic').querySelector('[data-field="bucket-warning"]')).toBeNull()
    })

    it('ADM27.RULES.13 unchanged older-style rules still save', async () => {
      const onsave = vi.fn()
      const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, onsave } })
      await fireEvent.click(container.querySelector('.config-save-btn')!)
      expect(onsave).toHaveBeenCalled()
      expect(container.querySelector('[data-field="rules-error"]')).toBeNull()
    })

    it('ADM27.RULES.13 changed rules that still break a rule are not saved', async () => {
      const onsave = vi.fn()
      const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, onsave } })
      const pewBest = pool(container, 'international').querySelectorAll('.bucket-rule input[type="number"]')[1] as HTMLInputElement
      await fireEvent.change(pewBest, { target: { value: '4' } })
      await fireEvent.click(container.querySelector('.config-save-btn')!)
      expect(onsave).not.toHaveBeenCalled()
      expect(container.querySelector('[data-field="rules-error"]')?.textContent).toContain('Nie zapisano')
    })

    it('ADM27.RULES.13 once the flagged buckets are removed, the change saves', async () => {
      const onsave = vi.fn()
      const { container } = render(ScoringConfigEditor, { props: { ...defaultProps, onsave } })
      const intl = pool(container, 'international')
      await fireEvent.click(intl.querySelectorAll('.remove-bucket-btn')[0])
      await fireEvent.click(intl.querySelectorAll('.remove-bucket-btn')[0])
      await fireEvent.click(container.querySelector('.config-save-btn')!)
      expect(onsave).toHaveBeenCalled()
      const saved = onsave.mock.calls[0][0] as ScoringConfig
      expect(saved.ranking_rules!.international).toEqual([{ types: ['PEW'], best: 3 }, { types: ['MEW'], always: true }])
    })
  })
})
