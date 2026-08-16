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
