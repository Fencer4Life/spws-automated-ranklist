// Plan tests: 6.1, 6.5, 6.11 — RanklistTable component.
// See doc/archive/POC_development_plan.md §M6 test table.
// SS26.UI (design step 7, ADR-101): RANKING mode now renders the schema-v2
// SPWS/EVF+/Razem columns from fn_ranking_full, replacing the legacy
// PPW Total/PEW Total/Total columns from fn_ranking_kadra.
// RT.ROUND.06–08 (ADR-114): whole points; a small decimal only in the
// ordering column (Razem / Points) of close-call rows.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import RanklistTable from '../src/components/RanklistTable.svelte'
import type { RankingPpwRow, RankingFullRow } from '../src/lib/types'
import { setLocale } from '../src/lib/locale.svelte'

beforeEach(() => {
  setLocale('en')
})

const ppwData: RankingPpwRow[] = [
  { rank: 1, id_fencer: 1, fencer_name: 'ALPHA Test', ppw_score: 300, mpw_score: 80, total_score: 380 },
  { rank: 2, id_fencer: 2, fencer_name: 'BETA Test', ppw_score: 200, mpw_score: 60, total_score: 260 },
]

const fullData: RankingFullRow[] = [
  { rank: 1, id_fencer: 1, fencer_name: 'ALPHA Test', spws_total: 380, evf_plus_total: 200, total_score: 580, bool_has_carryover: false },
]

describe('RanklistTable', () => {
  // 6.1 — table renders rank, name, score columns
  it('renders PPW columns in PPW mode', () => {
    const { container } = render(RanklistTable, {
      props: { mode: 'PPW', ppwRows: ppwData },
    })
    const headers = Array.from(container.querySelectorAll('th')).map((th) => th.textContent)
    expect(headers).toContain('Points')
    expect(headers).not.toContain('Best-4 PPW')
    expect(headers).not.toContain('SPWS')
    expect(headers).not.toContain('EVF+')
  })

  // SS26.UI: Ranking mode shows exactly SPWS/EVF+/Razem columns
  it('renders SPWS/EVF+/Razem columns in RANKING mode', () => {
    const { container } = render(RanklistTable, {
      props: { mode: 'RANKING', fullRows: fullData },
    })
    const headers = Array.from(container.querySelectorAll('th')).map((th) => th.textContent)
    expect(headers).toContain('SPWS')
    expect(headers).toContain('EVF+')
    expect(headers).toContain('Total')
    expect(headers).not.toContain('Best-4 PPW')
    expect(headers).not.toContain('PPW Total')
    expect(headers).not.toContain('PEW Total')
  })

  // SS26.UI: Ranking mode renders spws_total/evf_plus_total/total_score
  it('renders SPWS/EVF+/Razem values from fn_ranking_full rows', () => {
    const { container } = render(RanklistTable, {
      props: { mode: 'RANKING', fullRows: fullData },
    })
    const cells = Array.from(container.querySelectorAll('.data-row td')).map((td) => td.textContent)
    expect(cells).toContain('380')
    expect(cells).toContain('200')
    expect(cells).toContain('580')
  })

  // 6.1 — data rows rendered
  it('renders correct number of data rows', () => {
    const { container } = render(RanklistTable, {
      props: { mode: 'PPW', ppwRows: ppwData },
    })
    const rows = container.querySelectorAll('.data-row')
    expect(rows.length).toBe(2)
  })

  // 6.5 — row click opens drill-down
  it('calls onrowclick when row is clicked', async () => {
    const handler = vi.fn()
    const { container } = render(RanklistTable, {
      props: { mode: 'PPW', ppwRows: ppwData, onrowclick: handler },
    })
    const firstRow = container.querySelector('.data-row')!
    await fireEvent.click(firstRow)
    expect(handler).toHaveBeenCalledWith(1, 'ALPHA Test')
  })

  it('shows empty state when no rows', () => {
    const { container } = render(RanklistTable, {
      props: { mode: 'PPW', ppwRows: [] },
    })
    expect(container.textContent).toContain('No results found')
  })

  it('shows empty state when no rows in RANKING mode', () => {
    const { container } = render(RanklistTable, {
      props: { mode: 'RANKING', fullRows: [] },
    })
    expect(container.textContent).toContain('No results found')
  })

  const cellsOf = (row: Element) => Array.from(row.querySelectorAll('td'))

  it('RT.ROUND.06 — a Ranking row shows whole points and no decimal', () => {
    const { container } = render(RanklistTable, {
      props: {
        mode: 'RANKING',
        fullRows: [
          { rank: 1, id_fencer: 1, fencer_name: 'ALPHA Test', spws_total: 96.35, evf_plus_total: 76.25, total_score: 172.6, bool_has_carryover: false },
        ],
      },
    })
    const cells = cellsOf(container.querySelector('.data-row')!).map((td) => td.textContent)
    expect(cells.slice(2)).toEqual(['96', '76', '173'])
    expect(container.querySelector('.dec')).toBeNull()
  })

  it('RT.ROUND.07 — close-call rows show a small decimal in Razem only', () => {
    const { container } = render(RanklistTable, {
      props: {
        mode: 'RANKING',
        fullRows: [
          { rank: 1, id_fencer: 1, fencer_name: 'A Test', spws_total: 0, evf_plus_total: 22.96, total_score: 22.96, bool_has_carryover: false },
          { rank: 2, id_fencer: 2, fencer_name: 'B Test', spws_total: 22.09, evf_plus_total: 0, total_score: 22.09, bool_has_carryover: false },
          { rank: 3, id_fencer: 3, fencer_name: 'C Test', spws_total: 0, evf_plus_total: 21.51, total_score: 21.51, bool_has_carryover: false },
          { rank: 4, id_fencer: 4, fencer_name: 'D Test', spws_total: 0, evf_plus_total: 20.44, total_score: 20.44, bool_has_carryover: false },
        ],
      },
    })
    const rows = Array.from(container.querySelectorAll('.data-row')).map(cellsOf)
    expect(rows.map((r) => r[4].textContent)).toEqual(['23', '22.1', '21.5', '20'])
    expect(rows.map((r) => r[4].querySelector('.dec')?.textContent ?? null)).toEqual([null, '.1', '.5', null])
    expect(rows[1].slice(2, 4).map((td) => td.textContent)).toEqual(['22', '0'])
    expect(rows[2].slice(2, 4).map((td) => td.textContent)).toEqual(['0', '22'])
    expect(container.querySelectorAll('.dec').length).toBe(2)
  })

  it('RT.ROUND.08 — the PPW view follows the same rule in Points', () => {
    const { container } = render(RanklistTable, {
      props: {
        mode: 'PPW',
        ppwRows: [
          { rank: 1, id_fencer: 1, fencer_name: 'A Test', ppw_score: 22.09, mpw_score: 0, total_score: 22.09 },
          { rank: 2, id_fencer: 2, fencer_name: 'B Test', ppw_score: 21.51, mpw_score: 0, total_score: 21.51 },
          { rank: 3, id_fencer: 3, fencer_name: 'C Test', ppw_score: 18.2, mpw_score: 0, total_score: 18.2 },
        ],
      },
    })
    const points = Array.from(container.querySelectorAll('.data-row')).map((r) => cellsOf(r)[2])
    expect(points.map((td) => td.textContent)).toEqual(['22.1', '21.5', '18'])
    expect(points.map((td) => td.querySelector('.dec')?.textContent ?? null)).toEqual(['.1', '.5', null])
  })
})
