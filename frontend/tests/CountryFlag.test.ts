// CountryFlag.svelte — CSS flag chips for the calendar location line.
// ADR-084 §15. Test IDs CF.1–CF.22.
//
// The component draws only flags it can render correctly, from four primitives:
// stripes (optionally weighted), a cross (centred or hoist-offset), a plain
// centred disc, and hand-authored inline SVG where the geometry demands it or
// where bands alone would collide with another country (CF.20).
//
// Flags whose sole distinguishing mark is an intricate emblem — and which do NOT
// collide with anything — stay unlisted and must render nothing (CF.3).

import { describe, it, expect } from 'vitest'
import { render } from '@testing-library/svelte'
import CountryFlag from '../src/components/CountryFlag.svelte'

function bands(code: string | null, props: Record<string, unknown> = {}) {
  const { container } = render(CountryFlag, { props: { code, ...props } })
  return [...container.querySelectorAll('.band')] as HTMLElement[]
}

describe('CountryFlag — absence', () => {
  // CF.1 — the designed fallback: no flag at all, so the card shows the place
  // without one rather than the wrong one.
  it('CF.1: renders nothing for a null code', () => {
    const { container } = render(CountryFlag, { props: { code: null } })
    expect(container.querySelector('.flag')).toBeNull()
  })

  it('CF.2: renders nothing for an unrecognised code', () => {
    const { container } = render(CountryFlag, { props: { code: 'ZZ' } })
    expect(container.querySelector('.flag')).toBeNull()
  })

  // CF.3 — emblem-bearing flags are absent by policy, not by oversight. These
  // are the ones whose stripe-only rendering would collide with another
  // country's flag, so drawing them would be actively wrong.
  it('CF.3: omits emblem-bearing flags rather than approximating them', () => {
    for (const code of ['MX', 'CI', 'AL', 'TR', 'BR', 'US', 'ZA', 'SA']) {
      const { container } = render(CountryFlag, { props: { code } })
      expect(container.querySelector('.flag'), `${code} should be unlisted`).toBeNull()
    }
  })
})

describe('CountryFlag — inline SVG', () => {
  // CF.17 — Britain is real EVF data (Guildford, Bath), and its saltire-over-
  // cross geometry has no band equivalent, so it is drawn as inline SVG rather
  // than left blank.
  it('CF.17: draws the Union flag as inline SVG', () => {
    const { container } = render(CountryFlag, { props: { code: 'GB', label: 'Wielka Brytania' } })
    const svg = container.querySelector('.flag .art')
    expect(svg).not.toBeNull()
    expect(svg!.getAttribute('viewBox')).toBe('0 0 60 30')
    expect(container.querySelector('.flag')!.getAttribute('aria-label')).toBe('Wielka Brytania')
    // No bands — this path does not use them.
    expect(container.querySelectorAll('.band')).toHaveLength(0)
  })

  // CF.18 — no network request of any kind: a fetch would be blocked by the
  // embed's CSP, and a document-relative <img src> would resolve against the
  // host page (the bug latent in SPWS-logo.png).
  it('CF.18: makes no external request for the drawn flag', () => {
    const { container } = render(CountryFlag, { props: { code: 'GB' } })
    expect(container.querySelector('img')).toBeNull()
    expect(container.innerHTML).not.toContain('http')
    expect(container.innerHTML).not.toContain('url(data:')
  })

  // CF.20 — THE COLLISION FIX. Rendered as plain bands, Croatia is
  // red/white/blue exactly like the Netherlands, and Slovakia and Slovenia are
  // white/blue/red exactly like Russia. Their emblem is the only thing that
  // distinguishes them, so each must draw and must differ from its twin.
  it('CF.20: distinguishes the flags that collide as plain bands', () => {
    const drawn = (code: string) => {
      const { container } = render(CountryFlag, { props: { code } })
      return container.querySelector('.flag')!.innerHTML
    }
    const hr = drawn('HR')
    const nl = drawn('NL')
    const sk = drawn('SK')
    const si = drawn('SI')
    const ru = drawn('RU')

    // Croatia and Slovakia/Slovenia are drawn; their band-only twins are not.
    for (const html of [hr, sk, si]) expect(html).toContain('<svg')
    for (const html of [nl, ru]) expect(html).not.toContain('<svg')

    // And the three drawn ones are not each other.
    expect(new Set([hr, sk, si]).size).toBe(3)
  })

  // CF.21 — Greece is 9 stripes with a cantoned cross, not 5 bands.
  it('CF.21: draws Greece with nine stripes and a canton', () => {
    const { container } = render(CountryFlag, { props: { code: 'GR' } })
    const svg = container.querySelector('.art')!
    expect(svg.getAttribute('viewBox')).toBe('0 0 27 18')
    // 4 white stripes over a blue field, plus the canton and its two arms.
    expect(svg.querySelectorAll('rect').length).toBeGreaterThanOrEqual(8)
  })

  // CF.22 — every drawn flag scales to the chip rather than keeping its own
  // aspect ratio, so it fills the 19x13 box like the band flags do.
  it('CF.22: stretches drawn flags to the chip box', () => {
    for (const code of ['GB', 'GR', 'HR', 'SK', 'SI', 'RS', 'PT']) {
      const { container } = render(CountryFlag, { props: { code } })
      const svg = container.querySelector('.art')
      expect(svg, `${code} should draw`).not.toBeNull()
      expect(svg!.getAttribute('preserveAspectRatio')).toBe('none')
    }
  })

  // CF.19 — a clipPath id must be unique per instance or several flags on one
  // page all clip against whichever definition rendered last.
  it('CF.19: gives each instance a unique clipPath id', () => {
    const a = render(CountryFlag, { props: { code: 'GB' } })
    const b = render(CountryFlag, { props: { code: 'GB' } })
    const idA = a.container.querySelector('clipPath')!.getAttribute('id')
    const idB = b.container.querySelector('clipPath')!.getAttribute('id')
    expect(idA).not.toBe(idB)
    expect(a.container.querySelector('[clip-path]')!.getAttribute('clip-path')).toBe(`url(#${idA})`)
  })
})

describe('CountryFlag — stripes', () => {
  // CF.4 — two equal horizontal bands.
  it('CF.4: draws equal horizontal stripes', () => {
    const out = bands('PL')
    expect(out).toHaveLength(2)
    expect(out[0]!.style.top).toBe('0%')
    expect(out[0]!.style.height).toBe('50%')
    expect(out[1]!.style.top).toBe('50%')
    expect(out[1]!.style.background).toContain('rgb(220, 20, 60)')
  })

  // CF.5 — three equal vertical bands.
  it('CF.5: draws equal vertical stripes', () => {
    const out = bands('FR')
    expect(out).toHaveLength(3)
    const lefts = out.map((b) => Number.parseFloat(b.style.left))
    const widths = out.map((b) => Number.parseFloat(b.style.width))
    expect(lefts[0]).toBeCloseTo(0, 3)
    expect(lefts[1]).toBeCloseTo(100 / 3, 3)
    expect(lefts[2]).toBeCloseTo(200 / 3, 3)
    for (const w of widths) expect(w).toBeCloseTo(100 / 3, 3)
  })

  // CF.6 — Latvia is 2:1:2, not three equal bands. Weighted stripes are the
  // reason a plain equal-thirds renderer is not enough.
  it('CF.6: honours stripe weights', () => {
    const out = bands('LV')
    expect(out).toHaveLength(3)
    expect(out[0]!.style.height).toBe('40%')
    expect(out[1]!.style.top).toBe('40%')
    expect(out[1]!.style.height).toBe('20%')
    expect(out[2]!.style.top).toBe('60%')
  })

  // CF.7 — Spain is 1:2:1.
  it('CF.7: draws Spain as 1:2:1', () => {
    const out = bands('ES')
    expect(out[0]!.style.height).toBe('25%')
    expect(out[1]!.style.height).toBe('50%')
  })

  // CF.8 — five bands must not collapse.
  it('CF.8: draws five-band flags', () => {
    expect(bands('TH')).toHaveLength(5)
    expect(bands('CR')).toHaveLength(5)
  })

  // CF.9 — Bahrain's vertical split is 1:3, hoist much narrower than fly.
  it('CF.9: honours vertical stripe weights', () => {
    const out = bands('BH')
    expect(out).toHaveLength(2)
    expect(out[0]!.style.width).toBe('25%')
    expect(out[1]!.style.left).toBe('25%')
    expect(out[1]!.style.width).toBe('75%')
  })
})

describe('CountryFlag — crosses', () => {
  // CF.10 — a Nordic cross is offset toward the hoist; that offset is the
  // whole visual signature of the family.
  it('CF.10: offsets the Nordic cross toward the hoist', () => {
    const out = bands('SE')
    expect(out).toHaveLength(3)
    expect(out[1]!.style.top).toBe('38%') // horizontal arm
    expect(out[2]!.style.left).toBe('30%') // vertical arm, off-centre
  })

  // CF.11 — Norway and Iceland carry an inner cross inside the outer one.
  it('CF.11: draws the inner cross when present', () => {
    expect(bands('NO')).toHaveLength(5)
    expect(bands('IS')).toHaveLength(5)
    expect(bands('FI')).toHaveLength(3) // no inner cross
  })

  // CF.12 — Switzerland's cross is centred, unlike the Nordic family.
  it('CF.12: centres a non-Nordic cross', () => {
    const out = bands('CH')
    expect(out[2]!.style.left).toBe('38%')
  })
})

describe('CountryFlag — disc', () => {
  // CF.13 — a plain centred disc is the only charge the set draws.
  it('CF.13: draws a centred disc', () => {
    const out = bands('JP')
    expect(out).toHaveLength(2)
    expect(out[1]!.style.borderRadius).toBe('50%')
    expect(out[1]!.style.left).toBe('50%')
  })

  // CF.14 — Bangladesh's disc sits slightly toward the hoist.
  it('CF.14: offsets the disc where the flag does', () => {
    expect(bands('BD')[1]!.style.left).toBe('45%')
  })
})

describe('CountryFlag — presentation', () => {
  // CF.15 — an icon-only graphic needs an accessible name; the translated
  // country name is preferred, the code is the fallback.
  it('CF.15: labels the chip, preferring the country name', () => {
    const { container } = render(CountryFlag, { props: { code: 'PL', label: 'Polska' } })
    const flag = container.querySelector('.flag')!
    expect(flag.getAttribute('role')).toBe('img')
    expect(flag.getAttribute('aria-label')).toBe('Polska')

    const { container: bare } = render(CountryFlag, { props: { code: 'PL' } })
    expect(bare.querySelector('.flag')!.getAttribute('aria-label')).toBe('PL')
  })

  // CF.16 — codes arrive from free-text normalisation, so casing is incidental.
  it('CF.16: accepts a lowercase code and applies the small size', () => {
    expect(bands('pl')).toHaveLength(2)
    const { container } = render(CountryFlag, { props: { code: 'PL', size: 'sm' } })
    expect(container.querySelector('.flag')!.classList.contains('sm')).toBe(true)
  })
})
