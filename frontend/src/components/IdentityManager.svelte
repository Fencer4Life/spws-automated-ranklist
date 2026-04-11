{#if isAdmin}
  <div data-field="identity-queue" class="identity-queue">
    <div class="queue-header">
      <h3>{t('identity_title')}</h3>
      <div class="status-counts">
        {#each statusKeys as status}
          <span data-field="count-{status}" class="count-badge count-{status.toLowerCase()}">
            {status}: {statusCounts.get(status) ?? 0}
          </span>
        {/each}
      </div>
    </div>

    {#if errorMsg}
      <div data-field="identity-error" class="error-banner">{errorMsg}</div>
    {/if}

    <div class="filter-bar">
      <select data-field="status-filter" class="status-filter" bind:value={statusFilter}>
        <option value="ALL">{t('identity_filter_all')}</option>
        <option value="PENDING">{t('identity_filter_pending')}</option>
        <option value="AUTO_MATCHED">AUTO_MATCHED</option>
        <option value="UNMATCHED">UNMATCHED</option>
        <option value="APPROVED">APPROVED</option>
        <option value="NEW_FENCER">NEW_FENCER</option>
        <option value="DISMISSED">DISMISSED</option>
      </select>
    </div>

    <div class="candidate-list">
      {#each filteredCandidates as candidate (candidate.id_match)}
        {@const editing = editingMatchId === candidate.id_match}
        <div data-field="candidate-row" class="candidate-card" class:editing>
          <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
          <div class="card-header" onclick={() => { if (!isReadOnly(candidate)) toggleEdit(candidate) }}>
            <div class="header-left">
              <span class="scraped-name">{candidate.txt_scraped_name}</span>
              {#if candidate.txt_tournament_code}
                <span class="tournament-code">{candidate.txt_tournament_code}</span>
              {/if}
            </div>
            <div class="header-right">
              <span
                data-field="confidence-badge"
                class="confidence-badge {confidenceClass(candidate.num_confidence)}"
              >
                {candidate.num_confidence ?? '—'}%
              </span>
              {#if candidate.txt_fencer_name}
                <span class="suggested-name">→ {candidate.txt_fencer_name}</span>
              {/if}
              <span data-field="status-badge" class="status-badge status-{candidate.enum_status.toLowerCase()}">
                {candidate.enum_status}
              </span>
              {#if isGenderMismatch(candidate)}
                <span class="mismatch-icon" title={t('identity_gender_mismatch')}>⚠</span>
              {/if}
              {#if !isReadOnly(candidate)}
                <button data-field="edit-btn" class="edit-toggle" onclick={(e) => { e.stopPropagation(); toggleEdit(candidate) }}>
                  {editing ? '▲' : '▼'}
                </button>
              {/if}
            </div>
          </div>

          {#if editing}
            <div data-field="edit-form" class="edit-form">
              <div class="form-row">
                <span class="form-label">{t('identity_fencer_choice')}</span>
                <select
                  data-field="fencer-choice"
                  class="fencer-choice-select"
                  value={editChoice}
                  onchange={(e) => { handleChoiceChange(candidate, (e.target as HTMLSelectElement).value) }}
                >
                  {#if candidate.id_fencer != null && candidate.txt_fencer_name}
                    <option value="SUGGESTED">✓ {candidate.txt_fencer_name} ({candidate.num_confidence}%)</option>
                  {/if}
                  <option value="NEW">➕ {t('identity_create_new')}</option>
                  <option value="SEARCH">🔍 {t('identity_search_other')}</option>
                </select>
              </div>

              {#if editChoice === 'SEARCH'}
                <div class="search-panel">
                  <input
                    data-field="fencer-search-input"
                    type="text"
                    class="search-input"
                    placeholder={t('identity_search_placeholder')}
                    bind:value={searchQuery}
                  />
                  <div class="search-results">
                    {#each displayedFencers as fc (fc.id_fencer)}
                      <label data-field="fencer-option" class="fencer-option" class:selected={editFencerId === fc.id_fencer}>
                        <input
                          type="radio"
                          name="fencer-select-{candidate.id_match}"
                          value={fc.id_fencer}
                          checked={editFencerId === fc.id_fencer}
                          onchange={() => { selectExistingFencer(fc) }}
                        />
                        <span class="fencer-name">{fc.txt_surname} {fc.txt_first_name}</span>
                        <span class="fencer-detail">{fc.int_birth_year ?? '?'}</span>
                        {#if fc.txt_club}<span class="fencer-detail">{fc.txt_club}</span>{/if}
                        {#if fc.enum_gender}<span class="gender-badge">{fc.enum_gender}</span>{/if}
                      </label>
                    {/each}
                    {#if filteredFencers.length > 50}
                      <div class="truncation-notice">{filteredFencers.length - 50} more — refine search</div>
                    {/if}
                    {#if filteredFencers.length === 0 && searchQuery.length > 0}
                      <div class="no-results">No fencers found</div>
                    {/if}
                  </div>
                </div>
              {/if}

              <div class="form-fields">
                <div class="field-row">
                  <label class="form-field">
                    <span class="field-label">{t('identity_surname')}</span>
                    <input
                      data-field="surname-input"
                      type="text"
                      class="field-input surname"
                      bind:value={editSurname}
                      oninput={(e) => { editSurname = (e.target as HTMLInputElement).value.toUpperCase() }}
                    />
                  </label>
                  <label class="form-field">
                    <span class="field-label">{t('identity_first_name')}</span>
                    <input data-field="first-name-input" type="text" class="field-input" bind:value={editFirstName} />
                  </label>
                </div>
                <div class="field-row">
                  <label class="form-field">
                    <span class="field-label">{t('identity_gender')}</span>
                    <select data-field="gender-select" class="field-input {isEditGenderMismatch(candidate) ? 'gender-mismatch-select' : ''}" bind:value={editGender}>
                      <option value="M">M</option>
                      <option value="F">F</option>
                    </select>
                    {#if isEditGenderMismatch(candidate)}
                      <span class="mismatch-warn">⚠ {t('identity_gender_mismatch')}</span>
                    {/if}
                  </label>
                  <label class="form-field">
                    <span class="field-label">{t('identity_birth_year')}</span>
                    <input data-field="birth-year-input" type="number" class="field-input" bind:value={editBirthYear} placeholder="e.g. 1970" />
                  </label>
                  <label class="form-field">
                    <span class="field-label">{t('identity_birth_year_type')}</span>
                    <select data-field="birth-year-estimated" class="field-input" bind:value={editBirthYearEstimated}>
                      <option value={false}>{t('identity_birth_year_exact')}</option>
                      <option value={true}>{t('identity_birth_year_estimated')}</option>
                    </select>
                  </label>
                </div>
              </div>

              <div class="form-actions">
                <button data-field="save-btn" class="action-btn save" disabled={!canSave} onclick={() => { handleSave(candidate) }}>
                  {t('identity_save')}
                </button>
                {#if candidate.enum_status === 'PENDING' || candidate.enum_status === 'UNMATCHED' || candidate.enum_status === 'AUTO_MATCHED'}
                  <button data-field="dismiss-btn" class="action-btn dismiss" onclick={() => { ondismiss(candidate.id_match); editingMatchId = null }}>
                    {t('identity_dismiss')}
                  </button>
                {/if}
                <button class="action-btn cancel" onclick={() => { editingMatchId = null }}>
                  {t('import_cancel')}
                </button>
              </div>
            </div>
          {/if}
        </div>
      {/each}
    </div>
  </div>
{/if}

<script lang="ts">
  import type { MatchCandidate, MatchStatus, FencerListItem, GenderType } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  let {
    candidates = [] as MatchCandidate[],
    fencers = [] as FencerListItem[],
    isAdmin = false,
    errorMsg = null as string | null,
    onapprove = (_id: number, _fencerId: number) => {},
    onassign = (_id: number, _fencerId: number) => {},
    oncreatenew = (_id: number, _surname: string, _firstName: string, _gender: GenderType, _birthYear?: number, _birthYearEstimated?: boolean) => {},
    ondismiss = (_id: number) => {},
    onupdategender = (_fencerId: number, _gender: GenderType) => {},
  }: {
    candidates?: MatchCandidate[]
    fencers?: FencerListItem[]
    isAdmin?: boolean
    errorMsg?: string | null
    onapprove?: (id: number, fencerId: number) => void
    onassign?: (id: number, fencerId: number) => void
    oncreatenew?: (id: number, surname: string, firstName: string, gender: GenderType, birthYear?: number, birthYearEstimated?: boolean) => void
    ondismiss?: (id: number) => void
    onupdategender?: (fencerId: number, gender: GenderType) => void
  } = $props()

  let statusFilter = $state<MatchStatus | 'ALL'>('PENDING')
  let editingMatchId: number | null = $state(null)

  // Edit form state
  let editChoice = $state<'NEW' | 'SUGGESTED' | 'SEARCH'>('NEW')
  let editSurname = $state('')
  let editFirstName = $state('')
  let editGender = $state<GenderType>('M')
  let editBirthYear: number | undefined = $state(undefined)
  let editBirthYearEstimated = $state(true)
  let editFencerId: number | null = $state(null)
  let searchQuery = $state('')

  const statusKeys: MatchStatus[] = ['PENDING', 'AUTO_MATCHED', 'UNMATCHED', 'APPROVED', 'NEW_FENCER', 'DISMISSED']

  let statusCounts = $derived(
    new Map(statusKeys.map(s => [s, candidates.filter(c => c.enum_status === s).length]))
  )

  let filteredCandidates = $derived(
    statusFilter === 'ALL'
      ? candidates
      : candidates.filter(c => c.enum_status === statusFilter)
  )

  let filteredFencers = $derived(
    searchQuery.length === 0
      ? fencers
      : fencers.filter(f => {
          const q = searchQuery.toLowerCase()
          return f.txt_surname.toLowerCase().includes(q) || f.txt_first_name.toLowerCase().includes(q)
        })
  )

  let displayedFencers = $derived(filteredFencers.slice(0, 50))

  let canSave = $derived(
    editSurname.trim().length > 0 && editFirstName.trim().length > 0
      && (editChoice !== 'SEARCH' || editFencerId != null)
  )

  function confidenceClass(confidence: number | null): string {
    if (confidence == null) return 'confidence-low'
    if (confidence >= 95) return 'confidence-high'
    if (confidence >= 50) return 'confidence-medium'
    return 'confidence-low'
  }

  function isReadOnly(candidate: MatchCandidate): boolean {
    return candidate.num_confidence === 100 && candidate.enum_status === 'APPROVED'
  }

  function isGenderMismatch(candidate: MatchCandidate): boolean {
    return candidate.enum_fencer_gender != null
      && candidate.enum_tournament_gender != null
      && candidate.enum_fencer_gender !== candidate.enum_tournament_gender
  }

  function isEditGenderMismatch(candidate: MatchCandidate): boolean {
    return candidate.enum_tournament_gender != null && editGender !== candidate.enum_tournament_gender
  }

  function toggleEdit(candidate: MatchCandidate) {
    if (editingMatchId === candidate.id_match) {
      editingMatchId = null
      return
    }
    editingMatchId = candidate.id_match
    searchQuery = ''
    editFencerId = null

    if (candidate.id_fencer != null && candidate.txt_fencer_name) {
      editChoice = 'SUGGESTED'
      editFencerId = candidate.id_fencer
      const f = fencers.find(x => x.id_fencer === candidate.id_fencer)
      if (f) {
        editSurname = f.txt_surname.toUpperCase()
        editFirstName = f.txt_first_name
        editGender = f.enum_gender ?? candidate.enum_tournament_gender ?? 'M'
        editBirthYear = f.int_birth_year ?? undefined
        editBirthYearEstimated = false
      }
    } else {
      editChoice = 'NEW'
      prefillFromScrapedName(candidate)
    }
  }

  function prefillFromScrapedName(candidate: MatchCandidate) {
    const name = candidate.txt_scraped_name
    const spaceIdx = name.indexOf(' ')
    editSurname = (spaceIdx > 0 ? name.substring(0, spaceIdx) : name).toUpperCase()
    editFirstName = spaceIdx > 0 ? name.substring(spaceIdx + 1) : ''
    editGender = candidate.enum_tournament_gender ?? 'M'
    editBirthYear = undefined
    editBirthYearEstimated = true
    editFencerId = null
  }

  function handleChoiceChange(candidate: MatchCandidate, value: string) {
    editChoice = value as 'NEW' | 'SUGGESTED' | 'SEARCH'
    searchQuery = ''

    if (value === 'NEW') {
      prefillFromScrapedName(candidate)
    } else if (value === 'SUGGESTED' && candidate.id_fencer != null) {
      editFencerId = candidate.id_fencer
      const f = fencers.find(x => x.id_fencer === candidate.id_fencer)
      if (f) {
        editSurname = f.txt_surname.toUpperCase()
        editFirstName = f.txt_first_name
        editGender = f.enum_gender ?? candidate.enum_tournament_gender ?? 'M'
        editBirthYear = f.int_birth_year ?? undefined
      }
    } else if (value === 'SEARCH') {
      editFencerId = null
      editSurname = ''
      editFirstName = ''
      editGender = candidate.enum_tournament_gender ?? 'M'
      editBirthYear = undefined
    }
  }

  function selectExistingFencer(fc: FencerListItem) {
    editFencerId = fc.id_fencer
    editSurname = fc.txt_surname.toUpperCase()
    editFirstName = fc.txt_first_name
    editGender = fc.enum_gender ?? editGender
    editBirthYear = fc.int_birth_year ?? undefined
  }

  // Auto-close form when the edited candidate's status changes (parent reloaded)
  $effect(() => {
    if (editingMatchId != null) {
      const c = candidates.find(x => x.id_match === editingMatchId)
      if (!c || c.enum_status === 'APPROVED' || c.enum_status === 'NEW_FENCER' || c.enum_status === 'DISMISSED') {
        editingMatchId = null
      }
    }
  })

  function handleSave(candidate: MatchCandidate) {
    const surname = editSurname.trim().toUpperCase()
    const firstName = editFirstName.trim()

    if (editChoice === 'NEW') {
      oncreatenew(candidate.id_match, surname, firstName, editGender, editBirthYear || undefined, editBirthYearEstimated)
    } else if (editFencerId != null) {
      if (editChoice === 'SUGGESTED' && candidate.id_fencer === editFencerId) {
        onapprove(candidate.id_match, editFencerId)
      } else {
        onassign(candidate.id_match, editFencerId)
      }
      const f = fencers.find(x => x.id_fencer === editFencerId)
      if (f && f.enum_gender !== editGender) {
        onupdategender(editFencerId, editGender)
      }
    }
    // Form stays open — auto-closes via $effect when status changes on reload.
    // If error occurs, errorMsg shows while form is still visible.
  }
</script>

<style>
  .identity-queue { padding: 16px; }
  .queue-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; flex-wrap: wrap; gap: 8px; }
  .queue-header h3 { margin: 0; font-size: 18px; color: #333; }
  .status-counts { display: flex; gap: 6px; flex-wrap: wrap; }
  .count-badge { font-size: 11px; padding: 2px 8px; border-radius: 10px; font-weight: 600; background: #e9ecef; color: #555; }
  .count-badge.count-pending { background: #fff3cd; color: #856404; }
  .count-badge.count-approved { background: #d4edda; color: #155724; }
  .count-badge.count-unmatched { background: #f8d7da; color: #721c24; }
  .error-banner { margin-bottom: 12px; padding: 10px 14px; background: #fff0f0; border: 1px solid #fcc; border-radius: 4px; color: #c33; font-size: 13px; }
  .filter-bar { margin-bottom: 12px; }
  .status-filter { padding: 6px 12px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px; }

  .candidate-list { display: flex; flex-direction: column; gap: 8px; }
  .candidate-card { border: 1px solid #e0e0e0; border-radius: 6px; background: #fff; }
  .candidate-card.editing { border-color: #4a90d9; box-shadow: 0 2px 8px rgba(74,144,217,0.15); }

  .card-header { display: flex; align-items: center; justify-content: space-between; padding: 10px 14px; cursor: pointer; gap: 10px; }
  .card-header:hover { background: #f8f9fa; }
  .header-left { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
  .header-right { display: flex; align-items: center; gap: 8px; flex-shrink: 0; flex-wrap: wrap; }
  .scraped-name { font-weight: 600; color: #333; font-size: 14px; }
  .tournament-code { font-size: 11px; color: #888; }
  .suggested-name { font-size: 12px; color: #555; }

  .confidence-badge { padding: 2px 8px; border-radius: 10px; font-size: 12px; font-weight: 600; }
  .confidence-high { background: #d4edda; color: #155724; }
  .confidence-medium { background: #fff3cd; color: #856404; }
  .confidence-low { background: #f8d7da; color: #721c24; }

  .status-badge { font-size: 11px; padding: 2px 8px; border-radius: 10px; font-weight: 600; }
  .status-badge.status-pending { background: #fff3cd; color: #856404; }
  .status-badge.status-auto_matched { background: #d4edda; color: #155724; }
  .status-badge.status-unmatched { background: #f8d7da; color: #721c24; }
  .status-badge.status-approved { background: #d4edda; color: #155724; }
  .status-badge.status-new_fencer { background: #cce5ff; color: #004085; }
  .status-badge.status-dismissed { background: #e9ecef; color: #555; }
  .mismatch-icon { color: #dc3545; font-size: 14px; }
  .edit-toggle { border: none; background: none; cursor: pointer; font-size: 12px; color: #888; padding: 2px 6px; }

  .edit-form { padding: 14px; border-top: 1px solid #e0e0e0; background: #f8f9fa; }
  .form-row { margin-bottom: 12px; }
  .form-label { display: block; font-size: 12px; font-weight: 600; color: #555; margin-bottom: 4px; }
  .fencer-choice-select { width: 100%; padding: 8px 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px; background: #fff; }

  .search-panel { margin-bottom: 12px; }
  .search-input { width: 100%; padding: 8px 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px; margin-bottom: 8px; box-sizing: border-box; }
  .search-results { max-height: 200px; overflow-y: auto; display: flex; flex-direction: column; gap: 4px; }
  .fencer-option { display: flex; align-items: center; gap: 8px; padding: 6px 10px; border: 1px solid #e0e0e0; border-radius: 4px; cursor: pointer; font-size: 13px; background: #fff; }
  .fencer-option:hover { border-color: #4a90d9; }
  .fencer-option.selected { border-color: #4a90d9; background: #f0f7ff; }
  .fencer-name { font-weight: 600; color: #333; }
  .fencer-detail { font-size: 12px; color: #555; }
  .gender-badge { font-size: 11px; padding: 1px 5px; border-radius: 6px; font-weight: 600; background: #e9ecef; color: #555; }
  .truncation-notice, .no-results { text-align: center; font-size: 12px; color: #888; padding: 8px; }

  .form-fields { margin-bottom: 12px; }
  .field-row { display: flex; gap: 12px; margin-bottom: 10px; }
  .form-field { flex: 1; display: flex; flex-direction: column; gap: 4px; }
  .field-label { font-size: 12px; font-weight: 600; color: #555; }
  .field-input { padding: 7px 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px; }
  .field-input.surname { text-transform: uppercase; font-weight: 600; }
  .gender-mismatch-select { border-color: #dc3545; color: #dc3545; }
  .mismatch-warn { font-size: 11px; color: #dc3545; margin-top: 2px; }

  .form-actions { display: flex; gap: 8px; }
  .action-btn { padding: 7px 16px; border: none; border-radius: 4px; font-size: 13px; cursor: pointer; font-weight: 600; }
  .action-btn.save { background: #4a90d9; color: #fff; }
  .action-btn.save:disabled { background: #b0c4de; cursor: not-allowed; }
  .action-btn.dismiss { background: #f8d7da; color: #721c24; }
  .action-btn.cancel { background: #e9ecef; color: #555; }

  @media (max-width: 600px) {
    .field-row { flex-direction: column; gap: 8px; }
    .card-header { flex-direction: column; align-items: flex-start; }
    .header-right { width: 100%; justify-content: flex-start; }
  }
</style>
