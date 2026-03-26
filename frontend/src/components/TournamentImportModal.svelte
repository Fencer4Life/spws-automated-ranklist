{#if open && tournament}
  <div class="modal-overlay" onclick={() => { onclose() }}>
    <div data-field="import-modal" class="modal-box" onclick={(e) => e.stopPropagation()}>
      <div class="modal-header">
        <h3>{t('import_title')} — {tournament.txt_code}</h3>
        <button class="close-btn" onclick={() => { onclose() }}>&times;</button>
      </div>

      <div data-field="tournament-info" class="tournament-info">
        <span class="info-code">{tournament.txt_code}</span>
        <span class="info-badge type-badge {typeClass(tournament.enum_type)}">{tournament.enum_type}</span>
        <span class="info-badge {isReimport ? 'reimport-badge' : 'new-badge'}">
          {isReimport ? t('import_status_reimport') : t('import_status_new')}
        </span>
        <span class="info-detail">{tournament.enum_weapon}</span>
        <span class="info-detail">{tournament.enum_gender}</span>
        <span class="info-detail">{tournament.enum_age_category}</span>
        {#if tournament.int_participant_count}
          <span class="info-detail">N={tournament.int_participant_count}</span>
        {/if}
      </div>

      <div
        data-field="file-drop-zone"
        class="file-drop-zone"
        class:has-file={selectedFile != null}
        ondragover={(e) => { e.preventDefault() }}
        ondrop={(e) => { handleDrop(e) }}
        onclick={() => { fileInputEl?.click() }}
      >
        {#if selectedFile}
          <span data-field="selected-file-name" class="selected-file">{selectedFile.name}</span>
        {:else}
          <span class="drop-text">{t('import_file_drop')}</span>
        {/if}
        <span class="formats-text">{t('import_file_formats')}</span>
        <input
          data-field="file-input"
          type="file"
          accept=".xlsx,.xls,.json,.csv"
          class="hidden-input"
          bind:this={fileInputEl}
          onchange={(e) => { handleFileSelect(e) }}
        />
      </div>

      {#if isReimport}
        <div data-field="reimport-warning" class="reimport-warning">
          {t('import_reimport_warning')}
        </div>
      {/if}

      <div class="modal-footer">
        <button data-field="cancel-btn" class="cancel-btn" onclick={() => { onclose() }}>
          {t('import_cancel')}
        </button>
        <button
          data-field="import-btn"
          class="import-btn"
          disabled={selectedFile == null}
          onclick={() => { handleImport() }}
        >
          {t('import_btn')}
        </button>
      </div>
    </div>
  </div>
{/if}

<script lang="ts">
  import type { Tournament, TournamentType } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  let {
    tournament = null as Tournament | null,
    open = false,
    onimport = (_tournamentId: number, _file: File) => {},
    onclose = () => {},
  }: {
    tournament?: Tournament | null
    open?: boolean
    onimport?: (tournamentId: number, file: File) => void
    onclose?: () => void
  } = $props()

  let selectedFile: File | null = $state(null)
  let fileInputEl: HTMLInputElement | undefined = $state(undefined)

  let isReimport = $derived(
    tournament != null &&
    (tournament.enum_import_status === 'IMPORTED' || tournament.enum_import_status === 'SCORED')
  )

  function typeClass(type: TournamentType): string {
    switch (type) {
      case 'PPW': return 'type-ppw'
      case 'MPW': return 'type-mpw'
      case 'PEW': case 'MEW': case 'MSW': case 'PSW': return 'type-international'
      default: return ''
    }
  }

  function handleFileSelect(e: Event) {
    const input = e.target as HTMLInputElement
    if (input.files && input.files.length > 0) {
      selectedFile = input.files[0]
    }
  }

  function handleDrop(e: DragEvent) {
    e.preventDefault()
    if (e.dataTransfer?.files && e.dataTransfer.files.length > 0) {
      selectedFile = e.dataTransfer.files[0]
    }
  }

  function handleImport() {
    if (tournament && selectedFile) {
      onimport(tournament.id_tournament, selectedFile)
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
  .tournament-info {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 14px 20px;
    background: #f8f9fa;
    flex-wrap: wrap;
  }
  .info-code {
    font-weight: 600;
    font-size: 14px;
    color: #333;
  }
  .info-badge {
    font-size: 11px;
    padding: 2px 8px;
    border-radius: 10px;
    font-weight: 600;
  }
  .type-badge.type-ppw { background: #d4edda; color: #155724; }
  .type-badge.type-mpw { background: #cce5ff; color: #004085; }
  .type-badge.type-international { background: #fff3cd; color: #856404; }
  .new-badge { background: #cce5ff; color: #004085; }
  .reimport-badge { background: #fff3cd; color: #856404; }
  .info-detail {
    font-size: 13px;
    color: #555;
  }
  .file-drop-zone {
    margin: 16px 20px;
    padding: 32px 20px;
    border: 2px dashed #ccc;
    border-radius: 8px;
    text-align: center;
    cursor: pointer;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    transition: border-color 0.2s;
  }
  .file-drop-zone:hover {
    border-color: #4a90d9;
  }
  .file-drop-zone.has-file {
    border-color: #2ecc71;
    background: #f0faf4;
  }
  .drop-text {
    font-size: 14px;
    color: #555;
  }
  .formats-text {
    font-size: 12px;
    color: #999;
  }
  .selected-file {
    font-size: 14px;
    font-weight: 600;
    color: #155724;
  }
  .hidden-input {
    display: none;
  }
  .reimport-warning {
    margin: 0 20px 16px;
    padding: 12px 16px;
    background: #fff3cd;
    border: 1px solid #ffc107;
    border-radius: 6px;
    color: #856404;
    font-size: 13px;
    line-height: 1.5;
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
  .import-btn {
    padding: 8px 18px;
    border: none;
    border-radius: 4px;
    background: #4a90d9;
    color: #fff;
    font-size: 14px;
    cursor: pointer;
  }
  .import-btn:disabled {
    background: #b0c4de;
    cursor: not-allowed;
  }
</style>
