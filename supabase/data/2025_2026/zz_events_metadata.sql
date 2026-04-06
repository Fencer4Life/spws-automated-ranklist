-- =========================================================================
-- Season 2025-2026 — Events Metadata — auto-exported from CERT (ADR-027)
-- =========================================================================

-- ---- PEW1-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PEW1-2025-2026', 'EVF Circuit Budapest',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW1-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Budapest',
    txt_country = 'Hungary',
    dt_start = '2025-09-20',
    dt_end = '2025-09-21',
    url_event = 'https://engarde-service.com/tournament/hunfencing/2025_09_20_pbt',
    url_invitation = 'https://www.veteransfencing.eu/wp-content/uploads/2025/08/International-Veteran-Budapest-Cup-event-2025-september-ENG.pdf'
WHERE txt_code = 'PEW1-2025-2026';

-- ---- PPW1-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PPW1-2025-2026', 'I Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW1-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Opole',
    txt_country = 'Polska',
    dt_start = '2025-09-27',
    dt_end = '2025-09-28',
    url_event = 'https://fencingtimelive.com/tournaments/eventSchedule/BF6E1ADD88844A8CAC2F8CD353D082F9#today',
    url_invitation = 'https://weteraniszermierki.pl/zaproszenie-na-i-puchar-polski-weteranow-szermierki-opole-2025/',
    num_entry_fee = 250,
    txt_entry_fee_currency = 'PLN'
WHERE txt_code = 'PPW1-2025-2026';

-- ---- PPW2-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PPW2-2025-2026', 'II Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW2-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Poznań',
    txt_country = 'Polska',
    dt_start = '2025-10-25',
    dt_end = '2025-10-26',
    url_event = 'https://fencingtimelive.com/tournaments/eventSchedule/BC4FAB2F4A5E466DAA8FC46EB73E50F6#today',
    url_invitation = 'https://weteraniszermierki.pl/wp-content/uploads/2025/10/Komunikat-zawodow-Poznan-2.pdf',
    num_entry_fee = 250,
    txt_entry_fee_currency = 'PLN'
WHERE txt_code = 'PPW2-2025-2026';

-- ---- PEW2-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PEW2-2025-2026', 'EVF Circuit Madrid',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW2-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Madrid',
    txt_country = 'Spain',
    dt_start = '2025-11-01',
    dt_end = '2025-11-02',
    url_event = 'https://engarde-service.com/tournament/aeve_esgrima/evf_madrid_2025',
    url_invitation = 'https://www.veteransfencing.eu/wp-content/uploads/2025/10/EVF-Circuit-Madrid-2025.pdf'
WHERE txt_code = 'PEW2-2025-2026';

-- ---- PEW-SPORTHALLE-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PEW-SPORTHALLE-2025-2026', 'EVF Circuit Memoriam Max Geuter – Munich (GER)',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW-SPORTHALLE-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Sporthalle der Städtischen Berufsschule für Informationstechnik',
    txt_country = 'Germany',
    dt_start = '2025-12-06',
    dt_end = '2025-12-06',
    txt_entry_fee_currency = 'PLN'
WHERE txt_code = 'PEW-SPORTHALLE-2025-2026';

-- ---- PPW3-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PPW3-2025-2026', 'III Puchar Polski Weteranów / Warsaw Epee Open',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW3-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Warszawa-Łomianki',
    txt_country = 'Polska',
    dt_start = '2025-12-13',
    dt_end = '2025-12-14',
    url_event = 'https://fencingtimelive.com/tournaments/eventSchedule/D099355BC4334343949BD91172023B49#today',
    url_invitation = 'https://weteraniszermierki.pl/zaproszenie-na-iii-puchar-polski-weteranow-szermierki-warsaw-epee-open-2025/',
    num_entry_fee = 250,
    txt_entry_fee_currency = 'PLN'
WHERE txt_code = 'PPW3-2025-2026';

-- ---- PEW3-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PEW3-2025-2026', 'EVF Circuit Guildford',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW3-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Guildford',
    txt_country = 'Great Britain',
    dt_start = '2026-01-10',
    dt_end = '2026-01-11',
    url_event = 'https://fencingtimelive.com/tournaments/eventSchedule/E2A7B077F2824DD8A7F2E413B4211296#today',
    url_invitation = 'https://www.veteransfencing.eu/wp-content/uploads/2025/10/EVf-Guildford-2026-invitation-letter.pdf'
WHERE txt_code = 'PEW3-2025-2026';

-- ---- PEW-SALLEJEANZ-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PEW-SALLEJEANZ-2025-2026', 'EVF Circuit – Fâches-Thumesnil (FRA)',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW-SALLEJEANZ-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Salle Jean Zay',
    txt_country = 'France',
    dt_start = '2026-02-07',
    dt_end = '2026-02-07',
    txt_entry_fee_currency = 'PLN'
WHERE txt_code = 'PEW-SALLEJEANZ-2025-2026';

-- ---- PPW4-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PPW4-2025-2026', 'IV Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW4-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Gdańsk',
    txt_country = 'Polska',
    dt_start = '2026-02-21',
    dt_end = '2026-02-22',
    url_event = 'https://fencingtimelive.com/tournaments/eventSchedule/D586C1250E8C41D3BB9B9E5772CB998F#today',
    url_invitation = 'https://weteraniszermierki.pl/zaproszenie-na-iv-puchar-polski-weteranow-szermierki-gdansk-2026/',
    num_entry_fee = 250,
    txt_entry_fee_currency = 'PLN'
WHERE txt_code = 'PPW4-2025-2026';

-- ---- PEW4-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PEW4-2025-2026', 'EVF Circuit Napoli',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW4-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Napoli',
    txt_country = 'Italy',
    dt_start = '2026-03-07',
    dt_end = '2026-03-08',
    url_event = 'https://www.4fence.it/FIS/Risultati/2026-03-08-07_Napoli_-_4_Prova_Circuito_Nazionale_Master_2025-2/',
    url_invitation = 'https://www.veteransfencing.eu/wp-content/uploads/2026/01/EVF-Circuit-Napoli-7-and-8-mar26-ENG.pdf'
WHERE txt_code = 'PEW4-2025-2026';

-- ---- PEW5-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PEW5-2025-2026', 'EVF Circuit Stockholm',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW5-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Stockholm',
    txt_country = 'Sweden',
    dt_start = '2026-03-14',
    dt_end = '2026-03-14',
    url_event = 'https://engarde-service.com/tournament/sthlm/vet2026',
    url_invitation = 'https://www.veteransfencing.eu/wp-content/uploads/2023/05/Invitation-EVF-Stockholm-2026.pdf'
WHERE txt_code = 'PEW5-2025-2026';

-- ---- PEW6-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PEW6-2025-2026', 'EVF Circuit Jabłonna',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW6-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Jabłonna',
    txt_country = 'Polska',
    dt_start = '2026-03-28',
    dt_end = '2026-03-29',
    url_event = 'https://www.fencingtimelive.com/tournaments/eventSchedule/98F13C10A47B49FFA2D39E4D47F1EDA8#today',
    url_invitation = 'https://www.veteransfencing.eu/wp-content/uploads/2026/02/62c4d775-86d2-454c-9b61-c999e8d24791.pdf'
WHERE txt_code = 'PEW6-2025-2026';

-- ---- PPW5-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PPW5-2025-2026', 'V Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'SCHEDULED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PPW5-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Gdańsk',
    txt_country = 'Polska',
    dt_start = '2026-04-11',
    dt_end = '2026-04-11',
    url_invitation = 'https://weteraniszermierki.pl/wp-content/uploads/2026/03/Komunikat-organizacyjny-V-Pucharu-Polski-Weteranow-Szermierki_Gdansk_11_kwietnia_2026.pdf',
    num_entry_fee = 250,
    txt_entry_fee_currency = 'PLN'
WHERE txt_code = 'PPW5-2025-2026';

-- ---- PEW7-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PEW7-2025-2026', 'EVF Circuit Salzburg',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'PLANNED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW7-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Salzburg',
    txt_country = 'Austria',
    dt_start = '2026-04-18',
    dt_end = '2026-04-19',
    url_invitation = 'https://www.veteransfencing.eu/wp-content/uploads/2026/03/EVC-Salzburg-Ausschreibung-2026_Aktuell-1.pdf'
WHERE txt_code = 'PEW7-2025-2026';

-- ---- PEW8-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PEW8-2025-2026', 'EVF Circuit Chania',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'PLANNED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW8-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Chania',
    txt_country = 'Greece',
    dt_start = '2026-05-02',
    dt_end = '2026-05-03',
    url_invitation = 'https://www.veteransfencing.eu/wp-content/uploads/2026/03/Chania-Invitation-letter-2026.pdf'
WHERE txt_code = 'PEW8-2025-2026';

-- ---- MEW-COMPLEXESP-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'MEW-COMPLEXESP-2025-2026', 'European Team Championships 2026 – Cognac',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'PLANNED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'MEW-COMPLEXESP-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Complexe Sportif Omnisports des Vauzelles',
    txt_country = 'France',
    dt_start = '2026-05-14',
    dt_end = '2026-05-14',
    txt_entry_fee_currency = 'PLN'
WHERE txt_code = 'MEW-COMPLEXESP-2025-2026';

-- ---- PEW9-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PEW9-2025-2026', 'EVF Circuit Dublin',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'PLANNED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW9-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Dublin',
    txt_country = 'Ireland',
    dt_start = '2026-05-30',
    dt_end = '2026-05-31',
    url_invitation = 'https://www.veteransfencing.eu/wp-content/uploads/2026/02/VIO-2026-Invitation-Letter.pdf'
WHERE txt_code = 'PEW9-2025-2026';

-- ---- MPW-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'MPW-2025-2026', 'MPW',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'SCHEDULED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'MPW-2025-2026');
UPDATE tbl_event SET
    txt_location = 'Warszawa',
    txt_country = 'Polska',
    dt_start = '2026-06-20',
    dt_end = '2026-06-21',
    num_entry_fee = 250,
    txt_entry_fee_currency = 'PLN'
WHERE txt_code = 'MPW-2025-2026';

-- ---- IMSW-2025-2026 ----
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'IMSW-2025-2026', 'IMSW',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED'
WHERE NOT EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'IMSW-2025-2026');
