<div class="filter-bar">
  <div class="filter-row">
    <label class="filter-group">
      <span class="filter-label">Weapon</span>
      <select bind:value={weapon} onchange={emitChange}>
        <option value="EPEE">Epee</option>
        <option value="FOIL">Foil</option>
        <option value="SABRE">Sabre</option>
      </select>
    </label>

    <label class="filter-group">
      <span class="filter-label">Gender</span>
      <select bind:value={gender} onchange={emitChange}>
        <option value="M">Men</option>
        <option value="F">Women</option>
      </select>
    </label>

    <label class="filter-group">
      <span class="filter-label">Category</span>
      <select bind:value={category} onchange={onCategoryChange}>
        <option value="V0">V0 (30+)</option>
        <option value="V1">V1 (40+)</option>
        <option value="V2">V2 (50+)</option>
        <option value="V3">V3 (60+)</option>
        <option value="V4">V4 (70+)</option>
      </select>
    </label>

    <div class="filter-group toggle-group">
      <span class="filter-label">Ranking</span>
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
          title={category === 'V0' ? 'No EVF equivalent for V0' : 'Kadra ranking'}
          onclick={() => setMode('KADRA')}
        >Kadra</button>
      </div>
    </div>
  </div>
</div>

<script lang="ts">
  import type { WeaponType, GenderType, AgeCategory, RankingMode, Filters } from '../lib/types'

  let {
    weapon = 'EPEE' as WeaponType,
    gender = 'M' as GenderType,
    category = 'V2' as AgeCategory,
    mode = 'PPW' as RankingMode,
    onfilterchange,
  }: {
    weapon?: WeaponType
    gender?: GenderType
    category?: AgeCategory
    mode?: RankingMode
    onfilterchange?: (filters: Omit<Filters, 'season'>) => void
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
