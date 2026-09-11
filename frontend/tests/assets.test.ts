// Plan test 8.88 — the points calculator shipped as a temporary static page
// under frontend/public/ (ADR-085: a one-off exception, not a pattern; the page
// and this test are removed once the formula becomes the live SPWS scoring).
// See doc/plans/kalkulator-w-menu-ranklisty-2026-08-15.html §5.
//
// The two files are imported with Vite's ?raw suffix rather than through
// node:fs — the frontend project carries no Node type definitions, and adding
// them for one assertion would be a heavier change than the assertion is worth.

import { describe, it, expect } from 'vitest'
import published from '../public/kalkulator-punktow.html?raw'
import source from '../../doc/tools/kalkulator-punktow-za-wynik-spws.v2.html?raw'
import wordpress from '../../doc/tools/WP-kalkulator-punktow-za-wynik-spws.html?raw'
import tablePublished from '../public/tabela-punktacji.html?raw'
import tableSource from '../../doc/tools/Tabela-punktacji-SPWS_2026-2027.html?raw'

describe('static tool assets (ADR-085)', () => {
  // 8.88 — the menu entry must point at a file that actually ships, and that
  // file must not drift from the copy kept under doc/tools/.
  it('ships the points calculator identical to the documentation copy', () => {
    expect(published.length).toBeGreaterThan(1000)
    expect(published).toBe(source)
  })

  // The WordPress upload copy is the third of three copies of the same file and
  // the only one nothing else checks — it is carried by hand to the SPWS site.
  it('keeps the WordPress upload copy in step with the same source', () => {
    expect(wordpress).toBe(source)
  })
})

// Plan tests 8.94–8.96 — Załącznik nr 1, the scoring-table annex (ADR-092).
// The second — and, per ADR-092 §3, still exceptional — static page published
// this way. See doc/plans/tabela-punktacji-2026-09-11.html §7.
describe('scoring table annex (ADR-092)', () => {
  // 8.94 — the drawer entry must point at a file that actually ships, and that
  // file must not drift from the copy kept under doc/tools/.
  it('ships the scoring table identical to the documentation copy', () => {
    expect(tablePublished.length).toBeGreaterThan(1000)
    expect(tablePublished).toBe(tableSource)
  })

  // 8.95 — The header no longer carries a "Status: projekt" chip (removed
  // 2026-09-11 at the user's request), so this meta is the ONLY thing keeping an
  // unadopted regulation annex out of search results. ADR-092 §4 makes removing
  // it a deliberate act performed at adoption; this test is what makes an
  // accidental removal loud.
  it('keeps the draft annex out of search engines', () => {
    expect(tablePublished).toContain('name="robots"')
    expect(tablePublished).toMatch(/content="noindex,\s*nofollow"/)
  })

  // 8.96 — The PL/EN switch is pure CSS, so the document stays readable and
  // switchable with JavaScript disabled — the failure mode that made hosting
  // necessary in the first place. Both copies must be present in the MARKUP
  // (not assembled by script), and the two switch rules must exist.
  it('carries both languages in the markup, switched without JavaScript', () => {
    expect(tablePublished).toContain('class="copy-pl"')
    expect(tablePublished).toContain('class="copy-en"')
    expect(tablePublished).toContain('#langPl:checked ~ main .copy-en { display: none; }')
    expect(tablePublished).toContain('#langEn:checked ~ main .copy-pl { display: none; }')
  })

  // The general sibling combinator only reaches <main> if the radios precede it
  // as siblings. Reordering breaks the switch silently — no error, the page just
  // sticks in one language — so the order is pinned here. ADR-092 consequences.
  it('keeps the language radios before main, as siblings', () => {
    const plRadio = tablePublished.indexOf('id="langPl"')
    const enRadio = tablePublished.indexOf('id="langEn"')
    const main = tablePublished.indexOf('<main class="wrap">')
    expect(plRadio).toBeGreaterThan(-1)
    expect(plRadio).toBeLessThan(main)
    expect(enRadio).toBeLessThan(main)
  })
})
