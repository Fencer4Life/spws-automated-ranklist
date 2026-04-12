{#if isAdmin}
  <div data-field="birth-year-review" class="birth-year-review">
    <div class="filter-bar">
      <div class="status-counts">
        <span data-field="count-estimated" class="count-badge estimated">
          {t('birth_year_filter_estimated')}: {statusCounts.estimated}
        </span>
        <span data-field="count-missing" class="count-badge missing">
          {t('birth_year_filter_missing')}: {statusCounts.missing}
        </span>
        <span data-field="count-confirmed" class="count-badge confirmed">
          {t('birth_year_filter_confirmed')}: {statusCounts.confirmed}
        </span>
      </div>
      <div class="filters">
        <select data-field="status-filter" class="filter-select" bind:value={statusFilter}>
          <option value="ALL">{t('birth_year_filter_all')}</option>
          <option value="ESTIMATED">{t('birth_year_filter_estimated')}</option>
          <option value="MISSING">{t('birth_year_filter_missing')}</option>
          <option value="CONFIRMED">{t('birth_year_filter_confirmed')}</option>
        </select>
        <select data-field="gender-filter" class="filter-select" bind:value={genderFilter}>
          <option value="BOTH">{t('birth_year_filter_gender_both')}</option>
          <option value="M">M</option>
          <option value="F">F</option>
        </select>
        <input
          data-field="search-box"
          type="text"
          class="search-box"
          placeholder={t('birth_year_search_placeholder')}
          bind:value={searchQuery}
        />
      </div>
    </div>

    <div class="fencer-list">
      {#each filteredFencers as fencer (fencer.id_fencer)}
        {@const expanded = expandedFencerId === fencer.id_fencer}
        <div data-field="fencer-row" class="fencer-card" class:expanded>
          <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
          <div class="card-header" onclick={() => { toggleExpand(fencer.id_fencer) }}>
            <div class="header-left">
              <span class="fencer-name">{fencer.txt_surname} {fencer.txt_first_name}</span>
              {#if fencer.txt_club}
                <span class="fencer-detail">{fencer.txt_club}</span>
              {/if}
            </div>
            <div class="header-right">
              {#if fencer.enum_gender}
                <span class="gender-badge">{fencer.enum_gender}</span>
              {/if}
              <span class="birth-year-display">{fencer.int_birth_year ?? '—'}</span>
              <span data-field="by-status-badge" class="by-status-badge {birthYearStatusClass(fencer)}">
                {birthYearStatusLabel(fencer)}
              </span>
              <span class="expand-toggle">{expanded ? '▲' : '▼'}</span>
            </div>
          </div>

          {#if expanded}
            <div data-field="edit-form" class="edit-form">
              {#if errorMsg}
                <div class="error-banner">{errorMsg}</div>
              {/if}

              <!-- Read-only fencer info -->
              <div class="readonly-fields">
                <div class="ro-row">
                  <span class="ro-label">{t('identity_surname')}</span>
                  <span class="ro-value">{fencer.txt_surname}</span>
                </div>
                <div class="ro-row">
                  <span class="ro-label">{t('identity_first_name')}</span>
                  <span class="ro-value">{fencer.txt_first_name}</span>
                </div>
                <div class="ro-row">
                  <span class="ro-label">{t('identity_gender')}</span>
                  <span class="ro-value">{fencer.enum_gender ?? '—'}</span>
                </div>
                <div class="ro-row">
                  <span class="ro-label">{t('birth_year_club')}</span>
                  <span class="ro-value">{fencer.txt_club ?? '—'}</span>
                </div>
                <div class="ro-row">
                  <span class="ro-label">{t('birth_year_nationality')}</span>
                  <span class="ro-value">{fencer.txt_nationality ?? '—'}</span>
                </div>
              </div>

              <!-- Editable birth year -->
              <div class="edit-fields">
                <div class="field-row">
                  <label class="form-field">
                    <span class="field-label">{t('identity_birth_year')}</span>
                    <input data-field="birth-year-input" type="number" class="field-input" bind:value={editBirthYear} placeholder="e.g. 1970" />
                  </label>
                  <label class="form-field">
                    <span class="field-label">{t('identity_birth_year_type')}</span>
                    <select data-field="birth-year-estimated" class="field-input" bind:value={editEstimated}>
                      <option value={false}>{t('identity_birth_year_exact')}</option>
                      <option value={true}>{t('identity_birth_year_estimated')}</option>
                    </select>
                  </label>
                </div>

                {#if birthYearHint}
                  <div data-field="birth-year-hint" class="hint-box">
                    {birthYearHint}
                  </div>
                {/if}

                {#if inconsistencyWarning}
                  <div data-field="inconsistency-flag" class="warning-box">
                    ⚠ {inconsistencyWarning}
                  </div>
                {/if}
              </div>

              <!-- Tournament history -->
              <div class="history-section">
                <h4>{t('birth_year_tournament_history')}</h4>
                {#if historyLoading}
                  <div class="loading">Loading...</div>
                {:else if Object.keys(historyBySeason).length === 0}
                  <div class="no-history">—</div>
                {:else}
                  {#each Object.entries(historyBySeason) as [season, rows]}
                    <div data-field="season-group" class="season-group">
                      <div class="season-header">{season}</div>
                      {#each rows as row}
                        <div data-field="tournament-row" class="tournament-row">
                          <span class="t-category">{row.enum_age_category}</span>
                          <span class="t-weapon">{row.enum_weapon}</span>
                          <span class="t-gender">{row.enum_gender}</span>
                          <span class="t-code">{row.txt_tournament_code}</span>
                          <span class="t-place">#{row.int_place}</span>
                          {#if row.num_final_score != null}
                            <span class="t-score">{row.num_final_score} pts</span>
                          {/if}
                          {#if row.txt_location}
                            <span class="t-location">{row.txt_location}</span>
                          {/if}
                        </div>
                      {/each}
                    </div>
                  {/each}
                {/if}
              </div>

              <div class="form-actions">
                <button data-field="save-btn" class="action-btn save" disabled={!editBirthYear} onclick={() => { handleSave(fencer) }}>
                  {t('birth_year_save')}
                </button>
                <button class="action-btn cancel" onclick={() => { expandedFencerId = null }}>
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
  import type { FencerListItem, FencerTournamentRow, BirthYearFilter, GenderType, AgeCategory } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  let {
    fencers = [] as FencerListItem[],
    isAdmin = false,
    errorMsg = null as string | null,
    onupdatebirthyear = (_fencerId: number, _birthYear: number, _estimated: boolean) => {},
    onfetchhistory = (_fencerId: number): Promise<FencerTournamentRow[]> => Promise.resolve([]),
  }: {
    fencers?: FencerListItem[]
    isAdmin?: boolean
    errorMsg?: string | null
    onupdatebirthyear?: (fencerId: number, birthYear: number, estimated: boolean) => void
    onfetchhistory?: (fencerId: number) => Promise<FencerTournamentRow[]>
  } = $props()

  let statusFilter = $state<BirthYearFilter>('ALL')
  let genderFilter = $state<GenderType | 'BOTH'>('BOTH')
  let searchQuery = $state('')
  let expandedFencerId: number | null = $state(null)
  let editBirthYear: number | undefined = $state(undefined)
  let editEstimated = $state(false)
  let tournamentHistory: FencerTournamentRow[] = $state([])
  let historyLoading = $state(false)

  const AGE_THRESHOLDS: Record<AgeCategory, number> = { V0: 30, V1: 40, V2: 50, V3: 60, V4: 70 }

  let statusCounts = $derived({
    estimated: fencers.filter(f => f.int_birth_year != null && f.bool_birth_year_estimated).length,
    missing: fencers.filter(f => f.int_birth_year == null).length,
    confirmed: fencers.filter(f => f.int_birth_year != null && !f.bool_birth_year_estimated).length,
  })

  let filteredFencers = $derived((() => {
    let list = fencers
    if (statusFilter === 'ESTIMATED') list = list.filter(f => f.int_birth_year != null && f.bool_birth_year_estimated)
    else if (statusFilter === 'MISSING') list = list.filter(f => f.int_birth_year == null)
    else if (statusFilter === 'CONFIRMED') list = list.filter(f => f.int_birth_year != null && !f.bool_birth_year_estimated)

    if (genderFilter !== 'BOTH') list = list.filter(f => f.enum_gender === genderFilter)

    if (searchQuery.length > 0) {
      const q = searchQuery.toLowerCase()
      list = list.filter(f => f.txt_surname.toLowerCase().includes(q) || f.txt_first_name.toLowerCase().includes(q))
    }

    return [...list].sort((a, b) => a.txt_surname.localeCompare(b.txt_surname))
  })())

  let historyBySeason = $derived((() => {
    const groups: Record<string, FencerTournamentRow[]> = {}
    for (const row of tournamentHistory) {
      const key = row.txt_season_code
      if (!groups[key]) groups[key] = []
      groups[key].push(row)
    }
    return groups
  })())

  let birthYearHint = $derived((() => {
    if (tournamentHistory.length === 0) return null
    // Find youngest category (lowest threshold = V0)
    let youngestCat: AgeCategory | null = null
    let youngestThreshold = Infinity
    let hintSeason = ''
    for (const row of tournamentHistory) {
      const threshold = AGE_THRESHOLDS[row.enum_age_category]
      if (threshold < youngestThreshold) {
        youngestThreshold = threshold
        youngestCat = row.enum_age_category
        hintSeason = row.txt_season_code
      }
    }
    if (youngestCat == null) return null
    // Compute expected range from season end year
    const seasonEndYear = parseInt(hintSeason.replace(/.*(\d{4})$/, '$1')) || null
    if (!seasonEndYear) return null
    const newest = seasonEndYear - youngestThreshold
    const oldest = newest - 9
    return t('birth_year_age_hint', { cat: youngestCat, season: hintSeason, min: oldest, max: newest })
  })())

  let inconsistencyWarning = $derived((() => {
    if (!editBirthYear || editEstimated) return null
    for (const row of tournamentHistory) {
      const seasonEndYear = parseInt(row.txt_season_code.replace(/.*(\d{4})$/, '$1')) || null
      if (!seasonEndYear) continue
      const age = seasonEndYear - editBirthYear
      const expectedCat = ageCategoryFromAge(age)
      if (expectedCat && expectedCat !== row.enum_age_category) {
        return t('birth_year_inconsistency') + `: ${row.txt_tournament_code} (${row.enum_age_category}) — ${t('birth_year_age_hint', { cat: expectedCat, season: row.txt_season_code, min: '', max: '' }).split(':')[0]}`
      }
    }
    return null
  })())

  function ageCategoryFromAge(age: number): AgeCategory | null {
    if (age >= 70) return 'V4'
    if (age >= 60) return 'V3'
    if (age >= 50) return 'V2'
    if (age >= 40) return 'V1'
    if (age >= 30) return 'V0'
    return null
  }

  function birthYearStatusClass(f: FencerListItem): string {
    if (f.int_birth_year == null) return 'missing'
    return f.bool_birth_year_estimated ? 'estimated' : 'confirmed'
  }

  function birthYearStatusLabel(f: FencerListItem): string {
    if (f.int_birth_year == null) return t('birth_year_filter_missing')
    return f.bool_birth_year_estimated ? t('birth_year_filter_estimated') : t('birth_year_filter_confirmed')
  }

  async function toggleExpand(fencerId: number) {
    if (expandedFencerId === fencerId) {
      expandedFencerId = null
      return
    }
    expandedFencerId = fencerId
    const fencer = fencers.find(f => f.id_fencer === fencerId)
    editEstimated = fencer?.bool_birth_year_estimated ?? true

    // Auto-suggest: pre-fill with existing value, or compute from history
    editBirthYear = fencer?.int_birth_year ?? undefined

    // Load tournament history
    historyLoading = true
    tournamentHistory = []
    try {
      tournamentHistory = await onfetchhistory(fencerId)
      // Auto-suggest if no birth year: youngest boundary of youngest category
      if (editBirthYear == null && tournamentHistory.length > 0) {
        let youngestThreshold = Infinity
        let suggestSeason = ''
        for (const row of tournamentHistory) {
          const threshold = AGE_THRESHOLDS[row.enum_age_category]
          if (threshold < youngestThreshold) {
            youngestThreshold = threshold
            suggestSeason = row.txt_season_code
          }
        }
        const seasonEndYear = parseInt(suggestSeason.replace(/.*(\d{4})$/, '$1')) || null
        if (seasonEndYear) {
          editBirthYear = seasonEndYear - youngestThreshold
          editEstimated = true
        }
      }
    } catch {
      // history fetch failed — form still usable
    } finally {
      historyLoading = false
    }
  }

  function handleSave(fencer: FencerListItem) {
    if (editBirthYear) {
      onupdatebirthyear(fencer.id_fencer, editBirthYear, editEstimated)
    }
  }
</script>

<style>
  .birth-year-review { padding: 0; }
  .filter-bar { margin-bottom: 12px; }
  .status-counts { display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 8px; }
  .count-badge { font-size: 11px; padding: 2px 8px; border-radius: 10px; font-weight: 600; }
  .count-badge.estimated { background: #fff3cd; color: #856404; }
  .count-badge.missing { background: #f8d7da; color: #721c24; }
  .count-badge.confirmed { background: #d4edda; color: #155724; }
  .filters { display: flex; gap: 8px; flex-wrap: wrap; }
  .filter-select { padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px; }
  .search-box { padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px; width: 200px; }

  .fencer-list { display: flex; flex-direction: column; gap: 6px; }
  .fencer-card { border: 1px solid #e0e0e0; border-radius: 6px; background: #fff; }
  .fencer-card.expanded { border-color: #4a90d9; box-shadow: 0 2px 8px rgba(74,144,217,0.15); }
  .card-header { display: flex; align-items: center; justify-content: space-between; padding: 10px 14px; cursor: pointer; gap: 10px; }
  .card-header:hover { background: #f8f9fa; }
  .header-left { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
  .header-right { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
  .fencer-name { font-weight: 600; font-size: 14px; color: #333; }
  .fencer-detail { font-size: 12px; color: #555; }
  .gender-badge { font-size: 11px; padding: 1px 5px; border-radius: 6px; font-weight: 600; background: #e9ecef; color: #555; }
  .birth-year-display { font-size: 13px; font-weight: 600; color: #333; }
  .by-status-badge { font-size: 11px; padding: 2px 8px; border-radius: 10px; font-weight: 600; }
  .by-status-badge.estimated { background: #fff3cd; color: #856404; }
  .by-status-badge.missing { background: #f8d7da; color: #721c24; }
  .by-status-badge.confirmed { background: #d4edda; color: #155724; }
  .expand-toggle { color: #888; font-size: 12px; }

  .edit-form { padding: 14px; border-top: 1px solid #e0e0e0; background: #f8f9fa; }
  .error-banner { margin-bottom: 10px; padding: 8px 12px; background: #fff0f0; border: 1px solid #fcc; border-radius: 4px; color: #c33; font-size: 13px; }
  .readonly-fields { display: grid; grid-template-columns: 1fr 1fr; gap: 6px 16px; margin-bottom: 14px; padding: 10px; background: #fff; border-radius: 4px; border: 1px solid #eee; }
  .ro-row { display: flex; gap: 6px; align-items: baseline; }
  .ro-label { font-size: 12px; font-weight: 600; color: #888; min-width: 80px; }
  .ro-value { font-size: 13px; color: #333; }

  .edit-fields { margin-bottom: 14px; }
  .field-row { display: flex; gap: 12px; margin-bottom: 8px; }
  .form-field { flex: 1; display: flex; flex-direction: column; gap: 4px; }
  .field-label { font-size: 12px; font-weight: 600; color: #555; }
  .field-input { padding: 7px 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px; }

  .hint-box { padding: 8px 12px; background: #e8f4fd; border: 1px solid #bee5eb; border-radius: 4px; font-size: 12px; color: #0c5460; margin-bottom: 8px; }
  .warning-box { padding: 8px 12px; background: #fff3cd; border: 1px solid #ffc107; border-radius: 4px; font-size: 12px; color: #856404; margin-bottom: 8px; }

  .history-section { margin-bottom: 14px; }
  .history-section h4 { font-size: 13px; color: #555; margin: 0 0 8px; }
  .loading, .no-history { font-size: 12px; color: #888; }
  .season-group { margin-bottom: 8px; }
  .season-header { font-size: 12px; font-weight: 700; color: #4a90d9; padding: 4px 0; border-bottom: 1px solid #e0e0e0; margin-bottom: 4px; }
  .tournament-row { display: flex; gap: 8px; padding: 3px 0; font-size: 12px; color: #333; flex-wrap: wrap; }
  .t-category { font-weight: 600; color: #555; }
  .t-weapon { color: #555; }
  .t-gender { color: #888; }
  .t-code { color: #4a90d9; }
  .t-place { font-weight: 600; }
  .t-score { color: #155724; }
  .t-location { color: #888; font-style: italic; }

  .form-actions { display: flex; gap: 8px; }
  .action-btn { padding: 7px 16px; border: none; border-radius: 4px; font-size: 13px; cursor: pointer; font-weight: 600; }
  .action-btn.save { background: #4a90d9; color: #fff; }
  .action-btn.save:disabled { background: #b0c4de; cursor: not-allowed; }
  .action-btn.cancel { background: #e9ecef; color: #555; }

  @media (max-width: 600px) {
    .field-row { flex-direction: column; gap: 8px; }
    .readonly-fields { grid-template-columns: 1fr; }
    .filters { flex-direction: column; }
    .search-box { width: 100%; }
  }
</style>
