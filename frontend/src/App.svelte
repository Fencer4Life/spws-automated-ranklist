<div class="ranklist-app">
  <header class="app-header">
    <h1>SPWS Ranklist</h1>
    <div class="season-selector">
      <select bind:value={selectedSeasonId} onchange={loadRanking}>
        {#each seasons as s}
          <option value={s.id_season}>{s.txt_code}{s.bool_active ? ' (active)' : ''}</option>
        {/each}
      </select>
    </div>
    <button class="btn-export" title="Export to ODS" onclick={handleMainExport}>&#9113;</button>
  </header>

  <FilterBar
    weapon={filters.weapon}
    gender={filters.gender}
    category={filters.category}
    mode={filters.mode}
    onfilterchange={onFilterChange}
  />

  {#if loading}
    <SkeletonLoader rows={10} />
  {:else}
    <RanklistTable
      mode={filters.mode}
      ppwRows={ppwRows}
      kadraRows={kadraRows}
      onrowclick={openDrilldown}
    />
  {/if}

  <DrilldownModal
    open={modalOpen}
    fencerName={modalFencerName}
    scores={modalScores}
    mode={filters.mode}
    kadraDisabled={filters.category === 'V0'}
    loading={modalLoading}
    context={modalContext}
    rankingRules={rankingRules}
    onclose={closeDrilldown}
  />

  {#if error}
    <div class="error-banner">{error}</div>
  {/if}
</div>

<script lang="ts">
  import type {
    Season,
    RankingPpwRow,
    RankingKadraRow,
    ScoreRow,
    DrilldownContext,
    WeaponType,
    GenderType,
    AgeCategory,
    RankingMode,
    Filters,
    RankingRules,
  } from './lib/types'
  import {
    initClient,
    fetchSeasons,
    fetchRankingPpw,
    fetchRankingKadra,
    fetchFencerScores,
    fetchRankingRules,
  } from './lib/api'
  import {
    MOCK_SEASONS,
    MOCK_PPW_ROWS,
    MOCK_KADRA_ROWS,
    MOCK_SCORES,
    MOCK_DRILLDOWN,
  } from './lib/mock-data'
  import { exportRankingPpw, exportRankingKadra } from './lib/export'
  import FilterBar from './components/FilterBar.svelte'
  import RanklistTable from './components/RanklistTable.svelte'
  import DrilldownModal from './components/DrilldownModal.svelte'
  import SkeletonLoader from './components/SkeletonLoader.svelte'

  let {
    'supabase-url': supabaseUrl = '',
    'supabase-key': supabaseKey = '',
    demo = false,
  }: {
    'supabase-url'?: string
    'supabase-key'?: string
    demo?: boolean
  } = $props()

  let seasons: Season[] = $state([])
  let selectedSeasonId: number | null = $state(null)
  let filters: Filters = $state({
    season: null,
    weapon: 'EPEE',
    gender: 'M',
    category: 'V2',
    mode: 'PPW',
  })
  let ppwRows: RankingPpwRow[] = $state([])
  let kadraRows: RankingKadraRow[] = $state([])
  let loading = $state(false)
  let error: string | null = $state(null)

  let rankingRules: RankingRules | null = $state(null)

  let modalOpen = $state(false)
  let modalFencerName = $state('')
  let modalFencerId: number | null = $state(null)
  let modalScores: ScoreRow[] = $state([])
  let modalLoading = $state(false)
  let modalContext: DrilldownContext | null = $state(null)

  $effect(() => {
    if (demo) {
      initDemo()
    } else if (supabaseUrl && supabaseKey) {
      initClient(supabaseUrl, supabaseKey)
      init()
    }
  })

  function initDemo() {
    seasons = MOCK_SEASONS
    selectedSeasonId = MOCK_SEASONS[0].id_season
    ppwRows = MOCK_PPW_ROWS
  }

  async function init() {
    try {
      seasons = await fetchSeasons()
      const active = seasons.find((s) => s.bool_active)
      if (active) {
        selectedSeasonId = active.id_season
      } else if (seasons.length > 0) {
        selectedSeasonId = seasons[0].id_season
      }
      await loadRanking()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  function onFilterChange(f: Omit<Filters, 'season'>) {
    filters = { ...filters, ...f }
    loadRanking()
  }

  async function loadRanking() {
    loading = true
    error = null
    try {
      if (demo) {
        if (filters.mode === 'PPW') {
          ppwRows = MOCK_PPW_ROWS
          kadraRows = []
        } else {
          kadraRows = MOCK_KADRA_ROWS
          ppwRows = []
        }
      } else if (filters.mode === 'PPW') {
        ppwRows = await fetchRankingPpw(
          filters.weapon,
          filters.gender,
          filters.category,
          selectedSeasonId,
        )
        kadraRows = []
        if (selectedSeasonId != null) {
          rankingRules = await fetchRankingRules(selectedSeasonId)
        }
      } else {
        kadraRows = await fetchRankingKadra(
          filters.weapon,
          filters.gender,
          filters.category,
          selectedSeasonId,
        )
        ppwRows = []
        if (selectedSeasonId != null) {
          rankingRules = await fetchRankingRules(selectedSeasonId)
        }
      }
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      loading = false
    }
  }

  async function openDrilldown(fencerId: number, fencerName: string) {
    modalOpen = true
    modalFencerName = fencerName
    modalFencerId = fencerId
    modalLoading = true
    modalScores = []
    modalContext = null
    try {
      if (demo) {
        modalScores = MOCK_SCORES[fencerId] ?? []
        modalContext = MOCK_DRILLDOWN[fencerId] ?? null
      } else if (selectedSeasonId != null) {
        modalScores = await fetchFencerScores(
          fencerId,
          selectedSeasonId,
          filters.weapon,
          filters.gender,
        )
      }
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      modalLoading = false
    }
  }

  function closeDrilldown() {
    modalOpen = false
    modalFencerId = null
    modalScores = []
    modalContext = null
  }

  function handleMainExport() {
    const title = `SPWS_${filters.mode}_${filters.weapon}_${filters.gender}_${filters.category}`
    if (filters.mode === 'PPW') {
      exportRankingPpw(ppwRows, title)
    } else {
      exportRankingKadra(kadraRows, title)
    }
  }
</script>

<style>
  .ranklist-app {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    max-width: 960px;
    margin: 0 auto;
    padding: 16px;
    color: #333;
  }
  .app-header {
    display: flex;
    align-items: center;
    gap: 16px;
    margin-bottom: 8px;
    flex-wrap: wrap;
  }
  .app-header h1 {
    margin: 0;
    font-size: 22px;
    color: #222;
  }
  .season-selector select {
    padding: 6px 10px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 14px;
    background: #fff;
  }
  .btn-export {
    margin-left: auto;
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
  .error-banner {
    margin-top: 16px;
    padding: 12px;
    background: #fff0f0;
    border: 1px solid #fcc;
    border-radius: 4px;
    color: #c33;
    font-size: 14px;
  }

  @media (max-width: 600px) {
    .ranklist-app {
      padding: 10px;
    }
    .app-header h1 {
      font-size: 18px;
    }
    .app-header {
      gap: 10px;
    }
  }
</style>
