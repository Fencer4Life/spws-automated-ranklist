{#if isAdmin}
  <div class="tournament-manager">
    <div class="tournament-header">
      <h3>{t('nav_admin_events')}</h3>
      <button data-field="add-tournament-btn" class="add-btn" onclick={() => { openCreateForm() }}>
        {t('tournament_add')}
      </button>
    </div>

    {#if showForm}
      <div data-field="tournament-form" class="tournament-form">
        {#if editingId == null}
          <!-- Create mode: all metadata fields -->
          <label>
            {t('tournament_code_label')}
            <input data-field="form-code" type="text" bind:value={draftCode} />
          </label>
          <label>
            {t('tournament_name_label')}
            <input data-field="form-name" type="text" bind:value={draftName} />
          </label>
          <label>
            {t('tournament_type_label')}
            <select data-field="form-type" bind:value={draftType}>
              <option value="">--</option>
              {#each TOURNAMENT_TYPES as tt}
                <option value={tt}>{tt}</option>
              {/each}
            </select>
          </label>
          <label>
            {t('tournament_weapon_label')}
            <select data-field="form-weapon" bind:value={draftWeapon}>
              <option value="">--</option>
              {#each WEAPONS as w}
                <option value={w}>{w}</option>
              {/each}
            </select>
          </label>
          <label>
            {t('tournament_gender_label')}
            <select data-field="form-gender" bind:value={draftGender}>
              <option value="">--</option>
              {#each GENDERS as g}
                <option value={g}>{g}</option>
              {/each}
            </select>
          </label>
          <label>
            {t('tournament_category_label')}
            <select data-field="form-age-category" bind:value={draftAgeCategory}>
              <option value="">--</option>
              {#each AGE_CATEGORIES as ac}
                <option value={ac}>{ac}</option>
              {/each}
            </select>
          </label>
          <label>
            {t('tournament_date_label')}
            <input data-field="form-dt-tournament" type="date" bind:value={draftDtTournament} />
          </label>
          <label>
            {t('tournament_participants_label')}
            <input data-field="form-participants" type="number" bind:value={draftParticipants} />
          </label>
          <label>
            {t('tournament_url_label')}
            <input data-field="form-url-results" type="text" bind:value={draftUrlResults} />
          </label>
        {:else}
          <!-- Edit mode: only import-related fields -->
          <label>
            {t('tournament_url_label')}
            <input data-field="form-url-results" type="text" bind:value={draftUrlResults} />
          </label>
          <label>
            {t('tournament_import_status_label')}
            <select data-field="form-import-status" bind:value={draftImportStatus}>
              {#each IMPORT_STATUSES as s}
                <option value={s}>{s}</option>
              {/each}
            </select>
          </label>
          <label>
            {t('tournament_status_reason_label')}
            <input data-field="form-status-reason" type="text" bind:value={draftStatusReason} />
          </label>
        {/if}
        <div class="form-actions">
          <button data-field="form-save-btn" class="save-btn" onclick={() => { handleSave() }}>
            {t('tournament_save')}
          </button>
          <button data-field="form-cancel-btn" class="cancel-btn" onclick={() => { closeForm() }}>
            {t('tournament_cancel')}
          </button>
        </div>
      </div>
    {/if}

    <div data-field="tournament-list" class="tournament-list">
      {#each tournaments as tournament}
        <div data-field="tournament-row" class="tournament-row">
          <span data-field="tournament-code" class="tournament-cell">{tournament.txt_code}</span>
          <span data-field="tournament-type" class="tournament-cell type-badge {typeClass(tournament.enum_type)}">{tournament.enum_type}</span>
          <span data-field="tournament-weapon" class="tournament-cell">{tournament.enum_weapon}</span>
          <span data-field="tournament-category" class="tournament-cell">{tournament.enum_age_category}</span>
          <span data-field="tournament-participants" class="tournament-cell">{tournament.int_participant_count ?? ''}</span>
          <span data-field="tournament-import-status" class="tournament-cell import-badge {importStatusClass(tournament.enum_import_status)}">{tournament.enum_import_status}</span>
          <span class="tournament-cell actions">
            <button data-field="edit-btn" class="icon-btn" onclick={() => { openEditForm(tournament) }}>&#9998;</button>
            <button data-field="delete-btn" class="icon-btn delete" onclick={() => { ondelete(tournament.id_tournament) }}>&#128465;</button>
          </span>
        </div>
      {/each}
    </div>
  </div>
{/if}

<script lang="ts">
  import type { Tournament, ImportStatus, TournamentType, WeaponType, GenderType, AgeCategory, CreateTournamentParams, UpdateTournamentParams } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  const TOURNAMENT_TYPES: TournamentType[] = ['PPW', 'MPW', 'PEW', 'MEW', 'MSW', 'PSW']
  const WEAPONS: WeaponType[] = ['EPEE', 'FOIL', 'SABRE']
  const GENDERS: GenderType[] = ['M', 'F']
  const AGE_CATEGORIES: AgeCategory[] = ['V0', 'V1', 'V2', 'V3', 'V4']
  const IMPORT_STATUSES: ImportStatus[] = ['PLANNED', 'PENDING', 'IMPORTED', 'SCORED', 'REJECTED']

  let {
    tournaments = [] as Tournament[],
    eventId = 0,
    isAdmin = false,
    oncreate = (_params: CreateTournamentParams) => {},
    onupdate = (_id: number, _params: UpdateTournamentParams) => {},
    ondelete = (_id: number) => {},
  }: {
    tournaments?: Tournament[]
    eventId?: number
    isAdmin?: boolean
    oncreate?: (params: CreateTournamentParams) => void
    onupdate?: (id: number, params: UpdateTournamentParams) => void
    ondelete?: (id: number) => void
  } = $props()

  let showForm = $state(false)
  let editingId: number | null = $state(null)
  let draftCode = $state('')
  let draftName = $state('')
  let draftType = $state('')
  let draftWeapon = $state('')
  let draftGender = $state('')
  let draftAgeCategory = $state('')
  let draftDtTournament = $state('')
  let draftParticipants: number | null = $state(null)
  let draftUrlResults = $state('')
  let draftImportStatus: ImportStatus = $state('PLANNED')
  let draftStatusReason = $state('')

  function typeClass(type: TournamentType): string {
    switch (type) {
      case 'PPW': return 'type-ppw'
      case 'MPW': return 'type-mpw'
      case 'PEW': case 'MEW': case 'MSW': case 'PSW': return 'type-international'
      default: return ''
    }
  }

  function importStatusClass(status: ImportStatus): string {
    switch (status) {
      case 'SCORED': return 'import-scored'
      case 'IMPORTED': return 'import-imported'
      case 'PENDING': return 'import-pending'
      case 'PLANNED': return 'import-planned'
      case 'REJECTED': return 'import-rejected'
      default: return ''
    }
  }

  function openCreateForm() {
    editingId = null
    draftCode = ''
    draftName = ''
    draftType = ''
    draftWeapon = ''
    draftGender = ''
    draftAgeCategory = ''
    draftDtTournament = ''
    draftParticipants = null
    draftUrlResults = ''
    showForm = true
  }

  function openEditForm(tournament: Tournament) {
    editingId = tournament.id_tournament
    draftUrlResults = tournament.url_results ?? ''
    draftImportStatus = tournament.enum_import_status
    draftStatusReason = tournament.txt_import_status_reason ?? ''
    showForm = true
  }

  function closeForm() {
    showForm = false
    editingId = null
  }

  function handleSave() {
    if (editingId != null) {
      onupdate(editingId, {
        urlResults: draftUrlResults || undefined,
        importStatus: draftImportStatus,
        statusReason: draftStatusReason || undefined,
      })
    } else {
      oncreate({
        idEvent: eventId,
        code: draftCode,
        name: draftName,
        type: draftType as TournamentType,
        weapon: draftWeapon as WeaponType,
        gender: draftGender as GenderType,
        ageCategory: draftAgeCategory as AgeCategory,
        dtTournament: draftDtTournament || undefined,
        participantCount: draftParticipants ?? undefined,
        urlResults: draftUrlResults || undefined,
      })
    }
    closeForm()
  }
</script>

<style>
  .tournament-manager {
    padding: 16px;
  }
  .tournament-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 16px;
  }
  .tournament-header h3 {
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
  .tournament-form {
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
  .tournament-form label {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 13px;
    color: #555;
  }
  .tournament-form input,
  .tournament-form select {
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
  .tournament-list {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .tournament-row {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 10px 12px;
    background: #fff;
    border: 1px solid #e8e8e8;
    border-radius: 4px;
  }
  .tournament-row:hover {
    background: #f8f9fa;
  }
  .tournament-cell {
    font-size: 14px;
    color: #333;
  }
  .tournament-cell.actions {
    margin-left: auto;
    display: flex;
    gap: 6px;
  }
  .type-badge {
    font-size: 11px;
    padding: 2px 8px;
    border-radius: 10px;
    font-weight: 600;
  }
  .type-ppw { background: #d4edda; color: #155724; }
  .type-mpw { background: #cce5ff; color: #004085; }
  .type-international { background: #fff3cd; color: #856404; }
  .import-badge {
    font-size: 11px;
    padding: 2px 8px;
    border-radius: 10px;
    font-weight: 600;
  }
  .import-scored { background: #d4edda; color: #155724; }
  .import-imported { background: #cce5ff; color: #004085; }
  .import-pending { background: #fff3cd; color: #856404; }
  .import-planned { background: #e2e3e5; color: #383d41; }
  .import-rejected { background: #f8d7da; color: #721c24; }
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
</style>
