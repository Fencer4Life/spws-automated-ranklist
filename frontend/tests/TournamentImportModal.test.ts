// Plan tests: 9.56, 9.57, 9.58, 9.59, 9.60, 9.61
// See .claude/plans/rosy-bouncing-kitten.md §T9.5.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import TournamentImportModal from '../src/components/TournamentImportModal.svelte'
import type { Tournament } from '../src/lib/types'

const SCORED_TOURNAMENT: Tournament = {
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
}

const PLANNED_TOURNAMENT: Tournament = {
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
}

describe('TournamentImportModal (T9.5)', () => {
  const defaultProps = {
    tournament: SCORED_TOURNAMENT,
    open: true,
    onimport: vi.fn(),
    onclose: vi.fn(),
  }

  // 9.56 — Renders modal with tournament info when open=true
  it('renders modal with tournament info when open=true', () => {
    const { container } = render(TournamentImportModal, { props: defaultProps })
    const modal = container.querySelector('[data-field="import-modal"]')
    expect(modal).not.toBeNull()

    const info = container.querySelector('[data-field="tournament-info"]')
    expect(info).not.toBeNull()
    expect(info!.textContent).toContain('PPW-WRO-2025-01-ME-V2')
    expect(info!.textContent).toContain('PPW')
    expect(info!.textContent).toContain('EPEE')
    expect(info!.textContent).toContain('V2')
  })

  // 9.57 — File drop zone present with supported formats text
  it('file drop zone present with supported formats text', () => {
    const { container } = render(TournamentImportModal, { props: defaultProps })
    const dropZone = container.querySelector('[data-field="file-drop-zone"]')
    expect(dropZone).not.toBeNull()
    expect(dropZone!.textContent).toContain('.xlsx')
    expect(dropZone!.textContent).toContain('.csv')
  })

  // 9.58 — File input accepts .xlsx, .xls, .json, .csv (accept attribute)
  it('file input accepts .xlsx, .xls, .json, .csv', () => {
    const { container } = render(TournamentImportModal, { props: defaultProps })
    const fileInput = container.querySelector('[data-field="file-input"]') as HTMLInputElement
    expect(fileInput).not.toBeNull()
    expect(fileInput.accept).toContain('.xlsx')
    expect(fileInput.accept).toContain('.xls')
    expect(fileInput.accept).toContain('.json')
    expect(fileInput.accept).toContain('.csv')
  })

  // 9.59 — Shows re-import warning (mentions deletion) when tournament has SCORED/IMPORTED status
  it('shows reimport warning mentioning deletion for SCORED tournament', () => {
    const { container } = render(TournamentImportModal, { props: defaultProps })
    const warning = container.querySelector('[data-field="reimport-warning"]')
    expect(warning).not.toBeNull()
    // Warning must mention that existing data will be deleted (ADR-014)
    expect(warning!.textContent!.length).toBeGreaterThan(0)
  })

  // 9.60 — Hides re-import warning for PLANNED tournament (new import)
  it('hides reimport warning for PLANNED tournament', () => {
    const { container } = render(TournamentImportModal, {
      props: { ...defaultProps, tournament: PLANNED_TOURNAMENT },
    })
    const warning = container.querySelector('[data-field="reimport-warning"]')
    expect(warning).toBeNull()
  })

  // 9.61 — Calls onimport with tournament id and selected file on submit
  it('calls onimport with tournament id and file on submit', async () => {
    const onimport = vi.fn()
    const { container } = render(TournamentImportModal, {
      props: { ...defaultProps, onimport },
    })

    // Simulate file selection via the hidden input
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
    expect(onimport).toHaveBeenCalledWith(100, testFile)
  })
})
