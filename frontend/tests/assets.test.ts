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

// SE27.PREVIEW.01–03 — the board preview of the proposed 2026/2027 engine
// (ADR-085 §2, amended 2026-09-28). The third static page, and the only one
// that reads no season parameters: no engine implements its formula yet, so it
// computes everything in the page. It is not in the drawer, and it is deleted —
// with these tests — in the change that releases that engine.
// See doc/plans/scoring-engine-2026-2027-implementation-plan-2026-09-28.html, Step A.
//
// Loaded through import.meta.glob rather than a ?raw import, so a missing file
// fails 01 as an assertion instead of failing this whole file to load and
// taking 8.88 and 8.94–8.96 down with it.
const publicPages = import.meta.glob<string>('../public/*.html', {
  query: '?raw',
  import: 'default',
  eager: true,
})
const publishedFiles = new Set(
  Object.keys(import.meta.glob('../public/*')).map((p) => p.replace('../public/', '')),
)
const PREVIEW = '../public/tabela-punktacji-projekt-2026-2027.html'
const preview = publicPages[PREVIEW] ?? ''

describe('board preview of the 2026/2027 engine (ADR-085 §2 amendment)', () => {
  // SE27.PREVIEW.01 — the address given to the board must actually ship.
  it('ships the preview page', () => {
    expect(Object.keys(publicPages)).toContain(PREVIEW)
    expect(preview.length).toBeGreaterThan(1000)
  })

  // SE27.PREVIEW.02 — an unadopted proposal must not be found by search and
  // read as the rule in force; same reasoning as 8.95.
  it('keeps the unadopted proposal out of search engines', () => {
    expect(preview).toContain('name="robots"')
    expect(preview).toMatch(/content="noindex,\s*nofollow"/)
  })

  // SE27.PREVIEW.03 — self-contained: no database, no network, no credential
  // (the release workflow injects keys only into the two parameter-reading
  // pages), and no relative link to a file Pages does not publish — the
  // source page links a doc/plans/ analysis that would 404 here.
  it('is self-contained', () => {
    // An empty string passes every negative assertion below.
    expect(preview.length).toBeGreaterThan(1000)
    expect(preview).not.toMatch(/\bfetch\s*\(/)
    expect(preview).not.toMatch(/XMLHttpRequest|sendBeacon|WebSocket/)
    expect(preview).not.toContain('spws-env')
    expect(preview).not.toMatch(/supabase/i)
    expect(preview).not.toMatch(/eyJ[A-Za-z0-9_-]{10,}/)
    const relative = [...preview.matchAll(/\b(?:href|src)\s*=\s*["']([^"']+)["']/g)]
      .map((m) => m[1])
      .filter((url) => !/^(#|[a-z][a-z0-9+.-]*:)/i.test(url))
    for (const url of relative) {
      expect(publishedFiles).toContain(url.split(/[?#]/)[0].replace(/^\.\//, ''))
    }
  })
})
