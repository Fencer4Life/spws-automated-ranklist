<div class="calendar-view">
  {#if showEvfToggle}
    <div class="calendar-filters">
      <div class="scope-filters">
        <button
          class="scope-filter-btn"
          class:active={scopeFilter === 'ppw'}
          onclick={() => { scopeFilter = 'ppw'; scopeUserOverride = true }}
        >PPW</button>
        <button
          class="scope-filter-btn"
          class:active={scopeFilter === 'all'}
          onclick={() => { scopeFilter = 'all'; scopeUserOverride = true }}
        >+EVF</button>
      </div>
    </div>
  {/if}

  {#if hasEvents}
    <CalendarBarrel
      quarters={model.quarters}
      anchorIndex={model.anchorIndex}
      nextUpcoming={model.nextUpcoming}
      onselect={(event) => { selected = event }}
    />
    {#if shown}
      <EventCard
        event={shown}
        isNextUpcoming={shown.id_event === model.nextUpcoming?.id_event}
        onopenregistration={openRegistrationModal}
        onopenentrylist={openEntryListModal}
      />
    {/if}
  {:else}
    <div class="no-events">{t('no_results')}</div>
  {/if}

  <!-- ADR-084 does not touch this. `activeEnv` is $bindable and App.svelte
       re-points the Supabase client from it, so the footer retires with the
       WordPress migration, not with the calendar redesign. -->
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
</div>

<RegistrationModal
  open={regModalOpen}
  eventCode={regModalEventCode}
  eventId={regModalEventId}
  view={regModalView}
  onviewlist={() => { regModalView = 'list' }}
  onclose={() => { regModalOpen = false }}
/>

<script lang="ts">
  // Calendar orchestrator — ADR-084.
  //
  // It holds state and wires three children; it derives nothing itself. Every
  // rule that used to live here inline — visibility, scope, quarter bucketing,
  // next-upcoming, the anchor — now lives in `buildCalendar()`, where it can be
  // asserted without mounting anything.
  //
  // Retired with the timeline (ADR-084 §"Rejected alternatives"): the season
  // dropdown (the barrel owns season state and the seam carries the code), the
  // time filter (the drum IS the time control), the month grouping, and the
  // flat rolling-progress strip.
  import type { CalendarEvent, Environment } from '../lib/types'
  import { t } from '../lib/locale.svelte'
  import { buildCalendar, type CalendarScope } from '../lib/calendarQuarters'
  import CalendarBarrel from './CalendarBarrel.svelte'
  import EventCard from './EventCard.svelte'
  import RegistrationModal from './RegistrationModal.svelte'

  let {
    events = [] as CalendarEvent[],
    showEvfToggle = false,
    dualEnv = false,
    activeEnv = $bindable('CERT' as Environment),
  }: {
    events?: CalendarEvent[]
    showEvfToggle?: boolean
    dualEnv?: boolean
    activeEnv?: Environment
  } = $props()

  // ADR-044 amend — with the Calendar +EVF flag ON, default the scope to the
  // richer EVF+FIE view. The flag loads async, so re-sync the default until the
  // user picks a scope explicitly; a scope fixed at mount is wrong for the
  // first paint.
  let scopeFilter = $state<CalendarScope>('ppw')
  let scopeUserOverride = $state(false)
  $effect(() => {
    if (!scopeUserOverride) scopeFilter = showEvfToggle ? 'all' : 'ppw'
  })

  const model = $derived(
    buildCalendar({ events, scope: scopeFilter, showEvfToggle }),
  )

  const hasEvents = $derived(model.quarters.some((q) => q.events.length > 0))

  /** The barrel reports its own opening selection, so this starts null. */
  let selected = $state<CalendarEvent | null>(null)

  // A selection made before a scope change can fall outside the new model —
  // switching to PPW removes every EVF event, including the selected one. Fall
  // back to what the barrel would open on rather than rendering a card for an
  // event the barrel no longer shows.
  const shown = $derived.by((): CalendarEvent | null => {
    // Captured first: TypeScript will not narrow a mutable `$state` binding
    // inside the closure below, so `selected.id_event` there is an error.
    const current = selected
    const visible = model.quarters.flatMap((q) => q.events)
    if (current && visible.some((e) => e.id_event === current.id_event)) return current
    return model.nextUpcoming ?? model.quarters[model.anchorIndex]?.events[0] ?? visible[0] ?? null
  })

  // ADR-079 amend — SPWS-hosted registration and entry-list links open this
  // in-app modal instead of navigating; closing it returns to the calendar.
  let regModalOpen = $state(false)
  let regModalView = $state<'form' | 'list'>('form')
  let regModalEventCode = $state('')
  let regModalEventId = $state<number | null>(null)

  function openRegistrationModal(ev: CalendarEvent) {
    regModalEventCode = ev.txt_code
    regModalEventId = ev.id_event
    regModalView = 'form'
    regModalOpen = true
  }

  function openEntryListModal(ev: CalendarEvent) {
    regModalEventCode = ev.txt_code
    regModalEventId = ev.id_event
    regModalView = 'list'
    regModalOpen = true
  }
</script>

<style>
  .calendar-view {
    padding: 0;
  }
  .calendar-filters {
    display: flex;
    align-items: flex-end;
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
  .no-events {
    text-align: center;
    color: #888;
    padding: 32px 0;
    font-size: 14px;
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
    padding: 5px 10px;
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
</style>
