<div class="el-card">
  <div class="el-top">
    <span class="el-title">{t('reg_entry_list_title')}</span>
    <LangToggle />
  </div>

  <div class="el-metrics">
    <div class="el-metric"><div class="el-k">{t('reg_registered_count')}</div><div class="el-v">{rows.length}</div></div>
    <div class="el-metric"><div class="el-k">{t('reg_weapon_epee')}</div><div class="el-v">{countByWeapon('EPEE')}</div></div>
    <div class="el-metric"><div class="el-k">{t('reg_weapon_foil')}</div><div class="el-v">{countByWeapon('FOIL')}</div></div>
    <div class="el-metric"><div class="el-k">{t('reg_weapon_sabre')}</div><div class="el-v">{countByWeapon('SABRE')}</div></div>
  </div>

  <div class="el-filters">
    <input name="search" class="el-search" placeholder={t('reg_search_surname')} bind:value={search} />
    <select name="weaponFilter" bind:value={weaponFilter}>
      <option value="">{t('reg_filter_weapon_all')}</option>
      <option value="EPEE">{t('reg_weapon_epee')}</option>
      <option value="FOIL">{t('reg_weapon_foil')}</option>
      <option value="SABRE">{t('reg_weapon_sabre')}</option>
    </select>
    <select name="genderFilter" bind:value={genderFilter}>
      <option value="">{t('reg_filter_gender_all')}</option>
      <option value="F">{t('reg_filter_women')}</option>
      <option value="M">{t('reg_filter_men')}</option>
    </select>
  </div>

  {#if filteredRows.length > 0}
    <table>
      <thead>
        <tr>
          <th class="el-lp">{t('reg_col_lp')}</th>
          <th>{t('reg_col_name')}</th>
          <th class="el-narrow">{t('reg_col_gender')}</th>
          <th>{t('reg_col_weapon')}</th>
        </tr>
      </thead>
      <tbody>
        {#each filteredRows as row, i (row.id_registration)}
          <tr>
            <td>{i + 1}</td>
            <td>{row.txt_surname} {row.txt_first_name}</td>
            <td>{row.enum_gender}</td>
            <td>
              {#each row.arr_weapons as w}
                <span class="el-wpn el-w-{weaponCode(w)}">{weaponCode(w)}</span>
              {/each}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  {:else}
    <p class="el-empty">{t('reg_no_entries')}</p>
  {/if}

  <p class="el-legend">{t('reg_weapon_legend')}</p>
</div>

<script lang="ts">
  import { t } from '../lib/locale.svelte'
  import LangToggle from './LangToggle.svelte'
  import { fetchEntryList } from '../lib/api'
  import type { RegistrationEntry, WeaponType, GenderType } from '../lib/types'

  let { eventId }: { eventId: number } = $props()

  let rows = $state<RegistrationEntry[]>([])
  let search = $state('')
  let weaponFilter = $state<WeaponType | ''>('')
  let genderFilter = $state<GenderType | ''>('')

  $effect(() => {
    fetchEntryList(eventId).then((r) => {
      rows = r
    })
  })

  const filteredRows = $derived.by(() => {
    const q = search.trim().toLowerCase()
    return rows.filter((r) => {
      if (q && !`${r.txt_surname} ${r.txt_first_name}`.toLowerCase().includes(q)) return false
      if (weaponFilter && !r.arr_weapons.includes(weaponFilter)) return false
      if (genderFilter && r.enum_gender !== genderFilter) return false
      return true
    })
  })

  function countByWeapon(w: WeaponType): number {
    return rows.filter((r) => r.arr_weapons.includes(w)).length
  }

  function weaponCode(w: WeaponType): string {
    if (w === 'EPEE') return 'E'
    if (w === 'FOIL') return 'F'
    return 'S'
  }
</script>

<style>
  .el-card {
    max-width: 760px;
    margin: 0 auto;
    background: #16213e;
    border: 1px solid #0f3460;
    border-radius: 12px;
    padding: 22px;
    color: #e0e0e0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }
  .el-top {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 16px;
  }
  .el-title {
    font-weight: 600;
    color: #fff;
    font-size: 1.05em;
  }
  .el-metrics {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 8px;
    margin-bottom: 16px;
  }
  @media (max-width: 480px) {
    .el-metrics {
      grid-template-columns: repeat(2, 1fr);
    }
  }
  .el-metric {
    background: #0d1b2a;
    border-radius: 8px;
    padding: 9px 12px;
  }
  .el-k {
    font-size: 0.72em;
    color: #7fbadc;
  }
  .el-v {
    font-size: 1.3em;
    font-weight: 600;
    color: #fff;
  }
  .el-filters {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
    margin-bottom: 14px;
  }
  .el-filters input, .el-filters select {
    background: #0d1b2a;
    border: 1px solid #1a4a8a;
    color: #e0e0e0;
    padding: 8px 10px;
    border-radius: 8px;
    font-size: 0.9em;
    font-family: inherit;
    min-height: 40px;
  }
  .el-search {
    flex: 1;
    min-width: 150px;
  }
  table {
    width: 100%;
    border-collapse: collapse;
  }
  th {
    text-align: left;
    font-size: 0.74em;
    color: #7fbadc;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    padding: 8px;
    border-bottom: 1px solid #1a4a8a;
  }
  td {
    padding: 9px 8px;
    font-size: 0.88em;
    border-bottom: 1px solid #16273f;
  }
  .el-lp, .el-narrow {
    width: 40px;
  }
  .el-wpn {
    display: inline-block;
    width: 22px;
    text-align: center;
    font-size: 0.72em;
    padding: 2px 0;
    border-radius: 6px;
    margin-right: 3px;
    font-weight: 600;
  }
  .el-w-E {
    background: rgba(96, 196, 89, 0.18);
    color: #9fe08c;
  }
  .el-w-F {
    background: rgba(0, 212, 255, 0.16);
    color: #7fd8ff;
  }
  .el-w-S {
    background: rgba(240, 159, 39, 0.18);
    color: #f0b967;
  }
  .el-empty {
    text-align: center;
    color: #8894a8;
    font-size: 0.9em;
    padding: 20px;
  }
  .el-legend {
    color: #8894a8;
    font-size: 0.78em;
    margin-top: 12px;
  }

  @media (max-width: 480px) {
    table, thead, tbody, th, td, tr {
      display: block;
    }
    thead tr {
      display: none;
    }
    tr {
      border-bottom: 1px solid #1a2c4a;
      padding: 6px 0;
    }
    td {
      border-bottom: none;
      padding: 3px 0;
    }
  }
</style>
