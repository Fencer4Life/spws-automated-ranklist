<div class="view-switch toggle" role="group" aria-label={t('view_toggle_label')}>
  {#each OPTIONS as option (option.mode)}
    <button
      type="button"
      class="toggle-btn"
      class:active={mode === option.mode}
      aria-pressed={mode === option.mode}
      onclick={() => onchange?.(option.mode)}
    >{t(option.label)}</button>
  {/each}
</div>

<script lang="ts">
  // The Ranking | PPW switch, shared by the ranklist's filter bar and the
  // score drilldown so the two cannot drift apart (UX proposal A,
  // doc/mockups/ranklist-controls-ux-2026-10-01.html). Ranking first: it is
  // the default view, and ADR-101 names the switch "Ranking / PPW".
  import type { RankingMode } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  const OPTIONS: { mode: RankingMode; label: string }[] = [
    { mode: 'RANKING', label: 'mode_ranking' },
    { mode: 'PPW', label: 'mode_ppw' },
  ]

  let {
    mode = 'PPW' as RankingMode,
    onchange,
  }: {
    mode?: RankingMode
    onchange?: (mode: RankingMode) => void
  } = $props()
</script>

<style>
  .view-switch {
    display: inline-flex;
    flex: none;
    gap: 2px;
    padding: 3px;
    background: #eef2f7;
    border: 1px solid #c7ced8;
    border-radius: 10px;
  }
  .toggle-btn {
    height: 30px;
    padding: 0 13px;
    border: 0;
    border-radius: 7px;
    background: none;
    color: #3d4a5c;
    font-family: inherit;
    font-size: 14px;
    font-weight: 600;
    white-space: nowrap;
    cursor: pointer;
    transition: background 0.15s, color 0.15s;
  }
  .toggle-btn.active {
    background: #3b82d6;
    color: #fff;
    box-shadow: 0 1px 3px rgba(16, 34, 64, 0.28);
  }
  .toggle-btn:not(.active):hover {
    background: #e0e7f1;
  }
  .toggle-btn:focus-visible {
    outline: 2px solid #12467e;
    outline-offset: 2px;
  }

  /* On a phone the switch fills its row; 44 px tall with its frame. */
  @media (max-width: 600px) {
    .view-switch {
      display: flex;
      flex: 1 1 auto;
    }
    .toggle-btn {
      flex: 1;
      height: 36px;
    }
  }
</style>
