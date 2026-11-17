/**
 * A name folded for comparison: lower case, with diacritics removed.
 *
 * The rule is the one `fold_diacritics` in python/matcher/fuzzy_match.py
 * applies to names on the server side: ł/Ł are replaced by hand, because
 * Unicode NFD does not decompose them, then NFD splits every other accented
 * letter into its base letter and combining marks, and the marks are dropped.
 * So "ŻAK", "Żak" and "zak" all fold to "zak", and a visitor without Polish
 * keys still finds the name (FR-165, FOLD.01–05).
 *
 * Only for comparing; never display the result.
 */
export function foldName(text: string): string {
  return text
    .replace(/ł/g, 'l')
    .replace(/Ł/g, 'L')
    .normalize('NFD')
    .replace(/\p{Mn}/gu, '')
    .toLowerCase()
}
