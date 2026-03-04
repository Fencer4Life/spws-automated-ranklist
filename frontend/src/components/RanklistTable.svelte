<div class="table-wrapper">
  <table>
    <thead>
      <tr>
        <th class="col-rank">#</th>
        <th class="col-fencer">Fencer</th>
        {#if mode === 'PPW'}
          <th class="col-score">Best-4 PPW</th>
          <th class="col-score">MPW</th>
        {:else}
          <th class="col-score">PPW Total</th>
          <th class="col-score">PEW Total</th>
        {/if}
        <th class="col-score col-total">Total</th>
      </tr>
    </thead>
    <tbody>
      {#if ppwRows.length === 0 && kadraRows.length === 0}
        <tr><td colspan={5} class="empty-state">No results found</td></tr>
      {:else if mode === 'PPW'}
        {#each ppwRows as row}
          <tr class="data-row" onclick={() => onrowclick?.(row.id_fencer, row.fencer_name)}>
            <td class="col-rank">{row.rank}</td>
            <td class="col-fencer">{row.fencer_name}</td>
            <td class="col-score">{fmt(row.ppw_score)}</td>
            <td class="col-score">{fmt(row.mpw_score)}</td>
            <td class="col-score col-total">{fmt(row.total_score)}</td>
          </tr>
        {/each}
      {:else}
        {#each kadraRows as row}
          <tr class="data-row" onclick={() => onrowclick?.(row.id_fencer, row.fencer_name)}>
            <td class="col-rank">{row.rank}</td>
            <td class="col-fencer">{row.fencer_name}</td>
            <td class="col-score">{fmt(row.ppw_total)}</td>
            <td class="col-score">{fmt(row.pew_total)}</td>
            <td class="col-score col-total">{fmt(row.total_score)}</td>
          </tr>
        {/each}
      {/if}
    </tbody>
  </table>
</div>

<script lang="ts">
  import type { RankingPpwRow, RankingKadraRow, RankingMode } from '../lib/types'

  let {
    mode = 'PPW' as RankingMode,
    ppwRows = [] as RankingPpwRow[],
    kadraRows = [] as RankingKadraRow[],
    onrowclick,
  }: {
    mode?: RankingMode
    ppwRows?: RankingPpwRow[]
    kadraRows?: RankingKadraRow[]
    onrowclick?: (fencerId: number, fencerName: string) => void
  } = $props()

  function fmt(v: number | null): string {
    if (v == null) return '—'
    const n = Math.round(Number(v) * 10) / 10
    return n % 1 === 0 ? n.toFixed(0) : n.toFixed(1)
  }
</script>

<style>
  .table-wrapper {
    overflow-x: auto;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 14px;
  }
  thead {
    background: #f5f7fa;
    position: sticky;
    top: 0;
  }
  th {
    padding: 10px 12px;
    text-align: left;
    font-weight: 600;
    color: #555;
    border-bottom: 2px solid #ddd;
    white-space: nowrap;
  }
  td {
    padding: 8px 12px;
    border-bottom: 1px solid #eee;
  }
  .col-rank {
    width: 50px;
    text-align: center;
  }
  .col-fencer {
    min-width: 180px;
  }
  .col-score {
    text-align: right;
    width: 100px;
  }
  .col-total {
    font-weight: 700;
  }
  .data-row {
    cursor: pointer;
    transition: background 0.1s;
  }
  .data-row:hover {
    background: #f0f5ff;
  }
  .empty-state {
    text-align: center;
    color: #999;
    padding: 32px;
    font-style: italic;
  }

  @media (max-width: 600px) {
    table {
      font-size: 13px;
    }
    th, td {
      padding: 6px 8px;
    }
    .col-rank {
      width: 36px;
    }
    .col-fencer {
      min-width: 120px;
    }
    .col-score {
      width: 70px;
    }
  }
</style>
