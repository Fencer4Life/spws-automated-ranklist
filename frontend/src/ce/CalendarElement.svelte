<svelte:options customElement="spws-calendar" />

<CalendarView events={calendarEvents} />

<script lang="ts">
  import CalendarView from '../components/CalendarView.svelte'
  import type { CalendarEvent } from '../lib/types'

  let {
    demo = false,
  }: {
    demo?: boolean
  } = $props()

  const MOCK_CALENDAR_EVENTS: CalendarEvent[] = [
    {
      id_event: 1,
      txt_code: 'PPW-1',
      txt_name: 'Puchar Polski Weteranów nr 1',
      id_season: 1,
      txt_season_code: 'SPWS-2024-2025',
      txt_location: 'Warszawa',
      txt_country: 'PL',
      txt_venue_address: null,
      url_invitation: null,
      num_entry_fee: null,
      dt_start: '2024-10-05',
      dt_end: '2024-10-06',
      url_event: null,
      enum_status: 'COMPLETED',
      num_tournaments: 6,
      bool_has_international: false,
    },
    {
      id_event: 2,
      txt_code: 'PEW-1',
      txt_name: 'European Veterans Circuit',
      id_season: 1,
      txt_season_code: 'SPWS-2024-2025',
      txt_location: 'Berlin',
      txt_country: 'DE',
      txt_venue_address: null,
      url_invitation: null,
      num_entry_fee: null,
      dt_start: '2024-11-15',
      dt_end: '2024-11-16',
      url_event: null,
      enum_status: 'COMPLETED',
      num_tournaments: 3,
      bool_has_international: true,
    },
  ]

  let calendarEvents: CalendarEvent[] = $state(demo ? MOCK_CALENDAR_EVENTS : [])
</script>
