{#if isAdmin}
  <div class="season-manager">
    <div class="season-header">
      <h3>{t('nav_admin_seasons')}</h3>
      <button data-field="add-season-btn" class="add-btn" onclick={() => { openCreateForm() }}>
        {t('season_add')}
      </button>
    </div>

    <div data-field="season-list" class="season-list">
      {#if showForm && editingId === null}
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
          {#if formError}
            <div class="form-error">{formError}</div>
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
      {#each seasons as season}
        <div data-field="season-card" class="season-card">
          {#if showForm && editingId === season.id_season}
            <div data-field="season-form" class="season-form">
              <!-- 🎯 Konfiguracja punktacji button — visible only for future + active seasons.
                   Past-complete seasons (dt_end < today) hide it (ADR-045). The existing
                   `readonly` prop on ScoringConfigEditor stays as defense-in-depth. -->
              {#if !isSeasonPast(season)}
                <div class="form-top-row">
                  <span class="tooltip-wrapper">
                    <button data-field="scoring-btn" class="scoring-btn" onclick={() => { onscoringconfig(season.id_season) }}>
                      🎯 {t('nav_admin_scoring')}
                    </button>
                    <span class="tooltip-text">{t('season_scoring_tooltip')}</span>
                  </span>
                </div>
              {/if}
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
              <label class="checkbox-label">
                <input data-field="form-evf-toggle" type="checkbox" bind:checked={draftShowEvf} />
                {t('sc_show_evf_toggle')}
              </label>
              {#if formError}
                <div class="form-error">{formError}</div>
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
            {#if scoringConfig && scoringSeasonId === season.id_season}
              <ScoringConfigEditor
                config={scoringConfig}
                seasonCode={season.txt_code}
                readonly={isSeasonPast(season)}
                onsave={onsavescoring}
                oncancel={onclosescoring}
              />
            {/if}
          {/if}
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
        </div>
      {/each}

    </div>
  </div>
{/if}

<script lang="ts">
  import type { Season, ScoringConfig } from '../lib/types'
  import { t } from '../lib/locale.svelte'
  import ScoringConfigEditor from './ScoringConfigEditor.svelte'

  let {
    seasons = [] as Season[],
    isAdmin = false,
    oncreate = (_code: string, _start: string, _end: string): Promise<string | null> => Promise.resolve(null),
    onupdate = (_id: number, _code: string, _start: string, _end: string, _showEvf: boolean): Promise<string | null> => Promise.resolve(null),
    ondelete = (_id: number) => {},
    onfetchevf = (_id: number): Promise<boolean> => Promise.resolve(false),
    onscoringconfig = (_id: number) => {},
    scoringConfig = null as ScoringConfig | null,
    scoringSeasonId = null as number | null,
    onsavescoring = (_c: ScoringConfig) => {},
    onclosescoring = () => {},
  }: {
    seasons?: Season[]
    isAdmin?: boolean
    oncreate?: (code: string, start: string, end: string) => Promise<string | null>
    onupdate?: (id: number, code: string, start: string, end: string, showEvf: boolean) => Promise<string | null>
    ondelete?: (id: number) => void
    onfetchevf?: (id: number) => Promise<boolean>
    onscoringconfig?: (id: number) => void
    scoringConfig?: ScoringConfig | null
    scoringSeasonId?: number | null
    onsavescoring?: (config: ScoringConfig) => void
    onclosescoring?: () => void
  } = $props()

  let showForm = $state(false)
  let editingId: number | null = $state(null)
  let draftCode = $state('')
  let draftStart = $state('')
  let draftEnd = $state('')
  let draftShowEvf = $state(false)
  let formError: string | null = $state(null)

  // Past-complete season = dt_end strictly before today's date (local TZ).
  // Used to hide the 🎯 Konfiguracja punktacji button per ADR-045.
  function isSeasonPast(s: Season): boolean {
    return new Date(s.dt_end) < new Date(new Date().toDateString())
  }

  function openCreateForm() {
    editingId = null
    draftCode = ''
    draftStart = ''
    draftEnd = ''
    formError = null
    showForm = true
  }

  async function openEditForm(season: Season) {
    editingId = season.id_season
    draftCode = season.txt_code
    draftStart = season.dt_start
    draftEnd = season.dt_end
    draftShowEvf = await onfetchevf(season.id_season)
    formError = null
    showForm = true
  }

  function closeForm() {
    showForm = false
    editingId = null
    formError = null
  }

  async function handleSave() {
    formError = null
    let err: string | null = null
    if (editingId != null) {
      err = await onupdate(editingId, draftCode, draftStart, draftEnd, draftShowEvf)
    } else {
      err = await oncreate(draftCode, draftStart, draftEnd)
    }
    if (err) {
      formError = err
    } else {
      closeForm()
    }
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
    margin-bottom: 8px;
    background: #eef4fb;
    border: 1px solid #b8d4ee;
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
  .form-top-row {
    width: 100%;
    display: flex;
    justify-content: flex-start;
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
  .scoring-btn {
    padding: 6px 14px;
    border: 1px solid #e8a020;
    border-radius: 4px;
    background: #fff8e8;
    color: #8a6010;
    font-size: 14px;
    cursor: pointer;
    font-weight: 600;
  }
  .scoring-btn:hover {
    background: #fff0c8;
  }
  .tooltip-wrapper {
    position: relative;
    display: inline-block;
  }
  .tooltip-text {
    visibility: hidden;
    opacity: 0;
    position: absolute;
    bottom: 100%;
    left: 50%;
    transform: translateX(-50%);
    background: #333;
    color: #fff;
    font-size: 12px;
    padding: 6px 10px;
    border-radius: 4px;
    white-space: nowrap;
    pointer-events: none;
    transition: opacity 0.2s;
    margin-bottom: 4px;
    z-index: 10;
  }
  .tooltip-wrapper:hover .tooltip-text {
    visibility: visible;
    opacity: 1;
  }
  .form-error {
    width: 100%;
    padding: 8px 12px;
    background: #fee;
    border: 1px solid #c33;
    border-radius: 4px;
    color: #c33;
    font-size: 13px;
  }
  .season-list {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .season-card {
    margin-bottom: 2px;
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
