// FR-169 — the fencing countries a registration may declare (plan
// registration-form-names-year-country rev 10, release 3; tests RFCTRY.01–03
// in frontend/tests/fencingCountries.test.ts).
//
// One reviewed table: each three-letter fencing code (the IOC code the FIE
// uses, the letters on a fencer's jacket) paired with the ISO-3166 alpha-2
// code the flag drawings use (flags.generated.ts). The pairs differ for about
// sixty countries (GER ↔ DE, SUI ↔ CH, NED ↔ NL …), which is why the table is
// written out rather than derived. The database holds the same codes
// (tbl_fencing_country, migration 20261121000004); RFCTRY.01 compares them.
//
// Two codes have no drawn flag: AIN, the individual neutral athletes, and TPE,
// which competes under no national flag. The entry list shows their three
// letters in the flag's place (decision D1). Every other country's name comes
// from the browser in the page's language (Intl.DisplayNames).

export interface FencingCountry {
  code: string
  iso: string | null
}

const PAIRS: ReadonlyArray<[string, string | null]> = [
  ['AFG', 'AF'],
  ['AIN', null],
  ['ALB', 'AL'],
  ['ALG', 'DZ'],
  ['AND', 'AD'],
  ['ANG', 'AO'],
  ['ANT', 'AG'],
  ['ARG', 'AR'],
  ['ARM', 'AM'],
  ['ARU', 'AW'],
  ['ASA', 'AS'],
  ['AUS', 'AU'],
  ['AUT', 'AT'],
  ['AZE', 'AZ'],
  ['BAH', 'BS'],
  ['BAN', 'BD'],
  ['BAR', 'BB'],
  ['BDI', 'BI'],
  ['BEL', 'BE'],
  ['BEN', 'BJ'],
  ['BER', 'BM'],
  ['BHU', 'BT'],
  ['BIH', 'BA'],
  ['BIZ', 'BZ'],
  ['BLR', 'BY'],
  ['BOL', 'BO'],
  ['BOT', 'BW'],
  ['BRA', 'BR'],
  ['BRN', 'BH'],
  ['BRU', 'BN'],
  ['BUL', 'BG'],
  ['BUR', 'BF'],
  ['CAF', 'CF'],
  ['CAM', 'KH'],
  ['CAN', 'CA'],
  ['CAY', 'KY'],
  ['CGO', 'CG'],
  ['CHA', 'TD'],
  ['CHI', 'CL'],
  ['CHN', 'CN'],
  ['CIV', 'CI'],
  ['CMR', 'CM'],
  ['COD', 'CD'],
  ['COK', 'CK'],
  ['COL', 'CO'],
  ['COM', 'KM'],
  ['CPV', 'CV'],
  ['CRC', 'CR'],
  ['CRO', 'HR'],
  ['CUB', 'CU'],
  ['CYP', 'CY'],
  ['CZE', 'CZ'],
  ['DEN', 'DK'],
  ['DJI', 'DJ'],
  ['DMA', 'DM'],
  ['DOM', 'DO'],
  ['ECU', 'EC'],
  ['EGY', 'EG'],
  ['ERI', 'ER'],
  ['ESA', 'SV'],
  ['ESP', 'ES'],
  ['EST', 'EE'],
  ['ETH', 'ET'],
  ['FIJ', 'FJ'],
  ['FIN', 'FI'],
  ['FRA', 'FR'],
  ['FSM', 'FM'],
  ['GAB', 'GA'],
  ['GAM', 'GM'],
  ['GBR', 'GB'],
  ['GBS', 'GW'],
  ['GEO', 'GE'],
  ['GEQ', 'GQ'],
  ['GER', 'DE'],
  ['GHA', 'GH'],
  ['GRE', 'GR'],
  ['GRN', 'GD'],
  ['GUA', 'GT'],
  ['GUI', 'GN'],
  ['GUM', 'GU'],
  ['GUY', 'GY'],
  ['HAI', 'HT'],
  ['HKG', 'HK'],
  ['HON', 'HN'],
  ['HUN', 'HU'],
  ['INA', 'ID'],
  ['IND', 'IN'],
  ['IRI', 'IR'],
  ['IRL', 'IE'],
  ['IRQ', 'IQ'],
  ['ISL', 'IS'],
  ['ISR', 'IL'],
  ['ISV', 'VI'],
  ['ITA', 'IT'],
  ['IVB', 'VG'],
  ['JAM', 'JM'],
  ['JOR', 'JO'],
  ['JPN', 'JP'],
  ['KAZ', 'KZ'],
  ['KEN', 'KE'],
  ['KGZ', 'KG'],
  ['KIR', 'KI'],
  ['KOR', 'KR'],
  ['KOS', 'XK'],
  ['KSA', 'SA'],
  ['KUW', 'KW'],
  ['LAO', 'LA'],
  ['LAT', 'LV'],
  ['LBA', 'LY'],
  ['LBN', 'LB'],
  ['LBR', 'LR'],
  ['LCA', 'LC'],
  ['LES', 'LS'],
  ['LIE', 'LI'],
  ['LTU', 'LT'],
  ['LUX', 'LU'],
  ['MAD', 'MG'],
  ['MAR', 'MA'],
  ['MAS', 'MY'],
  ['MAW', 'MW'],
  ['MDA', 'MD'],
  ['MDV', 'MV'],
  ['MEX', 'MX'],
  ['MGL', 'MN'],
  ['MHL', 'MH'],
  ['MKD', 'MK'],
  ['MLI', 'ML'],
  ['MLT', 'MT'],
  ['MNE', 'ME'],
  ['MON', 'MC'],
  ['MOZ', 'MZ'],
  ['MRI', 'MU'],
  ['MTN', 'MR'],
  ['MYA', 'MM'],
  ['NAM', 'NA'],
  ['NCA', 'NI'],
  ['NED', 'NL'],
  ['NEP', 'NP'],
  ['NGR', 'NG'],
  ['NIG', 'NE'],
  ['NOR', 'NO'],
  ['NRU', 'NR'],
  ['NZL', 'NZ'],
  ['OMA', 'OM'],
  ['PAK', 'PK'],
  ['PAN', 'PA'],
  ['PAR', 'PY'],
  ['PER', 'PE'],
  ['PHI', 'PH'],
  ['PLE', 'PS'],
  ['PLW', 'PW'],
  ['PNG', 'PG'],
  ['POL', 'PL'],
  ['POR', 'PT'],
  ['PRK', 'KP'],
  ['PUR', 'PR'],
  ['QAT', 'QA'],
  ['ROU', 'RO'],
  ['RSA', 'ZA'],
  ['RUS', 'RU'],
  ['RWA', 'RW'],
  ['SAM', 'WS'],
  ['SEN', 'SN'],
  ['SEY', 'SC'],
  ['SGP', 'SG'],
  ['SKN', 'KN'],
  ['SLE', 'SL'],
  ['SLO', 'SI'],
  ['SMR', 'SM'],
  ['SOL', 'SB'],
  ['SOM', 'SO'],
  ['SRB', 'RS'],
  ['SRI', 'LK'],
  ['SSD', 'SS'],
  ['STP', 'ST'],
  ['SUD', 'SD'],
  ['SUI', 'CH'],
  ['SUR', 'SR'],
  ['SVK', 'SK'],
  ['SWE', 'SE'],
  ['SWZ', 'SZ'],
  ['SYR', 'SY'],
  ['TAN', 'TZ'],
  ['TGA', 'TO'],
  ['THA', 'TH'],
  ['TJK', 'TJ'],
  ['TKM', 'TM'],
  ['TLS', 'TL'],
  ['TOG', 'TG'],
  ['TPE', null],
  ['TTO', 'TT'],
  ['TUN', 'TN'],
  ['TUR', 'TR'],
  ['TUV', 'TV'],
  ['UAE', 'AE'],
  ['UGA', 'UG'],
  ['UKR', 'UA'],
  ['URU', 'UY'],
  ['USA', 'US'],
  ['UZB', 'UZ'],
  ['VAN', 'VU'],
  ['VEN', 'VE'],
  ['VIE', 'VN'],
  ['VIN', 'VC'],
  ['YEM', 'YE'],
  ['ZAM', 'ZM'],
  ['ZIM', 'ZW'],
]

export const FENCING_COUNTRIES: ReadonlyArray<FencingCountry> = PAIRS.map(([code, iso]) => ({ code, iso }))

const ISO_BY_CODE = new Map(PAIRS)

const OWN_NAMES: Record<string, { pl: string; en: string }> = {
  AIN: { pl: 'Indywidualni Sportowcy Neutralni', en: 'Individual Neutral Athletes' },
  TPE: { pl: 'Chińskie Tajpej', en: 'Chinese Taipei' },
}

// Names a fencer may type that neither browser name holds: the team is
// „Great Britain” on the jacket while the browser says „United Kingdom”. For
// searching only; the shown name is always the browser's.
const SEARCH_ALIASES: Record<string, string[]> = {
  GBR: ['Great Britain', 'England', 'Anglia'],
  NED: ['Holland', 'Holandia'],
  CZE: ['Czech Republic', 'Republika Czeska'],
}

/** Extra names to search a country by, besides its Polish and English names. */
export function searchAliases(code: string): string[] {
  return SEARCH_ALIASES[code] ?? []
}

/** The default country of a new entry (decision Q4 B). */
export const DEFAULT_COUNTRY = 'POL'

/** The two-letter code of the code's drawn flag; null for no flag or an unknown code. */
export function flagIso(code: string | null | undefined): string | null {
  return code ? (ISO_BY_CODE.get(code) ?? null) : null
}

export function isFencingCountry(code: string | null | undefined): boolean {
  return !!code && ISO_BY_CODE.has(code)
}

const displayNames: Partial<Record<'pl' | 'en', Intl.DisplayNames>> = {}

/** The country's name in the page's language; an unknown code is named by itself. */
export function countryName(code: string, lang: 'pl' | 'en'): string {
  const own = OWN_NAMES[code]
  if (own) return own[lang]
  const iso = flagIso(code)
  if (!iso) return code
  displayNames[lang] ??= new Intl.DisplayNames([lang], { type: 'region' })
  return displayNames[lang].of(iso) ?? code
}
