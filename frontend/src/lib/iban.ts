// IBAN vetting (ISO 13616), shared by every surface that stores or shows an
// account number.
//
// The system never handles the money: it displays transfer instructions and
// deliberately does not track whether a transfer arrives, which the organizer
// verifies in person at the venue (ADR-079 §4). What it publishes is the account
// a fencer is asked to pay into — so a wrong number sends the fencer's own
// transfer astray, printed under a label saying IBAN and copied with one tap.
// That is why the value is checked rather than trusted.
//
// The rule is deliberately generic rather than PL-only: an organizer abroad is
// plausible, and rejecting a valid German IBAN would be a bug of our own making.

/** One definition of "absent", shared by the sync, the resolution and the
 *  toggle guard. Whitespace is not data — a payee of '   ' must not satisfy a
 *  check that an account exists. */
export function isBlank(value: string | null | undefined): boolean {
  return value == null || value.trim() === ''
}

/** Canonical comparison form: no whitespace, upper case. */
export function compactIban(value: string): string {
  return value.replace(/\s+/g, '').toUpperCase()
}

/**
 * ISO 13616: move the first four characters to the end, map letters to numbers
 * (A=10 … Z=35), and the whole value mod 97 must be exactly 1.
 *
 * Computed digit by digit because the expanded number far exceeds a JS integer;
 * taking the remainder as we go is exact where Number() would silently round.
 */
export function isValidIban(value: string | null | undefined): boolean {
  if (isBlank(value)) return false
  const s = compactIban(value as string)
  // Country code, two check digits, then at least one and at most 30 more.
  // 34 is the ISO maximum; Poland uses 28.
  if (!/^[A-Z]{2}\d{2}[A-Z0-9]{1,30}$/.test(s)) return false
  const rearranged = s.slice(4) + s.slice(0, 4)
  let remainder = 0
  for (const ch of rearranged) {
    const mapped = /[A-Z]/.test(ch) ? String(ch.charCodeAt(0) - 55) : ch
    for (const digit of mapped) remainder = (remainder * 10 + Number(digit)) % 97
  }
  return remainder === 1
}

/**
 * Present a Polish IBAN the way the bank prints it — country code, check
 * digits, then six groups of four:
 *
 *   PL 06 1090 1665 0000 0001 5004 1549
 *   D  C  <---A---> <---------B--------->
 *
 * A fencer compares this against the invitation character by character, so the
 * grouping is part of the value rather than decoration. Anything that is not a
 * Polish IBAN is returned untouched: reformatting a value we do not understand
 * would be worse than leaving it as the administrator typed it.
 */
export function formatPolishIban(value: string): string {
  const s = compactIban(value)
  if (!/^PL\d{26}$/.test(s)) return value
  const digits = s.slice(2)
  return `PL ${digits.slice(0, 2)} ${digits.slice(2).replace(/(\d{4})(?=\d)/g, '$1 ')}`
}
