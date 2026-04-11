{#if open}
  <div class="modal-overlay" onclick={() => { onclose() }}>
    <div data-field="fencer-search-modal" class="modal-box" onclick={(e) => e.stopPropagation()}>
      <div class="modal-header">
        <h3>{t('identity_assign')}</h3>
        <button class="close-btn" onclick={() => { onclose() }}>&times;</button>
      </div>

      <div class="scraped-info">
        <span class="label">{t('identity_scraped_name')}:</span>
        <span class="scraped-name">{scrapedName}</span>
      </div>

      <div class="search-bar">
        <input
          data-field="fencer-search-input"
          type="text"
          class="search-input"
          placeholder={t('identity_search_placeholder')}
          bind:value={searchQuery}
        />
      </div>

      <div class="fencer-list">
        {#each displayedFencers as fc (fc.id_fencer)}
          <label data-field="fencer-option" class="fencer-option" class:selected={selectedFencerId === fc.id_fencer}>
            <input
              type="radio"
              name="fencer-select"
              value={fc.id_fencer}
              checked={selectedFencerId === fc.id_fencer}
              onchange={() => { selectedFencerId = fc.id_fencer }}
            />
            <div class="fencer-info">
              <span class="fencer-name">{fc.txt_surname} {fc.txt_first_name}</span>
              <span class="fencer-detail">{fc.int_birth_year ?? '?'}</span>
              {#if fc.txt_club}
                <span class="fencer-detail">{fc.txt_club}</span>
              {/if}
              {#if fc.enum_gender}
                <span class="gender-badge">{fc.enum_gender}</span>
              {/if}
            </div>
          </label>
        {/each}
        {#if filteredFencers.length > 50}
          <div class="truncation-notice">{filteredFencers.length - 50} more — refine search</div>
        {/if}
        {#if filteredFencers.length === 0 && searchQuery.length > 0}
          <div class="no-results">No fencers found</div>
        {/if}
      </div>

      <div class="modal-footer">
        <button class="cancel-btn" onclick={() => { onclose() }}>
          {t('import_cancel')}
        </button>
        <button
          data-field="confirm-btn"
          class="confirm-btn"
          disabled={selectedFencerId == null}
          onclick={() => { handleConfirm() }}
        >
          {t('identity_approve')}
        </button>
      </div>
    </div>
  </div>
{/if}

<script lang="ts">
  import type { FencerListItem } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  let {
    open = false,
    scrapedName = '',
    fencers = [] as FencerListItem[],
    onconfirm = (_fencerId: number) => {},
    onclose = () => {},
  }: {
    open?: boolean
    scrapedName?: string
    fencers?: FencerListItem[]
    onconfirm?: (fencerId: number) => void
    onclose?: () => void
  } = $props()

  let searchQuery = $state('')
  let selectedFencerId: number | null = $state(null)

  $effect(() => {
    if (open) {
      searchQuery = ''
      selectedFencerId = null
    }
  })

  let filteredFencers = $derived(
    searchQuery.length === 0
      ? fencers
      : fencers.filter(f => {
          const q = searchQuery.toLowerCase()
          return f.txt_surname.toLowerCase().includes(q)
            || f.txt_first_name.toLowerCase().includes(q)
        })
  )

  let displayedFencers = $derived(filteredFencers.slice(0, 50))

  function handleConfirm() {
    if (selectedFencerId != null) {
      onconfirm(selectedFencerId)
    }
  }
</script>

<style>
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }
  .modal-box {
    background: #fff;
    border-radius: 8px;
    width: 520px;
    max-width: 95vw;
    max-height: 85vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.15);
  }
  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid #e0e0e0;
  }
  .modal-header h3 {
    margin: 0;
    font-size: 16px;
    color: #333;
  }
  .close-btn {
    border: none;
    background: none;
    font-size: 22px;
    cursor: pointer;
    color: #666;
    padding: 0 4px;
  }
  .scraped-info {
    padding: 14px 20px;
    background: #f8f9fa;
    display: flex;
    gap: 8px;
    align-items: center;
  }
  .label {
    font-size: 13px;
    color: #666;
  }
  .scraped-name {
    font-weight: 600;
    font-size: 14px;
    color: #333;
  }
  .search-bar {
    padding: 12px 20px;
  }
  .search-input {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 14px;
    box-sizing: border-box;
  }
  .fencer-list {
    padding: 0 20px 12px;
    display: flex;
    flex-direction: column;
    gap: 6px;
    overflow-y: auto;
    max-height: 40vh;
  }
  .fencer-option {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 12px;
    border: 1px solid #e0e0e0;
    border-radius: 6px;
    cursor: pointer;
    transition: border-color 0.2s;
  }
  .fencer-option:hover {
    border-color: #4a90d9;
  }
  .fencer-option.selected {
    border-color: #4a90d9;
    background: #f0f7ff;
  }
  .fencer-info {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }
  .fencer-name {
    font-weight: 600;
    font-size: 14px;
    color: #333;
  }
  .fencer-detail {
    font-size: 13px;
    color: #555;
  }
  .gender-badge {
    font-size: 11px;
    padding: 2px 6px;
    border-radius: 8px;
    font-weight: 600;
    background: #e9ecef;
    color: #555;
  }
  .truncation-notice {
    text-align: center;
    font-size: 12px;
    color: #888;
    padding: 8px;
  }
  .no-results {
    text-align: center;
    font-size: 13px;
    color: #888;
    padding: 16px;
  }
  .modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    padding: 14px 20px;
    border-top: 1px solid #e0e0e0;
  }
  .cancel-btn {
    padding: 8px 18px;
    border: 1px solid #ccc;
    border-radius: 4px;
    background: #fff;
    color: #555;
    font-size: 14px;
    cursor: pointer;
  }
  .confirm-btn {
    padding: 8px 18px;
    border: none;
    border-radius: 4px;
    background: #4a90d9;
    color: #fff;
    font-size: 14px;
    cursor: pointer;
  }
  .confirm-btn:disabled {
    background: #b0c4de;
    cursor: not-allowed;
  }
</style>
