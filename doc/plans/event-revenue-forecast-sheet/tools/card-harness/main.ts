// FR-176 — mounts the event card as a signed-in administrator sees it (with the
// „Prognoza przychodu” pill) and as a visitor does, both on an invented event.
// Built from the branch by build_harness.sh; nothing reaches a database.
import { mount } from 'svelte'
import EventCard from '../src/components/EventCard.svelte'

const event = {
  id_event: 86, txt_code: 'PEW5efs-2026-2027', txt_name: 'Puchar Europy Weteranów (test)', id_season: 1,
  txt_season_code: 'SPWS-2026-2027', id_organizer: null, txt_organizer_name: null,
  txt_location: 'Łomianki', txt_country: null, txt_venue_address: null, url_invitation: null,
  num_entry_fee: 200, num_entry_fee_2w: null, num_entry_fee_3w: null, txt_entry_fee_currency: 'PLN',
  dt_start: '2026-12-12', dt_end: '2026-12-13', arr_weapons: ['EPEE', 'FOIL', 'SABRE'], url_event: null,
  enum_status: 'PLANNED', num_tournaments: 1, bool_has_international: true,
  url_registration: 'https://example.invalid/register', dt_registration_deadline: '2026-12-01',
  url_entry_list: 'https://example.invalid/list', bool_use_spws_registration: true,
  url_event_2: null, url_event_3: null, url_event_4: null, url_event_5: null,
}
const admin = new URLSearchParams(location.search).get('admin') === '1'
mount(EventCard, {
  target: document.getElementById('harness')!,
  props: { event, today: '2026-11-17', isAdmin: admin, onopenrevenue: () => {} },
} as never)
