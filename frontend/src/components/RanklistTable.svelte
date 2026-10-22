<div class="table-wrapper">
  <table>
    <thead>
      <tr>
        <th class="col-rank">#</th>
        <th class="col-fencer">{t(gender === 'F' ? 'col_fencer_F' : 'col_fencer')}</th>
        {#if mode === 'PPW'}
          <th class="col-score col-total">{t('col_points')}</th>
        {:else}
          <th class="col-score">{t('col_spws')}</th>
          <th class="col-score">{t('col_evf_plus')}</th>
          <th class="col-score col-total">{t('col_total')}</th>
        {/if}
      </tr>
    </thead>
    <tbody>
      {#if ppwRows.length === 0 && fullRows.length === 0}
        <tr><td colspan={mode === 'PPW' ? 3 : 5} class="empty-state">{t('no_results')}</td></tr>
      {:else if mode === 'PPW'}
        {#each ppwRows as row, i}
          <tr class="data-row" onclick={() => onrowclick?.(row.id_fencer, row.fencer_name)}>
            <td class="col-rank">{row.rank}</td>
            <td class="col-fencer">{row.fencer_name}</td>
            <td class="col-score col-total">{@render total(row.total_score, ppwDecimals[i])}</td>
          </tr>
        {/each}
      {:else}
        {#each fullRows as row, i}
          <tr class="data-row" onclick={() => onrowclick?.(row.id_fencer, row.fencer_name)}>
            <td class="col-rank">{row.rank}</td>
            <td class="col-fencer">{row.fencer_name}</td>
            <td class="col-score">{wholePoints(row.spws_total)}</td>
            <td class="col-score">{wholePoints(row.evf_plus_total)}</td>
            <td class="col-score col-total">{@render total(row.total_score, fullDecimals[i])}</td>
          </tr>
        {/each}
      {/if}
    </tbody>
  </table>
</div>

<!-- ADR-114: the ordering column is whole, except a close call's small decimal. -->
{#snippet total(v: number, decimals: Decimals)}
  {#if decimals === 0}{wholePoints(v)}{:else}{@const p = splitPoints(Number(v), decimals)}{p.whole}<span class="dec">.{p.frac}</span>{/if}
{/snippet}

<script lang="ts">
  import type { RankingPpwRow, RankingFullRow, RankingMode, GenderType } from '../lib/types'
  import { t } from '../lib/locale.svelte'
  import { wholePoints, closeCallDecimals, splitPoints, type Decimals } from '../lib/ranklist-points'

  let {
    mode = 'PPW' as RankingMode,
    ppwRows = [] as RankingPpwRow[],
    fullRows = [] as RankingFullRow[],
    gender = 'M' as GenderType,
    onrowclick,
  }: {
    mode?: RankingMode
    ppwRows?: RankingPpwRow[]
    fullRows?: RankingFullRow[]
    // The gender dropdown's value: the Polish fencer column says „Zawodniczka”
    // on the women's list (gendered-fencer-wording plan, 2026-10-21).
    gender?: GenderType
    onrowclick?: (fencerId: number, fencerName: string) => void
  } = $props()

  // Rows arrive in rank order, as the ranking functions return them.
  const ppwDecimals = $derived(closeCallDecimals(ppwRows.map((r) => Number(r.total_score))))
  const fullDecimals = $derived(closeCallDecimals(fullRows.map((r) => Number(r.total_score))))
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
  /* ADR-114: a close call's decimal, three sizes smaller and in the table's grey */
  .dec {
    font-size: 0.72em;
    color: #999;
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
