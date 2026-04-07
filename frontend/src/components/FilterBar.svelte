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

    {#if showEvfToggle}
      <div class="filter-group toggle-group">
        <span class="filter-label">{t('ranking')}</span>
        <div class="toggle" class:kadra-disabled={category === 'V0'}>
          <button
            class="toggle-btn"
            class:active={mode === 'PPW'}
            onclick={() => setMode('PPW')}
          >PPW</button>
          <button
            class="toggle-btn"
            class:active={mode === 'KADRA'}
            disabled={category === 'V0'}
            title={category === 'V0' ? t('kadra_disabled_title') : t('kadra_title')}
            onclick={() => setMode('KADRA')}
          >+EVF</button>
        </div>
      </div>
    {/if}

    {#if dualEnv}
      <div class="filter-group toggle-group">
        <span class="filter-label">&nbsp;</span>
        <div class="env-toggle">
          <button class="env-btn" class:active={activeEnv === 'CERT'}
            onclick={() => { activeEnv = 'CERT' }}>CT</button>
          <button class="env-btn" class:active={activeEnv === 'PROD'}
            onclick={() => { activeEnv = 'PROD' }}>PD</button>
        </div>
      </div>
    {/if}

    <button class="btn-export" title={t('export_to_ods')} onclick={onexport}>&#9113;</button>
  </div>
</div>

<script lang="ts">
  import type { WeaponType, GenderType, AgeCategory, RankingMode, Filters, Season, Environment } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  let {
    weapon = 'EPEE' as WeaponType,
    gender = 'M' as GenderType,
    category = 'V2' as AgeCategory,
    mode = 'PPW' as RankingMode,
    showEvfToggle = false,
    seasons = [] as Season[],
    selectedSeasonId = $bindable(null as number | null),
    dualEnv = false,
    activeEnv = $bindable('CERT' as Environment),
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
    dualEnv?: boolean
    activeEnv?: Environment
    onseasonchange?: () => void
    onfilterchange?: (filters: Omit<Filters, 'season'>) => void
    onexport?: () => void
  } = $props()

  function emitChange() {
    onfilterchange?.({ weapon, gender, category, mode })
  }

  function onCategoryChange() {
    if (category === 'V0' && mode === 'KADRA') {
      mode = 'PPW'
    }
    emitChange()
  }

  function setMode(m: RankingMode) {
    if (m === 'KADRA' && category === 'V0') return
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
  .env-toggle {
    display: flex;
    border: 1px solid #ccc;
    border-radius: 4px;
    overflow: hidden;
  }
  .env-btn {
    padding: 4px 10px;
    border: none;
    background: #fff;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    letter-spacing: 0.5px;
    transition: all 0.15s;
  }
  .env-btn:first-child {
    border-right: 1px solid #ccc;
  }
  .env-btn.active {
    background: #4a90d9;
    color: #fff;
  }
  .btn-export {
    margin-left: auto;
    align-self: flex-end;
    background: none;
    border: 1px solid #ccc;
    border-radius: 4px;
    padding: 6px 12px;
    font-size: 16px;
    cursor: pointer;
    color: #555;
  }
  .btn-export:hover {
    background: #f0f0f0;
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
  select {
    padding: 6px 10px;
    border: 1px solid #ccc;
    border-radius: 4px;
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
  .toggle {
    display: flex;
    border: 1px solid #ccc;
    border-radius: 4px;
    overflow: hidden;
  }
  .toggle-btn {
    padding: 6px 14px;
    border: none;
    background: #fff;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s;
  }
  .toggle-btn:first-child {
    border-right: 1px solid #ccc;
  }
  .toggle-btn.active {
    background: #4a90d9;
    color: #fff;
  }
  .toggle-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }
  .kadra-disabled .toggle-btn:last-child {
    background: #f5f5f5;
    color: #aaa;
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
    .toggle-btn {
      padding: 6px 10px;
      font-size: 13px;
    }
  }
</style>
