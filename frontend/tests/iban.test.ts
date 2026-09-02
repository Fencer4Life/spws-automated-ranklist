// IBAN vetting, shared by the association default, the per-event override and
// anything else that stores an account number.
//
// This lives in production code rather than inside a test because the value is
// becoming admin-typed. The system never handles the money — it publishes the
// account a fencer is asked to pay into — so a wrong number sends the fencer's
// own transfer astray, under a label saying IBAN, copied with one tap.
//
// Erste Bank Polska's two forms of the same account:
//   NRB  (domestic)      06 1090 1665 0000 0001 5004 1549       26 digits
//   IBAN (cross-border)  PL 06 1090 1665 0000 0001 5004 1549  PL + 26 digits

import { describe, it, expect } from 'vitest'
import { compactIban, formatPolishIban, isBlank, isValidIban } from '../src/lib/iban'

const GOOD = 'PL 06 1090 1665 0000 0001 5004 1549'

describe('isBlank', () => {
  // One definition of "absent", shared by the sync, the resolution and the
  // toggle guard. Whitespace must never count as data.
  it('treats null, undefined, empty and whitespace-only alike', () => {
    for (const v of [null, undefined, '', '   ', '\t', '\n  ']) expect(isBlank(v)).toBe(true)
  })
  it('does not treat a real value as blank', () => {
    expect(isBlank(GOOD)).toBe(false)
    expect(isBlank('  SPWS  ')).toBe(false)
  })
})

describe('compactIban', () => {
  it('strips whitespace and uppercases', () => {
    expect(compactIban('  pl 06 1090  1665 0000 0001 5004 1549 ')).toBe('PL06109016650000000150041549')
  })
})

describe('isValidIban', () => {
  it('accepts the association account', () => {
    expect(isValidIban(GOOD)).toBe(true)
  })

  it('rejects the domestic NRB — the same account without its country code', () => {
    // The exact defect found on 2026-09-02: 26 digits under an IBAN label,
    // scoring 73 on mod-97 rather than 1.
    expect(isValidIban('06 1090 1665 0000 0001 5004 1549')).toBe(false)
  })

  it('rejects a single mistyped digit', () => {
    expect(isValidIban('PL 06 1090 1665 0000 0001 5004 1548')).toBe(false)
  })

  it('rejects transposed digits, which is what a checksum is for', () => {
    expect(isValidIban('PL 06 1090 1665 0000 0001 5004 1594')).toBe(false)
  })

  it('rejects blank, junk and a bare country code', () => {
    for (const v of ['', '   ', 'PL', 'not an iban', 'PL06']) expect(isValidIban(v)).toBe(false)
  })

  it('accepts a valid IBAN from another country', () => {
    // The rule is ISO 13616, not Poland-specific: an organizer abroad is
    // plausible and must not be rejected by the generic check.
    expect(isValidIban('DE89 3704 0044 0532 0130 00')).toBe(true)
  })

  it('rejects a length no country uses', () => {
    expect(isValidIban('PL 06 1090 1665 0000 0001 5004 154')).toBe(false)
  })
})

describe('formatPolishIban', () => {
  it('groups as the bank prints it: country, check digits, then fours', () => {
    expect(formatPolishIban('PL06109016650000000150041549')).toBe(GOOD)
  })

  it('normalises whatever an admin pastes into the house grouping', () => {
    expect(formatPolishIban('pl0610901665 0000000150041549')).toBe(GOOD)
    expect(formatPolishIban('PL06 1090 1665 0000 0001 5004 1549')).toBe(GOOD)
  })

  it('leaves a non-Polish or unparseable value alone rather than mangling it', () => {
    expect(formatPolishIban('DE89370400440532013000')).toBe('DE89370400440532013000')
    expect(formatPolishIban('nonsense')).toBe('nonsense')
  })
})
