// Mounts the administrator's event list with invented events, so the event
// form can be photographed outside the signed-in admin application. Copied
// into <checkout>/frontend/.sheet-harness/ by build_form.sh and built there,
// once from main and once from the branch. Data requests go to stub.local,
// answered by capture_form.cjs; nothing reaches a database.
import { mount } from 'svelte'
import EventManager from '../src/components/EventManager.svelte'
import { initClient } from '../src/lib/api'

initClient('http://stub.local', 'stub')

const base = {
  id_season: 1, txt_season_code: 'SPWS-2026-2027', id_organizer: 1, txt_organizer_name: 'Klub (test)',
  txt_location: 'Łomianki', txt_country: 'Polska', txt_venue_address: 'Hala sportowa (test)',
  url_invitation: null, num_entry_fee: 200, num_entry_fee_2w: 250, num_entry_fee_3w: 300,
  txt_entry_fee_currency: 'PLN', dt_start: '2026-12-12', dt_end: '2026-12-13',
  arr_weapons: ['EPEE', 'FOIL', 'SABRE'], url_event: null, enum_status: 'PLANNED', num_tournaments: 0,
  bool_has_international: true, dt_registration_deadline: '2026-12-01',
  url_event_2: null, url_event_3: null, url_event_4: null, url_event_5: null,
  txt_payee: null, txt_iban: null, txt_event_payee: null, txt_event_iban: null, txt_payment_source: 'NONE',
  id_prior_event: null,
}
const events = [
  { ...base, id_event: 1, txt_code: 'PEW5efs-2026-2027', txt_name: 'Puchar Europy Weteranów (test)',
    bool_use_spws_registration: true,
    url_registration: 'https://example.invalid/register.html?event=PEW5efs-2026-2027',
    url_entry_list: 'https://example.invalid/register.html?event=PEW5efs-2026-2027&view=list' },
  { ...base, id_event: 2, txt_code: 'PPW2-2026-2027', txt_name: 'Puchar Polski Weteranów (test)',
    bool_use_spws_registration: false, url_registration: null, url_entry_list: null, dt_start: '2027-01-16', dt_end: '2027-01-17' },
]

mount(EventManager, {
  target: document.getElementById('harness')!,
  props: {
    events,
    seasons: [{ id_season: 1, txt_code: 'SPWS-2026-2027', dt_start: '2026-09-01', dt_end: '2027-06-30', bool_active: true, enum_ranking_publication: 'FULL' }],
    organizers: [{ id_organizer: 1, txt_code: 'KLUB', txt_name: 'Klub (test)' }],
    tournaments: [],
    selectedSeasonId: 1,
    isAdmin: true,
  },
} as never)
