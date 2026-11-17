// Fixed, invented data for the before/after captures of the entry list.
// Nothing here is a real person. Totals match the user's screenshot:
// 76 registered, épée 47, foil 19, sabre 25.
const TODAY = '2026-11-17T10:00:00'
const EVENT_ID = 86
const EVENT_CODE = 'PEW5efs-2026-2027'

const SUR = ['Lis','Kowal','Wilk','Sowa','Kruk','Mazur','Nowak','Baran','Zając','Żak','Łoś','Ćwik','Dąb','Góra','Wróbel','Kozioł','Gołąb','Sikora','Kos','Bąk','Kot','Ryba','Mróz','Śliwa','Jeż','Bocian','Rak','Dudek','Kania','Sroka','Czyż','Burak','Kwiat','Lach','Stach','Wrona','Żuk','Pająk']
const FM = ['Adam','Piotr','Marek','Jan','Tomasz','Robert','Paweł','Łukasz','Jerzy','Karol','Rafał','Zbigniew']
const FF = ['Anna','Ewa','Maria','Zofia','Halina','Dorota','Iwona','Bożena']
const SETS = [].concat(
  Array(37).fill('E'), Array(9).fill('F'), Array(16).fill('S'),
  Array(5).fill('EF'), Array(4).fill('ES'), Array(4).fill('FS'), ['EFS'])
const CATS = ['V0','V1','V1','V2','V2','V2','V3','V3','V4']
const WEAPON = { E: 'EPEE', F: 'FOIL', S: 'SABRE' }

const ROSTER = Array.from({ length: 76 }, (_, i) => {
  const g = i % 3 === 0 ? 'F' : 'M'
  return {
    id_registration: i + 1,
    id_event: EVENT_ID,
    txt_surname: SUR[i % SUR.length].toUpperCase(),
    txt_first_name: g === 'F' ? FF[(i * 5) % FF.length] : FM[(i * 7) % FM.length],
    enum_gender: g,
    arr_weapons: [...SETS[(i * 29) % 76]].map((c) => WEAPON[c]),
    enum_age_category: CATS[(i * 7) % CATS.length],
  }
})

// One calendar row in vw_calendar's shape (e2e/calendar-barrel.spec.ts row()).
function calendarRow(overrides = {}) {
  return {
    id_event: EVENT_ID, txt_code: EVENT_CODE, txt_name: 'Puchar Europy Weteranów (test)', id_season: 1,
    txt_season_code: 'SPWS-2026-2027', id_organizer: null, txt_organizer_name: null,
    txt_location: 'Łomianki', txt_country: null, txt_venue_address: null, url_invitation: null,
    num_entry_fee: 200, num_entry_fee_2w: null, num_entry_fee_3w: null, txt_entry_fee_currency: 'PLN',
    dt_start: '2026-12-12', dt_end: '2026-12-13', arr_weapons: ['EPEE', 'FOIL', 'SABRE'], url_event: null,
    enum_status: 'PLANNED', num_tournaments: 1, bool_has_international: true,
    url_registration: 'https://example.invalid/register', dt_registration_deadline: '2026-12-01',
    url_entry_list: 'https://example.invalid/list', bool_use_spws_registration: true,
    url_event_2: null, url_event_3: null, url_event_4: null, url_event_5: null,
    txt_payee: null, txt_iban: null, txt_payment_source: 'NONE',
    ...overrides,
  }
}

module.exports = { TODAY, EVENT_ID, EVENT_CODE, ROSTER, calendarRow }
