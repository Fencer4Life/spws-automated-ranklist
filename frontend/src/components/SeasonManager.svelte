{#if isAdmin}
  <div class="season-manager">
    <div class="season-header">
      <h3>{t('nav_admin_seasons')}</h3>
      <button data-field="add-season-btn" class="add-btn" onclick={() => { openCreateForm() }}>
        {t('season_add')}
      </button>
    </div>

    {#if showForm}
      <div data-field="season-form" class="season-form">
        <label>
          {t('season_code_label')}
          <input data-field="form-code" type="text" bind:value={draftCode} />
        </label>
        <label>
          {t('season_start_label')}
          <input data-field="form-start" type="date" bind:value={draftStart} />
        </label>
        <label>
          {t('season_end_label')}
          <input data-field="form-end" type="date" bind:value={draftEnd} />
        </label>
        {#if editingId != null}
          <label class="checkbox-label">
            <input data-field="form-evf-toggle" type="checkbox" bind:checked={draftShowEvf} />
            {t('sc_show_evf_toggle')}
          </label>
        {/if}
        <div class="form-actions">
          <button data-field="form-save-btn" class="save-btn" onclick={() => { handleSave() }}>
            {t('season_save')}
          </button>
          <button data-field="form-cancel-btn" class="cancel-btn" onclick={() => { closeForm() }}>
            {t('season_cancel')}
          </button>
        </div>
      </div>
    {/if}

    <div data-field="season-list" class="season-list">
      {#each seasons as season}
        <div data-field="season-row" class="season-row">
          <span data-field="season-code" class="season-cell">{season.txt_code}</span>
          <span data-field="season-start" class="season-cell">{season.dt_start}</span>
          <span data-field="season-end" class="season-cell">{season.dt_end}</span>
          <span class="season-cell">
            {#if season.bool_active}
              <span class="active-badge">{t('season_active_badge')}</span>
            {/if}
          </span>
          <span class="season-cell actions">
            <button data-field="edit-btn" class="icon-btn" onclick={() => { openEditForm(season) }}>&#9998;</button>
            <button data-field="delete-btn" class="icon-btn delete" onclick={() => { ondelete(season.id_season) }}>&#128465;</button>
          </span>
        </div>
      {/each}
    </div>
  </div>
{/if}

<script lang="ts">
  import type { Season } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  let {
    seasons = [] as Season[],
    isAdmin = false,
    oncreate = (_code: string, _start: string, _end: string) => {},
    onupdate = (_id: number, _code: string, _start: string, _end: string, _showEvf: boolean) => {},
    ondelete = (_id: number) => {},
    onfetchevf = (_id: number): Promise<boolean> => Promise.resolve(false),
  }: {
    seasons?: Season[]
    isAdmin?: boolean
    oncreate?: (code: string, start: string, end: string) => void
    onupdate?: (id: number, code: string, start: string, end: string, showEvf: boolean) => void
    ondelete?: (id: number) => void
    onfetchevf?: (id: number) => Promise<boolean>
  } = $props()

  let showForm = $state(false)
  let editingId: number | null = $state(null)
  let draftCode = $state('')
  let draftStart = $state('')
  let draftEnd = $state('')
  let draftShowEvf = $state(false)

  function openCreateForm() {
    editingId = null
    draftCode = ''
    draftStart = ''
    draftEnd = ''
    showForm = true
  }

  async function openEditForm(season: Season) {
    editingId = season.id_season
    draftCode = season.txt_code
    draftStart = season.dt_start
    draftEnd = season.dt_end
    draftShowEvf = await onfetchevf(season.id_season)
    showForm = true
  }

  function closeForm() {
    showForm = false
    editingId = null
  }

  function handleSave() {
    if (editingId != null) {
      onupdate(editingId, draftCode, draftStart, draftEnd, draftShowEvf)
    } else {
      oncreate(draftCode, draftStart, draftEnd)
    }
    closeForm()
  }
</script>

<style>
  .season-manager {
    padding: 16px;
  }
  .season-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 16px;
  }
  .season-header h3 {
    margin: 0;
    font-size: 18px;
    color: #333;
  }
  .add-btn {
    padding: 8px 16px;
    border: none;
    border-radius: 4px;
    background: #4a90d9;
    color: #fff;
    font-size: 14px;
    cursor: pointer;
  }
  .add-btn:hover {
    background: #3a7bc8;
  }
  .season-form {
    display: flex;
    gap: 12px;
    align-items: flex-end;
    padding: 12px;
    margin-bottom: 16px;
    background: #f8f9fa;
    border: 1px solid #e0e0e0;
    border-radius: 4px;
    flex-wrap: wrap;
  }
  .season-form label {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 13px;
    color: #555;
  }
  .season-form input {
    padding: 6px 10px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 14px;
  }
  .form-actions {
    display: flex;
    gap: 8px;
    align-items: flex-end;
  }
  .save-btn {
    padding: 6px 14px;
    border: none;
    border-radius: 4px;
    background: #2ecc71;
    color: #fff;
    font-size: 13px;
    cursor: pointer;
  }
  .cancel-btn {
    padding: 6px 14px;
    border: 1px solid #ccc;
    border-radius: 4px;
    background: #fff;
    color: #555;
    font-size: 13px;
    cursor: pointer;
  }
  .season-list {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .season-row {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 10px 12px;
    background: #fff;
    border: 1px solid #e8e8e8;
    border-radius: 4px;
  }
  .season-row:hover {
    background: #f8f9fa;
  }
  .season-cell {
    font-size: 14px;
    color: #333;
  }
  .season-cell.actions {
    margin-left: auto;
    display: flex;
    gap: 6px;
  }
  .active-badge {
    font-size: 11px;
    padding: 2px 8px;
    border-radius: 10px;
    background: #d4edda;
    color: #155724;
    font-weight: 600;
  }
  .icon-btn {
    border: none;
    background: none;
    cursor: pointer;
    font-size: 16px;
    padding: 4px;
    color: #666;
  }
  .icon-btn:hover {
    color: #333;
  }
  .icon-btn.delete:hover {
    color: #c33;
  }
  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    color: #555;
    cursor: pointer;
    white-space: nowrap;
  }
  .checkbox-label input[type="checkbox"] {
    accent-color: #4a90d9;
    cursor: pointer;
  }
</style>
