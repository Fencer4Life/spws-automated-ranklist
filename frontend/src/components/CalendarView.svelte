<div class="calendar-view">
  <div class="calendar-filters">
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
    <select class="time-filter-select" bind:value={timeFilter}>
      <option value="all">{t('filter_all')}</option>
      <option value="past">{t('filter_past')}</option>
      <option value="future">{t('filter_future')}</option>
    </select>
  </div>

  {#each monthGroups as group}
    <div class="month-header">{group.label}</div>
    {#each group.events as event}
      <div class="event-card" class:international={event.bool_has_international}>
        <div class="event-top">
          <span class="event-date">{formatDate(event.dt_start)}</span>
          <span class="event-name">{event.txt_name}</span>
        </div>
        {#if event.txt_location}
          <div class="event-loc">{event.txt_location}{event.txt_country ? ', ' + event.txt_country : ''}</div>
        {/if}
        <div class="event-meta">
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
          {#if event.num_entry_fee != null}
            <span class="entry-fee">{t('entry_fee')}: {event.num_entry_fee} PLN</span>
          {/if}
        </div>
        <div class="event-bottom">
          <span class="tournament-count">{event.num_tournaments} {t('tournaments_count')}</span>
          <span class="status-badge {statusClass(event.enum_status)}">{statusLabel(event.enum_status)}</span>
        </div>
      </div>
    {/each}
  {/each}

  {#if filteredEvents.length === 0}
    <div class="no-events">{t('no_results')}</div>
  {/if}
</div>

<script lang="ts">
  import type { CalendarEvent, EventStatus } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  let {
    events = [] as CalendarEvent[],
  }: {
    events?: CalendarEvent[]
  } = $props()

  let timeFilter: 'all' | 'past' | 'future' = $state('all')
  let scopeFilter: 'all' | 'ppw' = $state('all')

  const today = new Date().toISOString().slice(0, 10)

  let filteredEvents = $derived.by(() => {
    let result = events
    if (scopeFilter === 'ppw') {
      result = result.filter((e) => !e.bool_has_international)
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
    return `— ${MONTH_NAMES_PL[monthIdx]} ${y} —`
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
  .month-header {
    font-size: 13px;
    font-weight: 700;
    color: #888;
    letter-spacing: 1px;
    text-transform: uppercase;
    padding: 12px 0 8px;
    text-align: center;
    border-bottom: 1px solid #eee;
    margin-bottom: 10px;
  }
  .event-card {
    border: 1px solid #ddd;
    border-radius: 6px;
    padding: 12px 14px;
    margin-bottom: 10px;
    background: #fff;
  }
  .event-card.international {
    border-left: 4px solid #d4a017;
  }
  .event-top {
    display: flex;
    gap: 10px;
    align-items: baseline;
  }
  .event-date {
    font-weight: 700;
    font-size: 14px;
    color: #4a90d9;
    white-space: nowrap;
  }
  .event-name {
    font-size: 14px;
    font-weight: 600;
    color: #222;
  }
  .event-loc {
    font-size: 13px;
    color: #666;
    margin-top: 3px;
  }
  .event-bottom {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-top: 6px;
  }
  .tournament-count {
    font-size: 12px;
    color: #888;
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
  .event-meta {
    display: flex;
    flex-direction: column;
    gap: 2px;
    margin-top: 4px;
    font-size: 12px;
  }
  .results-link {
    color: #1a7f37;
    text-decoration: none;
    font-weight: 600;
  }
  .results-link:hover {
    text-decoration: underline;
  }
  .invitation-link {
    color: #4a90d9;
    text-decoration: none;
  }
  .invitation-link:hover {
    text-decoration: underline;
  }
  .entry-fee {
    color: #666;
  }
  .no-events {
    text-align: center;
    color: #888;
    padding: 32px 0;
    font-size: 14px;
  }
</style>
