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
    onfetchevf: vi.fn().mockResolvedValue({ ranklist: false, calendar: true }),
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

  // 9.39 — Wizard renders step 1 (smoke; full state-machine coverage lives in
  // tests/SeasonManagerWizard.test.ts). Part 4 (ADR-044): the wizard now pre-fills
  // the suggested next season, so the code input opens populated (latest of
  // MOCK_SEASONS is SPWS-2024-2025 → SPWS-2025-2026), not blank.
  it('wizard step 1 renders with the suggested next-season code', async () => {
    const { container } = render(SeasonManager, { props: defaultProps })
    await fireEvent.click(container.querySelector('[data-field="add-season-btn"]')!)
    const codeInput = container.querySelector('[data-field="wizard-code"]') as HTMLInputElement
    expect(codeInput).not.toBeNull()
    expect(codeInput.value).toBe('SPWS-2025-2026')
  })

  // 9.40 — Edit button opens form with pre-filled values
  it('opens form pre-filled with season values on edit', async () => {
    const onfetchevf = vi.fn().mockResolvedValue({ ranklist: false, calendar: true })
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
    const onfetchevf = vi.fn().mockResolvedValue({ ranklist: false, calendar: true })
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

  // Part 1 (ADR-044 amend) — the EDIT form renders a SECOND, independent
  // Calendar +EVF checkbox; it reflects the fetched calendar flag (default ON).
  it('shows an independent Calendar EVF checkbox in the edit form', async () => {
    const onfetchevf = vi.fn().mockResolvedValue({ ranklist: false, calendar: true })
    const { container } = render(SeasonManager, { props: { ...defaultProps, onfetchevf } })
    await fireEvent.click(container.querySelectorAll('[data-field="edit-btn"]')[0])
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="form-evf-toggle-calendar"]')).not.toBeNull()
    })
    const ranklist = container.querySelector('[data-field="form-evf-toggle"]') as HTMLInputElement
    const calendar = container.querySelector('[data-field="form-evf-toggle-calendar"]') as HTMLInputElement
    expect(ranklist.checked).toBe(false)
    expect(calendar.checked).toBe(true)
  })

  // 8.82 — EVF checkbox reflects true when onfetchevf returns true
  it('EVF checkbox checked when onfetchevf returns true', async () => {
    const onfetchevf = vi.fn().mockResolvedValue({ ranklist: true, calendar: true })
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
    const onfetchevf = vi.fn().mockResolvedValue({ ranklist: false, calendar: true })
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
    const onfetchevf = vi.fn().mockResolvedValue({ ranklist: false, calendar: true })
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
    // Part 1 (ADR-044 amend): onupdate now carries BOTH evf flags — ranklist
    // (just toggled on) and calendar (fetched TRUE) — before europeanType.
    expect(onupdate).toHaveBeenCalledWith(1, 'SPWS-2024-2025', '2024-09-01', '2025-06-30', true, true, null)
  })

  // Part 1 (ADR-044 amend) — the two EVF checkboxes are independent: toggling
  // the Calendar flag off while leaving Ranklist on threads (false_ranklist…,
  // true_ranklist, false_calendar) into onupdate.
  it('threads both evf flags independently into onupdate', async () => {
    const onfetchevf = vi.fn().mockResolvedValue({ ranklist: false, calendar: true })
    const onupdate = vi.fn()
    const { container } = render(SeasonManager, { props: { ...defaultProps, onfetchevf, onupdate } })
    await fireEvent.click(container.querySelectorAll('[data-field="edit-btn"]')[0])
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="form-evf-toggle-calendar"]')).not.toBeNull()
    })
    // Turn Ranklist ON, turn Calendar OFF
    await fireEvent.click(container.querySelector('[data-field="form-evf-toggle"]') as HTMLInputElement)
    await fireEvent.click(container.querySelector('[data-field="form-evf-toggle-calendar"]') as HTMLInputElement)
    await fireEvent.click(container.querySelector('[data-field="form-save-btn"]')!)
    expect(onupdate).toHaveBeenCalledWith(1, 'SPWS-2024-2025', '2024-09-01', '2025-06-30', true, false, null)
  })

  // ========================================================================
  // Part 2 (ADR-044 amend) — carry-over section cleanup
  // ========================================================================

  // Carry-over section header is a locale key ("Punktacja ciągła"), not the
  // old hardcoded "🔁 Carry-over" literal.
  it('renders the carry-over section header from a locale key', async () => {
    const onfetchevf = vi.fn().mockResolvedValue({ ranklist: false, calendar: true })
    const { container } = render(SeasonManager, { props: { ...defaultProps, onfetchevf } })
    await fireEvent.click(container.querySelectorAll('[data-field="edit-btn"]')[0])
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="carryover-section-header"]')).not.toBeNull()
    })
    const header = container.querySelector('[data-field="carryover-section-header"]')!
    expect(header.textContent).toContain('Punktacja ciągła')
  })

  // The carry-over-days control is gone (feeds only the inactive engine).
  it('does not render the carry-over days control in the edit form', async () => {
    const onfetchevf = vi.fn().mockResolvedValue({ ranklist: false, calendar: true })
    const { container } = render(SeasonManager, { props: { ...defaultProps, onfetchevf } })
    await fireEvent.click(container.querySelectorAll('[data-field="edit-btn"]')[0])
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="season-form"]')).not.toBeNull()
    })
    expect(container.querySelector('[data-field="form-carryover-days"]')).toBeNull()
    expect(container.querySelector('[data-field="carryover-days-label"]')).toBeNull()
  })

  // European-event choice round-trips: a season carrying enum_european_event_type
  // pre-selects the matching segment on edit (read-path fix verified at api layer).
  it('pre-selects the European segment from the season value', async () => {
    const onfetchevf = vi.fn().mockResolvedValue({ ranklist: false, calendar: true })
    const seasonWithEuropean: Season = { ...MOCK_SEASONS[0], enum_european_event_type: 'IMEW' }
    const { container } = render(SeasonManager, {
      props: { ...defaultProps, seasons: [seasonWithEuropean], onfetchevf },
    })
    await fireEvent.click(container.querySelector('[data-field="edit-btn"]')!)
    await vi.waitFor(() => {
      expect(container.querySelector('[data-field="form-european-imew"]')).not.toBeNull()
    })
    expect(container.querySelector('[data-field="form-european-imew"]')!.classList.contains('active')).toBe(true)
    expect(container.querySelector('[data-field="form-european-none"]')!.classList.contains('active')).toBe(false)
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
    const onfetchevf = vi.fn().mockResolvedValue({ ranklist: false, calendar: true })
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
    const onfetchevf = vi.fn().mockResolvedValue({ ranklist: false, calendar: true })
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

  // ===========================================================================
  // ADR-077 §7 — CERT→PROD season-skeleton promotion button (state-derived)
  // ===========================================================================

  // B3.1 — single-env: no promote control at all
  it('B3.1: no promote control when not dualEnv', () => {
    const { container } = render(SeasonManager, {
      props: { ...defaultProps, dualEnv: false, promotionByCode: { 'SPWS-2024-2025': 'promotable' } },
    })
    expect(container.querySelector('[data-field="promote-season-btn"]')).toBeNull()
    expect(container.querySelector('[data-field="remove-from-prod-btn"]')).toBeNull()
  })

  // B3.2 — promotable (not on PROD, childless): active ⬆ button → onpromote(code)
  it('B3.2: promotable season shows active Promote button and fires onpromote', async () => {
    const onpromote = vi.fn()
    const { container } = render(SeasonManager, {
      props: {
        ...defaultProps, dualEnv: true, onpromote,
        promotionByCode: { 'SPWS-2024-2025': 'promotable', 'SPWS-2023-2024': 'promotable' },
      },
    })
    const btn = container.querySelector('[data-field="promote-season-btn"]') as HTMLButtonElement
    expect(btn).not.toBeNull()
    expect(btn.disabled).toBe(false)
    await fireEvent.click(btn)
    expect(onpromote).toHaveBeenCalledWith('SPWS-2024-2025')
  })

  // B3.3 — on PROD: ✓ badge + Remove button → onremovefromprod(code)
  it('B3.3: on-PROD season shows badge + Remove button and fires onremovefromprod', async () => {
    const onremovefromprod = vi.fn()
    const { container } = render(SeasonManager, {
      props: {
        ...defaultProps, dualEnv: true, onremovefromprod,
        promotionByCode: { 'SPWS-2024-2025': 'on_prod', 'SPWS-2023-2024': 'on_prod' },
      },
    })
    expect(container.querySelector('[data-field="on-prod-badge"]')).not.toBeNull()
    const rm = container.querySelector('[data-field="remove-from-prod-btn"]') as HTMLButtonElement
    expect(rm).not.toBeNull()
    await fireEvent.click(rm)
    expect(onremovefromprod).toHaveBeenCalledWith('SPWS-2024-2025')
  })

  // B3.4 — has children: disabled button + hint, never promotable
  it('B3.4: season with tournament children shows a disabled button + hint', () => {
    const { container } = render(SeasonManager, {
      props: {
        ...defaultProps, dualEnv: true,
        promotionByCode: { 'SPWS-2024-2025': 'has_children', 'SPWS-2023-2024': 'has_children' },
      },
    })
    const btn = container.querySelector('[data-field="promote-season-btn"]') as HTMLButtonElement
    expect(btn).not.toBeNull()
    expect(btn.disabled).toBe(true)
    expect(container.querySelector('[data-field="promote-disabled-hint"]')).not.toBeNull()
  })
})
