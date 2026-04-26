// Plan tests: 9.37, 9.38, 9.39, 9.40, 9.41, 9.42, 9.43, 8.81, 8.82, 8.83
// See .claude/plans/rosy-bouncing-kitten.md §T9.2.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import SeasonManager from '../src/components/SeasonManager.svelte'
import type { Season } from '../src/lib/types'

const MOCK_SEASONS: Season[] = [
  { id_season: 1, txt_code: 'SPWS-2024-2025', dt_start: '2024-09-01', dt_end: '2025-06-30', bool_active: true },
  { id_season: 2, txt_code: 'SPWS-2023-2024', dt_start: '2023-09-01', dt_end: '2024-06-30', bool_active: false },
]

describe('SeasonManager (T9.2)', () => {
  const defaultProps = {
    seasons: MOCK_SEASONS,
    isAdmin: true,
    oncreate: vi.fn(),
    onupdate: vi.fn(),
    ondelete: vi.fn(),
    onfetchevf: vi.fn().mockResolvedValue(false),
  }

  // 9.37 — Renders season list with txt_code, dt_start, dt_end
  it('renders season list with txt_code, dt_start, dt_end', () => {
    const { container } = render(SeasonManager, { props: defaultProps })
    const rows = container.querySelectorAll('[data-field="season-row"]')
    expect(rows.length).toBe(2)

    const firstRow = rows[0]
    expect(firstRow.querySelector('[data-field="season-code"]')!.textContent).toContain('SPWS-2024-2025')
    expect(firstRow.querySelector('[data-field="season-start"]')!.textContent).toContain('2024-09-01')
    expect(firstRow.querySelector('[data-field="season-end"]')!.textContent).toContain('2025-06-30')
  })

  // 9.38 — "+ Dodaj sezon" opens the wizard (Phase 3 architectural change
  // per plan: inline create form replaced by 3-step wizard. Create flow itself
  // is exercised in tests/SeasonManagerWizard.test.ts ph3.23–ph3.32.)
  it('opens wizard modal when add button clicked', async () => {
    const { container } = render(SeasonManager, { props: defaultProps })
    const addBtn = container.querySelector('[data-field="add-season-btn"]')
    expect(addBtn).not.toBeNull()

    // Wizard not open initially
    expect(container.querySelector('[data-field="wizard-overlay"]')).toBeNull()

    await fireEvent.click(addBtn!)
    expect(container.querySelector('[data-field="wizard-overlay"]')).not.toBeNull()
  })

  // 9.39 — Wizard renders step 1 with empty inputs (smoke; full state-machine
  // coverage lives in tests/SeasonManagerWizard.test.ts).
  it('wizard step 1 renders with empty code input', async () => {
    const { container } = render(SeasonManager, { props: defaultProps })
    await fireEvent.click(container.querySelector('[data-field="add-season-btn"]')!)
    const codeInput = container.querySelector('[data-field="wizard-code"]') as HTMLInputElement
    expect(codeInput).not.toBeNull()
    expect(codeInput.value).toBe('')
  })

  // 9.40 — Edit button opens form with pre-filled values
  it('opens form pre-filled with season values on edit', async () => {
    const onfetchevf = vi.fn().mockResolvedValue(false)
    const { container } = render(SeasonManager, { props: { ...defaultProps, onfetchevf } })
    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    expect(editBtns.length).toBe(2)

    await fireEvent.click(editBtns[0])
    // Wait for async onfetchevf to resolve
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="season-form"]')).not.toBeNull()
    })

    const form = container.querySelector('[data-field="season-form"]')!
    const codeInput = form.querySelector('[data-field="form-code"]') as HTMLInputElement
    const startInput = form.querySelector('[data-field="form-start"]') as HTMLInputElement
    const endInput = form.querySelector('[data-field="form-end"]') as HTMLInputElement

    expect(codeInput.value).toBe('SPWS-2024-2025')
    expect(startInput.value).toBe('2024-09-01')
    expect(endInput.value).toBe('2025-06-30')
    expect(onfetchevf).toHaveBeenCalledWith(1)
  })

  // 9.41 — Delete calls ondelete with season id
  it('calls ondelete with season id on delete', async () => {
    const ondelete = vi.fn()
    const { container } = render(SeasonManager, { props: { ...defaultProps, ondelete } })
    const deleteBtns = container.querySelectorAll('[data-field="delete-btn"]')
    expect(deleteBtns.length).toBe(2)

    await fireEvent.click(deleteBtns[1])
    expect(ondelete).toHaveBeenCalledWith(2)
  })

  // 9.42 — Only visible when isAdmin=true
  it('renders nothing when isAdmin is false', () => {
    const { container } = render(SeasonManager, { props: { ...defaultProps, isAdmin: false } })
    expect(container.querySelector('[data-field="season-list"]')).toBeNull()
    expect(container.querySelector('[data-field="add-season-btn"]')).toBeNull()
  })

  // 8.81 — EVF checkbox renders in EDIT form (the wizard handles create with
  // its own EVF toggle; this test now scopes to the edit-flow checkbox).
  it('shows EVF checkbox in edit form', async () => {
    const onfetchevf = vi.fn().mockResolvedValue(false)
    const { container } = render(SeasonManager, { props: { ...defaultProps, onfetchevf } })

    // Open EDIT form — checkbox appears
    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    await fireEvent.click(editBtns[0])
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="form-evf-toggle"]')).not.toBeNull()
    })

    const checkbox = container.querySelector('[data-field="form-evf-toggle"]') as HTMLInputElement
    expect(checkbox.checked).toBe(false)
  })

  // 8.82 — EVF checkbox reflects true when onfetchevf returns true
  it('EVF checkbox checked when onfetchevf returns true', async () => {
    const onfetchevf = vi.fn().mockResolvedValue(true)
    const { container } = render(SeasonManager, { props: { ...defaultProps, onfetchevf } })

    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    await fireEvent.click(editBtns[0])
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="form-evf-toggle"]')).not.toBeNull()
    })

    const checkbox = container.querySelector('[data-field="form-evf-toggle"]') as HTMLInputElement
    expect(checkbox.checked).toBe(true)
  })

  // 9.43 — Edit form renders inline above the edited season row
  it('edit form appears directly above the edited season row', async () => {
    const onfetchevf = vi.fn().mockResolvedValue(false)
    const { container } = render(SeasonManager, { props: { ...defaultProps, onfetchevf } })

    // Click edit on the SECOND season
    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    await fireEvent.click(editBtns[1])
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="season-form"]')).not.toBeNull()
    })

    // Form should be inside the second season-card, not the first
    const cards = container.querySelectorAll('[data-field="season-card"]')
    expect(cards.length).toBe(2)
    expect(cards[0].querySelector('[data-field="season-form"]')).toBeNull()
    expect(cards[1].querySelector('[data-field="season-form"]')).not.toBeNull()
  })

  // 8.83 — Saving edit form calls onupdate with showEvf param
  it('calls onupdate with showEvf=true after toggling checkbox', async () => {
    const onfetchevf = vi.fn().mockResolvedValue(false)
    const onupdate = vi.fn()
    const { container } = render(SeasonManager, { props: { ...defaultProps, onfetchevf, onupdate } })

    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    await fireEvent.click(editBtns[0])
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="form-evf-toggle"]')).not.toBeNull()
    })

    // Toggle checkbox on
    const checkbox = container.querySelector('[data-field="form-evf-toggle"]') as HTMLInputElement
    await fireEvent.click(checkbox)
    expect(checkbox.checked).toBe(true)

    // Save
    await fireEvent.click(container.querySelector('[data-field="form-save-btn"]')!)
    // Phase 3 (ADR-044): onupdate signature now takes 7 args — the trailing
    // (carryoverDays, europeanType) come from the new EDIT form fields and
    // default to (366, null) when the season has no Phase-3 data yet.
    expect(onupdate).toHaveBeenCalledWith(1, 'SPWS-2024-2025', '2024-09-01', '2025-06-30', true, 366, null)
  })

  // ========================================================================
  // Phase 3 (ph3.37f, ph3.37g) — 🎯 Konfiguracja punktacji button visibility
  // Past-complete (dt_end < today) seasons hide the button entirely (ADR-045).
  // Future + active seasons render it as today.
  // ========================================================================

  // ph3.37f — past-complete season hides 🎯 button on EDIT
  it('ph3.37f: past-complete season hides the scoring config button', async () => {
    // Build a season that ended yesterday (definitely "past-complete")
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().slice(0, 10)
    const pastSeason: Season = {
      id_season: 99,
      txt_code: 'SPWS-PAST',
      dt_start: '2020-01-01',
      dt_end: yesterday,
      bool_active: false,
    }
    const onfetchevf = vi.fn().mockResolvedValue(false)
    const { container } = render(SeasonManager, {
      props: { ...defaultProps, seasons: [pastSeason], onfetchevf },
    })

    const editBtn = container.querySelector('[data-field="edit-btn"]') as HTMLButtonElement
    await fireEvent.click(editBtn)
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="season-form"]')).not.toBeNull()
    })

    // Button must NOT be in the DOM
    expect(container.querySelector('[data-field="scoring-btn"]')).toBeNull()
  })

  // ph3.37g — future + active seasons render the 🎯 button
  it('ph3.37g: future season renders the scoring config button', async () => {
    // Build a season that ends 30 days from now (definitely "future")
    const future = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10)
    const futureSeason: Season = {
      id_season: 100,
      txt_code: 'SPWS-FUTURE',
      dt_start: '2099-01-01',
      dt_end: future,
      bool_active: false,
    }
    const onfetchevf = vi.fn().mockResolvedValue(false)
    const { container } = render(SeasonManager, {
      props: { ...defaultProps, seasons: [futureSeason], onfetchevf },
    })

    const editBtn = container.querySelector('[data-field="edit-btn"]') as HTMLButtonElement
    await fireEvent.click(editBtn)
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="season-form"]')).not.toBeNull()
    })

    // Button must be in the DOM
    expect(container.querySelector('[data-field="scoring-btn"]')).not.toBeNull()
  })
})
