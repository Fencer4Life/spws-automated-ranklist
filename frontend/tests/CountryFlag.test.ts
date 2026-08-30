// CountryFlag.svelte — circular country flags for the calendar card.
// ADR-084 §15 as amended 2026-08-29. Test IDs CF.1–CF.14.
//
// This suite replaced one that asserted a hand-drawn implementation: four CSS
// primitives (weighted stripes, offset crosses, a centred disc) plus a handful
// of hand-authored SVGs, with emblem-bearing flags deliberately ABSENT rather
// than approximated and several stripe-only pairs acknowledged as
// indistinguishable.
//
// That approach produced WRONG flags, and the wrongness was silent — three of
// about sixty-six were found by eye in a single sitting, each on a country the
// calendar actually shows. CF.10–CF.12 pin exactly those three so they cannot
// regress.

import { describe, it, expect } from 'vitest'
import { render } from '@testing-library/svelte'
import CountryFlag from '../src/components/CountryFlag.svelte'
import { FLAG_SVG, FLAG_CODES } from '../src/lib/flags.generated'

function flag(code: string | null, props: Record<string, unknown> = {}) {
  const { container } = render(CountryFlag, { props: { code, ...props } })
  return container
}

/** The rendered artwork, with per-instance ids stripped so two flags compare. */
function artwork(code: string): string {
  const svg = flag(code).querySelector('svg')!
  return svg.innerHTML.replace(/f\d+/g, 'ID')
}

describe('CountryFlag — presence', () => {
  it('CF.1: draws a flag for a known code', () => {
    const c = flag('PL')
    expect(c.querySelector('.flag')).not.toBeNull()
    expect(c.querySelector('svg')).not.toBeNull()
  })

  it('CF.2: renders nothing for null or an unknown code', () => {
    expect(flag(null).querySelector('.flag')).toBeNull()
    expect(flag('ZZ').querySelector('.flag')).toBeNull()
  })

  it('CF.3: accepts a lowercase code', () => {
    expect(flag('pl').querySelector('svg')).not.toBeNull()
  })
})

describe('CountryFlag — coverage', () => {
  // The old set drew 66 of ~250 countries and omitted the rest by design.
  // Championships move — the calendar already reaches Toronto and Tbilisi — so
  // scoping the set to countries currently in the database would fail the first
  // time an event goes somewhere new.
  it('CF.4: covers the whole ISO-3166 alpha-2 set, not a curated subset', () => {
    expect(FLAG_CODES.length).toBeGreaterThan(240)
  })

  it('CF.5: includes the emblem-bearing flags the old set refused to draw', () => {
    // Mexico, Portugal, Spain, Brazil, Serbia: coats of arms and emblems.
    for (const iso of ['MX', 'PT', 'ES', 'BR', 'RS']) {
      expect(FLAG_SVG[iso], iso).toBeTruthy()
    }
  })

  it('CF.6: every country the SPWS calendar has visited is drawable', () => {
    for (const iso of ['PL', 'GB', 'DE', 'FR', 'IT', 'HU', 'ES', 'SE', 'CH', 'GE', 'AT', 'BE', 'IE', 'GR', 'SK', 'FI', 'CA', 'BH', 'BG']) {
      expect(FLAG_SVG[iso], iso).toBeTruthy()
    }
  })
})

describe('CountryFlag — accessibility and sizing', () => {
  it('CF.7: carries the translated country name as its accessible label', () => {
    const el = flag('PL', { label: 'Polska' }).querySelector('.flag')!
    expect(el.getAttribute('role')).toBe('img')
    expect(el.getAttribute('aria-label')).toBe('Polska')
  })

  it('CF.8: falls back to the code when no label is supplied', () => {
    expect(flag('PL').querySelector('.flag')!.getAttribute('aria-label')).toBe('PL')
  })

  it('CF.9: has a small variant for tighter rows', () => {
    expect(flag('PL', { size: 'sm' }).querySelector('.flag')!.classList.contains('sm')).toBe(true)
    expect(flag('PL').querySelector('.flag')!.classList.contains('sm')).toBe(false)
  })
})

describe('CountryFlag — the three that used to be wrong', () => {
  // Switzerland's cross is free-standing and INSET, arms stopping short of the
  // edges; a cross running to all four edges is Denmark. The old primitive drew
  // full-width bars, in a 19x13 box, giving a Danish cross with unequal arms.
  it('CF.10: Switzerland is not Denmark', () => {
    expect(artwork('CH')).not.toBe(artwork('DK'))
  })

  // Georgia is a red St George's cross on white PLUS four small Bolnisi
  // crosses. Without them it is precisely the flag of England.
  it('CF.11: Georgia is not a plain St George cross', () => {
    expect(artwork('GE')).not.toBe(artwork('GB'))
    // More content than a bare cross on a field: the four quadrant crosses.
    expect(artwork('GE').length).toBeGreaterThan(200)
  })

  // Greece is nine stripes AND a canton. Drawn as stripes alone it is
  // indistinguishable from any other striped flag once circled.
  it('CF.12: Greece carries more than plain stripes', () => {
    expect(artwork('GR')).not.toBe(artwork('RU'))
    expect(artwork('GR').length).toBeGreaterThan(200)
  })

  // The old header named these as knowingly indistinguishable.
  it('CF.13: the pairs the old set could not separate are now distinct', () => {
    expect(artwork('IT')).not.toBe(artwork('MX'))
    expect(artwork('IE')).not.toBe(artwork('CI'))
    expect(artwork('RO')).not.toBe(artwork('TD'))
    expect(artwork('MC')).not.toBe(artwork('ID'))
  })
})

describe('CountryFlag — instance isolation', () => {
  // Every source file reuses `mask id="a"`. Two flags on one page sharing it
  // would make one render unmasked — square, not circular.
  it('CF.14: gives each instance its own mask id', () => {
    const { container } = render(CountryFlag, { props: { code: 'PL' } })
    const { container: second } = render(CountryFlag, { props: { code: 'DE' } })
    const idOf = (c: HTMLElement) => c.querySelector('[id]')!.getAttribute('id')
    expect(idOf(container)).not.toBe(idOf(second))
    // and the reference matches the definition it points at
    const mask = container.querySelector('[id]')!.getAttribute('id')!
    expect(container.innerHTML).toContain(`url(#${mask})`)
    expect(container.innerHTML).not.toContain('__ID__')
  })
})
