{#if isAdmin && proposals.length > 0}
  <!-- Silent when empty, on purpose. This sits above a screen an administrator
       opens for other reasons, so an empty frame every day would train them to
       scroll past the one day it matters. -->
  <div data-field="proposals-panel" class="proposals-panel">
    <div class="panel-head">
      <span class="panel-title">{t('identity_proposals_title')}</span>
      <span class="panel-count">{proposals.length}</span>
    </div>
    <p class="panel-note">{t('identity_proposals_note')}</p>

    {#each proposals as p (p.idOverride)}
      <div data-field="proposal-row" class="proposal-row">
        <div class="who">
          <span class="name">{p.surname.toUpperCase()} {p.firstName}</span>
          <span class="meta">#{p.idFencer}</span>
        </div>
        <div class="change">
          <span class="before">{p.birthYearBefore}</span>
          <span class="arrow">&rarr;</span>
          <span class="after">{p.birthYearAfter}</span>
        </div>
        <div class="actions">
          <!-- Both lock while a decision is in flight: the server closes the row
               on the first call and raises on the second, so a double click
               would surface an error for work that actually succeeded. -->
          <button
            data-field="proposal-apply"
            class="btn apply"
            disabled={deciding === p.idOverride}
            onclick={() => onapply(p.idOverride)}
          >{t('identity_proposals_apply')}</button>
          <button
            data-field="proposal-reject"
            class="btn reject"
            disabled={deciding === p.idOverride}
            onclick={() => onreject(p.idOverride)}
          >{t('identity_proposals_reject')}</button>
        </div>
      </div>
    {/each}
  </div>
{/if}

<script lang="ts">
  import { t } from '../lib/locale.svelte'
  import type { IdentityProposal } from '../lib/types'

  // A request from a public registration to change an already-CONFIRMED birth
  // year. The public cannot carry one out — `fn_apply_identity_override` has no
  // anon grant — so this list is where the correction actually lands. Until
  // somebody decides, a genuine fencer's declaration sits unapplied, which is
  // why the panel is loud when it has anything to say and invisible otherwise.
  let {
    proposals = [],
    isAdmin = false,
    // The row currently being decided, so only that row's buttons lock.
    deciding = null,
    onapply,
    onreject,
  }: {
    proposals?: IdentityProposal[]
    isAdmin?: boolean
    deciding?: number | null
    onapply: (idOverride: number) => void
    onreject: (idOverride: number) => void
  } = $props()
</script>

<style>
  .proposals-panel {
    border: 1px solid #f0b967;
    background: rgba(240, 159, 39, 0.1);
    border-radius: 10px;
    padding: 12px 14px;
    margin-bottom: 16px;
  }
  .panel-head {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 4px;
  }
  .panel-title {
    font-weight: 600;
    color: #f0b967;
  }
  .panel-count {
    background: #f0b967;
    color: #0d1b2a;
    border-radius: 10px;
    padding: 0 7px;
    font-size: 0.8em;
    font-weight: 600;
  }
  .panel-note {
    margin: 0 0 10px;
    font-size: 0.85em;
    opacity: 0.75;
  }
  .proposal-row {
    display: flex;
    align-items: center;
    gap: 14px;
    flex-wrap: wrap;
    padding: 8px 0;
    border-top: 1px solid rgba(240, 159, 39, 0.25);
  }
  .who {
    flex: 1 1 220px;
  }
  .name {
    font-weight: 600;
  }
  .meta {
    opacity: 0.6;
    font-size: 0.85em;
    margin-left: 6px;
  }
  .change {
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
  }
  .before {
    opacity: 0.7;
    text-decoration: line-through;
  }
  .arrow {
    margin: 0 6px;
    opacity: 0.6;
  }
  .after {
    font-weight: 600;
    color: #f0b967;
  }
  .actions {
    display: flex;
    gap: 8px;
  }
  .btn {
    border-radius: 6px;
    padding: 5px 11px;
    font-size: 0.88em;
    cursor: pointer;
    border: 1px solid #1a4a8a;
    background: transparent;
    color: inherit;
  }
  .btn.apply {
    background: #1a4a8a;
    color: #fff;
  }
  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>
