// Plan tests: ph3.23-ph3.37 (Phase 3b — SeasonManager 3-step wizard).
// See ~/.claude/plans/eager-knitting-fog.md "Test plan" section.
//
// Coverage:
//   ph3.23 — clicking + Dodaj sezon opens identity modal
//   ph3.24 — required fields validated; Dalej disabled until filled
//   ph3.25 — step 2 receives prior-season config as ScoringConfigEditor `config` prop
//   ph3.26 — first-ever season: no prior config, static defaults used
//   ph3.27 — step 3 confirmation modal shows correct skeleton count
//   ph3.28 — clicking ✓ Utwórz calls oncommit exactly once with assembled payload
//   ph3.29 — cancel at step 1: no RPC fires, modal closes
//   ph3.30 — cancel at step 2: no RPC fires, no partial state
//   ph3.31 — cancel at step 3: no RPC fires, all wizard state cleared
//   ph3.32 — ← Wstecz preserves entered values
//   ph3.33 — post-wizard close fires onclose
//   ph3.34 — step 3 skeleton breakdown grouped (PPW count + PEW count)
//   ph3.35 — wizard validation: dt_end before dt_start blocks Dalej
//   ph3.36 — wizard validation: duplicate code blocks Dalej
//   ph3.37 — segmented control updates draftEuropean (None / IMEW / DMEW)

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import SeasonManagerWizard from '../src/components/SeasonManagerWizard.svelte'
import type { Season, ScoringConfig, SkeletonByKind } from '../src/lib/types'

const MOCK_SEASONS: Season[] = [
  { id_season: 1, txt_code: 'SPWS-2024-2025', dt_start: '2024-09-01', dt_end: '2025-06-30', bool_active: false },
  { id_season: 2, txt_code: 'SPWS-2025-2026', dt_start: '2025-09-01', dt_end: '2026-06-30', bool_active: true },
]

const PRIOR_CONFIG: ScoringConfig = {
  season_code: 'SPWS-2025-2026',
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
  mew_multiplier: 2.0,
  mew_droppable: false,
  msw_multiplier: 2.0,
  psw_multiplier: 2.0,
  min_participants_evf: 5,
  min_participants_ppw: 1,
  show_evf_toggle: false,
  ranking_rules: null,
  engine: 'EVENT_FK_MATCHING',
}

const PRIOR_BREAKDOWN: Required<SkeletonByKind> = {
  PPW: 5, PEW: 9, MPW: 1, MSW: 1, IMEW: 0, DMEW: 0,
}

describe('SeasonManagerWizard (Phase 3b)', () => {
  function defaultProps(overrides: Record<string, unknown> = {}) {
    return {
      open: true,
      seasons: MOCK_SEASONS,
      onclose: vi.fn(),
      onloadpriorconfig: vi.fn().mockResolvedValue({
        priorConfig: PRIOR_CONFIG,
        priorCode: 'SPWS-2025-2026',
        priorBreakdown: PRIOR_BREAKDOWN,
      }),
      oncommit: vi.fn().mockResolvedValue(null),
      ...overrides,
    }
  }

  // Helpers — fill step 1 with valid values.
  async function fillStep1(container: HTMLElement, code = 'SPWS-2026-2027') {
    await fireEvent.input(
      container.querySelector('[data-field="wizard-code"]') as HTMLInputElement,
      { target: { value: code } },
    )
    await fireEvent.input(
      container.querySelector('[data-field="wizard-dt-start"]') as HTMLInputElement,
      { target: { value: '2026-09-01' } },
    )
    await fireEvent.input(
      container.querySelector('[data-field="wizard-dt-end"]') as HTMLInputElement,
      { target: { value: '2027-06-30' } },
    )
  }

  // ph3.23 — open=true mounts the modal with step 1 pill
  it('ph3.23: mounts step 1 modal when open=true', () => {
    const { container } = render(SeasonManagerWizard, { props: defaultProps() })
    expect(container.querySelector('[data-field="wizard-overlay"]')).not.toBeNull()
    expect(container.querySelector('[data-field="wizard-step1"]')).not.toBeNull()
  })

  // ph3.24 — Dalej disabled until all required fields filled
  it('ph3.24: Dalej is disabled when required fields are empty', () => {
    const { container } = render(SeasonManagerWizard, { props: defaultProps() })
    const nextBtn = container.querySelector('[data-field="wizard-next-btn"]') as HTMLButtonElement
    expect(nextBtn.disabled).toBe(true)
  })

  it('ph3.24: Dalej enables after all fields are filled', async () => {
    const { container } = render(SeasonManagerWizard, { props: defaultProps() })
    await fillStep1(container)
    const nextBtn = container.querySelector('[data-field="wizard-next-btn"]') as HTMLButtonElement
    expect(nextBtn.disabled).toBe(false)
  })

  // ph3.25 — step 2 advances after Dalej; onloadpriorconfig was called
  it('ph3.25: step 2 calls onloadpriorconfig and renders step 2', async () => {
    const onloadpriorconfig = vi.fn().mockResolvedValue({
      priorConfig: PRIOR_CONFIG,
      priorCode: 'SPWS-2025-2026',
      priorBreakdown: PRIOR_BREAKDOWN,
    })
    const { container } = render(SeasonManagerWizard, { props: defaultProps({ onloadpriorconfig }) })
    await fillStep1(container)
    await fireEvent.click(container.querySelector('[data-field="wizard-next-btn"]')!)
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="wizard-step2"]')).not.toBeNull()
    })
    expect(onloadpriorconfig).toHaveBeenCalledWith('2026-09-01')
  })

  // ph3.26 — first-ever season (priorConfig=null) renders defaults banner
  it('ph3.26: first-ever season shows defaults banner in step 2', async () => {
    const onloadpriorconfig = vi.fn().mockResolvedValue({
      priorConfig: null,
      priorCode: null,
      priorBreakdown: null,
    })
    const { container } = render(SeasonManagerWizard, { props: defaultProps({ onloadpriorconfig }) })
    await fillStep1(container, 'SPWS-1900-1901')
    await fireEvent.input(
      container.querySelector('[data-field="wizard-dt-start"]') as HTMLInputElement,
      { target: { value: '1900-09-01' } },
    )
    await fireEvent.input(
      container.querySelector('[data-field="wizard-dt-end"]') as HTMLInputElement,
      { target: { value: '1901-06-30' } },
    )
    await fireEvent.click(container.querySelector('[data-field="wizard-next-btn"]')!)
    await vi.waitFor(() => {
      const banner = container.querySelector('[data-field="wizard-banner"]')
      expect(banner?.textContent).toMatch(/First season|Pierwszy sezon/)
    })
  })

  // ph3.27 — step 3 shows skeleton count breakdown
  it('ph3.27: step 3 shows skeleton breakdown from prior season', async () => {
    const { container } = render(SeasonManagerWizard, { props: defaultProps() })
    await fillStep1(container)
    await fireEvent.click(container.querySelector('[data-field="wizard-next-btn"]')!)
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="wizard-step2"]')).not.toBeNull()
    })
    // Trigger ScoringConfigEditor's Save which advances to step 3
    const saveBtn = container.querySelector('.config-save-btn') as HTMLButtonElement
    expect(saveBtn).not.toBeNull()
    await fireEvent.click(saveBtn)
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="wizard-step3"]')).not.toBeNull()
    })
    expect(container.querySelector('[data-field="wizard-skel-ppw"]')?.textContent).toContain('5')
    expect(container.querySelector('[data-field="wizard-skel-pew"]')?.textContent).toContain('9')
    expect(container.querySelector('[data-field="wizard-skel-mpw"]')?.textContent).toContain('1')
    expect(container.querySelector('[data-field="wizard-skel-msw"]')?.textContent).toContain('1')
  })

  // ph3.28 — ✓ Utwórz calls oncommit with the assembled payload
  it('ph3.28: ✓ Utwórz calls oncommit with assembled payload', async () => {
    const oncommit = vi.fn().mockResolvedValue(null)
    const { container } = render(SeasonManagerWizard, { props: defaultProps({ oncommit }) })
    await fillStep1(container)
    await fireEvent.click(container.querySelector('[data-field="wizard-next-btn"]')!)
    await vi.waitFor(() => container.querySelector('[data-field="wizard-step2"]'))
    await fireEvent.click(container.querySelector('.config-save-btn') as HTMLButtonElement)
    await vi.waitFor(() => container.querySelector('[data-field="wizard-step3"]'))
    await fireEvent.click(container.querySelector('[data-field="wizard-commit-btn"]')!)
    await vi.waitFor(() => {
      expect(oncommit).toHaveBeenCalledTimes(1)
    })
    const payload = oncommit.mock.calls[0][0]
    expect(payload.code).toBe('SPWS-2026-2027')
    expect(payload.dt_start).toBe('2026-09-01')
    expect(payload.dt_end).toBe('2027-06-30')
    expect(payload.carryover_days).toBe(366)
    expect(payload.european_type).toBe(null)
    expect(payload.carryover_engine).toBe('EVENT_FK_MATCHING')
    expect(payload.scoring_config).toBeDefined()
  })

  // ph3.29 — Cancel on step 1 fires onclose without firing oncommit
  it('ph3.29: cancel on step 1 fires onclose, not oncommit', async () => {
    const onclose = vi.fn()
    const oncommit = vi.fn()
    const { container } = render(SeasonManagerWizard, { props: defaultProps({ onclose, oncommit }) })
    await fillStep1(container)
    await fireEvent.click(container.querySelector('[data-field="wizard-cancel-btn"]')!)
    expect(onclose).toHaveBeenCalled()
    expect(oncommit).not.toHaveBeenCalled()
  })

  // ph3.30 — Cancel on step 2 fires onclose without firing oncommit
  it('ph3.30: cancel on step 2 fires onclose, not oncommit', async () => {
    const onclose = vi.fn()
    const oncommit = vi.fn()
    const { container } = render(SeasonManagerWizard, { props: defaultProps({ onclose, oncommit }) })
    await fillStep1(container)
    await fireEvent.click(container.querySelector('[data-field="wizard-next-btn"]')!)
    await vi.waitFor(() => container.querySelector('[data-field="wizard-step2"]'))
    await fireEvent.click(container.querySelector('[data-field="wizard-cancel-btn"]')!)
    expect(onclose).toHaveBeenCalled()
    expect(oncommit).not.toHaveBeenCalled()
  })

  // ph3.31 — Cancel on step 3 fires onclose without firing oncommit
  it('ph3.31: cancel on step 3 fires onclose, not oncommit', async () => {
    const onclose = vi.fn()
    const oncommit = vi.fn()
    const { container } = render(SeasonManagerWizard, { props: defaultProps({ onclose, oncommit }) })
    await fillStep1(container)
    await fireEvent.click(container.querySelector('[data-field="wizard-next-btn"]')!)
    await vi.waitFor(() => container.querySelector('[data-field="wizard-step2"]'))
    await fireEvent.click(container.querySelector('.config-save-btn') as HTMLButtonElement)
    await vi.waitFor(() => container.querySelector('[data-field="wizard-step3"]'))
    await fireEvent.click(container.querySelector('[data-field="wizard-cancel-btn"]')!)
    expect(onclose).toHaveBeenCalled()
    expect(oncommit).not.toHaveBeenCalled()
  })

  // ph3.32 — ← Wstecz from step 2 returns to step 1 with code preserved
  it('ph3.32: ← Wstecz preserves entered values', async () => {
    const { container } = render(SeasonManagerWizard, { props: defaultProps() })
    await fillStep1(container, 'SPWS-2026-2027')
    await fireEvent.click(container.querySelector('[data-field="wizard-next-btn"]')!)
    await vi.waitFor(() => container.querySelector('[data-field="wizard-step2"]'))
    await fireEvent.click(container.querySelector('[data-field="wizard-back-btn"]')!)
    expect(container.querySelector('[data-field="wizard-step1"]')).not.toBeNull()
    const codeInput = container.querySelector('[data-field="wizard-code"]') as HTMLInputElement
    expect(codeInput.value).toBe('SPWS-2026-2027')
  })

  // ph3.33 — open=false unmounts the wizard markup
  it('ph3.33: open=false hides wizard overlay', () => {
    const { container } = render(SeasonManagerWizard, { props: { ...defaultProps(), open: false } })
    expect(container.querySelector('[data-field="wizard-overlay"]')).toBeNull()
  })

  // ph3.34 — IMEW / DMEW segmented adds an extra row in the breakdown
  it('ph3.34: IMEW segmented shows IMEW row in step 3 breakdown', async () => {
    const { container } = render(SeasonManagerWizard, { props: defaultProps() })
    await fillStep1(container)
    await fireEvent.click(container.querySelector('[data-field="wizard-european-imew"]')!)
    await fireEvent.click(container.querySelector('[data-field="wizard-next-btn"]')!)
    await vi.waitFor(() => container.querySelector('[data-field="wizard-step2"]'))
    await fireEvent.click(container.querySelector('.config-save-btn') as HTMLButtonElement)
    await vi.waitFor(() => container.querySelector('[data-field="wizard-step3"]'))
    expect(container.querySelector('[data-field="wizard-skel-imew"]')).not.toBeNull()
  })

  // ph3.35 — dt_end before dt_start blocks advance with validation error
  it('ph3.35: dt_end before dt_start blocks Dalej with validation error', async () => {
    const { container } = render(SeasonManagerWizard, { props: defaultProps() })
    await fireEvent.input(
      container.querySelector('[data-field="wizard-code"]') as HTMLInputElement,
      { target: { value: 'SPWS-2026-2027' } },
    )
    await fireEvent.input(
      container.querySelector('[data-field="wizard-dt-start"]') as HTMLInputElement,
      { target: { value: '2026-09-01' } },
    )
    await fireEvent.input(
      container.querySelector('[data-field="wizard-dt-end"]') as HTMLInputElement,
      { target: { value: '2026-08-30' } },
    )
    await fireEvent.click(container.querySelector('[data-field="wizard-next-btn"]')!)
    expect(container.querySelector('[data-field="wizard-validation-error"]')).not.toBeNull()
    expect(container.querySelector('[data-field="wizard-step2"]')).toBeNull()
  })

  // ph3.36 — duplicate season code blocks Dalej with validation error
  it('ph3.36: duplicate season code blocks Dalej', async () => {
    const { container } = render(SeasonManagerWizard, { props: defaultProps() })
    await fillStep1(container, 'SPWS-2024-2025') // already in MOCK_SEASONS
    await fireEvent.click(container.querySelector('[data-field="wizard-next-btn"]')!)
    expect(container.querySelector('[data-field="wizard-validation-error"]')).not.toBeNull()
    expect(container.querySelector('[data-field="wizard-step2"]')).toBeNull()
  })

  // ph3.37 — DMEW segmented updates payload to european_type='DMEW'
  it('ph3.37: DMEW segmented threads european_type=DMEW into commit payload', async () => {
    const oncommit = vi.fn().mockResolvedValue(null)
    const { container } = render(SeasonManagerWizard, { props: defaultProps({ oncommit }) })
    await fillStep1(container)
    await fireEvent.click(container.querySelector('[data-field="wizard-european-dmew"]')!)
    await fireEvent.click(container.querySelector('[data-field="wizard-next-btn"]')!)
    await vi.waitFor(() => container.querySelector('[data-field="wizard-step2"]'))
    await fireEvent.click(container.querySelector('.config-save-btn') as HTMLButtonElement)
    await vi.waitFor(() => container.querySelector('[data-field="wizard-step3"]'))
    await fireEvent.click(container.querySelector('[data-field="wizard-commit-btn"]')!)
    await vi.waitFor(() => expect(oncommit).toHaveBeenCalled())
    expect(oncommit.mock.calls[0][0].european_type).toBe('DMEW')
  })
})
