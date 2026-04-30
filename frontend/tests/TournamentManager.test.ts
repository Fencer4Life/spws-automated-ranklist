// Plan tests: 9.50, 9.51, 9.52, 9.53, 9.54, 9.55
// See .claude/plans/rosy-bouncing-kitten.md §T9.4.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import TournamentManager from '../src/components/TournamentManager.svelte'
import type { Tournament } from '../src/lib/types'

const MOCK_TOURNAMENTS: Tournament[] = [
  {
    id_tournament: 100,
    id_event: 10,
    txt_code: 'PPW-WRO-2025-01-ME-V2',
    txt_name: 'PPW Wrocław Szpada M V2',
    enum_type: 'PPW',
    enum_weapon: 'EPEE',
    enum_gender: 'M',
    enum_age_category: 'V2',
    dt_tournament: '2025-01-15',
    int_participant_count: 24,
    num_multiplier: 1.0,
    url_results: 'https://example.com/results/100',
    enum_import_status: 'SCORED',
    txt_import_status_reason: null,
  },
  {
    id_tournament: 101,
    id_event: 10,
    txt_code: 'PPW-WRO-2025-01-FE-V1',
    txt_name: 'PPW Wrocław Szpada F V1',
    enum_type: 'PPW',
    enum_weapon: 'EPEE',
    enum_gender: 'F',
    enum_age_category: 'V1',
    dt_tournament: '2025-01-15',
    int_participant_count: 12,
    num_multiplier: 1.0,
    url_results: null,
    enum_import_status: 'PLANNED',
    txt_import_status_reason: null,
  },
  {
    id_tournament: 102,
    id_event: 10,
    txt_code: 'PPW-WRO-2025-01-MS-V3',
    txt_name: null,
    enum_type: 'PPW',
    enum_weapon: 'SABRE',
    enum_gender: 'M',
    enum_age_category: 'V3',
    dt_tournament: null,
    int_participant_count: null,
    num_multiplier: 1.0,
    url_results: null,
    enum_import_status: 'PENDING',
    txt_import_status_reason: null,
  },
]

describe('TournamentManager (T9.4)', () => {
  const defaultProps = {
    tournaments: MOCK_TOURNAMENTS,
    eventId: 10,
    isAdmin: true,
    oncreate: vi.fn(),
    onupdate: vi.fn(),
    ondelete: vi.fn(),
  }

  // 9.50 — Renders tournaments with code, type badge, weapon, age category
  it('renders tournaments with code, type badge, weapon, age category', () => {
    const { container } = render(TournamentManager, { props: defaultProps })
    const rows = container.querySelectorAll('[data-field="tournament-row"]')
    expect(rows.length).toBe(3)

    const firstRow = rows[0]
    expect(firstRow.querySelector('[data-field="tournament-code"]')!.textContent).toContain('PPW-WRO-2025-01-ME-V2')
    expect(firstRow.querySelector('[data-field="tournament-type"]')!.textContent).toContain('PPW')
    expect(firstRow.querySelector('[data-field="tournament-weapon"]')!.textContent).toContain('EPEE')
    expect(firstRow.querySelector('[data-field="tournament-category"]')!.textContent).toContain('V2')
  })

  // 9.51 — "+ Dodaj turniej" opens form with weapon/gender/age/type selects
  it('opens create form with enum selects when add button clicked', async () => {
    const { container } = render(TournamentManager, { props: defaultProps })
    expect(container.querySelector('[data-field="tournament-form"]')).toBeNull()

    const addBtn = container.querySelector('[data-field="add-tournament-btn"]')!
    await fireEvent.click(addBtn)

    const form = container.querySelector('[data-field="tournament-form"]')
    expect(form).not.toBeNull()

    // Must have all enum selects
    expect(form!.querySelector('[data-field="form-type"]')).not.toBeNull()
    expect(form!.querySelector('[data-field="form-weapon"]')).not.toBeNull()
    expect(form!.querySelector('[data-field="form-gender"]')).not.toBeNull()
    expect(form!.querySelector('[data-field="form-age-category"]')).not.toBeNull()
    expect(form!.querySelector('[data-field="form-code"]')).not.toBeNull()
    expect(form!.querySelector('[data-field="form-name"]')).not.toBeNull()
  })

  // 9.52 — Create form submits and calls oncreate with all params
  it('create form calls oncreate with all params on save', async () => {
    const oncreate = vi.fn()
    const { container } = render(TournamentManager, { props: { ...defaultProps, oncreate } })
    await fireEvent.click(container.querySelector('[data-field="add-tournament-btn"]')!)

    const form = container.querySelector('[data-field="tournament-form"]')!
    const codeInput = form.querySelector('[data-field="form-code"]') as HTMLInputElement
    const nameInput = form.querySelector('[data-field="form-name"]') as HTMLInputElement
    const typeSelect = form.querySelector('[data-field="form-type"]') as HTMLSelectElement
    const weaponSelect = form.querySelector('[data-field="form-weapon"]') as HTMLSelectElement
    const genderSelect = form.querySelector('[data-field="form-gender"]') as HTMLSelectElement
    const categorySelect = form.querySelector('[data-field="form-age-category"]') as HTMLSelectElement

    await fireEvent.input(codeInput, { target: { value: 'PPW-NEW-01' } })
    await fireEvent.input(nameInput, { target: { value: 'New Tournament' } })
    await fireEvent.change(typeSelect, { target: { value: 'PPW' } })
    await fireEvent.change(weaponSelect, { target: { value: 'FOIL' } })
    await fireEvent.change(genderSelect, { target: { value: 'F' } })
    await fireEvent.change(categorySelect, { target: { value: 'V1' } })

    await fireEvent.click(form.querySelector('[data-field="form-save-btn"]')!)

    expect(oncreate).toHaveBeenCalledTimes(1)
    const params = oncreate.mock.calls[0][0]
    expect(params.code).toBe('PPW-NEW-01')
    expect(params.name).toBe('New Tournament')
    expect(params.type).toBe('PPW')
    expect(params.weapon).toBe('FOIL')
    expect(params.gender).toBe('F')
    expect(params.ageCategory).toBe('V1')
  })

  // 9.53 — Edit form shows only url_results, import_status, status_reason (not core metadata)
  it('edit form shows only import-related fields', async () => {
    const { container } = render(TournamentManager, { props: defaultProps })
    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    await fireEvent.click(editBtns[0])

    const form = container.querySelector('[data-field="tournament-form"]')!
    // Import-related fields present
    expect(form.querySelector('[data-field="form-url-results"]')).not.toBeNull()
    expect(form.querySelector('[data-field="form-import-status"]')).not.toBeNull()
    expect(form.querySelector('[data-field="form-status-reason"]')).not.toBeNull()

    // Core metadata fields absent in edit mode
    expect(form.querySelector('[data-field="form-code"]')).toBeNull()
    expect(form.querySelector('[data-field="form-type"]')).toBeNull()
    expect(form.querySelector('[data-field="form-weapon"]')).toBeNull()
    expect(form.querySelector('[data-field="form-gender"]')).toBeNull()
    expect(form.querySelector('[data-field="form-age-category"]')).toBeNull()
  })

  // 9.54 — Delete button calls ondelete with tournament id
  it('delete button calls ondelete with tournament id', async () => {
    const ondelete = vi.fn()
    const { container } = render(TournamentManager, { props: { ...defaultProps, ondelete } })
    const deleteBtns = container.querySelectorAll('[data-field="delete-btn"]')
    expect(deleteBtns.length).toBe(3)

    await fireEvent.click(deleteBtns[1])
    expect(ondelete).toHaveBeenCalledWith(101)
  })

  // 9.55 — Shows import_status badge (PLANNED/IMPORTED/SCORED)
  it('shows import_status badge with correct text', () => {
    const { container } = render(TournamentManager, { props: defaultProps })
    const badges = container.querySelectorAll('[data-field="tournament-import-status"]')
    expect(badges.length).toBe(3)
    expect(badges[0].textContent).toContain('SCORED')
    expect(badges[1].textContent).toContain('PLANNED')
    expect(badges[2].textContent).toContain('PENDING')
  })

  // Admin guard — renders nothing when isAdmin=false
  it('renders nothing when isAdmin is false', () => {
    const { container } = render(TournamentManager, { props: { ...defaultProps, isAdmin: false } })
    expect(container.querySelector('[data-field="tournament-list"]')).toBeNull()
    expect(container.querySelector('[data-field="add-tournament-btn"]')).toBeNull()
  })

  // 9.312 — Sibling tournaments may share a url_results (combined-pool case).
  // Pasting the same FTL URL onto a V0 row and a V1 row is the supported
  // input shape: scrape_tournament.py finds the siblings via the URL and
  // calls split_combined_results. This test documents that the UI accepts
  // and persists the shared URL without de-duping or rejecting it.
  it('accepts the same url_results on sibling tournaments without modification', async () => {
    const onupdate = vi.fn()
    const SHARED_URL = 'https://www.fencingtime.com/2026/Wroclaw/results/123'
    const sharedTournaments: Tournament[] = [
      { ...MOCK_TOURNAMENTS[0], id_tournament: 200, enum_age_category: 'V0', url_results: SHARED_URL },
      { ...MOCK_TOURNAMENTS[0], id_tournament: 201, enum_age_category: 'V1', url_results: SHARED_URL },
    ]
    const { container } = render(TournamentManager, {
      props: { ...defaultProps, tournaments: sharedTournaments, onupdate },
    })

    const editBtns = container.querySelectorAll('[data-field="edit-btn"]')
    await fireEvent.click(editBtns[1])
    const form = container.querySelector('[data-field="tournament-form"]')!
    const urlInput = form.querySelector('[data-field="form-url-results"]') as HTMLInputElement
    expect(urlInput.value).toBe(SHARED_URL)

    await fireEvent.click(form.querySelector('[data-field="form-save-btn"]')!)
    expect(onupdate).toHaveBeenCalledWith(201, expect.objectContaining({
      urlResults: SHARED_URL,
    }))
  })
})
