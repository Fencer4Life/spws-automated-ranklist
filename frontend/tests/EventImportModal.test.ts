// Plan tests: 9.62, 9.63, 9.64, 9.65, 9.66, 9.67
// See .claude/plans/rosy-bouncing-kitten.md §T9.6.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import EventImportModal from '../src/components/EventImportModal.svelte'
import type { CalendarEvent, Tournament } from '../src/lib/types'

const MOCK_EVENT: CalendarEvent = {
  id_event: 10,
  txt_code: 'PP1-2025',
  txt_name: 'Puchar Polski #1',
  id_season: 1,
  txt_season_code: '2024-2025',
  txt_location: 'Wrocław',
  txt_country: 'PL',
  txt_venue_address: null,
  url_invitation: null,
  num_entry_fee: null,
  txt_entry_fee_currency: null,
  dt_start: '2025-01-15',
  dt_end: '2025-01-16',
  url_event: 'https://example.com/pp1',
  enum_status: 'COMPLETED',
  num_tournaments: 3,
  bool_has_international: false,
}

const MOCK_TOURNAMENTS: Tournament[] = [
  {
    id_tournament: 100, id_event: 10, txt_code: 'PP1-V2-M-EPEE',
    txt_name: 'Epee V2 M', enum_type: 'PPW', enum_weapon: 'EPEE',
    enum_gender: 'M', enum_age_category: 'V2', dt_tournament: '2025-01-15',
    int_participant_count: 24, num_multiplier: 1.0,
    url_results: 'https://example.com/results/100',
    enum_import_status: 'SCORED', txt_import_status_reason: null,
  },
  {
    id_tournament: 101, id_event: 10, txt_code: 'PP1-V1-M-EPEE',
    txt_name: 'Epee V1 M', enum_type: 'PPW', enum_weapon: 'EPEE',
    enum_gender: 'M', enum_age_category: 'V1', dt_tournament: '2025-01-15',
    int_participant_count: 18, num_multiplier: 1.0,
    url_results: null,
    enum_import_status: 'IMPORTED', txt_import_status_reason: null,
  },
  {
    id_tournament: 102, id_event: 10, txt_code: 'PP1-V0-F-SABRE',
    txt_name: 'Sabre V0 F', enum_type: 'PPW', enum_weapon: 'SABRE',
    enum_gender: 'F', enum_age_category: 'V0', dt_tournament: '2025-01-16',
    int_participant_count: null, num_multiplier: 1.0,
    url_results: null,
    enum_import_status: 'PLANNED', txt_import_status_reason: null,
  },
]

describe('EventImportModal (T9.6)', () => {
  const defaultProps = {
    event: MOCK_EVENT,
    tournaments: MOCK_TOURNAMENTS,
    open: true,
    onimport: vi.fn(),
    onclose: vi.fn(),
  }

  // 9.62 — Renders modal with event info and tournament checklist when open=true
  it('renders modal with event info and tournament checklist', () => {
    const { container } = render(EventImportModal, { props: defaultProps })
    const modal = container.querySelector('[data-field="event-import-modal"]')
    expect(modal).not.toBeNull()

    const info = container.querySelector('[data-field="event-info"]')
    expect(info).not.toBeNull()
    expect(info!.textContent).toContain('Puchar Polski #1')

    // Tournament checklist present
    const checkRows = container.querySelectorAll('[data-field="tournament-check"]')
    expect(checkRows.length).toBe(3)
  })

  // 9.63 — File drop zone present with supported formats text
  it('file drop zone present with supported formats text', () => {
    const { container } = render(EventImportModal, { props: defaultProps })
    const dropZone = container.querySelector('[data-field="file-drop-zone"]')
    expect(dropZone).not.toBeNull()
    expect(dropZone!.textContent).toContain('.xlsx')
    expect(dropZone!.textContent).toContain('.csv')
  })

  // 9.64 — File input accepts .xlsx, .xls, .json, .csv (accept attribute)
  it('file input accepts .xlsx, .xls, .json, .csv', () => {
    const { container } = render(EventImportModal, { props: defaultProps })
    const fileInput = container.querySelector('[data-field="file-input"]') as HTMLInputElement
    expect(fileInput).not.toBeNull()
    expect(fileInput.accept).toContain('.xlsx')
    expect(fileInput.accept).toContain('.xls')
    expect(fileInput.accept).toContain('.json')
    expect(fileInput.accept).toContain('.csv')
  })

  // 9.65 — Tournament checklist shows all tournaments with select-all toggle
  it('tournament checklist with select-all toggle', async () => {
    const { container } = render(EventImportModal, { props: defaultProps })

    // Select-all checkbox present
    const selectAll = container.querySelector('[data-field="select-all"]') as HTMLInputElement
    expect(selectAll).not.toBeNull()
    expect(selectAll.checked).toBe(true) // all selected by default

    // Each tournament row has a checkbox and code
    const checkRows = container.querySelectorAll('[data-field="tournament-check"]')
    expect(checkRows.length).toBe(3)
    expect(checkRows[0].textContent).toContain('PP1-V2-M-EPEE')
    expect(checkRows[2].textContent).toContain('PP1-V0-F-SABRE')

    // Uncheck select-all deselects all
    await fireEvent.click(selectAll)
    const checkboxes = container.querySelectorAll('[data-field="tournament-checkbox"]') as NodeListOf<HTMLInputElement>
    const allUnchecked = [...checkboxes].every(cb => !cb.checked)
    expect(allUnchecked).toBe(true)
  })

  // 9.66 — Calls onimport with selected tournament IDs and file on submit
  it('calls onimport with selected tournament IDs and file', async () => {
    const onimport = vi.fn()
    const { container } = render(EventImportModal, { props: { ...defaultProps, onimport } })

    // Uncheck the third tournament (PP1-V0-F-SABRE, id=102)
    const checkboxes = container.querySelectorAll('[data-field="tournament-checkbox"]') as NodeListOf<HTMLInputElement>
    await fireEvent.click(checkboxes[2]) // uncheck

    // Select a file
    const fileInput = container.querySelector('[data-field="file-input"]') as HTMLInputElement
    const testFile = new File(['test-content'], 'results.xlsx', {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    })
    Object.defineProperty(fileInput, 'files', { value: [testFile], writable: false })
    await fireEvent.change(fileInput)

    // Click import button
    const importBtn = container.querySelector('[data-field="import-btn"]') as HTMLButtonElement
    expect(importBtn.disabled).toBe(false)
    await fireEvent.click(importBtn)

    expect(onimport).toHaveBeenCalledTimes(1)
    const [ids, file] = onimport.mock.calls[0]
    expect(ids).toEqual([100, 101]) // only first two selected
    expect(file).toBe(testFile)
  })

  // 9.67 — Shows reimport warning when any selected tournament has SCORED/IMPORTED status
  it('shows reimport warning when selected tournaments include reimports', () => {
    const { container } = render(EventImportModal, { props: defaultProps })
    const warning = container.querySelector('[data-field="reimport-warning"]')
    expect(warning).not.toBeNull()
    expect(warning!.textContent!.length).toBeGreaterThan(0)
  })
})
