<div class="filter-bar">
  <div class="filter-row">
    {#if seasons.length > 0}
      <label class="filter-group">
        <span class="filter-label">{t('season_label')}</span>
        <select class="season-select" bind:value={selectedSeasonId} onchange={onseasonchange}>
          {#each seasons as s}
            <option value={s.id_season}>{s.txt_code}{s.bool_active ? ' ' + t('season_active') : ''}</option>
          {/each}
        </select>
      </label>
    {/if}
    <label class="filter-group">
      <span class="filter-label">{t('weapon')}</span>
      <select bind:value={weapon} onchange={emitChange}>
        <option value="EPEE">{t('epee')}</option>
        <option value="FOIL">{t('foil')}</option>
        <option value="SABRE">{t('sabre')}</option>
      </select>
    </label>

    <label class="filter-group">
      <span class="filter-label">{t('gender')}</span>
      <select bind:value={gender} onchange={emitChange}>
        <option value="M">{t('men')}</option>
        <option value="F">{t('women')}</option>
      </select>
    </label>

    <label class="filter-group">
      <span class="filter-label">{t('category')}</span>
      <select bind:value={category} onchange={onCategoryChange}>
        <option value="V0">V0 (30+)</option>
        <option value="V1">V1 (40+)</option>
        <option value="V2">V2 (50+)</option>
        <option value="V3">V3 (60+)</option>
        <option value="V4">V4 (70+)</option>
      </select>
    </label>

    <!-- The data controls: the view, then its ODS file, at the right end of
         the row — the same place and order as in the score drilldown. -->
    <div class="view-tools">
      {#if showEvfToggle}
        <div class="filter-group toggle-group">
          <span class="filter-label">{t('view_toggle_label')}</span>
          <ViewSwitch {mode} onchange={setMode} />
        </div>
      {/if}
      <OdsButton title={t('ods_tip_list')} onclick={() => onexport?.()} />
    </div>
  </div>
</div>

<script lang="ts">
  import type { WeaponType, GenderType, AgeCategory, RankingMode, Filters, Season } from '../lib/types'
  import { t } from '../lib/locale.svelte'
  import ViewSwitch from './ViewSwitch.svelte'
  import OdsButton from './OdsButton.svelte'

  let {
    weapon = 'EPEE' as WeaponType,
    gender = 'M' as GenderType,
    category = 'V2' as AgeCategory,
    mode = 'PPW' as RankingMode,
    showEvfToggle = false,
    seasons = [] as Season[],
    selectedSeasonId = $bindable(null as number | null),
    onseasonchange,
    onfilterchange,
    onexport,
  }: {
    weapon?: WeaponType
    gender?: GenderType
    category?: AgeCategory
    mode?: RankingMode
    showEvfToggle?: boolean
    seasons?: Season[]
    selectedSeasonId?: number | null
    onseasonchange?: () => void
    onfilterchange?: (filters: Omit<Filters, 'season'>) => void
    onexport?: () => void
  } = $props()

  function emitChange() {
    onfilterchange?.({ weapon, gender, category, mode })
  }

  function onCategoryChange() {
    emitChange()
  }

  function setMode(m: RankingMode) {
    mode = m
    emitChange()
  }
</script>

<style>
  .filter-bar {
    padding: 8px 0;
  }
  .filter-row {
    display: flex;
    gap: 16px;
    align-items: flex-end;
    flex-wrap: wrap;
  }
  .view-tools {
    margin-left: auto;
    display: flex;
    align-items: flex-end;
    gap: 8px;
  }
  .filter-group {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .filter-label {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    color: #666;
    letter-spacing: 0.5px;
  }
  /* 38 px, the height of the view switch and the ODS button, so the whole
     row lines up. */
  select {
    height: 38px;
    padding: 0 10px;
    border: 1px solid #c7ced8;
    border-radius: 8px;
    font-size: 14px;
    background: #fff;
    cursor: pointer;
  }
  select:focus {
    outline: 2px solid #4a90d9;
    outline-offset: -1px;
  }
  .toggle-group {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  @media (max-width: 600px) {
    .filter-row {
      gap: 10px;
    }
    .filter-group {
      flex: 1 1 calc(50% - 10px);
      min-width: 0;
    }
    select {
      width: 100%;
      font-size: 13px;
    }
    /* The view switch fills its own row with the ODS button beside it; the
       switch names itself, so the "Widok" label above it is dropped. */
    .view-tools {
      flex: 1 1 100%;
      margin-left: 0;
      align-items: center;
    }
    .view-tools .toggle-group {
      flex: 1 1 auto;
    }
    .view-tools .toggle-group .filter-label {
      display: none;
    }
  }
</style>
