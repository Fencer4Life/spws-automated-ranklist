{#if open}
  <div class="modal-overlay" onclick={() => { onclose() }}>
    <div data-field="disambiguation-modal" class="modal-box" onclick={(e) => e.stopPropagation()}>
      <div class="modal-header">
        <h3>{t('disambiguation_title')}</h3>
        <button class="close-btn" onclick={() => { onclose() }}>&times;</button>
      </div>

      <div class="scraped-info">
        <span class="label">{t('identity_scraped_name')}:</span>
        <span class="scraped-name">{scrapedName}</span>
      </div>

      <div class="fencer-list">
        {#each fencerCandidates as fc (fc.id_fencer)}
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
              <span data-field="fencer-birth-year" class="fencer-detail">
                {fc.int_birth_year ?? '?'}
              </span>
              {#if fc.txt_club}
                <span class="fencer-detail">{fc.txt_club}</span>
              {/if}
              <span class="confidence-badge">{fc.num_confidence}%</span>
              <span
                data-field="fencer-age-match"
                class="age-indicator {fc.bool_age_match ? 'age-match' : 'age-no-match'}"
              >
                {fc.bool_age_match ? '✓ age match' : '✗ age mismatch'}
              </span>
            </div>
          </label>
        {/each}
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
  import type { FencerCandidate } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  let {
    open = false,
    scrapedName = '',
    fencerCandidates = [] as FencerCandidate[],
    onconfirm = (_fencerId: number) => {},
    onclose = () => {},
  }: {
    open?: boolean
    scrapedName?: string
    fencerCandidates?: FencerCandidate[]
    onconfirm?: (fencerId: number) => void
    onclose?: () => void
  } = $props()

  let selectedFencerId: number | null = $state(null)

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
  .fencer-list {
    padding: 12px 20px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .fencer-option {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 12px;
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
  .confidence-badge {
    font-size: 12px;
    padding: 2px 8px;
    border-radius: 10px;
    font-weight: 600;
    background: #fff3cd;
    color: #856404;
  }
  .age-indicator {
    font-size: 12px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: 10px;
  }
  .age-match {
    background: #d4edda;
    color: #155724;
  }
  .age-no-match {
    background: #f8d7da;
    color: #721c24;
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
