{#if !embedded}
  <Sidebar
    open={sidebarOpen}
    currentView={currentView}
    isAdmin={isAdmin}
    {adminTimerText}
    onnavigate={(view) => { navigateTo(view) }}
    onclose={() => { sidebarOpen = false }}
    onlogout={() => { signOut() }}
  />
{/if}

<div class="ranklist-app" class:embedded>
  {#if !embedded}
    <header class="app-header">
      <button class="hamburger-btn" onclick={() => { sidebarOpen = true }} aria-label="Menu">&#9776;</button>
      <h2 class="app-title">
        <img src={assetUrl('SPWS-logo.png')} alt="SPWS" class="header-logo" />
        {currentView === 'ranklist' ? t('app_title') : currentView === 'calendar' ? t('calendar_title') : currentView === 'admin_seasons' ? t('nav_admin_seasons') : currentView === 'admin_events' ? t('nav_admin_events') : currentView === 'admin_fencers' ? t('nav_admin_fencers') : t('app_title')}
      </h2>
      <div class="header-right">
        <LangToggle />
      </div>
    </header>
  {:else}
    <!-- The embed's one row, carrying what the removed application header used
         to at no extra height: the SPWS mark linked back to the association's
         site, the page's own name in the active language, and the language
         toggle.

         The mark is REQUIRED, not decorative. The host page hides the theme's
         header, navigation and footer, so this is the only route back to
         weteraniszermierki.pl from the calendar. -->
    <div class="embed-bar">
      <a
        class="embed-home"
        href="https://weteraniszermierki.pl"
        aria-label={t('embed_home_label')}
        title={t('embed_home_label')}
      >
        <img src={assetUrl('SPWS-logo.png')} alt="SPWS" class="embed-logo" />
      </a>
      <span class="embed-title">{t('embed_page_title')}</span>
      <div class="embed-actions">
        <LangToggle />
      </div>
    </div>
  {/if}

  {#if currentView === 'ranklist'}
    <FilterBar
      weapon={filters.weapon}
      gender={filters.gender}
      category={filters.category}
      mode={filters.mode}
      showEvfToggle={showEvfToggleRanklist}
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
      showEvfToggle={showEvfToggleRanklist}
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
    <!-- The calendar is the one view built from geometry rather than a list,
         and a throw inside a `$derived` there is not a broken card: it tears
         down the whole component tree, so the header, the nav and the hamburger
         stop responding too and only a reload brings them back. That is what
         2026-09-02 looked like from the outside. The boundary keeps a calendar
         failure inside the calendar. -->
    <svelte:boundary>
      <CalendarView events={calendarEvents} showEvfToggle={showEvfToggleCalendar} {dualEnv} bind:activeEnv />
      {#snippet failed(err: unknown)}
        <div class="calendar-failed" role="alert">
          <p>{t('calendar_render_failed')}</p>
          <p class="calendar-failed-detail">{err instanceof Error ? err.message : String(err)}</p>
        </div>
      {/snippet}
    </svelte:boundary>
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
      {dualEnv}
      {promotionByCode}
      onpromote={handlePromoteSeason}
      onremovefromprod={handleRemoveFromProd}
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
      <span style="white-space: pre-line">{error}</span>
      {#if errorLink}
        <br><a href={errorLink} target="_blank" rel="noopener">{errorLink}</a>
      {/if}
    </div>
  {/if}

  <!-- Phase 5.5 (ADR-058+059+061) — Create-new-fencer modal -->
  <CreateFencerFromAliasModal
    open={createAliasModalOpen}
    alias={createAliasContext?.alias ?? ''}
    fromFencerId={createAliasContext?.fromId ?? 0}
    categoryHint={createAliasContext?.categoryHint ?? null}
    sourceCategoryHint={createAliasContext?.sourceCategoryHint ?? null}
    seasonEndYear={createAliasContext?.seasonEndYear ?? null}
    sourceBracketUrl={createAliasContext?.sourceBracketUrl ?? null}
    onconfirm={handleAliasCreateConfirm}
    onclose={handleAliasCreateClose}
  />
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
    fetchAllCalendarEvents,
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
    regenStagingReport,  // Phase 5.5 (ADR-058+059+061)
    discardFencerAliasAndResults,
    confirmFencerAlias,
    requestDispatch,                 // ADR-077 season-skeleton promotion
    fetchSeasonChildState,           // ADR-077
    fetchProdSeasonCodes,            // ADR-077
  } from './lib/api'
  import {
    MOCK_SEASONS,
    MOCK_PPW_ROWS,
    MOCK_KADRA_ROWS,
    MOCK_SCORES,
    MOCK_DRILLDOWN,
  } from './lib/mock-data'
  import { exportRankingPpw, exportRankingKadra } from './lib/export'
  import { shouldUseRolling } from './lib/rolling'
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
  // Phase 5.5 (ADR-058+059) — alias-create modal + cascade banner regen.
  import CreateFencerFromAliasModal from './components/CreateFencerFromAliasModal.svelte'
  import { getAuthState, startAuth, signIn, confirmEnroll, verifyChallenge, signOut, reset as resetAuth } from './lib/admin-auth.svelte'
  import { setAssetBase, assetUrl } from './lib/assetBase'

  // ADR-041: github-pat / github-repo attributes removed. Workflow dispatch
  // is now server-side via the dispatch-workflow Edge Function — no PAT in
  // browser, ever.
  let {
    'supabase-cert-url': certUrl = '',
    'supabase-cert-key': certKey = '',
    'supabase-prod-url': prodUrl = '',
    'supabase-prod-key': prodKey = '',
    // PROD deployment step 1 — the WordPress embed mounts this same component
    // with `view="calendar" chrome="none"`. Both default to the Pages app's
    // existing behaviour, so nothing on GitHub Pages changes.
    view = 'ranklist',
    chrome = 'full',
    // Where the static marks live. Empty (the Pages default) leaves every asset
    // path exactly as it is today; the embed points it at the Pages origin.
    'asset-base': assetBase = '',
    demo = false,
  }: {
    'supabase-cert-url'?: string
    'supabase-cert-key'?: string
    'supabase-prod-url'?: string
    'supabase-prod-key'?: string
    view?: AppView
    chrome?: 'full' | 'none'
    'asset-base'?: string
    demo?: boolean
  } = $props()

  // Synchronously at init, not in an $effect: child components read this while
  // rendering, and Svelte 5 runs child effects before the parent's own — an
  // $effect here would let the first paint resolve against an unset base.
  // svelte-ignore state_referenced_locally
  setAssetBase(assetBase)

  // `chrome="none"` strips the header, hamburger and drawer: a single embed has
  // no second view to navigate to, so the navigation affordances have nothing
  // to point at.
  const embedded = $derived(chrome === 'none')


  // The one-shot capture is the point: `view` is the STARTING view, and
  // navigateTo() owns it from then on. Re-deriving it from the prop would undo
  // every navigation the moment anything re-rendered.
  // svelte-ignore state_referenced_locally
  let currentView: AppView = $state(view)
  let sidebarOpen = $state(false)

  // The embed ignores ?admin=1 outright. Administration stays on GitHub Pages,
  // and the embed is a public page on the association's own site — the sign-in
  // modal must not be reachable from it whatever the address bar says.
  // Reads `chrome` rather than the `embedded` rune: this is a one-shot const
  // evaluated at init, and the attribute is static once the element is created.
  // svelte-ignore state_referenced_locally
  const adminRequested = chrome !== 'none'
    && typeof window !== 'undefined'
    && new URLSearchParams(window.location.search).get('admin') === '1'
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

  // Open on the environment we actually hold credentials for. The WordPress
  // embed is given ONLY the PROD pair; with a hardcoded 'CERT' start the
  // derivations below fell through to an empty certUrl, the init effect's
  // `supabaseUrl && supabaseKey` guard never passed, and the embed rendered
  // blank with no error anywhere. Both pairs present still opens on CERT, so
  // the Pages app is unchanged and its CT/PD toggle keeps its meaning.
  // svelte-ignore state_referenced_locally
  let activeEnv: Environment = $state((certUrl && certKey ? 'CERT' : 'PROD') as Environment)
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

  // ADR-077: rolling carry-over applies to the active season AND future seasons
  // (a not-yet-started season's ranklist is the carry-over preview); past seasons
  // show their own finals. Was gated to isActiveSeason only, so a promoted future
  // season rendered empty.
  let useRolling = $derived(shouldUseRolling(seasons.find(s => s.id_season === selectedSeasonId)))
  let rankingRules: RankingRules | null = $state(null)

  let calendarEvents: CalendarEvent[] = $state([])
  let priorSeasonEvents: CalendarEvent[] = $state([])
  let allTournaments: Tournament[] = $state([])
  let organizers: Organizer[] = $state([])
  let scoringConfig: ScoringConfig | null = $state(null)
  let editingScoringSeasonId: number | null = $state(null)
  // Part 1 (ADR-044 amend): two independent +EVF flags. Ranklist defaults OFF
  // (SPWS lost the national-team appointment); Calendar defaults ON (richer view).
  let showEvfToggleRanklist = $state(false)
  let showEvfToggleCalendar = $state(true)
  let matchCandidates: MatchCandidate[] = $state([])
  let allFencers: FencerListItem[] = $state([])
  let identityError: string | null = $state(null)
  let birthYearError: string | null = $state(null)
  let fencerTab = $state('identities')
  let aliasFencers: FencerWithAliases[] = $state([])
  let aliasError: string | null = $state(null)

  // Phase 5.5 (ADR-058+059+061) — Create-new-fencer modal + cascade-banner state.
  let createAliasModalOpen = $state(false)
  let createAliasContext: {
    fromId: number
    alias: string
    categoryHint: string | null
    sourceCategoryHint: string | null  // 5.18 — source bracket V-cat (preferred over destination)
    seasonEndYear: number | null
    sourceBracketUrl: string | null    // 5.18 — verify-on-FTL link
  } | null = $state(null)
  let aliasCreateSteps: string[] = $state([])  // progressive checkmarks rendered in the status banner

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
      // Load whatever the app actually opened on. This was an unconditional
      // loadRanking(), which was correct while `currentView` always started at
      // 'ranklist' — the calendar was only ever reached through navigateTo(),
      // which loads it. The WordPress embed opens directly on the calendar, so
      // that path never ran: it fetched ranking rows nobody sees and left the
      // barrel with no events at all.
      if (currentView === 'calendar') {
        await loadCalendar()
      } else {
        await loadRanking()
      }
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
      showEvfToggleRanklist = false
      showEvfToggleCalendar = true
      return
    }
    try {
      scoringConfig = await fetchScoringConfig(selectedSeasonId)
      showEvfToggleRanklist = scoringConfig?.show_evf_toggle ?? false
      showEvfToggleCalendar = scoringConfig?.show_evf_toggle_calendar ?? true
    } catch {
      showEvfToggleRanklist = false
      showEvfToggleCalendar = true
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
          useRolling,
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
          useRolling,
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
        modalScores = useRolling
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
        await reloadCalendar()
        // The admin list filters by season itself, but the tournament fetch is
        // keyed on ids — keep that scoped to the season on screen rather than
        // pulling every season's tournaments along with the calendar.
        const eventIds = calendarEvents.filter(e => e.id_season === selectedSeasonId).map(e => e.id_event)
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
      await reloadCalendar()
      const eventIds = calendarEvents.filter(e => e.id_season === selectedSeasonId).map(e => e.id_event)
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

  async function handleAliasKeep(id: number, alias: string) {
    // Phase 5 — Keep persists the operator's confirmation to
    // tbl_fencer.json_user_confirmed_aliases via fn_confirm_fencer_alias,
    // so the staging verdict stops re-surfacing this alias as ❌ on
    // subsequent runs. Idempotent.
    aliasError = null
    try {
      await confirmFencerAlias(id, alias)
      await loadAliasFencers()
    } catch (e: unknown) {
      aliasError = e instanceof Error ? e.message : String(e)
    }
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

  // Phase 5.5 (ADR-058+059+061) — open the modal instead of the prompt chain.
  // Pulls latest_category_hint + latest_season_end_year from the alias view
  // so the modal can prepopulate the BY suggestion via estimateBirthYear.
  async function handleAliasCreate(fromId: number, alias: string) {
    aliasError = null
    const fencer = aliasFencers.find((f) => f.id_fencer === fromId)
    // 5.18 — extra source-V-cat + bracket URL context. The view returns
    // these per-fencer (most-recent draft/live row); they're populated for
    // events scraped after migration 20260503000007 lands. For pre-5.18
    // events the source-V-cat is null and the modal falls back to
    // categoryHint (destination), which is what we did before.
    createAliasContext = {
      fromId,
      alias,
      categoryHint: fencer?.latest_category_hint ?? null,
      sourceCategoryHint: fencer?.latest_source_category_hint ?? null,
      seasonEndYear: fencer?.latest_season_end_year ?? null,
      sourceBracketUrl: fencer?.latest_source_bracket_url ?? null,
    }
    createAliasModalOpen = true
  }

  async function handleAliasCreateConfirm(data: {
    txt_surname: string
    txt_first_name: string
    int_birth_year: number
    enum_gender: 'M' | 'F'
  }) {
    if (!createAliasContext) return
    const { fromId, alias } = createAliasContext
    const eventCode = stagingEventCode  // Phase-5 selected event code (see below)
    createAliasModalOpen = false
    aliasError = null
    aliasCreateSteps = []
    errorType = 'progress'

    try {
      const result = await splitFencerFromAlias(fromId, alias, data) as any
      const newId = result?.new_fencer_id
      const tr = result?.transfer_result ?? {}
      aliasCreateSteps = [
        `✓ Fencer created (id #${newId} — ${data.txt_surname} ${data.txt_first_name}, BY=${data.int_birth_year}, ${data.enum_gender})`,
        `✓ Removed from #${fromId} (${tr.results_moved ?? 0} results + ${tr.draft_results_moved ?? 0} drafts)`,
        `✓ Reassigned to #${newId} (${tr.tournaments_recomputed ?? 0} tournaments recomputed)`,
      ]

      // Cascade tournament list (id_tournaments[] + tournament_labels[] from
      // the extended RPC return per migration 20260503000002).
      const ids: number[] = tr.id_tournaments ?? []
      const labels: string[] = tr.tournament_labels ?? []
      if (ids.length > 0) {
        for (let i = 0; i < ids.length; i++) {
          aliasCreateSteps = [...aliasCreateSteps, `   • ${labels[i] ?? '?'}  [t#${ids[i]}]`]
        }
      }

      // Distinct event_codes touched (the prefix before the first ' / ')
      const distinctEvents = Array.from(new Set(
        labels.map((l) => l.split(' / ')[0]).filter(Boolean)
      ))
      const otherEvents = eventCode
        ? distinctEvents.filter((ec) => ec !== eventCode)
        : distinctEvents
      if (otherEvents.length > 0) {
        aliasCreateSteps = [
          ...aliasCreateSteps,
          `⚠ ${otherEvents.length} prior event(s) recomputed: ${otherEvents.join(', ')}`,
        ]
      }

      // Regen .md for each affected event_code (CERT/PROD only; LOCAL no-ops).
      const eventsToRegen = eventCode
        ? Array.from(new Set([eventCode, ...distinctEvents]))
        : distinctEvents
      for (const ec of eventsToRegen) {
        aliasCreateSteps = [...aliasCreateSteps, `⏳ Regenerating ${ec}/full.md...`]
        try {
          const r = await regenStagingReport(ec)
          aliasCreateSteps = aliasCreateSteps.slice(0, -1).concat(
            r?.skipped === 'local'
              ? `ℹ ${ec}/full.md regen skipped on LOCAL (rerun phase5_report from shell)`
              : `✓ ${ec}/full.md regenerated · sent to Telegram`,
          )
        } catch (e: unknown) {
          aliasCreateSteps = aliasCreateSteps.slice(0, -1).concat(
            `❌ ${ec}/full.md regen failed: ${e instanceof Error ? e.message : String(e)}`,
          )
        }
      }

      errorType = 'success'
      error = aliasCreateSteps.join('\n')
      await loadAliasFencers()
    } catch (e: unknown) {
      errorType = 'error'
      error = `Create-new-fencer failed: ${e instanceof Error ? e.message : String(e)}`
    }
  }

  function handleAliasCreateClose() {
    createAliasModalOpen = false
    createAliasContext = null
  }

  // Phase 5.5 — placeholder for the staging event_code. Phase 5 admin views
  // already track the selected event in their own state; for the cascade-
  // banner cross-event compare, the operator's "current event" is whichever
  // event they were last viewing in the alias UI. Until that lifting is
  // done, leave this null — the banner still works (it lists touched events
  // generically without the ⚠ "other events" warning).
  let stagingEventCode: string | null = $state(null)

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
    showEvfRanklist: boolean,
    showEvfCalendar: boolean = true,
    europeanType: EuropeanEventType = null,
  ): Promise<string | null> {
    try {
      await updateSeason(id, code, start, end)
      const cfg = await fetchScoringConfig(id)
      if (cfg && (cfg.show_evf_toggle !== showEvfRanklist || cfg.show_evf_toggle_calendar !== showEvfCalendar)) {
        await saveScoringConfig({
          ...cfg,
          show_evf_toggle: showEvfRanklist,
          show_evf_toggle_calendar: showEvfCalendar,
        } as unknown as Record<string, unknown>)
      }
      // Phase 3 (ADR-044): patch tbl_season's carry-over field directly.
      // Done via the api.ts helper since fn_update_season's signature does
      // not include it and we don't want to widen it for one column.
      // Part 2 (ADR-044 amend): carryover-days removed from the UI.
      await updateSeasonCarryoverFields(id, europeanType)
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

  async function handleFetchEvfToggle(seasonId: number): Promise<{ ranklist: boolean, calendar: boolean }> {
    try {
      const cfg = await fetchScoringConfig(seasonId)
      return {
        ranklist: cfg?.show_evf_toggle ?? false,
        calendar: cfg?.show_evf_toggle_calendar ?? true,
      }
    } catch {
      return { ranklist: false, calendar: true }
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

  // ADR-077 §7 — CERT→PROD season-skeleton promotion. State is DERIVED (never a
  // click-latch): per season, on_prod (present on PROD) > has_children (any event
  // has a tournament — not a skeleton) > promotable. Best-effort: on any read
  // error the map stays empty and seasons default to "promotable" (the actions
  // are still guarded server-side by the RPC/Python, so this is safe).
  let promotionByCode = $state<Record<string, 'promotable' | 'on_prod' | 'has_children'>>({})

  async function refreshPromotionState() {
    if (!dualEnv) { promotionByCode = {}; return }
    try {
      const [childState, prodCodes] = await Promise.all([
        fetchSeasonChildState(),
        fetchProdSeasonCodes(prodUrl, prodKey),
      ])
      const onProd = new Set(prodCodes)
      const next: Record<string, 'promotable' | 'on_prod' | 'has_children'> = {}
      for (const s of seasons) {
        next[s.txt_code] = onProd.has(s.txt_code)
          ? 'on_prod'
          : (childState[s.txt_code] ? 'has_children' : 'promotable')
      }
      promotionByCode = next
    } catch (e: unknown) {
      // Surface in-UI (never console); leave the map empty (safe default).
      error = `Promotion state unavailable: ${e instanceof Error ? e.message : String(e)}`
      errorType = 'error'
      promotionByCode = {}
    }
  }

  // Recompute when the Seasons admin view is open in dual-env and the season set changes.
  $effect(() => {
    if (currentView === 'admin_seasons' && dualEnv && seasons.length > 0) {
      void refreshPromotionState()
    }
  })

  async function handlePromoteSeason(code: string) {
    errorType = 'progress'
    error = `⏳ Promoting ${code} CERT→PROD…`
    errorLink = null
    try {
      const result = await requestDispatch('promote-season.yml', { season_code: code, action: 'promote' })
      if (result.ok) {
        errorType = 'success'
        error = `✓ Promotion of ${code} dispatched. PROD updates in ~30–60s.`
        errorLink = result.runs_url
      } else {
        errorType = 'error'
        error = `Promotion failed: ${result.message}`
      }
    } catch (e: unknown) {
      errorType = 'error'
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleRemoveFromProd(code: string) {
    errorType = 'progress'
    error = `⏳ Removing ${code} from PROD…`
    errorLink = null
    try {
      const result = await requestDispatch('promote-season.yml', { season_code: code, action: 'delete', target: 'PROD' })
      if (result.ok) {
        errorType = 'success'
        error = `✓ Removal of ${code} from PROD dispatched.`
        errorLink = result.runs_url
      } else {
        errorType = 'error'
        error = `Removal failed: ${result.message}`
      }
    } catch (e: unknown) {
      errorType = 'error'
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleCreateEvent(params: Record<string, unknown>) {
    try {
      await createEvent(params as unknown as CreateEventParams)
      await reloadCalendar()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleUpdateEvent(id: number, params: Record<string, unknown>) {
    try {
      await updateEvent(id, params as unknown as UpdateEventParams)
      await reloadCalendar()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleUpdateEventStatus(id: number, status: string) {
    try {
      await updateEventStatus(id, status)
      await reloadCalendar()
    } catch (e: unknown) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function handleDeleteEvent(id: number) {
    try {
      await deleteEventCascade(id)
      await reloadCalendar()
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

  // ADR-084 — the barrel spans every season, so the calendar view is no longer
  // clamped to `selectedSeasonId`. Admin views still load per-season.
  /**
   * The calendar's dataset, and the only thing allowed to set it.
   *
   * It spans EVERY season: the drum rolls back to the start of history with no
   * season clamp (ADR-084 §4), so the season-scoped `fetchCalendarEvents`
   * cannot feed it. Six sites used to refill `calendarEvents` from that query
   * instead — every admin write path among them — which silently cut the
   * calendar down to the selected season after a save. On 2026-09-02 that took
   * the PROD calendar down: 66 month rows became 10 while the barrel still held
   * a selection from the wider set, and the out-of-range index threw out of a
   * `$derived`, killing the whole component tree (CalendarBarrel CB.30).
   *
   * The admin list keeps its own season-scoped load; only this one is shared.
   */
  async function reloadCalendar() {
    if (demo) return
    calendarEvents = await fetchAllCalendarEvents()
  }

  async function loadCalendar() {
    try {
      await reloadCalendar()
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

  /* ---- WordPress embed (chrome="none") ------------------------------------
     Full viewport height by default: the barrel is built from geometry and the
     WordPress page gives it no height of its own. `dvh` rather than `vh` so a
     phone's collapsing address bar does not crop the last row. */
  .ranklist-app.embedded {
    max-width: none;
    /* The event card's entry animation is a perspective rotateX, and while it
       plays the card's bounding box is a few px wider than its container. On a
       phone that briefly spilled sideways and made the card's right border look
       cut off. The overflow is transient and purely decorative, so clip it
       rather than reserve permanent width for it. */
    overflow-x: hidden;
    /* Fills the host, which owns the viewport height (see CalendarElement's
       :host rule). */
    height: 100%;
    padding: 10px 12px;
    display: flex;
    flex-direction: column;
    box-sizing: border-box;
  }
  .embed-bar {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 8px;
    flex: 0 0 auto;
  }
  .embed-home {
    display: inline-flex;
    align-items: center;
    flex: 0 0 auto;
  }
  .embed-logo {
    height: 26px;
    width: auto;
    display: block;
  }
  .embed-title {
    /* Not uppercased: "COMPETITION FINDER" is materially wider than
       "Competition finder" and barely fits a 375px phone beside the mark and
       the language toggle. Sentence case buys the width back. */
    font-size: 28px;
    font-weight: 400;
    color: #173f70;
    /* Takes the slack so the actions sit hard right without justify-content,
       which would also push the mark away from the title. */
    flex: 1 1 auto;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .embed-actions {
    display: flex;
    align-items: center;
    gap: 8px;
    flex: 0 0 auto;
  }
  /* The calendar takes the remaining height; the barrel scrolls inside it
     rather than growing the page. */
  .ranklist-app.embedded :global(.calendar-view) {
    flex: 1 1 auto;
    min-height: 0;
  }
  @media (max-width: 600px) {
    .ranklist-app.embedded {
      padding: 8px;
    }
    .embed-title {
      font-size: 23px;
    }
    .embed-logo {
      height: 22px;
    }
  }
  /* A 375px phone leaves the title barely 110px between the mark and the two
     controls, which clipped it to "Znajdź z…". Buy the width back from the
     things around it rather than letting the page name go unreadable.

     The ENGLISH name is the binding case, not the Polish one. At 20px
     "Competition Finder" measures 167.2px against a 164px box and ellipsed to
     "Competition Finde…", while "Znajdź zawody" (133.6px) had 30px to spare.
     19px plus a 6px bar gap gives the English 6.7px of headroom and the Polish
     41.1px, both on one line, with the SPWS mark left at its full 84px. */
  @media (max-width: 430px) {
    .ranklist-app.embedded {
      padding-left: 10px;
      padding-right: 10px;
    }
    .embed-bar {
      gap: 6px;
    }
    .embed-title {
      font-size: 19px;
    }
    .embed-logo {
      height: 19px;
    }
    .embed-actions {
      gap: 5px;
    }
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
  .calendar-failed {
    max-width: 46rem;
    margin: 48px auto;
    padding: 22px 26px;
    border: 1px solid var(--line, #c9d1dc);
    border-left: 5px solid var(--danger, #9e2418);
    border-radius: 10px;
    background: var(--surface, #fff);
  }
  .calendar-failed p { margin: 0 0 8px; }
  .calendar-failed p:last-child { margin-bottom: 0; }
  .calendar-failed-detail {
    font-family: ui-monospace, "SF Mono", Menlo, monospace;
    font-size: 13px;
    opacity: 0.75;
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
