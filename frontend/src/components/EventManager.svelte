{#if isAdmin}
  <div class="event-manager">
    <div class="event-header">
      <h3>{t('nav_admin_events')}</h3>
      <button data-field="add-event-btn" class="add-btn" onclick={() => { openCreateForm() }}>
        {t('event_add')}
      </button>
    </div>

    <div data-field="event-list" class="event-list">
      {#each filteredEvents as event}
        {@const displayStatus = getEventDisplayStatus(event.enum_status, event.dt_end, event.dt_start)}
        <div class="event-card">
          {#if showForm && editingId === event.id_event}
            <div data-field="event-form" class="event-form">
              <label>{t('event_name_label')} <input data-field="form-name" type="text" bind:value={draftName} /></label>
              <label>{t('event_location_label')} <input data-field="form-location" type="text" bind:value={draftLocation} /></label>
              <label>{t('event_start_label')} <input data-field="form-dt-start" type="date" bind:value={draftDtStart} /></label>
              <label>{t('event_end_label')} <input data-field="form-dt-end" type="date" bind:value={draftDtEnd} /></label>
              <label>{t('event_country_label')} <input data-field="form-country" type="text" bind:value={draftCountry} /></label>
              <label>{t('event_venue_label')} <input data-field="form-venue" type="text" bind:value={draftVenue} /></label>
              <div class="url-section">
                <div class="url-section-header">{t('event_results_url_label')}</div>
                <div class="url-row">
                  <span data-field="url-num-1" class="url-num primary">URL #1</span>
                  <input data-field="form-url-event" type="text" bind:value={draftUrlEvent} />
                </div>
                {#if urlExtrasOpen}
                  <div class="url-row">
                    <span data-field="url-num-2" class="url-num">URL #2</span>
                    <input data-field="form-url-event-2" type="text" bind:value={draftUrlEvent2} placeholder={t('event_results_url_extra_placeholder')} />
                  </div>
                  <div class="url-row">
                    <span data-field="url-num-3" class="url-num">URL #3</span>
                    <input data-field="form-url-event-3" type="text" bind:value={draftUrlEvent3} placeholder={t('event_results_url_extra_placeholder')} />
                  </div>
                  <div class="url-row">
                    <span data-field="url-num-4" class="url-num">URL #4</span>
                    <input data-field="form-url-event-4" type="text" bind:value={draftUrlEvent4} placeholder={t('event_results_url_extra_placeholder')} />
                  </div>
                  <div class="url-row">
                    <span data-field="url-num-5" class="url-num">URL #5</span>
                    <input data-field="form-url-event-5" type="text" bind:value={draftUrlEvent5} placeholder={t('event_results_url_extra_placeholder')} />
                  </div>
                {/if}
                <button data-field="url-extras-disclosure" type="button" class="disclosure-btn" onclick={() => { urlExtrasOpen = !urlExtrasOpen }}>
                  {urlExtrasOpen ? t('event_results_url_disclosure_hide') : t('event_results_url_disclosure_show')}
                  <span class="filled-count">{t('event_results_url_filled_count').replace('{n}', String(extrasFilledCount))}</span>
                </button>
              </div>
              <label>{t('event_invitation_label')} <input data-field="form-invitation" type="text" bind:value={draftInvitation} /></label>
              <label>{t('event_registration_deadline_label')} <input data-field="form-registration-deadline" type="date" bind:value={draftRegistrationDeadline} /></label>
              <label>{t('event_registration_label')} <input data-field="form-registration" type="text" bind:value={draftRegistration} /></label>
              <label>{t('event_entry_fee_label')}
                <div class="fee-row">
                  <input data-field="form-entry-fee" type="number" bind:value={draftEntryFee} />
                  <select data-field="form-currency" bind:value={draftCurrency}>
                    <option value="PLN">PLN</option><option value="EUR">EUR</option><option value="USD">USD</option>
                  </select>
                </div>
              </label>
              <label>{t('event_organizer_label')}
                <select data-field="form-organizer" bind:value={draftOrganizerId}>
                  <option value={0}>--</option>
                  {#each organizers as org}<option value={org.id_organizer}>{org.txt_code}</option>{/each}
                </select>
              </label>
              <label>{t('event_weapons_label')}
                <div data-field="form-weapons" class="weapons-row">
                  {#each WEAPON_OPTIONS as w}<label class="weapon-check"><input type="checkbox" checked={draftWeapons.has(w)} onchange={() => { toggleWeapon(w) }} /> {weaponLabel(w)}</label>{/each}
                </div>
              </label>
              {#if getAvailableStatuses(event).length > 0}
                <label>{t('event_status_label')}
                  <select data-field="event-status-select" bind:value={draftStatus}>
                    <option value={event.enum_status}>{event.enum_status}</option>
                    {#each getAvailableStatuses(event) as next}
                      <option value={next}>{next}</option>
                    {/each}
                  </select>
                </label>
              {/if}
              <div class="form-actions">
                <button data-field="form-save-btn" class="save-btn" onclick={() => { handleSave() }}>{t('event_save')}</button>
                <button data-field="form-cancel-btn" class="cancel-btn" onclick={() => { closeForm() }}>{t('event_cancel')}</button>
              </div>
            </div>
          {/if}
          <div data-field="event-row" class="event-row">
            <button data-field="expand-btn"
                    class="expand-btn"
                    class:refreshing={refreshState.get(event.id_event) === 'visible'}
                    class:refresh-success={refreshState.get(event.id_event) === 'success'}
                    class:refresh-failed={refreshState.get(event.id_event) === 'failed'}
                    onclick={() => { toggleExpand(event.id_event) }}>
              {#if refreshState.get(event.id_event) === 'visible'}◐{:else if refreshState.get(event.id_event) === 'success'}✓{:else if refreshState.get(event.id_event) === 'failed'}⚠{:else}{expandedIds.has(event.id_event) ? '▼' : '▶'}{/if}
            </button>
            <span data-field="event-name" class="event-cell">{event.txt_name}</span>
            <span data-field="event-location" class="event-cell">{event.txt_location ?? ''}</span>
            <span data-field="event-weapons" class="event-cell event-weapons">{formatWeapons(event.arr_weapons ?? [])}</span>
            <span data-field="event-dates" class="event-cell">{event.dt_start ?? ''}{event.dt_end && event.dt_end !== event.dt_start ? ` – ${event.dt_end}` : ''}</span>
            {#if event.url_event}
              <span class="event-cell"><a class="event-url-link" href={event.url_event} target="_blank" rel="noopener" title={event.url_event}>🔗</a></span>
            {/if}
            <span data-field="event-status-badge" class="event-cell status-badge {displayStatus.cssClass}">{t(displayStatus.labelKey)}</span>
            <span data-field="tournament-count" class="event-cell tournament-count-badge">{tournamentsForEvent(event.id_event).length}</span>
            <span class="event-cell"></span>
            <span class="event-cell actions">
              {#if event.url_event}
                <button data-field="event-import-btn" class="action-btn import-btn" title={t('tooltip_import_event')} onclick={() => { handleDispatchEvent(event) }}>⬇</button>
              {/if}
              <button data-field="edit-btn" class="icon-btn" title={t('tooltip_edit_event')} onclick={() => { openEditForm(event) }}>&#9998;</button>
              <button data-field="delete-btn" class="icon-btn delete" title={t('tooltip_delete_event')} onclick={() => { if (confirm(t('confirm_delete_event'))) ondelete(event.id_event) }}>&#128465;</button>
            </span>
          </div>

          {#if dispatchStatus.get(event.id_event)}
            {@const ds = dispatchStatus.get(event.id_event)!}
            {@const rs = refreshState.get(event.id_event)}
            <div data-field="dispatch-status-{event.id_event}"
                 class="dispatch-status dispatch-{rs === 'visible' || rs === 'success' ? 'pending' : ds.phase}">
              {#if rs === 'visible'}
                <span class="dispatch-msg">🔄 Refreshing tournament data…</span>
              {:else if rs === 'success'}
                <span class="dispatch-msg">✓ Refreshed at {new Date().toTimeString().slice(0, 8)}</span>
              {:else}
                <span class="dispatch-msg">{ds.message}</span>
                {#if ds.link}
                  <a class="dispatch-link" href={ds.link} target="_blank" rel="noopener">view run on GitHub Actions ↗</a>
                {/if}
              {/if}
            </div>
          {/if}

          {#if expandedIds.has(event.id_event)}
            <div data-field="tournament-list" class="tournament-list">
              {#each tournamentsForEvent(event.id_event) as tourn}
                {#if editingTournId === tourn.id_tournament}
                  <div data-field="tourn-edit-form" class="tourn-edit-form">
                    <label>{t('tournament_code')}
                      <input data-field="tourn-edit-code" type="text" bind:value={tournEditCode} />
                    </label>
                    <label>{t('tournament_url')}
                      <input data-field="tourn-edit-url" type="text" bind:value={tournEditUrl} />
                    </label>
                    <label>{t('tournament_status')}
                      <select data-field="tourn-edit-status" bind:value={tournEditStatus}>
                        <option value="PLANNED">PLANNED</option>
                        <option value="PENDING">PENDING</option>
                        <option value="IMPORTED">IMPORTED</option>
                        <option value="SCORED">SCORED</option>
                        <option value="REJECTED">REJECTED</option>
                      </select>
                    </label>
                    <label>{t('tournament_status_reason')}
                      <input data-field="tourn-edit-reason" type="text" bind:value={tournEditReason} />
                    </label>
                    <div class="form-actions">
                      <button data-field="tourn-edit-save" class="save-btn" onclick={() => { handleTournEditSave() }}>{t('event_save')}</button>
                      <button class="cancel-btn" onclick={() => { editingTournId = null }}>{t('event_cancel')}</button>
                    </div>
                  </div>
                {:else}
                  <div data-field="tournament-row" class="tourn-row">
                    <span data-field="tourn-code" class="tourn-cell tourn-code">{tourn.txt_code}</span>
                    <span class="tourn-cell tourn-type-badge">{tourn.enum_type}</span>
                    <span class="tourn-cell">{tourn.enum_weapon}</span>
                    <span class="tourn-cell">{tourn.enum_age_category} {tourn.enum_gender}</span>
                    <span data-field="tourn-import-status" class="tourn-cell import-badge {importStatusClass(tourn.enum_import_status)}">{tourn.enum_import_status}</span>
                    <span data-field="tourn-participants" class="tourn-cell">{tourn.int_participant_count ?? '—'}</span>
                    <span class="tourn-cell actions">
                      <button data-field="tourn-import-btn" class="action-btn import-btn" title={t('tooltip_import_tournament')} onclick={() => { handleDispatchTournament(tourn) }}>⬇</button>
                      <button data-field="tourn-edit-btn" class="icon-btn" title={t('tooltip_edit_tournament')} onclick={() => { openTournEditForm(tourn) }}>&#9998;</button>
                      <button data-field="tourn-delete-btn" class="icon-btn delete" title={t('tooltip_delete_tournament')} onclick={() => { if (confirm(t('confirm_delete_tournament'))) ondeletetournament(tourn.id_tournament) }}>&#128465;</button>
                    </span>
                  </div>
                {/if}
              {/each}

              {#if creatingTournForEvent === event.id_event}
                <div data-field="tourn-create-form" class="tourn-edit-form">
                  <label>{t('weapon')}
                    <select data-field="tourn-create-weapon" bind:value={tournCreateWeapon}>
                      <option value="EPEE">{t('epee')}</option>
                      <option value="FOIL">{t('foil')}</option>
                      <option value="SABRE">{t('sabre')}</option>
                    </select>
                  </label>
                  <label>{t('gender')}
                    <select data-field="tourn-create-gender" bind:value={tournCreateGender}>
                      <option value="M">{t('men')}</option>
                      <option value="F">{t('women')}</option>
                    </select>
                  </label>
                  <label>{t('category')}
                    <select data-field="tourn-create-category" bind:value={tournCreateCategory}>
                      <option value="V0">V0</option>
                      <option value="V1">V1</option>
                      <option value="V2">V2</option>
                      <option value="V3">V3</option>
                      <option value="V4">V4</option>
                    </select>
                  </label>
                  <label>{t('tournament_type')}
                    <select data-field="tourn-create-type" bind:value={tournCreateType}>
                      <option value="PPW">PPW</option>
                      <option value="MPW">MPW</option>
                      <option value="PEW">PEW</option>
                      <option value="MEW">MEW</option>
                      <option value="MSW">MSW</option>
                      <option value="PSW">PSW</option>
                    </select>
                  </label>
                  <label>{t('tournament_url')}
                    <input data-field="tourn-create-url" type="text" bind:value={tournCreateUrl} />
                  </label>
                  <div class="form-actions">
                    <button data-field="tourn-create-save" class="save-btn" onclick={() => { handleTournCreateSave(event) }}>{t('event_save')}</button>
                    <button class="cancel-btn" onclick={() => { creatingTournForEvent = null }}>{t('event_cancel')}</button>
                  </div>
                </div>
              {:else}
                <button data-field="tourn-add-btn" class="action-btn add-btn" title={t('tooltip_add_tournament')} onclick={() => { creatingTournForEvent = event.id_event }}>+ {t('tooltip_add_tournament')}</button>
              {/if}
            </div>
          {/if}
        </div>
      {/each}

      {#if showForm && editingId === null}
        <div data-field="event-form" class="event-form">
          <label>{t('event_name_label')} <input data-field="form-name" type="text" bind:value={draftName} /></label>
          <label>{t('event_location_label')} <input data-field="form-location" type="text" bind:value={draftLocation} /></label>
          <label>{t('event_start_label')} <input data-field="form-dt-start" type="date" bind:value={draftDtStart} /></label>
          <label>{t('event_end_label')} <input data-field="form-dt-end" type="date" bind:value={draftDtEnd} /></label>
          <label>{t('event_country_label')} <input data-field="form-country" type="text" bind:value={draftCountry} /></label>
          <label>{t('event_venue_label')} <input data-field="form-venue" type="text" bind:value={draftVenue} /></label>
          <label>{t('event_results_url_label')} <input data-field="form-url-event" type="text" bind:value={draftUrlEvent} /></label>
          <label>{t('event_invitation_label')} <input data-field="form-invitation" type="text" bind:value={draftInvitation} /></label>
          <label>{t('event_registration_deadline_label')} <input data-field="form-registration-deadline" type="date" bind:value={draftRegistrationDeadline} /></label>
          <label>{t('event_registration_label')} <input data-field="form-registration" type="text" bind:value={draftRegistration} /></label>
          <label>{t('event_entry_fee_label')}
            <div class="fee-row">
              <input data-field="form-entry-fee" type="number" bind:value={draftEntryFee} />
              <select data-field="form-currency" bind:value={draftCurrency}>
                <option value="PLN">PLN</option><option value="EUR">EUR</option><option value="USD">USD</option>
              </select>
            </div>
          </label>
          <label>{t('event_organizer_label')}
            <select data-field="form-organizer" bind:value={draftOrganizerId}>
              <option value={0}>--</option>
              {#each organizers as org}<option value={org.id_organizer}>{org.txt_code}</option>{/each}
            </select>
          </label>
          <label>{t('event_weapons_label')}
            <div data-field="form-weapons" class="weapons-row">
              {#each WEAPON_OPTIONS as w}<label class="weapon-check"><input type="checkbox" checked={draftWeapons.has(w)} onchange={() => { toggleWeapon(w) }} /> {weaponLabel(w)}</label>{/each}
            </div>
          </label>
          <div class="form-actions">
            <button data-field="form-save-btn" class="save-btn" onclick={() => { handleSave() }}>{t('event_save')}</button>
            <button data-field="form-cancel-btn" class="cancel-btn" onclick={() => { closeForm() }}>{t('event_cancel')}</button>
          </div>
        </div>
      {/if}
    </div>
  </div>
{/if}

<script lang="ts">
  import type { CalendarEvent, Season, Organizer, WeaponType, Tournament, TournamentType, GenderType, AgeCategory } from '../lib/types'
  import { t } from '../lib/locale.svelte'
  import { getEventDisplayStatus } from '../lib/eventStatus'
  import { requestDispatch } from '../lib/api'

  // ADR-041: Per-event dispatch status, rendered inline below each event-row.
  type DispatchPhase = 'pending' | 'success' | 'error'
  type DispatchState = { phase: DispatchPhase; message: string; link?: string; ts: number }
  let dispatchStatus: Map<number, DispatchState> = $state(new Map())

  // ADR-041 follow-up — refresh state machine (per event):
  //   idle ─▶ pending ─[<200ms]──▶ success-flash (1.5s) ─▶ idle
  //               ↘[≥200ms]─▶ visible (spinner shown) ─▶ success-flash ─▶ idle
  //                                              ↘[error]─▶ failed (3s) ─▶ idle
  type RefreshPhase = 'pending' | 'visible' | 'success' | 'failed'
  let refreshState: Map<number, RefreshPhase> = $state(new Map())
  // Auto-refresh timers scheduled by dispatchAndTrack (per-event). A second
  // dispatch on the same event clears the prior timer (latest wins).
  const dispatchTimers: Map<number, ReturnType<typeof setTimeout>> = new Map()

  function setRefreshState(id: number, phase: RefreshPhase | null) {
    const next = new Map(refreshState)
    if (phase == null) next.delete(id)
    else next.set(id, phase)
    refreshState = next
  }

  // Delayed-show pattern: only render the spinner if the refresh takes >200 ms.
  // Sub-200ms refreshes complete silently — no flicker on fast networks.
  // After a successful refresh, also clear the dispatch banner — its purpose
  // was to track the dispatch + downstream refresh, which is now complete.
  // Only clear if the banner hasn't been replaced by a newer dispatch since
  // this refresh started (compare ts).
  async function runRefreshFor(eventId: number) {
    setRefreshState(eventId, 'pending')
    const dispatchTsAtStart = dispatchStatus.get(eventId)?.ts
    const visibilityTimer = setTimeout(() => {
      if (refreshState.get(eventId) === 'pending') {
        setRefreshState(eventId, 'visible')
      }
    }, 200)
    try {
      await onrefresh()
      clearTimeout(visibilityTimer)
      setRefreshState(eventId, 'success')
      setTimeout(() => {
        if (refreshState.get(eventId) === 'success') {
          setRefreshState(eventId, null)
          const cur = dispatchStatus.get(eventId)
          if (cur && cur.ts === dispatchTsAtStart) {
            const next = new Map(dispatchStatus)
            next.delete(eventId)
            dispatchStatus = next
          }
        }
      }, 1500)
    } catch {
      clearTimeout(visibilityTimer)
      setRefreshState(eventId, 'failed')
      setTimeout(() => {
        if (refreshState.get(eventId) === 'failed') setRefreshState(eventId, null)
      }, 3000)
    }
  }

  function setDispatchStatus(id: number, s: DispatchState) {
    const next = new Map(dispatchStatus)
    next.set(id, s)
    dispatchStatus = next
    if (s.phase !== 'pending') {
      // Auto-clear terminal states after 5 minutes so the row doesn't
      // accumulate stale banners forever.
      const stamp = s.ts
      setTimeout(() => {
        const m = new Map(dispatchStatus)
        const cur = m.get(id)
        if (cur && cur.ts === stamp) {
          m.delete(id)
          dispatchStatus = m
        }
      }, 5 * 60 * 1000)
    }
  }

  async function dispatchAndTrack(
    statusId: number,
    workflow: 'populate-urls.yml' | 'scrape-tournament.yml',
    inputs: Record<string, string>,
    label: string,
  ) {
    setDispatchStatus(statusId, {
      phase: 'pending',
      message: `⏳ Triggering ${workflow.replace('.yml', '')} for ${label}…`,
      ts: Date.now(),
    })
    try {
      const result = await requestDispatch(workflow, inputs)
      if (result.ok) {
        setDispatchStatus(statusId, {
          phase: 'success',
          message: `✓ Triggered: ${label}`,
          link: result.runs_url,
          ts: Date.now(),
        })
        // Auto-refresh ~40s after dispatch success — workflow runs ~20-30s
        // on GH Actions, 40s gives slack. New dispatch on the same event
        // clears the prior timer (latest wins, no double-fire).
        const prev = dispatchTimers.get(statusId)
        if (prev) clearTimeout(prev)
        const timerId = setTimeout(() => { void runRefreshFor(statusId) }, 40_000)
        dispatchTimers.set(statusId, timerId)
      } else {
        setDispatchStatus(statusId, {
          phase: 'error',
          message: `✗ Dispatch failed: ${result.message}`,
          ts: Date.now(),
        })
      }
    } catch (e: unknown) {
      setDispatchStatus(statusId, {
        phase: 'error',
        message: `✗ Dispatch failed: ${e instanceof Error ? e.message : String(e)}`,
        ts: Date.now(),
      })
    }
  }

  function handleDispatchEvent(event: CalendarEvent) {
    return dispatchAndTrack(
      event.id_event,
      'populate-urls.yml',
      { event_code: event.txt_code, target: activeEnv.toLowerCase() },
      event.txt_code,
    )
  }

  // Tournament dispatch is keyed off the parent event's id so the inline
  // status renders next to the event row (where the tournament list lives).
  function handleDispatchTournament(tourn: Tournament) {
    return dispatchAndTrack(
      tourn.id_event,
      'scrape-tournament.yml',
      { tournament_code: tourn.txt_code, target: activeEnv.toLowerCase() },
      tourn.txt_code,
    )
  }

  const ALL_STATUSES: string[] = ['PLANNED', 'SCHEDULED', 'CHANGED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']

  function getAvailableStatuses(event: CalendarEvent): string[] {
    const today = new Date().toISOString().slice(0, 10)
    if (event.dt_start != null && event.dt_start < today) return []
    return ALL_STATUSES.filter(s => s !== event.enum_status)
  }

  let {
    events = [] as CalendarEvent[],
    seasons = [] as Season[],
    organizers = [] as Organizer[],
    tournaments = [] as Tournament[],
    selectedSeasonId = null as number | null,
    isAdmin = false,
    oncreate = (_evt: Record<string, unknown>) => {},
    onupdate = (_id: number, _evt: Record<string, unknown>) => {},
    onupdatestatus = (_id: number, _status: string) => {},
    ondelete = (_id: number) => {},
    ondeletetournament = (_id: number) => {},
    onedittournament = (_id: number, _params: Record<string, unknown>) => {},
    oncreatetournament = (_eventId: number, _params: Record<string, unknown>) => {},
    // ADR-041 follow-up: parent provides a re-fetch hook (typically
    // App.reloadAdminEvents). Fired automatically 40s after a successful
    // dispatch and on every accordion expand.
    onrefresh = () => Promise.resolve(),
    // ADR-041: which Supabase env the admin is currently viewing. Threaded
    // into workflow_dispatch as `target` so the script writes to the right DB.
    activeEnv = 'CERT' as 'CERT' | 'PROD',
  }: {
    events?: CalendarEvent[]
    seasons?: Season[]
    organizers?: Organizer[]
    tournaments?: Tournament[]
    selectedSeasonId?: number | null
    isAdmin?: boolean
    oncreate?: (evt: Record<string, unknown>) => void
    onupdate?: (id: number, evt: Record<string, unknown>) => void
    onupdatestatus?: (id: number, status: string) => void
    ondelete?: (id: number) => void
    ondeletetournament?: (id: number) => void
    onedittournament?: (id: number, params: Record<string, unknown>) => void
    oncreatetournament?: (eventId: number, params: Record<string, unknown>) => void
    onrefresh?: () => void | Promise<void>
    activeEnv?: 'CERT' | 'PROD'
  } = $props()

  let showForm = $state(false)
  let editingId: number | null = $state(null)
  let draftName = $state('')
  let draftLocation = $state('')
  let draftDtStart = $state('')
  let draftDtEnd = $state('')
  let draftCountry = $state('')
  let draftVenue = $state('')
  let draftInvitation = $state('')
  let draftRegistration = $state('')
  let draftRegistrationDeadline = $state('')
  let draftEntryFee: number | null = $state(null)
  let draftCurrency = $state('PLN')
  let draftUrlEvent = $state('')
  let draftUrlEvent2 = $state('')
  let draftUrlEvent3 = $state('')
  let draftUrlEvent4 = $state('')
  let draftUrlEvent5 = $state('')
  let urlExtrasOpen = $state(false)
  const extrasFilledCount = $derived(
    [draftUrlEvent2, draftUrlEvent3, draftUrlEvent4, draftUrlEvent5]
      .filter(s => s.trim().length > 0).length
  )
  let draftOrganizerId = $state(0)
  let draftWeapons: Set<WeaponType> = $state(new Set(['EPEE', 'FOIL', 'SABRE']))
  let draftStatus = $state('')

  let expandedIds: Set<number> = $state(new Set())

  // Tournament edit state
  let editingTournId: number | null = $state(null)
  let tournEditCode = $state('')
  let tournEditUrl = $state('')
  let tournEditStatus = $state('PLANNED')
  let tournEditReason = $state('')

  function openTournEditForm(tourn: Tournament) {
    editingTournId = tourn.id_tournament
    tournEditCode = tourn.txt_code
    tournEditUrl = tourn.url_results ?? ''
    tournEditStatus = tourn.enum_import_status
    tournEditReason = tourn.txt_import_status_reason ?? ''
  }

  function handleTournEditSave() {
    if (editingTournId == null) return
    onedittournament(editingTournId, {
      code: tournEditCode,
      urlResults: tournEditUrl,
      importStatus: tournEditStatus,
      statusReason: tournEditReason,
    })
    editingTournId = null
  }

  // Tournament create state
  let creatingTournForEvent: number | null = $state(null)
  let tournCreateWeapon = $state('EPEE')
  let tournCreateGender = $state('M')
  let tournCreateCategory = $state('V2')
  let tournCreateType = $state('PPW')
  let tournCreateUrl = $state('')

  function handleTournCreateSave(event: CalendarEvent) {
    oncreatetournament(event.id_event, {
      weapon: tournCreateWeapon,
      gender: tournCreateGender,
      category: tournCreateCategory,
      type: tournCreateType,
      urlResults: tournCreateUrl || null,
      dtTournament: event.dt_start,
    })
    creatingTournForEvent = null
    tournCreateWeapon = 'EPEE'
    tournCreateGender = 'M'
    tournCreateCategory = 'V2'
    tournCreateType = 'PPW'
    tournCreateUrl = ''
  }

  function toggleExpand(eventId: number) {
    const next = new Set(expandedIds)
    const wasExpanded = next.has(eventId)
    if (wasExpanded) {
      next.delete(eventId)
    } else {
      next.add(eventId)
      // ADR-041 follow-up: collapsed → expanded triggers a refresh so the
      // tournament list reflects any URLs populated by a prior dispatch.
      // Collapsing (▼ → ▶) is a no-op for refresh.
      void runRefreshFor(eventId)
    }
    expandedIds = next
  }

  function tournamentsForEvent(eventId: number): Tournament[] {
    return tournaments.filter(t => t.id_event === eventId)
  }

  function importStatusClass(status: string): string {
    switch (status) {
      case 'SCORED': return 'import-scored'
      case 'IMPORTED': return 'import-imported'
      case 'PLANNED': return 'import-planned'
      case 'PENDING': return 'import-pending'
      case 'REJECTED': return 'import-rejected'
      default: return ''
    }
  }

  const WEAPON_OPTIONS: WeaponType[] = ['EPEE', 'FOIL', 'SABRE']

  function toggleWeapon(w: WeaponType) {
    const next = new Set(draftWeapons)
    if (next.has(w)) {
      if (next.size > 1) next.delete(w)  // keep at least one
    } else {
      next.add(w)
    }
    draftWeapons = next
  }

  function weaponLabel(w: WeaponType): string {
    switch (w) {
      case 'EPEE': return t('epee')
      case 'FOIL': return t('foil')
      case 'SABRE': return t('sabre')
    }
  }

  function formatWeapons(weapons: WeaponType[]): string {
    return weapons.map(weaponLabel).join(' + ')
  }

  let filteredEvents = $derived(
    selectedSeasonId != null
      ? events.filter(e => e.id_season === selectedSeasonId)
      : events
  )

  function openCreateForm() {
    editingId = null
    draftName = ''
    draftLocation = ''
    draftDtStart = ''
    draftDtEnd = ''
    draftCountry = ''
    draftVenue = ''
    draftInvitation = ''
    draftRegistration = ''
    draftRegistrationDeadline = ''
    draftEntryFee = null
    draftCurrency = 'PLN'
    draftUrlEvent = ''
    draftUrlEvent2 = ''
    draftUrlEvent3 = ''
    draftUrlEvent4 = ''
    draftUrlEvent5 = ''
    urlExtrasOpen = false
    draftOrganizerId = 0
    draftWeapons = new Set(['EPEE', 'FOIL', 'SABRE'] as WeaponType[])
    showForm = true
  }

  function openEditForm(event: CalendarEvent) {
    editingId = event.id_event
    draftName = event.txt_name
    draftLocation = event.txt_location ?? ''
    draftDtStart = event.dt_start ?? ''
    draftDtEnd = event.dt_end ?? ''
    draftCountry = event.txt_country ?? ''
    draftVenue = event.txt_venue_address ?? ''
    draftInvitation = event.url_invitation ?? ''
    draftRegistration = event.url_registration ?? ''
    draftRegistrationDeadline = event.dt_registration_deadline ?? ''
    draftEntryFee = event.num_entry_fee
    draftCurrency = event.txt_entry_fee_currency ?? 'PLN'
    draftUrlEvent = event.url_event ?? ''
    draftUrlEvent2 = event.url_event_2 ?? ''
    draftUrlEvent3 = event.url_event_3 ?? ''
    draftUrlEvent4 = event.url_event_4 ?? ''
    draftUrlEvent5 = event.url_event_5 ?? ''
    urlExtrasOpen = !!(event.url_event_2 || event.url_event_3 || event.url_event_4 || event.url_event_5)
    draftOrganizerId = event.id_organizer ?? 0
    draftWeapons = new Set((event.arr_weapons ?? ['EPEE', 'FOIL', 'SABRE']) as WeaponType[])
    draftStatus = event.enum_status
    showForm = true
  }

  function closeForm() {
    showForm = false
    editingId = null
  }

  // ADR-040: trim whitespace, drop empties, dedupe preserving first occurrence,
  // pad with NULL to length 5. Slot positions are non-semantic — compaction
  // guarantees the "URL #1 is the canonical primary URL" invariant.
  function compactUrls(urls: (string | null | undefined)[]): (string | null)[] {
    const seen = new Set<string>()
    const compact: string[] = []
    for (const u of urls) {
      const trimmed = (u ?? '').trim()
      if (trimmed && !seen.has(trimmed)) {
        seen.add(trimmed)
        compact.push(trimmed)
      }
    }
    const padded: (string | null)[] = [...compact]
    while (padded.length < 5) padded.push(null)
    return padded.slice(0, 5)
  }

  function handleSave() {
    const compact = compactUrls([draftUrlEvent, draftUrlEvent2, draftUrlEvent3, draftUrlEvent4, draftUrlEvent5])
    const params = {
      name: draftName,
      location: draftLocation || undefined,
      dtStart: draftDtStart || undefined,
      dtEnd: draftDtEnd || undefined,
      urlEvent: compact[0] ?? undefined,
      country: draftCountry || undefined,
      venueAddress: draftVenue || undefined,
      invitation: draftInvitation || undefined,
      registration: draftRegistration || undefined,
      registrationDeadline: draftRegistrationDeadline || undefined,
      entryFee: draftEntryFee ?? undefined,
      entryFeeCurrency: draftCurrency || undefined,
      organizerId: draftOrganizerId || undefined,
      weapons: [...draftWeapons],
      urlEvent2: compact[1],
      urlEvent3: compact[2],
      urlEvent4: compact[3],
      urlEvent5: compact[4],
    }
    if (editingId != null) {
      onupdate(editingId, params)
      const originalEvent = filteredEvents.find(e => e.id_event === editingId)
      if (originalEvent && draftStatus !== originalEvent.enum_status) {
        onupdatestatus(editingId, draftStatus)
      }
    } else {
      oncreate(params)
    }
    closeForm()
  }

  function handleStatusChange(_eventId: number, _newStatus: string) {
  }
</script>

<style>
  .event-manager {
    padding: 16px;
  }
  .event-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 16px;
  }
  .event-header h3 {
    margin: 0;
    font-size: 18px;
    color: #333;
  }
  .add-btn {
    padding: 8px 16px;
    border: none;
    border-radius: 4px;
    background: #4a90d9;
    color: #fff;
    font-size: 14px;
    cursor: pointer;
  }
  .add-btn:hover {
    background: #3a7bc8;
  }
  .event-form {
    display: flex;
    gap: 12px;
    align-items: flex-end;
    padding: 12px;
    margin-bottom: 8px;
    background: #eef4fb;
    border: 1px solid #b8d4ee;
    border-radius: 4px;
    flex-wrap: wrap;
  }
  .event-form label {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 13px;
    color: #555;
  }
  .event-form input,
  .event-form select {
    padding: 6px 10px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 14px;
  }
  .weapons-row {
    display: flex;
    gap: 10px;
  }
  .weapon-check {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 4px;
    font-size: 13px;
    cursor: pointer;
  }
  .event-weapons {
    font-size: 12px;
    color: #4a90d9;
  }
  /* ADR-041 follow-up: expand triangle morphs into spinner / status glyph
     during refresh. Colours stay subtle so the calendar isn't visually busy. */
  .expand-btn.refreshing {
    color: #2a5a9a;
    animation: spws-spin 1.1s linear infinite;
    display: inline-block;
  }
  .expand-btn.refresh-success { color: #2a7a3a; }
  .expand-btn.refresh-failed  { color: #c33; }
  @keyframes spws-spin { to { transform: rotate(360deg); } }

  .dispatch-status {
    margin: 6px 12px 8px 12px;
    padding: 8px 12px;
    border-radius: 4px;
    font-size: 13px;
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    align-items: center;
  }
  .dispatch-status.dispatch-pending { background: #f0f6ff; border: 1px solid #b8d4ee; color: #2a5a9a; }
  .dispatch-status.dispatch-success { background: #f0fff4; border: 1px solid #b8e6c4; color: #2a7a3a; }
  .dispatch-status.dispatch-error   { background: #fff0f0; border: 1px solid #fcc;    color: #c33; }
  .dispatch-status .dispatch-link { color: inherit; text-decoration: underline; font-weight: 600; }
  .url-section {
    display: flex;
    flex-direction: column;
    gap: 6px;
    width: 100%;
    padding: 10px 12px;
    border: 1px dashed #b8d4ee;
    border-radius: 4px;
    background: rgba(74, 144, 217, 0.04);
  }
  .url-section-header {
    font-size: 12px;
    font-weight: 600;
    color: #4a90d9;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .url-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .url-row input { flex: 1; }
  .url-num {
    font-size: 11px;
    font-family: monospace;
    color: #888;
    background: #fff;
    border: 1px solid #ccc;
    border-radius: 4px;
    padding: 4px 8px;
    min-width: 56px;
    text-align: center;
  }
  .url-num.primary { color: #4a90d9; border-color: #4a90d9; background: rgba(74, 144, 217, 0.08); }
  .disclosure-btn {
    align-self: flex-start;
    background: none;
    border: none;
    color: #4a90d9;
    font-size: 12px;
    cursor: pointer;
    padding: 4px 0;
  }
  .disclosure-btn:hover { text-decoration: underline; }
  .filled-count { color: #888; margin-left: 4px; }
  .fee-row {
    display: flex;
    gap: 6px;
  }
  .fee-row input {
    flex: 1;
    min-width: 80px;
  }
  .fee-row select {
    width: 70px;
  }
  .form-actions {
    display: flex;
    gap: 8px;
    align-items: flex-end;
  }
  .save-btn {
    padding: 6px 14px;
    border: none;
    border-radius: 4px;
    background: #2ecc71;
    color: #fff;
    font-size: 13px;
    cursor: pointer;
  }
  .cancel-btn {
    padding: 6px 14px;
    border: 1px solid #ccc;
    border-radius: 4px;
    background: #fff;
    color: #555;
    font-size: 13px;
    cursor: pointer;
  }
  .event-list {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .event-row {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 10px 12px;
    background: #fff;
    border: 1px solid #e8e8e8;
    border-radius: 4px;
  }
  .event-row:hover {
    background: #f8f9fa;
  }
  .event-cell {
    font-size: 14px;
    color: #333;
  }
  .event-cell.actions {
    margin-left: auto;
    display: flex;
    gap: 6px;
  }
  .status-badge {
    font-size: 11px;
    padding: 2px 8px;
    border-radius: 10px;
    font-weight: 600;
  }
  .status-completed { background: #d4edda; color: #155724; }
  .status-scheduled { background: #cce5ff; color: #004085; }
  .status-planned { background: #e2e3e5; color: #383d41; }
  .status-cancelled { background: #f8d7da; color: #721c24; }
  .status-inprogress { background: #fff3cd; color: #856404; }
  .status-changed { background: #ffe0cc; color: #8a4500; }
  .status-awaiting { background: #fef3c7; color: #92400e; }
  .event-url-link {
    text-decoration: none;
    font-size: 14px;
  }
  .event-url-link:hover {
    opacity: 0.7;
  }
  .icon-btn {
    border: 1px solid #ccc;
    background: #fff;
    cursor: pointer;
    font-size: 14px;
    padding: 4px 8px;
    border-radius: 4px;
    color: #555;
    transition: all 0.15s;
  }
  .icon-btn:hover {
    background: #f0f0f0;
    border-color: #999;
    color: #222;
  }
  .icon-btn.delete {
    color: #999;
  }
  .icon-btn.delete:hover {
    background: #ffeef0;
    border-color: #c33;
    color: #c33;
  }
  .event-card {
    margin-bottom: 2px;
  }
  .expand-btn {
    border: none;
    background: none;
    cursor: pointer;
    font-size: 12px;
    padding: 4px;
    color: #4a90d9;
    min-width: 20px;
  }
  .tournament-count-badge {
    background: #e0e8f0;
    color: #4a90d9;
    padding: 2px 8px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 600;
    min-width: 24px;
    text-align: center;
  }
  .tournament-list {
    background: #f4f6f8;
    border: 1px solid #e0e0e0;
    border-top: none;
    border-radius: 0 0 4px 4px;
    padding: 4px 12px 8px 32px;
  }
  .tourn-edit-form {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    padding: 10px;
    background: #f5f7f0;
    border: 1px solid #d4dcc8;
    border-radius: 4px;
    margin-bottom: 6px;
    font-size: 13px;
  }
  .tourn-edit-form label {
    display: flex;
    flex-direction: column;
    gap: 2px;
    font-size: 11px;
    font-weight: 600;
    color: #666;
  }
  .tourn-edit-form input,
  .tourn-edit-form select {
    padding: 4px 8px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 13px;
  }
  .add-btn {
    margin-top: 6px;
    font-size: 12px;
    color: #4a90d9;
    background: none;
    border: 1px dashed #4a90d9;
    border-radius: 4px;
    padding: 4px 12px;
    cursor: pointer;
  }
  .add-btn:hover {
    background: #f0f6ff;
  }
  .tourn-row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 6px 0;
    border-bottom: 1px solid #e8e8e8;
    font-size: 13px;
  }
  .tourn-row:last-child {
    border-bottom: none;
  }
  .tourn-cell {
    color: #333;
  }
  .tourn-code {
    font-family: monospace;
    font-size: 12px;
    color: #4a90d9;
    min-width: 180px;
  }
  .tourn-type-badge {
    font-size: 10px;
    padding: 1px 6px;
    border-radius: 8px;
    font-weight: 600;
    background: #d4edda;
    color: #155724;
  }
  .import-badge {
    font-size: 10px;
    padding: 1px 6px;
    border-radius: 8px;
    font-weight: 600;
  }
  .import-scored { background: #d4edda; color: #155724; }
  .import-imported { background: #cce5ff; color: #004085; }
  .import-planned { background: #e2e3e5; color: #383d41; }
  .import-pending { background: #fff3cd; color: #856404; }
  .import-rejected { background: #f8d7da; color: #721c24; }
  .action-btn {
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 12px;
    cursor: pointer;
    font-weight: 600;
    border: 1px solid;
  }
  .import-btn {
    background: #d4edda;
    color: #155724;
    border-color: #155724;
  }
  .import-btn:hover {
    background: #c3e6cb;
  }
</style>
