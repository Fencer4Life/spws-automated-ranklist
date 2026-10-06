// The approved mock's PROD pool (doc/plans/kalendarz-beben-strzalki-mock-2026-10-06.html,
// snapshot 29 Aug 2026) turned into full vw_calendar rows. Fixed: both captures use it.
const POOL=[["PEW2e-2023-2024","2022-01-08","","C"],["PEW16e-2023-2024","2022-02-25","","C"],["IMEW-2023-2024","2023-01-01","","C"],["PEW1e-2023-2024","2023-01-07","Guilford","C"],["GP1-2023-2024","2023-01-14","Pabianice","C"],["PEW17fs-2023-2024","2023-01-21","","C"],["PEW3s-2023-2024","2023-02-12","","C"],["PEW18e-2023-2024","2023-02-25","","C"],["GP2-2023-2024","2023-03-04","Toruń","C"],["PEW4f-2023-2024","2023-03-18","","C"],["PEW12f-2023-2024","2023-03-23","","C"],["PEW20s-2023-2024","2023-04-01","","C"],["PEW19e-2023-2024","2023-04-14","","C"],["GP3-2023-2024","2023-06-18","Niepołomice","C"],["VFC-2023-2024","2023-07-07","","C"],["PEW5efs-2023-2024","2023-09-16","Budapest","C"],["GP4-2023-2024","2023-09-23","Opole","C"],["PEW22e-2023-2024","2023-09-24","","C"],["PEW7s-2023-2024","2023-10-09","","C"],["GP5-2023-2024","2023-10-28","Gdańsk","C"],["PEW6efs-2023-2024","2023-11-11","","C"],["GP6-2023-2024","2023-11-18","Kraków","C"],["PEW23f-2023-2024","2023-12-09","","C"],["PEW8efs-2023-2024","2023-12-16","Terni","C"],["PEW25e-2023-2024","2024-01-06","","C"],["PEW10s-2023-2024","2024-01-20","","C"],["GP7-2023-2024","2024-01-27","Spała","C"],["PEW9ef-2023-2024","2024-02-24","Stockholm","C"],["MPW-2023-2024","2024-03-02","Warszawa","C"],["PEW13e-2023-2024","2024-04-06","","C"],["PEW14s-2023-2024","2024-04-06","","C"],["PEW15e-2023-2024","2024-04-27","","C"],["GP8-2023-2024","2024-06-22","Niepołomice","C"],["PEW1efs-2024-2025","2024-09-21","Budapest","C"],["PPW1-2024-2025","2024-09-28","Konin","C"],["PPW2-2024-2025","2024-10-26","Bytom","C"],["PEW2efs-2024-2025","2024-11-16","Madrid","C"],["PPW3-2024-2025","2024-11-30","Kraków","C"],["PEW3fs-2024-2025","2024-12-07","Munich","C"],["PEW4ef-2024-2025","2025-01-04","Guildford","C"],["PEW5s-2024-2025","2025-01-18","","C"],["PEW6efs-2024-2025","2025-02-01","Terni","C"],["PPW4-2024-2025","2025-02-22","Warszawa","C"],["PEW13e-2024-2025","2025-03-15","","C"],["PEW7es-2024-2025","2025-03-29","Jabłonna","C"],["PEW8f-2024-2025","2025-03-30","","C"],["PPW5-2024-2025","2025-04-26","Szczecin","C"],["PEW15f-2024-2025","2025-05-15","","C"],["IMEW-2024-2025","2025-05-28","Plovdiv","C"],["MPW-2024-2025","2025-06-07","Pabianice","C"],["PEW10efs-2024-2025","2025-07-05","Paris","C"],["PEW1efs-2025-2026","2025-09-20","Budapest","C"],["PPW1-2025-2026","2025-09-27","Opole","C"],["PPW2-2025-2026","2025-10-25","Poznań","C"],["PEW2efs-2025-2026","2025-11-01","Madrid","C"],["IMSW-2025-2026","2025-11-12","Manama","I"],["PEW3fs-2025-2026","2025-12-06","Munich","C"],["PPW3-2025-2026","2025-12-13","Warszawa-Łomianki","C"],["PEW62efs-2025-2026","2026-01-10","Guildford","C"],["PEW31fs-2025-2026","2026-02-07","Faches","C"],["PPW4-2025-2026","2026-02-21","Gdańsk","C"],["PEW4efs-2025-2026","2026-03-07","Napoli","C"],["PEW5ef-2025-2026","2026-03-14","Stockholm","C"],["PEW6efs-2025-2026","2026-03-28","Jabłonna","C"],["PPW5-2025-2026","2026-04-11","Gdańsk","C"],["PEW61s-2025-2026","2026-04-11","Liège","C"],["PEW7ef-2025-2026","2026-04-18","Salzburg","C"],["PEW8es-2025-2026","2026-05-02","Chania","P"],["DMEW-2025-2026","2026-05-14","Complexe Sportif Omnispo","P"],["PEW9efs-2025-2026","2026-05-30","Dublin","I"],["MPW-2025-2026","2026-06-20","Warszawa","C"],["PEW0efs-2026-2027","2026-09-12","Samorin","C"],["PEW1f-2026-2027","2026-09-19","Savoy Terrace - Buda Cas","P"],["PPW1-2026-2027","2026-09-26","Opole","P"],["MSW-2026-2027","2026-10-09","TBILISI","P"],["PEW2es-2026-2027","2026-10-31","POLIDEPORTIVO MUNICIPAL ","P"],["PEW3ef-2026-2027","2026-11-14","Budapeszt","P"],["PEW4fs-2026-2027","2026-11-28","Sporthalle der Städtisch","P"],["PEW5efs-2026-2027","2026-12-12","Łomianki","P"],["PEW6efs-2026-2027","2027-01-09","Guildford Spectrum","P"],["PEW7es-2026-2027","2027-01-23","","P"],["PEW8efs-2026-2027","2027-01-30","","P"],["PEW9fs-2026-2027","2027-02-06","Salle Jean Zay","P"],["PEW10e-2026-2027","2027-02-06","Vaudoise aréna - Lausann","P"],["PEW11efs-2026-2027","2027-03-06","Palavesuvio","P"],["PEW12ef-2026-2027","2027-03-13","Stora mossen IP idrottsh","C"],["PEW13s-2026-2027","2027-04-10","Liège","P"],["PEW14ef-2026-2027","2027-04-24","Sporthalle HAK 2 - Salzb","P"],["PEW15es-2026-2027","2027-05-22","Ateny","P"],["PEW16efs-2026-2027","2027-05-29","UCD Sport Center Dublin","P"],["PEW17efs-2026-2027","2027-06-18","Toronto","P"]]

const STATUS = { C: 'COMPLETED', P: 'PLANNED', I: 'IN_PROGRESS' }
const W = { e: 'EPEE', f: 'FOIL', s: 'SABRE' }

function weapons(code) {
  const m = /^PEW\d*([efs]+)-/.exec(code)
  return m ? [...m[1]].map((c) => W[c]) : ['EPEE', 'FOIL', 'SABRE']
}

function plusDays(iso, n) {
  const d = new Date(`${iso}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + n)
  return d.toISOString().slice(0, 10)
}

const seasonIds = new Map()
export const EVENTS = POOL.map(([code, start, loc, st], i) => {
  const season = `SPWS-${code.slice(-9)}`
  if (!seasonIds.has(season)) seasonIds.set(season, seasonIds.size + 1)
  const org = /^(PPW|MPW|GP)/.test(code) ? ['SPWS', 1] : /^PEW|^DMEW|^IMEW/.test(code) ? ['EVF', 2] : ['FIE', 3]
  return {
    id_event: i + 1,
    txt_code: code,
    txt_name: code,
    id_season: seasonIds.get(season),
    txt_season_code: season,
    id_organizer: org[1],
    txt_organizer_name: org[0],
    txt_organizer_code: org[0],
    txt_location: loc || null,
    txt_country: null,
    txt_venue_address: null,
    url_invitation: null,
    num_entry_fee: null,
    txt_entry_fee_currency: null,
    dt_start: start,
    dt_end: plusDays(start, 1),
    dt_start_first_published: start,
    arr_weapons: weapons(code),
    url_event: null,
    enum_status: STATUS[st],
    num_tournaments: 1,
    bool_has_international: !/^(PPW|MPW|GP)/.test(code),
    url_registration: null,
    dt_registration_deadline: null,
    url_event_2: null,
    url_event_3: null,
    url_event_4: null,
    url_event_5: null,
    id_prior_event: null,
    json_ingest_sources: null,
  }
})
