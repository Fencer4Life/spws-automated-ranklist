// Edit-handle generation. The handle is short-lived and lives only in the
// page's memory — there is deliberately no persistence layer any more, because
// localStorage bound the capability to one origin and one device (register.html
// on GitHub Pages and the CMS-embedded element cannot see each other's storage,
// and a phone registration could not be corrected from a laptop). A returning
// fencer re-enters their declared tuple instead, which mints a fresh handle.
//
// So all that is left to test is that we can mint a valid, distinct UUID in
// every browser the page has to run in.

import { describe, it, expect } from 'vitest'
import { newEditToken } from '../src/lib/editToken'

describe('newEditToken', () => {
  it('mints a distinct token each time', () => {
    const a = newEditToken()
    const b = newEditToken()
    expect(a).not.toBe(b)
    expect(a.length).toBeGreaterThan(20)
  })

  it('produces a syntactically valid v4 UUID for the uuid column', () => {
    expect(newEditToken()).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
  })

  it('still mints one when crypto.randomUUID is unavailable', () => {
    // Older Safari and any non-secure context lack randomUUID; the page must
    // still be able to register there.
    const original = globalThis.crypto
    Object.defineProperty(globalThis, 'crypto', {
      value: { getRandomValues: original.getRandomValues.bind(original) },
      configurable: true,
      writable: true,
    })
    try {
      expect(newEditToken()).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
    } finally {
      Object.defineProperty(globalThis, 'crypto', { value: original, configurable: true, writable: true })
    }
  })

  it('still mints one when no crypto is available at all', () => {
    const original = globalThis.crypto
    Object.defineProperty(globalThis, 'crypto', { value: {}, configurable: true, writable: true })
    try {
      expect(newEditToken()).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
    } finally {
      Object.defineProperty(globalThis, 'crypto', { value: original, configurable: true, writable: true })
    }
  })
})
