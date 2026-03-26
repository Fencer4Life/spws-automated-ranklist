// Plan tests: 9.37, 9.38, 9.39, 9.40, 9.41, 9.42
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

  // 9.38 — "+ Dodaj sezon" opens create form
  it('opens create form when add button clicked', async () => {
    const { container } = render(SeasonManager, { props: defaultProps })
    const addBtn = container.querySelector('[data-field="add-season-btn"]')
    expect(addBtn).not.toBeNull()

    // Form should not be visible initially
    expect(container.querySelector('[data-field="season-form"]')).toBeNull()

    await fireEvent.click(addBtn!)
    const form = container.querySelector('[data-field="season-form"]')
    expect(form).not.toBeNull()

    // Form inputs should be empty for create
    const codeInput = form!.querySelector('[data-field="form-code"]') as HTMLInputElement
    expect(codeInput.value).toBe('')
  })

  // 9.39 — Create form submits txt_code, dt_start, dt_end
  it('calls oncreate with form values on save', async () => {
    const oncreate = vi.fn()
    const { container } = render(SeasonManager, { props: { ...defaultProps, oncreate } })

    await fireEvent.click(container.querySelector('[data-field="add-season-btn"]')!)

    const form = container.querySelector('[data-field="season-form"]')!
    const codeInput = form.querySelector('[data-field="form-code"]') as HTMLInputElement
    const startInput = form.querySelector('[data-field="form-start"]') as HTMLInputElement
    const endInput = form.querySelector('[data-field="form-end"]') as HTMLInputElement

    await fireEvent.input(codeInput, { target: { value: 'NEW-SEASON' } })
    await fireEvent.input(startInput, { target: { value: '2025-09-01' } })
    await fireEvent.input(endInput, { target: { value: '2026-06-30' } })

    await fireEvent.click(form.querySelector('[data-field="form-save-btn"]')!)
    expect(oncreate).toHaveBeenCalledWith('NEW-SEASON', '2025-09-01', '2026-06-30')
  })

  // 9.40 — Edit button opens form with pre-filled values
  it('opens form pre-filled with season values on edit', async () => {
    const { container } = render(SeasonManager, { props: defaultProps })
    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    expect(editBtns.length).toBe(2)

    await fireEvent.click(editBtns[0])

    const form = container.querySelector('[data-field="season-form"]')
    expect(form).not.toBeNull()

    const codeInput = form!.querySelector('[data-field="form-code"]') as HTMLInputElement
    const startInput = form!.querySelector('[data-field="form-start"]') as HTMLInputElement
    const endInput = form!.querySelector('[data-field="form-end"]') as HTMLInputElement

    expect(codeInput.value).toBe('SPWS-2024-2025')
    expect(startInput.value).toBe('2024-09-01')
    expect(endInput.value).toBe('2025-06-30')
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
})
