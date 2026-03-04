import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import RanklistTable from '../src/components/RanklistTable.svelte'
import type { RankingPpwRow, RankingKadraRow } from '../src/lib/types'

const ppwData: RankingPpwRow[] = [
  { rank: 1, id_fencer: 1, fencer_name: 'ALPHA Test', ppw_score: 300, mpw_score: 80, total_score: 380 },
  { rank: 2, id_fencer: 2, fencer_name: 'BETA Test', ppw_score: 200, mpw_score: 60, total_score: 260 },
]

const kadraData: RankingKadraRow[] = [
  { rank: 1, id_fencer: 1, fencer_name: 'ALPHA Test', ppw_total: 380, pew_total: 200, total_score: 580 },
]

describe('RanklistTable', () => {
  it('renders PPW columns in PPW mode', () => {
    const { container } = render(RanklistTable, {
      props: { mode: 'PPW', ppwRows: ppwData },
    })
    const headers = Array.from(container.querySelectorAll('th')).map((th) => th.textContent)
    expect(headers).toContain('Best-4 PPW')
    expect(headers).toContain('MPW')
    expect(headers).not.toContain('PEW Total')
  })

  it('renders Kadra columns in KADRA mode', () => {
    const { container } = render(RanklistTable, {
      props: { mode: 'KADRA', kadraRows: kadraData },
    })
    const headers = Array.from(container.querySelectorAll('th')).map((th) => th.textContent)
    expect(headers).toContain('PPW Total')
    expect(headers).toContain('PEW Total')
    expect(headers).not.toContain('Best-4 PPW')
  })

  it('renders correct number of data rows', () => {
    const { container } = render(RanklistTable, {
      props: { mode: 'PPW', ppwRows: ppwData },
    })
    const rows = container.querySelectorAll('.data-row')
    expect(rows.length).toBe(2)
  })

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
})
