<div class="calendar-view">
  <div class="calendar-filters">
    {#if showEvfToggle}
      <div class="scope-filters">
        <button
          class="scope-filter-btn"
          class:active={scopeFilter === 'ppw'}
          onclick={() => { scopeFilter = 'ppw' }}
        >PPW</button>
        <button
          class="scope-filter-btn"
          class:active={scopeFilter === 'all'}
          onclick={() => { scopeFilter = 'all' }}
        >+EVF</button>
      </div>
    {/if}
    <select class="time-filter-select" bind:value={timeFilter}>
      <option value="all">{t('filter_all')}</option>
      <option value="past">{t('filter_past')}</option>
      <option value="future">{t('filter_future')}</option>
    </select>
  </div>

  {#if isActiveSeason && positionSlots.length > 0}
    <div class="rolling-progress">
      <div class="progress-slots">
        {#each positionSlots as slot}
          <div class="slot" class:completed={slot.completed} class:planned={!slot.completed}>
            <span class="slot-name">{slot.name}</span>
            <span class="slot-icon">{slot.completed ? '✓' : '📅'}</span>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  {#each monthGroups as group}
    <div class="timeline-month">{group.label}</div>
    {#each group.events as event, i}
      <div
        class="timeline-event"
        class:completed={event.enum_status === 'COMPLETED'}
        class:international={event.bool_has_international}
      >
        {#if i < group.events.length - 1}
          <div class="timeline-line"></div>
        {/if}
        <div class="timeline-date">{formatDate(event.dt_start)}</div>
        <div class="timeline-info">
          <div class="timeline-name">{event.txt_name}</div>
          {#if event.txt_location}
            <div class="timeline-loc">
              {event.txt_location}{event.txt_country ? ', ' + event.txt_country : ''} · {event.num_tournaments} {t('tournaments_count')}
            </div>
          {:else}
            <div class="timeline-loc">{event.num_tournaments} {t('tournaments_count')}</div>
          {/if}
          {#if event.arr_weapons?.length}
            <div class="timeline-weapons">{formatWeapons(event.arr_weapons)}</div>
          {/if}
          <div class="timeline-meta">
            <span class="status-badge {statusClass(event.enum_status)}">{statusLabel(event.enum_status)}</span>
          </div>
          {#if (event.enum_status === 'COMPLETED' && event.url_event) || event.url_invitation}
            <div class="timeline-links">
              {#if event.enum_status === 'COMPLETED' && event.url_event}
                <a class="results-link" href={event.url_event} target="_blank" rel="noopener">
                  {t('event_results')} &rarr;
                </a>
              {/if}
              {#if event.url_invitation}
                <a class="invitation-link" href={event.url_invitation} target="_blank" rel="noopener">
                  {t('organizer_announcement')} &rarr;
                </a>
              {/if}
            </div>
          {/if}
          {#if event.num_entry_fee != null}
            <div class="timeline-fee">{t('entry_fee')}: {event.num_entry_fee} {event.txt_entry_fee_currency ?? 'PLN'}</div>
          {/if}
        </div>
      </div>
    {/each}
  {/each}

  {#if filteredEvents.length === 0}
    <div class="no-events">{t('no_results')}</div>
  {/if}
</div>

<script lang="ts">
  import type { CalendarEvent, EventStatus, WeaponType } from '../lib/types'
  import { t } from '../lib/locale.svelte'

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

  let {
    events = [] as CalendarEvent[],
    showEvfToggle = false,
    isActiveSeason = false,
  }: {
    events?: CalendarEvent[]
    showEvfToggle?: boolean
    isActiveSeason?: boolean
  } = $props()

  let timeFilter: 'all' | 'past' | 'future' = $state('all')
  let scopeFilter: 'all' | 'ppw' = $state('ppw')

  const INTL_PREFIXES = /^(PEW|MEW|MSW|PSW|IMEW|IMSW)/

  function isInternationalEvent(e: CalendarEvent): boolean {
    return e.bool_has_international || INTL_PREFIXES.test(e.txt_code)
  }

  // Rolling progress: derive position slots respecting scope filter
  let positionSlots = $derived.by(() => {
    if (!isActiveSeason) return []
    const inScope = scopeFilter === 'all'
      ? events
      : events.filter(e => !isInternationalEvent(e))
    return inScope
      .slice()
      .sort((a, b) => (a.dt_start ?? '').localeCompare(b.dt_start ?? ''))
      .map(e => ({
        name: e.txt_code.split('-')[0].replace(/^PP(\d)/, 'PPW$1'),
        completed: e.enum_status === 'COMPLETED',
      }))
  })

  const today = new Date().toISOString().slice(0, 10)

  let filteredEvents = $derived.by(() => {
    let result = events
    if (!showEvfToggle || scopeFilter === 'ppw') {
      result = result.filter((e) => !isInternationalEvent(e))
    }
    if (timeFilter === 'past') {
      result = result.filter((e) => e.dt_start != null && e.dt_start < today)
    } else if (timeFilter === 'future') {
      result = result.filter((e) => e.dt_start != null && e.dt_start > today)
    }
    return result.slice().sort((a, b) => (a.dt_start ?? '').localeCompare(b.dt_start ?? ''))
  })

  let monthGroups = $derived.by(() => {
    const groups: { label: string; events: CalendarEvent[] }[] = []
    let currentKey = ''
    for (const event of filteredEvents) {
      const key = event.dt_start ? event.dt_start.slice(0, 7) : 'unknown'
      if (key !== currentKey) {
        currentKey = key
        groups.push({ label: formatMonth(key), events: [] })
      }
      groups[groups.length - 1].events.push(event)
    }
    return groups
  })

  const MONTH_NAMES_PL = [
    'Styczeń', 'Luty', 'Marzec', 'Kwiecień', 'Maj', 'Czerwiec',
    'Lipiec', 'Sierpień', 'Wrzesień', 'Październik', 'Listopad', 'Grudzień',
  ]

  function formatMonth(yearMonth: string): string {
    if (yearMonth === 'unknown') return '—'
    const [y, m] = yearMonth.split('-')
    const monthIdx = parseInt(m, 10) - 1
    return `${MONTH_NAMES_PL[monthIdx]} ${y}`
  }

  function formatDate(dt: string | null): string {
    if (!dt) return '—'
    const [, m, d] = dt.split('-')
    return `${parseInt(d, 10)}.${m}`
  }

  function statusClass(status: EventStatus): string {
    const map: Record<EventStatus, string> = {
      COMPLETED: 'status-completed',
      SCHEDULED: 'status-scheduled',
      PLANNED: 'status-planned',
      CANCELLED: 'status-cancelled',
      IN_PROGRESS: 'status-inprogress',
      CHANGED: 'status-scheduled',
    }
    return map[status] ?? 'status-planned'
  }

  function statusLabel(status: EventStatus): string {
    const map: Record<EventStatus, string> = {
      COMPLETED: t('status_completed'),
      SCHEDULED: t('status_scheduled'),
      PLANNED: t('status_planned'),
      CANCELLED: t('status_cancelled'),
      IN_PROGRESS: t('status_in_progress'),
      CHANGED: t('status_scheduled'),
    }
    return map[status] ?? status
  }
</script>

<style>
  .calendar-view {
    padding: 0;
  }
  .calendar-filters {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px 0;
    flex-wrap: wrap;
  }
  .scope-filters {
    display: flex;
    border: 1px solid #ccc;
    border-radius: 4px;
    overflow: hidden;
  }
  .scope-filter-btn {
    padding: 5px 12px;
    border: none;
    background: #fff;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
  }
  .scope-filter-btn + .scope-filter-btn {
    border-left: 1px solid #ccc;
  }
  .scope-filter-btn.active {
    background: #4a90d9;
    color: #fff;
  }
  .time-filter-select {
    padding: 5px 10px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 600;
    background: #fff;
    cursor: pointer;
  }
  .timeline-month {
    font-size: 13px;
    font-weight: 700;
    color: #888;
    letter-spacing: 1px;
    text-transform: uppercase;
    padding: 14px 0 8px;
  }
  .timeline-event {
    display: flex;
    gap: 14px;
    margin-bottom: 14px;
    position: relative;
    padding-left: 20px;
  }
  .timeline-event::before {
    content: '';
    position: absolute;
    left: 0;
    top: 8px;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: #4a90d9;
    border: 2px solid #fff;
    box-shadow: 0 0 0 1px #4a90d9;
  }
  .timeline-event.completed::before {
    background: #1a7f37;
    box-shadow: 0 0 0 1px #1a7f37;
  }
  .timeline-event.international::before {
    background: #d4a017;
    box-shadow: 0 0 0 1px #d4a017;
  }
  .timeline-line {
    position: absolute;
    left: 4px;
    top: 20px;
    bottom: -14px;
    width: 2px;
    background: #e0e0e0;
  }
  .timeline-date {
    font-weight: 700;
    font-size: 13px;
    color: #4a90d9;
    white-space: nowrap;
    min-width: 50px;
    padding-top: 2px;
  }
  .timeline-info {
    flex: 1;
  }
  .timeline-name {
    font-size: 14px;
    font-weight: 600;
    color: #222;
  }
  .timeline-loc {
    font-size: 12px;
    color: #888;
    margin-top: 2px;
  }
  .timeline-weapons {
    font-size: 11px;
    color: #4a90d9;
    margin-top: 3px;
  }
  .timeline-meta {
    display: flex;
    gap: 8px;
    align-items: center;
    margin-top: 4px;
    flex-wrap: wrap;
  }
  .timeline-fee {
    font-size: 11px;
    color: #666;
    margin-top: 3px;
  }
  .status-badge {
    font-size: 12px;
    padding: 2px 8px;
    border-radius: 10px;
    font-weight: 600;
    display: inline-block;
  }
  .status-completed { background: #e6f4ea; color: #1a7f37; }
  .status-scheduled { background: #e1f0ff; color: #1a6fbf; }
  .status-planned { background: #f0f0f0; color: #666; }
  .status-cancelled { background: #ffeef0; color: #c33; }
  .status-inprogress { background: #fff4e6; color: #b35c00; }
  .timeline-links {
    display: flex;
    flex-direction: column;
    gap: 4px;
    align-items: flex-start;
    margin-top: 4px;
  }
  .results-link {
    font-size: 11px;
    color: #1a7f37;
    text-decoration: none;
    font-weight: 600;
  }
  .results-link:hover {
    text-decoration: underline;
  }
  .invitation-link {
    font-size: 11px;
    color: #4a90d9;
    text-decoration: none;
  }
  .invitation-link:hover {
    text-decoration: underline;
  }
  .no-events {
    text-align: center;
    color: #888;
    padding: 32px 0;
    font-size: 14px;
  }
  .rolling-progress {
    padding: 12px 0;
    border-bottom: 1px solid #eee;
    margin-bottom: 12px;
  }
  .progress-slots {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
  .slot {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 6px 12px;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 600;
    min-width: 48px;
  }
  .slot.completed {
    background: #e6f4ea;
    color: #1a7f37;
    border: 1px solid #b4dfbf;
  }
  .slot.planned {
    background: #f0f0f0;
    color: #888;
    border: 1px solid #ddd;
  }
  .slot-name {
    font-size: 11px;
  }
  .slot-icon {
    font-size: 16px;
    margin-top: 2px;
  }
</style>
