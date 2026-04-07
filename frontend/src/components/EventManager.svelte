{#if isAdmin}
  <div class="event-manager">
    <div class="event-header">
      <h3>{t('nav_admin_events')}</h3>
      <button data-field="add-event-btn" class="add-btn" onclick={() => { openCreateForm() }}>
        {t('event_add')}
      </button>
    </div>

    {#if showForm}
      <div data-field="event-form" class="event-form">
        <label>
          {t('event_name_label')}
          <input data-field="form-name" type="text" bind:value={draftName} />
        </label>
        <label>
          {t('event_location_label')}
          <input data-field="form-location" type="text" bind:value={draftLocation} />
        </label>
        <label>
          {t('event_start_label')}
          <input data-field="form-dt-start" type="date" bind:value={draftDtStart} />
        </label>
        <label>
          {t('event_end_label')}
          <input data-field="form-dt-end" type="date" bind:value={draftDtEnd} />
        </label>
        <label>
          {t('event_country_label')}
          <input data-field="form-country" type="text" bind:value={draftCountry} />
        </label>
        <label>
          {t('event_venue_label')}
          <input data-field="form-venue" type="text" bind:value={draftVenue} />
        </label>
        <label>
          {t('event_results_url_label')}
          <input data-field="form-url-event" type="text" bind:value={draftUrlEvent} />
        </label>
        <label>
          {t('event_invitation_label')}
          <input data-field="form-invitation" type="text" bind:value={draftInvitation} />
        </label>
        <label>
          {t('event_entry_fee_label')}
          <div class="fee-row">
            <input data-field="form-entry-fee" type="number" bind:value={draftEntryFee} />
            <select data-field="form-currency" bind:value={draftCurrency}>
              <option value="PLN">PLN</option>
              <option value="EUR">EUR</option>
              <option value="USD">USD</option>
            </select>
          </div>
        </label>
        <label>
          {t('event_organizer_label')}
          <select data-field="form-organizer" bind:value={draftOrganizerId}>
            <option value={0}>--</option>
            {#each organizers as org}
              <option value={org.id_organizer}>{org.txt_code}</option>
            {/each}
          </select>
        </label>
        <label>
          {t('event_weapons_label')}
          <div data-field="form-weapons" class="weapons-row">
            {#each WEAPON_OPTIONS as w}
              <label class="weapon-check">
                <input type="checkbox" checked={draftWeapons.has(w)} onchange={() => { toggleWeapon(w) }} />
                {weaponLabel(w)}
              </label>
            {/each}
          </div>
        </label>
        <div class="form-actions">
          <button data-field="form-save-btn" class="save-btn" onclick={() => { handleSave() }}>
            {t('event_save')}
          </button>
          <button data-field="form-cancel-btn" class="cancel-btn" onclick={() => { closeForm() }}>
            {t('event_cancel')}
          </button>
        </div>
      </div>
    {/if}

    <div data-field="event-list" class="event-list">
      {#each filteredEvents as event}
        <div class="event-card">
          <div data-field="event-row" class="event-row">
            <button data-field="expand-btn" class="expand-btn" onclick={() => { toggleExpand(event.id_event) }}>
              {expandedIds.has(event.id_event) ? '▼' : '▶'}
            </button>
            <span data-field="event-name" class="event-cell">{event.txt_name}</span>
            <span data-field="event-location" class="event-cell">{event.txt_location ?? ''}</span>
            <span data-field="event-weapons" class="event-cell event-weapons">{formatWeapons(event.arr_weapons ?? [])}</span>
            <span data-field="event-dates" class="event-cell">{event.dt_start ?? ''}{event.dt_end && event.dt_end !== event.dt_start ? ` – ${event.dt_end}` : ''}</span>
            <span data-field="event-status-badge" class="event-cell status-badge {statusClass(event.enum_status)}">{event.enum_status}</span>
            <span data-field="tournament-count" class="event-cell tournament-count-badge">{tournamentsForEvent(event.id_event).length}</span>
            <span class="event-cell">
              {#if VALID_TRANSITIONS[event.enum_status]?.length > 0}
                <select data-field="event-status-select" onchange={(e) => { handleStatusChange(event.id_event, (e.target as HTMLSelectElement).value) }}>
                  <option value="">--</option>
                  {#each VALID_TRANSITIONS[event.enum_status] as next}
                    <option value={next}>{next}</option>
                  {/each}
                </select>
              {/if}
            </span>
            <span class="event-cell actions">
              <button data-field="edit-btn" class="icon-btn" title={t('tooltip_edit_event')} onclick={() => { openEditForm(event) }}>&#9998;</button>
              <button data-field="delete-btn" class="icon-btn delete" title={t('tooltip_delete_event')} onclick={() => { if (confirm(t('confirm_delete_event'))) ondelete(event.id_event) }}>&#128465;</button>
            </span>
          </div>

          {#if expandedIds.has(event.id_event)}
            <div data-field="tournament-list" class="tournament-list">
              {#each tournamentsForEvent(event.id_event) as tourn}
                <div data-field="tournament-row" class="tourn-row">
                  <span data-field="tourn-code" class="tourn-cell tourn-code">{tourn.txt_code}</span>
                  <span class="tourn-cell tourn-type-badge">{tourn.enum_type}</span>
                  <span class="tourn-cell">{tourn.enum_weapon}</span>
                  <span class="tourn-cell">{tourn.enum_age_category} {tourn.enum_gender}</span>
                  <span data-field="tourn-import-status" class="tourn-cell import-badge {importStatusClass(tourn.enum_import_status)}">{tourn.enum_import_status}</span>
                  <span data-field="tourn-participants" class="tourn-cell">{tourn.int_participant_count ?? '—'}</span>
                  <span class="tourn-cell actions">
                    <button data-field="tourn-import-btn" class="action-btn import-btn" title={t('tooltip_import_tournament')} onclick={() => { onimporttournament(tourn.id_tournament, tourn.enum_import_status !== 'PLANNED') }}>⬇</button>
                    <button data-field="tourn-edit-btn" class="icon-btn" title={t('tooltip_edit_tournament')} onclick={() => { onedittournament(tourn.id_tournament) }}>&#9998;</button>
                    <button data-field="tourn-delete-btn" class="icon-btn delete" title={t('tooltip_delete_tournament')} onclick={() => { if (confirm(t('confirm_delete_tournament'))) ondeletetournament(tourn.id_tournament) }}>&#128465;</button>
                  </span>
                </div>
              {/each}
            </div>
          {/if}
        </div>
      {/each}
    </div>
  </div>
{/if}

<script lang="ts">
  import type { CalendarEvent, Season, Organizer, WeaponType, Tournament } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  const VALID_TRANSITIONS: Record<string, string[]> = {
    PLANNED:     ['SCHEDULED', 'CANCELLED'],
    SCHEDULED:   ['CHANGED', 'IN_PROGRESS', 'CANCELLED'],
    CHANGED:     ['SCHEDULED', 'IN_PROGRESS', 'CANCELLED'],
    IN_PROGRESS: ['COMPLETED', 'CANCELLED'],
    COMPLETED:   [],
    CANCELLED:   [],
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
    onimporttournament = (_id: number, _isReimport: boolean) => {},
    onedittournament = (_id: number) => {},
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
    onimporttournament?: (id: number, isReimport: boolean) => void
    onedittournament?: (id: number) => void
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
  let draftEntryFee: number | null = $state(null)
  let draftCurrency = $state('PLN')
  let draftUrlEvent = $state('')
  let draftOrganizerId = $state(0)
  let draftWeapons: Set<WeaponType> = $state(new Set(['EPEE', 'FOIL', 'SABRE']))

  let expandedIds: Set<number> = $state(new Set())

  function toggleExpand(eventId: number) {
    const next = new Set(expandedIds)
    if (next.has(eventId)) {
      next.delete(eventId)
    } else {
      next.add(eventId)
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

  function statusClass(status: string): string {
    switch (status) {
      case 'COMPLETED': return 'status-completed'
      case 'SCHEDULED': return 'status-scheduled'
      case 'PLANNED': return 'status-planned'
      case 'CANCELLED': return 'status-cancelled'
      case 'IN_PROGRESS': return 'status-in-progress'
      case 'CHANGED': return 'status-changed'
      default: return ''
    }
  }

  function openCreateForm() {
    editingId = null
    draftName = ''
    draftLocation = ''
    draftDtStart = ''
    draftDtEnd = ''
    draftCountry = ''
    draftVenue = ''
    draftInvitation = ''
    draftEntryFee = null
    draftCurrency = 'PLN'
    draftUrlEvent = ''
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
    draftEntryFee = event.num_entry_fee
    draftCurrency = event.txt_entry_fee_currency ?? 'PLN'
    draftUrlEvent = event.url_event ?? ''
    draftOrganizerId = event.id_organizer ?? 0
    draftWeapons = new Set((event.arr_weapons ?? ['EPEE', 'FOIL', 'SABRE']) as WeaponType[])
    showForm = true
  }

  function closeForm() {
    showForm = false
    editingId = null
  }

  function handleSave() {
    const params = {
      name: draftName,
      location: draftLocation || undefined,
      dtStart: draftDtStart || undefined,
      dtEnd: draftDtEnd || undefined,
      urlEvent: draftUrlEvent || undefined,
      country: draftCountry || undefined,
      venueAddress: draftVenue || undefined,
      invitation: draftInvitation || undefined,
      entryFee: draftEntryFee ?? undefined,
      entryFeeCurrency: draftCurrency || undefined,
      organizerId: draftOrganizerId || undefined,
      weapons: [...draftWeapons],
    }
    if (editingId != null) {
      onupdate(editingId, params)
    } else {
      oncreate(params)
    }
    closeForm()
  }

  function handleStatusChange(eventId: number, newStatus: string) {
    if (newStatus) {
      onupdatestatus(eventId, newStatus)
    }
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
    margin-bottom: 16px;
    background: #f8f9fa;
    border: 1px solid #e0e0e0;
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
  .status-in-progress { background: #fff3cd; color: #856404; }
  .status-changed { background: #ffe0cc; color: #8a4500; }
  .icon-btn {
    border: none;
    background: none;
    cursor: pointer;
    font-size: 16px;
    padding: 4px;
    color: #666;
  }
  .icon-btn:hover {
    color: #333;
  }
  .icon-btn.delete:hover {
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
