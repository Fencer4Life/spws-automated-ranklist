{#if open && event}
  <div class="modal-overlay" onclick={() => { onclose() }}>
    <div data-field="event-import-modal" class="modal-box" onclick={(e) => e.stopPropagation()}>
      <div class="modal-header">
        <h3>{t('import_event_title')} — {event.txt_name}</h3>
        <button class="close-btn" onclick={() => { onclose() }}>&times;</button>
      </div>

      <div data-field="event-info" class="event-info">
        <span class="info-name">{event.txt_name}</span>
        <span class="info-detail">{event.dt_start} — {event.dt_end}</span>
        <span class="info-detail">{event.num_tournaments} {t('tournaments_count')}</span>
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
          <span class="selected-file">{selectedFile.name}</span>
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

      <div class="tournament-checklist">
        <label class="check-row select-all-row">
          <input
            data-field="select-all"
            type="checkbox"
            checked={allSelected}
            onchange={() => { toggleAll() }}
          />
          <span>{t('import_select_all')}</span>
        </label>
        {#each tournaments as tour (tour.id_tournament)}
          <label data-field="tournament-check" class="check-row">
            <input
              data-field="tournament-checkbox"
              type="checkbox"
              checked={selectedIds.has(tour.id_tournament)}
              onchange={() => { toggleTournament(tour.id_tournament) }}
            />
            <span class="tour-code">{tour.txt_code}</span>
            <span class="tour-name">{tour.txt_name}</span>
            <span class="info-badge type-badge {typeClass(tour.enum_type)}">{tour.enum_type}</span>
            <span class="info-badge {reimportIds.has(tour.id_tournament) ? 'reimport-badge' : 'new-badge'}">
              {reimportIds.has(tour.id_tournament) ? t('import_status_reimport') : t('import_status_new')}
            </span>
          </label>
        {/each}
      </div>

      {#if hasReimport}
        <div data-field="reimport-warning" class="reimport-warning">
          {t('import_reimport_warning')}
        </div>
      {/if}

      <div class="modal-footer">
        <span data-field="selection-summary" class="selection-summary">
          {t('import_selected_summary').replace('{selected}', String(selectedIds.size)).replace('{total}', String(tournaments.length))}
        </span>
        <button data-field="cancel-btn" class="cancel-btn" onclick={() => { onclose() }}>
          {t('import_cancel')}
        </button>
        <button
          data-field="import-btn"
          class="import-btn"
          disabled={selectedFile == null || selectedIds.size === 0}
          onclick={() => { handleImport() }}
        >
          {t('import_selected_btn')}
        </button>
      </div>
    </div>
  </div>
{/if}

<script lang="ts">
  import type { CalendarEvent, Tournament, TournamentType } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  let {
    event = null as CalendarEvent | null,
    tournaments = [] as Tournament[],
    open = false,
    onimport = (_tournamentIds: number[], _file: File) => {},
    onclose = () => {},
  }: {
    event?: CalendarEvent | null
    tournaments?: Tournament[]
    open?: boolean
    onimport?: (tournamentIds: number[], file: File) => void
    onclose?: () => void
  } = $props()

  let selectedFile: File | null = $state(null)
  let fileInputEl: HTMLInputElement | undefined = $state(undefined)
  let selectedIds: Set<number> = $state(new Set(tournaments.map(t => t.id_tournament)))

  let reimportIds = $derived(
    new Set(
      tournaments
        .filter(t => t.enum_import_status === 'IMPORTED' || t.enum_import_status === 'SCORED')
        .map(t => t.id_tournament)
    )
  )

  let hasReimport = $derived(
    [...selectedIds].some(id => reimportIds.has(id))
  )

  let allSelected = $derived(selectedIds.size === tournaments.length)

  function typeClass(type: TournamentType): string {
    switch (type) {
      case 'PPW': return 'type-ppw'
      case 'MPW': return 'type-mpw'
      case 'PEW': case 'MEW': case 'MSW': case 'PSW': return 'type-international'
      default: return ''
    }
  }

  function toggleAll() {
    if (allSelected) {
      selectedIds = new Set()
    } else {
      selectedIds = new Set(tournaments.map(t => t.id_tournament))
    }
  }

  function toggleTournament(id: number) {
    const next = new Set(selectedIds)
    if (next.has(id)) {
      next.delete(id)
    } else {
      next.add(id)
    }
    selectedIds = next
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
    if (selectedFile && selectedIds.size > 0) {
      onimport([...selectedIds], selectedFile)
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
    width: 580px;
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
  .event-info {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 14px 20px;
    background: #f8f9fa;
    flex-wrap: wrap;
  }
  .info-name {
    font-weight: 600;
    font-size: 14px;
    color: #333;
  }
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
  .tournament-checklist {
    margin: 0 20px 16px;
    border: 1px solid #e0e0e0;
    border-radius: 6px;
    overflow: hidden;
  }
  .check-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 12px;
    border-bottom: 1px solid #f0f0f0;
    cursor: pointer;
    font-size: 13px;
  }
  .check-row:last-child {
    border-bottom: none;
  }
  .select-all-row {
    background: #f8f9fa;
    font-weight: 600;
    font-size: 13px;
  }
  .tour-code {
    font-weight: 600;
    color: #333;
  }
  .tour-name {
    color: #555;
    flex: 1;
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
    align-items: center;
    gap: 10px;
    padding: 14px 20px;
    border-top: 1px solid #e0e0e0;
  }
  .selection-summary {
    flex: 1;
    font-size: 13px;
    color: #666;
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
