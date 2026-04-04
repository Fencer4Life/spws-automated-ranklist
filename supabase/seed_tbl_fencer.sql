-- =============================================================================
-- Master Fencer List — tbl_fencer
-- 280 SPWS members (domestic PPW/MPW participants only — ADR-019).
-- Birth year only; club and nationality not tracked.
-- Auto-loaded via config.toml sql_paths glob after seed.sql.
-- Note: birth year alone is sufficient for SPWS age-category rules (calendar-year-based).
-- NULL int_birth_year = year unknown.
-- =============================================================================
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year) VALUES

    ('ADAMCZEWSKI',                 'Wojciech',            1952),
    ('ADAMCZYK',                    'Grzegorz',            1990), -- ESTIMATED from V0 (range 1986-1994)
    ('ADAMS',                       'Richard',             1991), -- ESTIMATED from V0 (range 1987-1996)
    ('ADAMSKA',                     'Maria',               1979),
    ('ANDERSCH',                    'Robert',              1971),
    ('ATANASSOW',                   'Aleksander',          1969),
    ('AUGUSTOWSKI',                 'Waldemar',            1959),
    ('AUGUSTYN',                    'Kajetan',             1990), -- ESTIMATED from V0 (range 1987-1994)
    ('BARAN',                       'Agata',               1986),
    ('BARAŃSKI',                    'Wacław',              1964),
    ('BARTUSIK',                    'Grzegorz',            1990),
    ('BAZAK',                       'Jacek',               1974),
    ('BEDNARSKA',                   'Halina',              1968),
    ('BEDNARZ',                     'Przemysław',          1984),
    ('BETLEJ',                      'Daniel',              1977),
    ('BETLEJA',                     'Artur',               1984),
    ('BOBUSIA',                     'Jarosław',            1985),
    ('BORKOWSKA',                   'Halina',              1956),
    ('BORKOWSKI',                   'Andrzej',             1950),
    ('BOROWIEC',                    'Maciej',              1981), -- ESTIMATED from V1 (range 1977-1986)
    ('BORYSIUK',                    'Zbigniew',            1953),
    ('BROMBEREK',                   'Angelika',            1988),
    ('BROSCH',                      'Artur',               1969), -- ESTIMATED from V2 (range 1965-1974)
    ('BUJKO',                       'Paulina',             1979), -- ESTIMATED from V1 (range 1975-1984)
    ('CANIARD',                     'Henry',               1970),
    ('CHARKIEWICZ',                 'Paweł',               1991), -- ESTIMATED from V0 (range 1987-1996)
    ('CHIAROMONTE',                 'Francesco',           1971), -- ESTIMATED from V2 (range 1967-1976)
    ('CHMIELEWSKA',                 'Emilia',              1986),
    ('CHOJNACKI',                   'Tomasz',              1987),
    ('CHOJNECKI',                   'Mateusz',             1988),
    ('CHUDY',                       'Tomasz',              1980), -- ESTIMATED from V1 category (PPW4 Excel)
    ('CHUDYCKI',                    'Artur',               1960),
    ('CYGAŃSKI',                    'Tomasz',              1973),
    ('CZAJKOWSKI',                  'Marcin',              1979),
    ('ĆWIORO',                      'Krzysztof',           1960),
    ('ĆWIORO',                      'Tomasz',              1985),
    ('DAMIAN',                      'Mateusz',             1988),
    ('DARUL',                       'Tomasz',              1978),
    ('DOBRZAŃSKI',                  'Maciej',              1978),
    ('DOMAŃSKI',                    'Sławomir',            1990), -- ESTIMATED from V0 (range 1987-1994)
    ('DONKE',                       'Ryszard',             1931), -- ESTIMATED from V4 (range 1906-1956)
    ('DRAPELLA',                    'Maciej',              1964),
    ('DRAPELLA',                    'Magdalena',           1996),
    ('DROBCZYK',                    'Paweł',               1980),
    ('DROBIŃSKI',                   'Leszek',              1967),
    ('DUDEK',                       'Mariusz',             1973),
    ('DWORAKOWSKA-BANAŚ',           'Agnieszka',           1971), -- ESTIMATED from V2 (range 1967-1975)
    ('DYNAREK',                     'Aleksander',          1990),
    ('DZIUBIŃSKI',                  'Mateusz',             1988),
    ('EJCHSZTET',                   'Mariusz',             1981), -- ESTIMATED from V1 (range 1977-1986)
    ('FARAGO',                      'József',              1959), -- ESTIMATED from V3 (range 1955-1964)
    ('FORAJTER',                    'Roman',               1977),
    ('FORNAL',                      'Mateusz',             1991), -- ESTIMATED from V0 (range 1987-1996)
    ('FRAŚ',                        'Feliks',              1990), -- ESTIMATED from V0 (range 1986-1995)
    ('FRYDRYCH',                    'Szymon',              1986),
    ('FUHRMANN',                    'Ulrike',              1960), -- ESTIMATED from V3 (range 1957-1964)
    ('FURMANIAK',                   'Andrzej',             1947),
    ('GAJDA',                       'Leszek',              1965),
    ('GAJDA',                       'Zbigniew',            1967),
    ('GANSZCZYK',                   'Anna',                1972),
    ('GANSZCZYK',                   'Marcin',              1974),
    ('GAWLE',                       'Katarzyna',           1980), -- ESTIMATED from V1 (range 1977-1984)
    ('GĄSIOROWSKI',                 'Maciej',              1970),
    ('GĘZIKIEWICZ',                 'Marcin',              1991),
    ('GIBULA',                      'Marcin',              1981), -- ESTIMATED from V1 (range 1977-1986)
    ('GIERS-ROMEK',                 'Monika',              1984),
    ('GÓRNA',                       'Karolina',            1991), -- ESTIMATED from V0 (range 1987-1996)
    ('GRABOWSKI',                   'Alan',                1991),
    ('GRABOWSKI',                   'Romuald',             1962),
    ('GRABOWSKI',                   'Sebastian',           1988),
    ('GRACZYK',                     'Anna',                1985),
    ('GRACZYK',                     'Bogdan',              1984),
    ('GRIPAS',                      'Artiom',              1984),
    ('GRODNER',                     'Michał',              1960),
    ('GROMADA',                     'Roland',              1985),
    ('GRZEGOREK',                   'Norbert',             1970),
    ('GRZYWACZ',                    'Mirosław',            1972),
    ('GUZY',                        'Adrian',              1983),
    ('GWIAZDA',                     'Paweł',               1970),
    ('HAJDAS',                      'Martyna',             1990), -- ESTIMATED from V0 (range 1987-1994)
    ('HAŁOŃ',                       'Bartłomiej',          1984),
    ('HAŚKO',                       'Sergiusz',            1974),
    ('HEŁKA',                       'Jacek',               1968),
    ('HERONIMEK',                   'Leszek',              1959),
    ('IRZYK',                       'Sabina',              1990), -- ESTIMATED from V0 (range 1987-1994)
    ('JABŁOŃSKA',                   'Ewa',                 1971),
    ('JADCZUK',                     'Wojciech',            1980),
    ('JANKOWSKI',                   'Kamil',               1992),
    ('JAROSZEK',                    'Zbigniew',            1972),
    ('JASIELCZUK',                  'Igor',                1987),
    ('JASIŃSKI',                    'Tomasz',              1961), -- ESTIMATED from V3 (range 1957-1966)
    ('JASZCZAK',                    'Piotr',               1973),
    ('JENDRYŚ',                     'Marek',               1974),
    ('JEROZOLIMSKI',                'Marek',               1990), -- ESTIMATED from V0 category (PPW4 Excel)
    ('JUSZKIEWICZ',                 'Piotr',               1954),
    ('KACZMAREK',                   'Paweł',               1970),
    ('KAMIŃSKA',                    'Gabriela',            1979),
    ('KARMAN',                      'Irene',               1970), -- ESTIMATED from V2 (range 1967-1974)
    ('KASPRZYK-KUŹNIAK',            'Michalina',           1977),
    ('KĘDZIORA',                    'Agata',               1988),
    ('KIEROŃSKI',                   'Tomasz',              NULL),
    ('KIERSZNICKI',                 'Ryszard',             1955),
    ('KLEPACKI',                    'Denis',               1981), -- ESTIMATED from V1 (range 1977-1986)
    ('KLIMECKA',                    'Dorota',              1977),
    ('KŁOS',                        'Iwona',               1980), -- ESTIMATED from V1 (range 1976-1984)
    ('KŁUSEK',                      'Damian',              1991), -- ESTIMATED from V0 (range 1987-1996)
    ('KMIECIK',                     'Adam',                1986),
    ('KOBIERSKI',                   'Krzysztof',           1976),
    ('KOCÓR',                       'Agata',               1990),
    ('KOLLAR',                      'Gabriel',             1930),
    ('KOŁUCKI',                     'Michał',              1975), -- CONFIRMED from category crossing
    ('KONARSKI',                    'Marcin',              1991), -- ESTIMATED from V0 (range 1987-1996)
    ('KOŃCZYŁO',                    'Tomasz',              1973),
    ('KOŃCZYŃSKI',                  'Adam',                1984),
    ('KORNAŚ',                      'Jarosław',            1985),
    ('KORONA',                      'Przemysław',          1976),
    ('KORONA',                      'Radosław',            1981), -- ESTIMATED from V1 (range 1977-1986)
    ('KORYGA',                      'Bartłomiej',          1992),
    ('KORZH',                       'Valery',              1979), -- ESTIMATED from V1 (range 1975-1984)
    ('KOSIŃSKI',                    'Łukasz',              1983),
    ('KOSTRZEWA',                   'Ireneusz',            1965),
    ('KOTERSKI',                    'Paweł',               1971),
    ('KOTSEV',                      'Ivan',                1990), -- ESTIMATED from V0 (range 1986-1995)
    ('KOTTS',                       'Radosław',            1970),
    ('KOWALCZYK',                   'Piotr',               1986), -- CONFIRMED from category crossing
    ('KOWALEWSKI',                  'Rafał',               1979),
    ('KOWALSKA',                    'Milena',              1984),
    ('KOWALSKI',                    'Bartosz',             1995),
    ('KOWALSKI',                    'Tomasz',              1975),
    ('KOZAK',                       'Marta',               1990),
    ('KOZIEJOWSKI',                 'Sebastian',           1979), -- ESTIMATED from V1 (range 1975-1984)
    ('KRAMARZ',                     'Konrad',              1986),
    ('KROCHMALSKI',                 'Jakub',               1976),
    ('KRUJALSKIENE',                'Julija',              1991), -- ESTIMATED from V0 (range 1987-1996)
    ('KRUJALSKIS',                  'Gotfridas',           1989), -- ESTIMATED from V0 (range 1985-1994)
    ('KRZEMIŃSKI',                  'Mariusz',             1962),
    ('KUCIĘBA',                     'Piotr',               1979),
    ('KURBATSKYI',                  'Stepan',              1991), -- ESTIMATED from V0 (range 1987-1996)
    ('KUZMICHOVA',                  'Svitlana',            1971), -- ESTIMATED from V2 (range 1967-1976)
    ('LASKUS',                      'Krystyna',            1969),
    ('LELONEK',                     'Tomasz',              1980), -- ESTIMATED from V1 (range 1977-1984)
    ('LIPKOWSKA',                   'Dominika',            1984),
    ('LISOWSKI',                    'Igor',                1990), -- ESTIMATED from V0 category (PPW4 Excel)
    ('LISOWSKI',                    'Robert',              1971), -- ESTIMATED from V2 (range 1967-1976)
    ('LYNCH',                       'Pat',                 1930), -- ESTIMATED from V4 (range 1906-1955)
    ('ŁĘCKI',                       'Krzysztof',           1991),
    ('MADDEN',                      'Gerard',              1991), -- ESTIMATED from V0 (range 1987-1996)
    ('MAINKA',                      'Andrzej',             1949),
    ('MALINOWSKI',                  'Piotr',               1980), -- ESTIMATED from V1 (range 1977-1984)
    ('MAŁASIŃSKI',                  'Adam',                1958),
    ('MAŁASIŃSKI',                  'Maciej',              NULL),
    ('MANDRELA',                    'Jarosław',            1976),
    ('MARASEK',                     'Tomasz',              1976),
    ('MARNIAK',                     'Ksenia',              1980), -- ESTIMATED from V1 category (PPW4 Excel)
    ('MAZIK',                       'Aleksander',          1970),
    ('MCGINNITY',                   'Marie',               1960), -- ESTIMATED from V3 (range 1956-1965)
    ('MIECZYŃSKI',                  'Adam',                1980), -- ESTIMATED from V1 (range 1976-1985)
    ('MIKOŁAJCZUK',                 'Norbert',             1990), -- ESTIMATED from V0 (range 1986-1995)
    ('MIKULICKA',                   'Joanna',              1979), -- ESTIMATED from V1 (range 1975-1984)
    ('MIKULICKI',                   'Arkadiusz',           1979), -- ESTIMATED from V1 (range 1975-1984)
    ('MILCZAREK',                   'Renata',              1968),
    ('MILOVA',                      'Tatiana',             1965),
    ('MŁYNEK',                      'Janusz',              1984),
    ('MORDEL',                      'Adam',                1985),
    ('MULSON',                      'Irena',               1956),
    ('MUTWIL',                      'Marcin',              1970),
    ('NIECZKOWSKI',                 'Tomasz',              1977),
    ('NIKALAICHUK',                 'Aliaksandr',          1963),
    ('NOWAK',                       'Marta',               1979),
    ('NOWAK',                       'Szymon',              1990), -- ESTIMATED from V0 (range 1987-1994)
    ('NOWAKOWSKI',                  'Andrzej',             1952),
    ('NOWICKI',                     'Wiesław',             1964),
    ('ODOLAK',                      'Jarosław',            1970), -- ESTIMATED from V2 (range 1966-1975)
    ('OLBRYCHSKI',                  'Antoni',              1990), -- ESTIMATED from V0 (range 1986-1995)
    ('OLSZEWSKI',                   'Mikołaj',             1968),
    ('OSSOWSKI',                    'Wojciech',            1961),
    ('OWCZAREK',                    'Elżbieta',            1957),
    ('OWCZAREK',                    'Ewelina',             1987),
    ('OWCZAREK',                    'Hubert',              1976),
    ('PAKUŁA',                      'Łukasz',              1978),
    ('PANZ',                        'Marian',              1930), -- ESTIMATED from V4 (range 1906-1954)
    ('PARDUS',                      'Borys',               1970),
    ('PARELL',                      'Mikołaj',             1990), -- ESTIMATED from V0 category (PPW4 Excel)
    ('PAWŁOWSKI',                   'Łukasz',              1980), -- ESTIMATED from V1 category (PPW4 Excel)
    ('PĘCZEK',                      'Sandra',              1991), -- ESTIMATED from V0 (range 1987-1996)
    ('PILARSKA',                    'Barbara',             1974),
    ('PILUTKIEWICZ',                'Igor',                1975),
    ('PLUCIŃSKI',                   'Paweł',               1969),
    ('POKRYWA',                     'Bartosz',             1984),
    ('POKRZYWA',                    'Mariusz',             1959),
    ('POPRAWA',                     'Mariusz',             1960),
    ('POŚPIESZNY',                  'Sławomir',            1969),
    ('PRAHA-TSAREHRADSKA',          'Nadiia',              1970), -- ESTIMATED from V2 (range 1967-1974)
    ('PRĘGOWSKI',                   'Jerzy',               1947),
    ('PRZYSTAJKO',                  'Daniel',              1985),
    ('PYZIK',                       'Zdzisław',            1960),
    ('RAJKIEWICZ',                  'Radosław',            1982),
    ('REDZIŃSKI',                   'Michał',              1990), -- ESTIMATED from V0 (range 1986-1995)
    ('REMIAN',                      'Paulina',             1989), -- ESTIMATED from V0 (range 1985-1994)
    ('ROMANOWICZ',                  'Aleksiej',            1991), -- ESTIMATED from V0 (range 1987-1995)
    ('RUDY',                        'Andrzej',             1973),
    ('RUSEK',                       'Roman',               1970), -- ESTIMATED from V2 (range 1966-1975)
    ('RUT',                         'Agnieszka',           NULL),
    ('RUTECKI',                     'Bogdan',              1929), -- ESTIMATED from V4 (range 1904-1954)
    ('RUTECKI',                     'Paweł',               1978),
    ('RZEPECKA',                    'Martyna',             1990), -- ESTIMATED from V0 category (PPW4 Excel)
    ('RZESZUTKO',                   'Jakub',               1984),
    ('SADOWIŃSKA',                  'Adriana',             1970), -- ESTIMATED from V2 (range 1967-1974)
    ('SADOWIŃSKA',                  'Adrianna',            1970),
    ('SADOWSKA',                    'Małgorzata',          1982),
    ('SAJEWICZ',                    'Izabela',             1987),
    ('SAMECKA-NACZYŃSKA',           'Martyna',             1985),
    ('SAMSONOWICZ',                 'Maciej',              1978),
    ('SERAFIN',                     'Błażej',              1980), -- ESTIMATED from V1 (range 1977-1984)
    ('SERWATKA',                    'Marek',               1968),
    ('SĘKOWSKI',                    'Maciej',              1981),
    ('SKOCZEK',                     'Artur',               1970), -- ESTIMATED from V2 (range 1967-1974)
    ('SKRYPKA',                     'Glib',                1991), -- ESTIMATED from V0 (range 1987-1996)
    ('SOBIERAJ',                    'Wojciech',            1955),
    ('SOKOL',                       'Vratislav',           1976), -- CONFIRMED from category crossing
    ('SOSNOWSKA',                   'Aniela',              1952),
    ('SPŁAWA-NEYMAN',               'MACIEJ',              1991), -- ESTIMATED from V0 (range 1987-1995)
    ('STANIEWICZ',                  'Witold',              1967),
    ('STANISŁAWSKI',                'Albert',              1991), -- ESTIMATED from V0 (range 1987-1995)
    ('STAŃCZYK',                    'Agnieszka',           1971),
    ('STAŃCZYK',                    'Marcin',              1980), -- ESTIMATED from V1 category (PPW4 Excel)
    ('STOCKI',                      'Piotr',               1980), -- ESTIMATED from V1 (range 1977-1984)
    ('STOŁOWSKI',                   'Mariusz',             1963),
    ('STYŚ',                        'Jan',                 1979), -- ESTIMATED from V1 (range 1975-1984)
    ('SULŻYC',                      'Piotr',               1989), -- ESTIMATED from V0 (range 1985-1994)
    ('SUROWIEC',                    'Tomasz',              1962),
    ('SZCZERBOWSKI',                'Lech',                1972),
    ('SZCZĘSNY',                    'Jacek',               1956),
    ('SZEPIETOWSKI',                'Rafał',               1989), -- ESTIMATED from V0 (range 1985-1994)
    ('SZKODA',                      'Marek Tomasz',        1969), -- ESTIMATED from V2 (range 1965-1974)
    ('SZMAJDZIŃSKA',                'Katarzyna',           1992),
    ('SZMELC',                      'Łukasz',              1991), -- ESTIMATED from V0 (range 1987-1996)
    ('SZMIDT',                      'Grzegorz',            1969),
    ('SZTYBER',                     'Michał',              1991), -- ESTIMATED from V0 (range 1987-1996)
    ('SZURLEJ',                     'Agata',               1975),
    ('SZYMAŃSKI',                   'Adam',                1976),
    ('SZYMKOWIAK',                  'Krzysztof',           1956), -- CONFIRMED from category crossing
    ('SZYPUŁOWSKA-GRZYŚ',           'Joanna',              1989), -- ESTIMATED from V0 (range 1985-1994)
    ('TARANCZEWSKI',                'Janusz',              1949),
    ('TATCHYN',                     'Andriy',              1980), -- ESTIMATED from V1 category (PPW4 Excel)
    ('TECŁAW',                      'Robert',              1977),
    ('TOMASZEWSKA',                 'Hanna',               1974),
    ('TOMCZAK',                     'Ireneusz',            1968),
    ('TRACZ',                       'Jerzy',               1966),
    ('TRISCORNIA',                  'Anton',               1990),
    ('TRZENSIOK',                   'Bernard',             1970),
    ('VETULANI',                    'Zygmunt',             1930), -- ESTIMATED from V4 (range 1905-1955)
    ('WALCZEWSKI',                  'Konrad',              1990), -- ESTIMATED from V0 (range 1986-1994)
    ('WALECKA',                     'Wanda',               1973),
    ('WALESIAK',                    'Stanisław',           1991),
    ('WASILCZUK',                   'Beata',               1971),
    ('WASIOŁKA',                    'Sebastian',           1976),
    ('WHITLEY',                     'Gary',                1961),
    ('WIERZBICKI',                  'Jacek',               1970),
    ('WINGROWICZ',                  'Mariusz',             1973),
    ('WIŚNIEWSKI',                  'Bernard',             1982),
    ('WITOSŁAWSKI',                 'Przemysław',          NULL),
    ('WITOSŁAWSKI',                 'Tomasz',              1988),
    ('WOJCIECHOWSKI',               'Marek',               1960),
    ('WOJTAS',                      'Bogusław',            1970), -- ESTIMATED from V2 (range 1966-1975)
    ('WOLAŃSKI',                    'Adam',                1990), -- ESTIMATED from V0 (range 1986-1995)
    ('WRONA',                       'Grzegorz',            1965),
    ('WROŃSKI',                     'Stanisław',           1950),
    ('WUJEK',                       'Dariusz',             1959), -- ESTIMATED from V3 (range 1955-1964)
    ('ZABŁOCKI',                    'Michał',              1964),
    ('ZAJĄC',                       'Michał',              1982),
    ('ZAKONEK',                     'Bronisław',           1950), -- ESTIMATED from V4 category (PPW4 Excel)
    ('ZAWALICH',                    'Leszek',              1969),
    ('ZAWROTNIAK',                  'Przemysław',          1974),
    ('ZIELIŃSKI',                   'Dariusz',             1969),
    ('ZIEMECKI',                    'Grzegorz',            1980), -- ESTIMATED from V1 (range 1976-1984)
    ('ZIMNY',                       'Lech',                1955),
    ('ZYLKA',                       'Henryk',              1930), -- ESTIMATED from V4 (range 1906-1955)
    ('ŻUKOWSKI',                    'Wojciech',            1969),
    ('ŻYCZKOWSKI',                  'Adam',                1960);

-- Name aliases for identity resolution (M4/M5)
-- FRAŚ Feliks also competed as: FRAŚ Felix
UPDATE tbl_fencer SET json_name_aliases = '["FRAŚ Felix"]'
WHERE txt_surname = 'FRAŚ' AND txt_first_name = 'Feliks';
-- FUHRMANN Ulrike also competed as: FUHRMANN Urlike
UPDATE tbl_fencer SET json_name_aliases = '["FUHRMANN Urlike"]'
WHERE txt_surname = 'FUHRMANN' AND txt_first_name = 'Ulrike';
-- KORONA Przemysław also competed as: KORONA-TRZEBSKI Przemysław
UPDATE tbl_fencer SET json_name_aliases = '["KORONA-TRZEBSKI Przemysław"]'
WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław';
-- KOŃCZYŁO Tomasz also competed as: TK
UPDATE tbl_fencer SET json_name_aliases = '["TK"]'
WHERE txt_surname = 'KOŃCZYŁO' AND txt_first_name = 'Tomasz';
-- KRUJALSKIS Gotfridas also competed as: KRUJASKIS Gotfridas
UPDATE tbl_fencer SET json_name_aliases = '["KRUJASKIS Gotfridas"]'
WHERE txt_surname = 'KRUJALSKIS' AND txt_first_name = 'Gotfridas';
-- MAZIK Aleksander also competed as: MAZIK Alksander
UPDATE tbl_fencer SET json_name_aliases = '["MAZIK Alksander"]'
WHERE txt_surname = 'MAZIK' AND txt_first_name = 'Aleksander';
-- NIKALAICHUK Aliaksandr also competed as: NIKALAICHUK Aleksander
UPDATE tbl_fencer SET json_name_aliases = '["NIKALAICHUK Aleksander"]'
WHERE txt_surname = 'NIKALAICHUK' AND txt_first_name = 'Aliaksandr';
-- SZMAJDZIŃSKA Katarzyna also competed as: SZMAJDZIŃSKA - BOŁDYS Katarzyna
UPDATE tbl_fencer SET json_name_aliases = '["SZMAJDZIŃSKA - BOŁDYS Katarzyna"]'
WHERE txt_surname = 'SZMAJDZIŃSKA' AND txt_first_name = 'Katarzyna';
-- WOJTAS Bogusław also competed as: WOJTAS Bogdan
UPDATE tbl_fencer SET json_name_aliases = '["WOJTAS Bogdan"]'
WHERE txt_surname = 'WOJTAS' AND txt_first_name = 'Bogusław';
