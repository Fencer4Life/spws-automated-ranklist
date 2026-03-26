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
          {t('event_invitation_label')}
          <input data-field="form-invitation" type="text" bind:value={draftInvitation} />
        </label>
        <label>
          {t('event_entry_fee_label')}
          <input data-field="form-entry-fee" type="number" bind:value={draftEntryFee} />
        </label>
        <label>
          {t('event_organizer_label')}
          <select data-field="form-organizer" bind:value={draftOrganizerId}>
            <option value={0}>--</option>
            {#each organizers as org}
              <option value={org.id_organizer}>{org.txt_name}</option>
            {/each}
          </select>
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
        <div data-field="event-row" class="event-row">
          <span data-field="event-name" class="event-cell">{event.txt_name}</span>
          <span data-field="event-location" class="event-cell">{event.txt_location ?? ''}</span>
          <span data-field="event-dates" class="event-cell">{event.dt_start ?? ''}{event.dt_end && event.dt_end !== event.dt_start ? ` – ${event.dt_end}` : ''}</span>
          <span data-field="event-status-badge" class="event-cell status-badge {statusClass(event.enum_status)}">{event.enum_status}</span>
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
            <button data-field="edit-btn" class="icon-btn" onclick={() => { openEditForm(event) }}>&#9998;</button>
            <button data-field="delete-btn" class="icon-btn delete" onclick={() => { ondelete(event.id_event) }}>&#128465;</button>
          </span>
        </div>
      {/each}
    </div>
  </div>
{/if}

<script lang="ts">
  import type { CalendarEvent, Season, Organizer } from '../lib/types'
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
    selectedSeasonId = null as number | null,
    isAdmin = false,
    oncreate = (_evt: Record<string, unknown>) => {},
    onupdate = (_id: number, _evt: Record<string, unknown>) => {},
    onupdatestatus = (_id: number, _status: string) => {},
    ondelete = (_id: number) => {},
  }: {
    events?: CalendarEvent[]
    seasons?: Season[]
    organizers?: Organizer[]
    selectedSeasonId?: number | null
    isAdmin?: boolean
    oncreate?: (evt: Record<string, unknown>) => void
    onupdate?: (id: number, evt: Record<string, unknown>) => void
    onupdatestatus?: (id: number, status: string) => void
    ondelete?: (id: number) => void
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
  let draftOrganizerId = $state(0)

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
    draftOrganizerId = 0
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
    draftOrganizerId = 0
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
      country: draftCountry || undefined,
      venueAddress: draftVenue || undefined,
      invitation: draftInvitation || undefined,
      entryFee: draftEntryFee ?? undefined,
      organizerId: draftOrganizerId || undefined,
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
</style>
