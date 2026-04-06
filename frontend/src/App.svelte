<Sidebar
  open={sidebarOpen}
  currentView={currentView}
  isAdmin={isAdmin}
  {adminTimerText}
  onnavigate={(view) => { navigateTo(view) }}
  onclose={() => { sidebarOpen = false }}
  onlogout={() => { signOut() }}
/>

<div class="ranklist-app">
  <header class="app-header">
    <button class="hamburger-btn" onclick={() => { sidebarOpen = true }} aria-label="Menu">&#9776;</button>
    {#if dualEnv}
      <div class="env-toggle">
        <button class="env-btn" class:active={activeEnv === 'CERT'}
          onclick={() => { activeEnv = 'CERT' }}>CT</button>
        <button class="env-btn" class:active={activeEnv === 'PROD'}
          onclick={() => { activeEnv = 'PROD' }}>PD</button>
      </div>
    {/if}
    <h2 class="app-title">
      <img src="SPWS-logo.png" alt="SPWS" class="header-logo" />
      {currentView === 'ranklist' ? t('app_title') : currentView === 'calendar' ? t('calendar_title') : currentView === 'admin_seasons' ? t('nav_admin_seasons') : currentView === 'admin_events' ? t('nav_admin_events') : currentView === 'admin_identities' ? t('nav_admin_identities') : currentView === 'admin_scoring' ? t('nav_admin_scoring') : t('app_title')}
    </h2>
    <div class="season-selector">
      <select bind:value={selectedSeasonId} onchange={handleSeasonChange}>
        {#each seasons as s}
          <option value={s.id_season}>{s.txt_code}{s.bool_active ? ' ' + t('season_active') : ''}</option>
        {/each}
      </select>
      <label class="season-label">{t('season_label')}</label>
    </div>
    <div class="header-right">
      <LangToggle />
    </div>
  </header>

  {#if currentView === 'ranklist'}
    <FilterBar
      weapon={filters.weapon}
      gender={filters.gender}
      category={filters.category}
      mode={filters.mode}
      {showEvfToggle}
      onfilterchange={onFilterChange}
      onexport={handleMainExport}
    />

    {#if selectedSeasonId}
      {@const season = seasons.find(s => s.id_season === selectedSeasonId)}
      {#if season}
        <div class="category-subtitle">
          {birthYearSubtitle(filters.category, season.dt_end)}
        </div>
      {/if}
    {/if}

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
      {showEvfToggle}
      loading={modalLoading}
      context={modalContext}
      rankingRules={rankingRules}
      onclose={closeDrilldown}
    />
  {:else if currentView === 'calendar'}
    <CalendarView events={calendarEvents} {showEvfToggle} {isActiveSeason} />
  {:else if currentView === 'admin_seasons'}
    <SeasonManager
      {seasons}
      isAdmin={isAdmin}
      oncreate={handleCreateSeason}
      onupdate={handleUpdateSeason}
      ondelete={handleDeleteSeason}
      onfetchevf={handleFetchEvfToggle}
    />
  {:else if currentView === 'admin_events'}
    <EventManager
      events={calendarEvents}
      tournaments={allTournaments}
      {seasons}
      {organizers}
      selectedSeasonId={selectedSeasonId}
      isAdmin={isAdmin}
      oncreate={handleCreateEvent}
      onupdate={handleUpdateEvent}
      onupdatestatus={handleUpdateEventStatus}
      ondelete={handleDeleteEvent}
      ondeletetournament={handleDeleteTournament}
    />
  {:else if currentView === 'admin_identities'}
    <IdentityManager
      candidates={matchCandidates}
      isAdmin={isAdmin}
      onapprove={handleApproveMatch}
      oncreatenew={handleCreateNewFencer}
      ondismiss={handleDismissMatch}
    />
  {:else if currentView === 'admin_scoring'}
    {#if scoringConfig}
      <ScoringConfigEditor
        config={scoringConfig}
        seasonCode={seasons.find(s => s.id_season === selectedSeasonId)?.txt_code ?? ''}
        onsave={handleSaveScoringConfig}
      />
    {:else}
      <p style="padding: 20px; color: #999;">Ładowanie konfiguracji punktacji…</p>
    {/if}
  {/if}

  {#if error}
    <div class="error-banner">{error}</div>
  {/if}
</div>

<AdminSignInModal
  open={auth.step === 'sign_in'}
  error={auth.error}
  onsubmit={(email, password) => { signIn(email, password) }}
  oncancel={() => { resetAuth() }}
/>

<AdminMfaEnrollModal
  open={auth.step === 'mfa_enroll'}
  qrCode={auth.qrCode}
  secret={auth.secret}
  error={auth.error}
  onconfirm={(code) => { confirmEnroll(code) }}
  oncancel={() => { resetAuth() }}
/>

<AdminMfaChallengeModal
  open={auth.step === 'mfa_challenge'}
  error={auth.error}
  onverify={(code) => { verifyChallenge(code) }}
  oncancel={() => { resetAuth() }}
/>


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
    Environment,
    Filters,
    RankingRules,
    AppView,
    CalendarEvent,
  } from './lib/types'
  import type { Organizer, ScoringConfig, MatchCandidate, CreateEventParams, UpdateEventParams, Tournament } from './lib/types'
  import {
    initClient,
    fetchSeasons,
    fetchRankingPpw,
    fetchRankingKadra,
    fetchFencerScores,
    fetchFencerScoresRolling,
    fetchRankingRules,
    fetchCalendarEvents,
    fetchOrganizers,
    createSeason,
    updateSeason,
    deleteSeason,
    createEvent,
    updateEvent,
    updateEventStatus,
    deleteEventCascade,
    fetchScoringConfig,
    saveScoringConfig,
    fetchAllTournaments,
    deleteTournamentCascade,
    fetchMatchCandidates,
    approveMatch,
    dismissMatch,
    createFencerFromMatch,
  } from './lib/api'
  import {
    MOCK_SEASONS,
    MOCK_PPW_ROWS,
    MOCK_KADRA_ROWS,
    MOCK_SCORES,
    MOCK_DRILLDOWN,
  } from './lib/mock-data'
  import { exportRankingPpw, exportRankingKadra } from './lib/export'
  import { t } from './lib/locale.svelte'
  import Sidebar from './components/Sidebar.svelte'
  import CalendarView from './components/CalendarView.svelte'
  import FilterBar from './components/FilterBar.svelte'
  import LangToggle from './components/LangToggle.svelte'
  import RanklistTable from './components/RanklistTable.svelte'
  import DrilldownModal from './components/DrilldownModal.svelte'
  import SkeletonLoader from './components/SkeletonLoader.svelte'
  import AdminSignInModal from './components/AdminSignInModal.svelte'
  import AdminMfaEnrollModal from './components/AdminMfaEnrollModal.svelte'
  import AdminMfaChallengeModal from './components/AdminMfaChallengeModal.svelte'
  import SeasonManager from './components/SeasonManager.svelte'
  import EventManager from './components/EventManager.svelte'
  import IdentityManager from './components/IdentityManager.svelte'
  import ScoringConfigEditor from './components/ScoringConfigEditor.svelte'
  import { getAuthState, startAuth, signIn, confirmEnroll, verifyChallenge, signOut, reset as resetAuth } from './lib/admin-auth.svelte'

  let {
    'supabase-cert-url': certUrl = '',
    'supabase-cert-key': certKey = '',
    'supabase-prod-url': prodUrl = '',
    'supabase-prod-key': prodKey = '',
    demo = false,
  }: {
    'supabase-cert-url'?: string
    'supabase-cert-key'?: string
    'supabase-prod-url'?: string
    'supabase-prod-key'?: string
    demo?: boolean
  } = $props()

  let currentView: AppView = $state('ranklist')
  let sidebarOpen = $state(false)

  const adminRequested = typeof window !== 'undefined' && new URLSearchParams(window.location.search).get('admin') === '1'
  const auth = getAuthState()
  let isAdmin = $derived(auth.step === 'authenticated')

  // Admin session timer
  const ADMIN_TIMEOUT_MS = 59 * 60 * 1000
  let adminStartTime: number | null = $state(null)
  let adminRemainingMs = $state(ADMIN_TIMEOUT_MS)
  let adminTimerId: ReturnType<typeof setInterval> | null = null
  let adminTimeoutId: ReturnType<typeof setTimeout> | null = null

  function startAdminTimer() {
    stopAdminTimer()
    adminStartTime = Date.now()
    adminRemainingMs = ADMIN_TIMEOUT_MS
    adminTimerId = setInterval(() => {
      adminRemainingMs = Math.max(0, ADMIN_TIMEOUT_MS - (Date.now() - (adminStartTime ?? Date.now())))
    }, 1000)
    adminTimeoutId = setTimeout(() => { signOut(); startAuth() }, ADMIN_TIMEOUT_MS)
  }

  function stopAdminTimer() {
    if (adminTimerId) { clearInterval(adminTimerId); adminTimerId = null }
    if (adminTimeoutId) { clearTimeout(adminTimeoutId); adminTimeoutId = null }
  }

  function formatAdminTimer(ms: number): string {
    const totalMin = Math.floor(ms / 60000)
    const h = Math.floor(totalMin / 60)
    const m = totalMin % 60
    return h > 0 ? `${h}h ${m}m` : `${m}m`
  }

  let adminTimerText = $derived(formatAdminTimer(adminRemainingMs))

  let activeEnv: Environment = $state('CERT')
  let dualEnv = $derived(!!(certUrl && certKey && prodUrl && prodKey))
  let supabaseUrl = $derived(activeEnv === 'PROD' && prodUrl ? prodUrl : certUrl)
  let supabaseKey = $derived(activeEnv === 'PROD' && prodKey ? prodKey : certKey)

  let seasons: Season[] = $state([])
  let selectedSeasonId: number | null = $state(null)
  let filters: Filters = $state({
    season: null,
    weapon: 'EPEE',
    gender: 'F',
    category: 'V1',
    mode: 'PPW',
  })
  let ppwRows: RankingPpwRow[] = $state([])
  let kadraRows: RankingKadraRow[] = $state([])
  let loading = $state(false)
  let error: string | null = $state(null)

  let isActiveSeason = $derived(seasons.find(s => s.id_season === selectedSeasonId)?.bool_active ?? false)
  let rankingRules: RankingRules | null = $state(null)

  let calendarEvents: CalendarEvent[] = $state([])
  let allTournaments: Tournament[] = $state([])
  let organizers: Organizer[] = $state([])
  let scoringConfig: ScoringConfig | null = $state(null)
  let showEvfToggle = $state(false)
  let matchCandidates: MatchCandidate[] = $state([])

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
      resetAuth()
      if (adminRequested) startAuth()
      init()
    }
  })

  $effect(() => {
    if (isAdmin) { startAdminTimer() } else { stopAdminTimer() }
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
      await refreshEvfToggle()
      await loadRanking()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  function onFilterChange(f: Omit<Filters, 'season'>) {
    filters = { ...filters, ...f }
    loadRanking()
  }

  async function refreshEvfToggle() {
    if (demo || selectedSeasonId == null) {
      showEvfToggle = false
      return
    }
    try {
      scoringConfig = await fetchScoringConfig(selectedSeasonId)
      showEvfToggle = scoringConfig?.show_evf_toggle ?? false
    } catch {
      showEvfToggle = false
    }
    if (filters.mode === 'KADRA') {
      filters = { ...filters, mode: 'PPW' }
    }
  }

  async function handleSeasonChange() {
    await refreshEvfToggle()
    if (currentView === 'ranklist') {
      loadRanking()
    } else if (currentView === 'calendar') {
      loadCalendar()
    } else if (currentView === 'admin_events') {
      loadAdminEvents()
    } else if (currentView === 'admin_scoring') {
      // scoringConfig already fetched by refreshEvfToggle
    } else {
      loadRanking()
    }
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
          isActiveSeason,
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
          isActiveSeason,
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
        modalScores = isActiveSeason
          ? await fetchFencerScoresRolling(
              fencerId,
              filters.weapon,
              filters.gender,
              filters.category,
              selectedSeasonId,
            )
          : await fetchFencerScores(
              fencerId,
              selectedSeasonId,
              filters.weapon,
              filters.gender,
            )
        const row =
          filters.mode === 'PPW'
            ? ppwRows.find((r) => r.id_fencer === fencerId)
            : kadraRows.find((r) => r.id_fencer === fencerId)
        if (row) {
          const birthYear = modalScores[0]?.int_birth_year ?? null
          const season = seasons.find((s) => s.id_season === selectedSeasonId)
          const seasonEndYear = season ? parseInt(season.dt_end.split('-')[0]) : null
          const age =
            birthYear != null && seasonEndYear != null ? seasonEndYear - birthYear : null
          modalContext = {
            rank: row.rank,
            birthYear,
            age,
            category: filters.category,
            totalScore: row.total_score,
            ppwBestCount: 4,
            pewBestCount: 3,
          }
        }
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

  async function navigateTo(view: AppView) {
    // Guard: admin views require auth
    if (!isAdmin && view.startsWith('admin_')) {
      currentView = 'ranklist'
      return
    }
    currentView = view
    if (view === 'calendar') loadCalendar()
    else if (view === 'admin_events') loadAdminEvents()
    else if (view === 'admin_identities') loadMatchCandidates()
    else if (view === 'admin_scoring') loadScoringConfig()
  }

  async function loadAdminEvents() {
    if (demo) return
    try {
      if (organizers.length === 0) {
        organizers = await fetchOrganizers()
      }
      if (selectedSeasonId) {
        calendarEvents = await fetchCalendarEvents(selectedSeasonId)
        const eventIds = calendarEvents.map(e => e.id_event)
        allTournaments = await fetchAllTournaments(eventIds)
      }
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleDeleteTournament(id: number) {
    try {
      await deleteTournamentCascade(id)
      if (selectedSeasonId) {
        calendarEvents = await fetchCalendarEvents(selectedSeasonId)
        const eventIds = calendarEvents.map(e => e.id_event)
        allTournaments = await fetchAllTournaments(eventIds)
      }
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function loadMatchCandidates() {
    if (demo) return
    try {
      matchCandidates = await fetchMatchCandidates()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleApproveMatch(matchId: number, fencerId: number) {
    try {
      await approveMatch(matchId, fencerId)
      await loadMatchCandidates()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleDismissMatch(matchId: number) {
    try {
      await dismissMatch(matchId)
      await loadMatchCandidates()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleCreateNewFencer(matchId: number) {
    const candidate = matchCandidates.find(c => c.id_match === matchId)
    if (!candidate) return
    const name = candidate.txt_scraped_name
    const spaceIdx = name.indexOf(' ')
    const surname = spaceIdx > 0 ? name.substring(0, spaceIdx) : name
    const firstName = spaceIdx > 0 ? name.substring(spaceIdx + 1) : ''
    try {
      await createFencerFromMatch(matchId, surname, firstName)
      await loadMatchCandidates()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function loadScoringConfig() {
    if (demo || !selectedSeasonId) return
    try {
      scoringConfig = await fetchScoringConfig(selectedSeasonId)
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleCreateSeason(code: string, start: string, end: string) {
    try {
      await createSeason(code, start, end)
      seasons = await fetchSeasons()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleUpdateSeason(id: number, code: string, start: string, end: string, showEvf: boolean) {
    try {
      await updateSeason(id, code, start, end)
      const cfg = await fetchScoringConfig(id)
      if (cfg && cfg.show_evf_toggle !== showEvf) {
        await saveScoringConfig({ ...cfg, show_evf_toggle: showEvf } as unknown as Record<string, unknown>)
      }
      seasons = await fetchSeasons()
      if (id === selectedSeasonId) await refreshEvfToggle()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleFetchEvfToggle(seasonId: number): Promise<boolean> {
    try {
      const cfg = await fetchScoringConfig(seasonId)
      return cfg?.show_evf_toggle ?? false
    } catch {
      return false
    }
  }

  async function handleDeleteSeason(id: number) {
    try {
      await deleteSeason(id)
      seasons = await fetchSeasons()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleCreateEvent(params: Record<string, unknown>) {
    try {
      await createEvent(params as unknown as CreateEventParams)
      if (selectedSeasonId) calendarEvents = await fetchCalendarEvents(selectedSeasonId)
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleUpdateEvent(id: number, params: Record<string, unknown>) {
    try {
      await updateEvent(id, params as unknown as UpdateEventParams)
      if (selectedSeasonId) calendarEvents = await fetchCalendarEvents(selectedSeasonId)
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleUpdateEventStatus(id: number, status: string) {
    try {
      await updateEventStatus(id, status)
      if (selectedSeasonId) calendarEvents = await fetchCalendarEvents(selectedSeasonId)
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleDeleteEvent(id: number) {
    try {
      await deleteEventCascade(id)
      if (selectedSeasonId) calendarEvents = await fetchCalendarEvents(selectedSeasonId)
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleSaveScoringConfig(config: ScoringConfig) {
    try {
      await saveScoringConfig(config as unknown as Record<string, unknown>)
      await refreshEvfToggle()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function loadCalendar() {
    if (demo || !selectedSeasonId) return
    try {
      calendarEvents = await fetchCalendarEvents(selectedSeasonId)
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  function handleMainExport() {
    const title = `SPWS_${filters.mode}_${filters.weapon}_${filters.gender}_${filters.category}`
    if (filters.mode === 'PPW') {
      exportRankingPpw(ppwRows, title)
    } else {
      exportRankingKadra(kadraRows, title)
    }
  }

  const AGE_THRESHOLDS: Record<AgeCategory, number> = {
    V0: 30, V1: 40, V2: 50, V3: 60, V4: 70,
  }

  function birthYearSubtitle(category: AgeCategory, seasonEndDate: string): string {
    const endYear = parseInt(seasonEndDate.split('-')[0])
    const minAge = AGE_THRESHOLDS[category]
    const newest = endYear - minAge
    const oldest = endYear - (minAge + 9)
    const catNum = category.replace('V', '')

    if (category === 'V4') {
      const years = `${newest}, ${newest - 1}, .. ${t('birth_year_and_older')}`
      return t('birth_year_subtitle', { cat: catNum, years })
    }

    const years = `${newest}, ${newest - 1}, .. ${oldest}`
    return t('birth_year_subtitle', { cat: catNum, years })
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
  .hamburger-btn {
    border: none;
    background: none;
    font-size: 22px;
    cursor: pointer;
    padding: 4px 8px;
    color: #333;
    line-height: 1;
  }
  .app-title {
    margin: 0;
    font-size: 20px;
    color: #222;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .header-logo {
    height: 22px;
    width: auto;
  }
  .season-selector {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .season-label {
    font-size: 13px;
    font-weight: 600;
    color: #555;
    white-space: nowrap;
  }
  .season-selector select {
    padding: 6px 10px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 14px;
    background: #fff;
  }
  .header-right {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-left: auto;
  }
  .category-subtitle {
    padding: 6px 14px;
    background: #fafbfc;
    border-bottom: 1px solid #eee;
    font-size: 12px;
    color: #888;
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
    .app-title {
      font-size: 16px;
    }
    .header-logo {
      height: 18px;
    }
    .app-header {
      gap: 10px;
    }
  }
</style>
