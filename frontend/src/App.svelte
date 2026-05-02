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
    <h2 class="app-title">
      <img src="SPWS-logo.png" alt="SPWS" class="header-logo" />
      {currentView === 'ranklist' ? t('app_title') : currentView === 'calendar' ? t('calendar_title') : currentView === 'admin_seasons' ? t('nav_admin_seasons') : currentView === 'admin_events' ? t('nav_admin_events') : currentView === 'admin_fencers' ? t('nav_admin_fencers') : t('app_title')}
    </h2>
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
      {seasons}
      bind:selectedSeasonId
      onseasonchange={handleSeasonChange}
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

    {#if dualEnv}
      <div class="env-footer">
        <div class="env-toggle">
          <button class="env-btn" class:active={activeEnv === 'CERT'}
            onclick={() => { activeEnv = 'CERT' }}>CT</button>
          <button class="env-btn" class:active={activeEnv === 'PROD'}
            onclick={() => { activeEnv = 'PROD' }}>PD</button>
        </div>
      </div>
    {/if}
  {:else if currentView === 'calendar'}
    <CalendarView events={calendarEvents} {showEvfToggle} {isActiveSeason} {seasons} bind:selectedSeasonId {dualEnv} bind:activeEnv onseasonchange={handleSeasonChange} />
  {:else if currentView === 'admin_seasons'}
    <SeasonManager
      {seasons}
      isAdmin={isAdmin}
      onupdate={handleUpdateSeason}
      ondelete={handleDeleteSeason}
      onfetchevf={handleFetchEvfToggle}
      onscoringconfig={handleOpenScoringConfig}
      {scoringConfig}
      scoringSeasonId={editingScoringSeasonId}
      onsavescoring={handleSaveScoringConfig}
      onclosescoring={() => { editingScoringSeasonId = null }}
      onwizardloadprior={handleWizardLoadPrior}
      onwizardcommit={handleWizardCommit}
      onfetchskeletons={handleFetchSkeletons}
      onrevertinit={handleRevertSeasonInit}
    />
  {:else if currentView === 'admin_events'}
    <EventManager
      events={calendarEvents}
      priorEvents={priorSeasonEvents}
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
      onedittournament={handleEditTournament}
      oncreatetournament={handleCreateTournament}
      onrefresh={reloadAdminEvents}
      {activeEnv}
      onseasonchange={(id) => {
        selectedSeasonId = id
        handleSeasonChange()
      }}
    />
  {:else if currentView === 'admin_fencers'}
    <div class="fencer-tabs">
      <span class="fencer-count">{t('fencer_header_count', { count: allFencers.length })}</span>
      <div class="tab-bar">
        <button class="tab-btn" class:active={fencerTab === 'identities'} onclick={() => { fencerTab = 'identities' }}>
          {t('fencer_tab_identities')}
        </button>
        <button class="tab-btn" class:active={fencerTab === 'birth_year_review'} onclick={() => { fencerTab = 'birth_year_review' }}>
          {t('fencer_tab_birth_year')}
        </button>
        <button class="tab-btn" class:active={fencerTab === 'aliases'} onclick={() => { fencerTab = 'aliases'; loadAliasFencers() }}>
          {t('fencer_tab_aliases')}
        </button>
      </div>
    </div>
    {#if fencerTab === 'identities'}
      <IdentityManager
        candidates={matchCandidates}
        fencers={allFencers}
        isAdmin={isAdmin}
        errorMsg={identityError}
        onapprove={handleApproveMatch}
        onassign={handleAssignFencer}
        oncreatenew={handleCreateNewFencer}
        ondismiss={handleDismissMatch}
        onundismiss={handleUndismissMatch}
        onupdategender={handleUpdateFencerGender}
      />
    {:else if fencerTab === 'birth_year_review'}
      <BirthYearReview
        fencers={allFencers}
        isAdmin={isAdmin}
        errorMsg={birthYearError}
        onupdatebirthyear={handleUpdateFencerBirthYear}
        onupdategender={handleUpdateFencerGender}
        onfetchhistory={handleFetchTournamentHistory}
      />
    {:else}
      <FencerAliasManager
        fencers={aliasFencers}
        isAdmin={isAdmin}
        errorMsg={aliasError}
        onkeep={handleAliasKeep}
        ontransfer={handleAliasTransfer}
        oncreate={handleAliasCreate}
        ondiscard={handleAliasDiscard}
      />
    {/if}
  {/if}


  {#if error}
    <div class="error-banner {errorType}">
      <button class="close-x" onclick={() => clearStatus()} title="Dismiss">×</button>
      {error}
      {#if errorLink}
        <br><a href={errorLink} target="_blank" rel="noopener">{errorLink}</a>
      {/if}
    </div>
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
    TournamentType,
  } from './lib/types'
  import type { Organizer, ScoringConfig, MatchCandidate, CreateEventParams, UpdateEventParams, Tournament, FencerListItem, FencerWithAliases, EuropeanEventType, CarryoverEngine, SkeletonByKind } from './lib/types'
  import {
    initClient,
    fetchSeasons,
    fetchRankingPpw,
    fetchRankingKadra,
    fetchFencerScores,
    fetchFencerScoresRolling,
    fetchRankingRules,
    fetchCalendarEvents,
    fetchPriorSeasonEvents,
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
    updateSeasonCarryoverEngine,
    updateSeasonCarryoverFields,
    copyPriorScoringConfig,
    createSeasonWithSkeletons,
    revertSeasonInit,
    fetchAllTournaments,
    deleteTournamentCascade,
    updateTournament,
    createTournament,
    fetchMatchCandidates,
    approveMatch,
    dismissMatch,
    undismissMatch,
    createFencerFromMatch,
    fetchAllFencers,
    updateFencerGender,
    updateFencerBirthYear,
    fetchFencerTournamentHistory,
    refreshActiveSeason,
    listFencerAliases,
    transferFencerAlias,
    splitFencerFromAlias,
    discardFencerAliasAndResults,
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
  import BirthYearReview from './components/BirthYearReview.svelte'
  import FencerAliasManager from './components/FencerAliasManager.svelte'
  import { getAuthState, startAuth, signIn, confirmEnroll, verifyChallenge, signOut, reset as resetAuth } from './lib/admin-auth.svelte'

  // ADR-041: github-pat / github-repo attributes removed. Workflow dispatch
  // is now server-side via the dispatch-workflow Edge Function — no PAT in
  // browser, ever.
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
  let errorType: 'error' | 'success' | 'progress' = $state('error')
  let errorLink: string | null = $state(null)
  function clearStatus() { error = null; errorLink = null }

  let isActiveSeason = $derived(seasons.find(s => s.id_season === selectedSeasonId)?.bool_active ?? false)
  let rankingRules: RankingRules | null = $state(null)

  let calendarEvents: CalendarEvent[] = $state([])
  let priorSeasonEvents: CalendarEvent[] = $state([])
  let allTournaments: Tournament[] = $state([])
  let organizers: Organizer[] = $state([])
  let scoringConfig: ScoringConfig | null = $state(null)
  let editingScoringSeasonId: number | null = $state(null)
  let showEvfToggle = $state(false)
  let matchCandidates: MatchCandidate[] = $state([])
  let allFencers: FencerListItem[] = $state([])
  let identityError: string | null = $state(null)
  let birthYearError: string | null = $state(null)
  let fencerTab = $state('identities')
  let aliasFencers: FencerWithAliases[] = $state([])
  let aliasError: string | null = $state(null)

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
      await refreshActiveSeason().catch(() => {}) // best-effort: may fail for anon
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
    else if (view === 'admin_fencers') loadMatchCandidates()
  }

  async function loadPriorSeasonEvents() {
    const currentSeason = seasons.find(s => s.id_season === selectedSeasonId)
    if (!currentSeason) {
      priorSeasonEvents = []
      return
    }
    const immediatePrior = seasons
      .filter(s => s.dt_end < currentSeason.dt_start)
      .sort((a, b) => b.dt_end.localeCompare(a.dt_end))[0]
    priorSeasonEvents = immediatePrior
      ? await fetchPriorSeasonEvents([immediatePrior.id_season])
      : []
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
        await loadPriorSeasonEvents()
      }
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleDeleteTournament(id: number) {
    try {
      await deleteTournamentCascade(id)
      await reloadAdminEvents()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleEditTournament(id: number, params: Record<string, unknown>) {
    try {
      await updateTournament(id, {
        code: params.code as string | undefined,
        urlResults: params.urlResults as string | undefined,
        importStatus: params.importStatus as import('./lib/types').ImportStatus | undefined,
        statusReason: params.statusReason as string | undefined,
      })
      await reloadAdminEvents()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleCreateTournament(eventId: number, params: Record<string, unknown>) {
    try {
      const event = calendarEvents.find(e => e.id_event === eventId)
      const season = seasons.find(s => s.id_season === selectedSeasonId)
      const code = `${event?.txt_code ?? 'T'}-${params.category}-${params.gender}-${params.weapon}-${season?.txt_code?.replace('SPWS-', '') ?? ''}`
      await createTournament({
        idEvent: eventId,
        code,
        name: code,
        type: params.type as TournamentType,
        weapon: params.weapon as WeaponType,
        gender: params.gender as GenderType,
        ageCategory: params.category as AgeCategory,
        dtTournament: (params.dtTournament as string) ?? undefined,
        urlResults: (params.urlResults as string) ?? undefined,
      })
      await reloadAdminEvents()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  // ADR-041: handleImportEvent / handleImportTournament moved into
  // EventManager.svelte and now dispatch via the dispatch-workflow Edge
  // Function instead of a browser-side PAT.

  async function reloadAdminEvents() {
    if (selectedSeasonId) {
      calendarEvents = await fetchCalendarEvents(selectedSeasonId)
      const eventIds = calendarEvents.map(e => e.id_event)
      allTournaments = await fetchAllTournaments(eventIds)
      await loadPriorSeasonEvents()
    }
  }

  async function loadMatchCandidates() {
    if (demo) return
    identityError = null
    try {
      matchCandidates = await fetchMatchCandidates()
      if (allFencers.length === 0) {
        allFencers = await fetchAllFencers()
      }
    } catch (e: unknown) {
      identityError = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleApproveMatch(matchId: number, fencerId: number) {
    identityError = null
    try {
      await approveMatch(matchId, fencerId)
      await loadMatchCandidates()
    } catch (e: unknown) {
      identityError = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleDismissMatch(matchId: number) {
    identityError = null
    try {
      await dismissMatch(matchId)
      await loadMatchCandidates()
    } catch (e: unknown) {
      identityError = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleUndismissMatch(matchId: number) {
    identityError = null
    try {
      await undismissMatch(matchId)
      await loadMatchCandidates()
    } catch (e: unknown) {
      identityError = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleCreateNewFencer(matchId: number, surname: string, firstName: string, gender: GenderType, birthYear?: number, birthYearEstimated?: boolean) {
    identityError = null
    try {
      await createFencerFromMatch(matchId, surname, firstName, birthYear, gender, birthYearEstimated)
      allFencers = await fetchAllFencers()
      await loadMatchCandidates()
    } catch (e: unknown) {
      identityError = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleAssignFencer(matchId: number, fencerId: number) {
    identityError = null
    try {
      await approveMatch(matchId, fencerId)
      await loadMatchCandidates()
    } catch (e: unknown) {
      identityError = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleUpdateFencerGender(fencerId: number, gender: GenderType) {
    identityError = null
    try {
      await updateFencerGender(fencerId, gender)
      await loadMatchCandidates()
    } catch (e: unknown) {
      identityError = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleUpdateFencerBirthYear(fencerId: number, birthYear: number, estimated: boolean) {
    birthYearError = null
    try {
      await updateFencerBirthYear(fencerId, birthYear, estimated)
      allFencers = await fetchAllFencers()
    } catch (e: unknown) {
      birthYearError = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleFetchTournamentHistory(fencerId: number) {
    return await fetchFencerTournamentHistory(fencerId)
  }

  // Phase 4 (ADR-050) — alias management. Modal-based UX (FencerSearchModal /
  // CreateFencerModal reuse) is a follow-up; v1 uses browser dialogs as a
  // placeholder so the locked Option A layout can ship.
  async function loadAliasFencers() {
    aliasError = null
    try {
      aliasFencers = await listFencerAliases()
    } catch (e: unknown) {
      aliasError = e instanceof Error ? e.message : String(e)
    }
  }

  function handleAliasKeep(_id: number, _alias: string) {
    // No-op: keeping an alias requires no action — it's already on the fencer.
  }

  async function handleAliasTransfer(fromId: number, alias: string) {
    aliasError = null
    const target = window.prompt(`Transfer alias "${alias}" — destination id_fencer:`)
    if (!target) return
    const toId = Number(target)
    if (!Number.isFinite(toId) || toId <= 0) {
      aliasError = `Invalid id_fencer: ${target}`
      return
    }
    try {
      await transferFencerAlias(fromId, toId, alias)
      await loadAliasFencers()
    } catch (e: unknown) {
      aliasError = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleAliasCreate(fromId: number, alias: string) {
    aliasError = null
    const surname = window.prompt(`Create new fencer from alias "${alias}". Surname:`)
    if (!surname) return
    const firstName = window.prompt('First name:')
    if (!firstName) return
    const byStr = window.prompt('Birth year (YYYY):')
    const birthYear = Number(byStr)
    if (!Number.isFinite(birthYear) || birthYear < 1900 || birthYear > 2030) {
      aliasError = `Invalid birth year: ${byStr}`
      return
    }
    const gender = window.prompt('Gender (M/F):')
    if (gender !== 'M' && gender !== 'F') {
      aliasError = `Invalid gender: ${gender}`
      return
    }
    try {
      await splitFencerFromAlias(fromId, alias, {
        txt_surname: surname,
        txt_first_name: firstName,
        int_birth_year: birthYear,
        enum_gender: gender,
      })
      await loadAliasFencers()
    } catch (e: unknown) {
      aliasError = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleAliasDiscard(fromId: number, alias: string) {
    aliasError = null
    if (!window.confirm(`Discard alias "${alias}" and DELETE all results tagged with it?`)) {
      return
    }
    try {
      await discardFencerAliasAndResults(fromId, alias)
      await loadAliasFencers()
    } catch (e: unknown) {
      aliasError = e instanceof Error ? e.message : String(e)
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

  async function handleOpenScoringConfig(seasonId: number) {
    try {
      scoringConfig = await fetchScoringConfig(seasonId)
      editingScoringSeasonId = seasonId
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  function friendlySeasonError(e: unknown): string {
    let msg: string
    if (e instanceof Error) {
      msg = e.message
    } else if (e && typeof e === 'object' && 'message' in e) {
      msg = String((e as { message: unknown }).message)
    } else {
      msg = String(e)
    }
    if (msg.includes('excl_season_date_overlap')) return t('season_overlap_error')
    return msg
  }

  async function handleCreateSeason(code: string, start: string, end: string): Promise<string | null> {
    try {
      await createSeason(code, start, end)
      seasons = await fetchSeasons()
      return null
    } catch (e: unknown) {
      return friendlySeasonError(e)
    }
  }

  async function handleUpdateSeason(
    id: number,
    code: string,
    start: string,
    end: string,
    showEvf: boolean,
    carryoverDays: number = 366,
    europeanType: EuropeanEventType = null,
  ): Promise<string | null> {
    try {
      await updateSeason(id, code, start, end)
      const cfg = await fetchScoringConfig(id)
      if (cfg && cfg.show_evf_toggle !== showEvf) {
        await saveScoringConfig({ ...cfg, show_evf_toggle: showEvf } as unknown as Record<string, unknown>)
      }
      // Phase 3 (ADR-044): patch tbl_season's carry-over fields directly.
      // Done via the api.ts helper since fn_update_season's signature does
      // not include them and we don't want to widen it for one column-pair.
      await updateSeasonCarryoverFields(id, carryoverDays, europeanType)
      seasons = await fetchSeasons()
      if (id === selectedSeasonId) await refreshEvfToggle()
      return null
    } catch (e: unknown) {
      return friendlySeasonError(e)
    }
  }

  // Phase 3 (ADR-044) — wizard handlers
  async function handleWizardLoadPrior(dtStart: string): Promise<{
    priorConfig: ScoringConfig | null
    priorCode: string | null
    priorBreakdown: Required<SkeletonByKind> | null
  }> {
    const priorConfig = await copyPriorScoringConfig(dtStart)
    if (!priorConfig) {
      return { priorConfig: null, priorCode: null, priorBreakdown: null }
    }
    const priorCode = priorConfig.season_code
    // Compute breakdown by querying prior season's events. Wizard step 3 uses
    // it to render "5 PPW + 9 PEW" before the user commits.
    const priorSeason = seasons.find((s) => s.txt_code === priorCode)
    if (!priorSeason) {
      return { priorConfig, priorCode, priorBreakdown: null }
    }
    const priorEvents = await fetchCalendarEvents(priorSeason.id_season)
    const breakdown: Required<SkeletonByKind> = {
      PPW: priorEvents.filter((e) => /^PPW\d+-/.test(e.txt_code)).length,
      PEW: priorEvents.filter((e) => /^PEW\d+[efs]*-/.test(e.txt_code)).length,
      MPW: 1,
      MSW: 1,
      IMEW: 0,
      DMEW: 0,
    }
    return { priorConfig, priorCode, priorBreakdown: breakdown }
  }

  async function handleWizardCommit(payload: {
    code: string
    dt_start: string
    dt_end: string
    carryover_days: number
    european_type: EuropeanEventType
    carryover_engine: CarryoverEngine
    scoring_config: ScoringConfig
    show_evf: boolean
  }): Promise<string | null> {
    try {
      await createSeasonWithSkeletons(payload)
      seasons = await fetchSeasons()
      return null
    } catch (e: unknown) {
      return friendlySeasonError(e)
    }
  }

  async function handleFetchSkeletons(seasonId: number): Promise<CalendarEvent[]> {
    try {
      const events = await fetchCalendarEvents(seasonId)
      return events.filter((e) => e.enum_status === 'CREATED')
    } catch {
      return []
    }
  }

  async function handleRevertSeasonInit(seasonId: number): Promise<string | null> {
    try {
      await revertSeasonInit(seasonId)
      seasons = await fetchSeasons()
      return null
    } catch (e: unknown) {
      return e instanceof Error ? e.message : String(e)
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
      // Phase 3 (ADR-045): patch the season's carry-over engine separately.
      // ScoringConfigEditor's save payload now carries `engine` so the dropdown
      // flip propagates to tbl_season without a migration.
      if (config.engine && editingScoringSeasonId != null) {
        await updateSeasonCarryoverEngine(editingScoringSeasonId, config.engine)
      }
      await refreshEvfToggle()
      await fetchSeasons()
      editingScoringSeasonId = null
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
  .env-footer {
    display: flex;
    justify-content: center;
    padding: 16px 0;
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
    position: fixed;
    top: 16px;
    right: 16px;
    z-index: 9999;
    max-width: min(480px, calc(100vw - 32px));
    padding: 12px 36px 12px 14px;
    background: #fff0f0;
    border: 1px solid #fcc;
    border-radius: 6px;
    color: #c33;
    font-size: 14px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
    word-break: break-word;
    white-space: pre-wrap;
  }
  .error-banner .close-x {
    position: absolute;
    top: 6px;
    right: 8px;
    cursor: pointer;
    background: none;
    border: none;
    color: #c33;
    font-size: 18px;
    line-height: 1;
    padding: 2px 6px;
  }
  .error-banner.success { background: #f0fff4; border-color: #b8e6c4; color: #2a7a3a; }
  .error-banner.success .close-x { color: #2a7a3a; }
  .error-banner.progress { background: #f0f6ff; border-color: #b8d4ee; color: #2a5a9a; }
  .error-banner.progress .close-x { color: #2a5a9a; }
  .error-banner a { color: inherit; text-decoration: underline; }

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
  .fencer-tabs {
    padding: 0 16px;
    position: sticky;
    top: 0;
    background: #fff;
    z-index: 10;
    border-bottom: 1px solid #eee;
    padding-bottom: 0;
  }
  .fencer-count {
    font-size: 14px;
    font-weight: 600;
    color: #555;
    display: block;
    padding-top: 8px;
    margin-bottom: 8px;
  }
  .tab-bar {
    display: flex;
    gap: 0;
    border-bottom: 2px solid #dee2e6;
  }
  .tab-btn {
    padding: 8px 16px;
    border: none;
    background: none;
    font-size: 13px;
    font-weight: 600;
    color: #888;
    cursor: pointer;
    border-bottom: 2px solid transparent;
    margin-bottom: -2px;
  }
  .tab-btn:hover { color: #555; }
  .tab-btn.active { color: #4a90d9; border-bottom-color: #4a90d9; }
</style>
