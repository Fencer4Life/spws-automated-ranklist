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
import scoringSource from '../src/lib/scoring.ts?raw'
import typesSource from '../src/lib/types.ts?raw'
import exportSource from '../src/lib/export.ts?raw'
import editorSource from '../src/components/ScoringConfigEditor.svelte?raw'
import plLocale from '../src/lib/locales/pl.json?raw'
import enLocale from '../src/lib/locales/en.json?raw'
import generatorSource from '../scripts/build-scoring-pages.mjs?raw'

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

// SE27.PAGE.01–03 — the published pages carry the 2026/2027 engine (ADR-103
// §7, FR-142). build-scoring-pages.mjs --check, a preflight gate, proves the
// generated block is byte for byte the current src/lib/scoring.ts; these
// assertions say what that block must contain and how each page reads its
// season parameters. The browser half of SE27.PAGE.03 — the annex renders
// 64 x 64 with rows 32–64 on EVF, the joined mode works, nothing scrolls
// sideways at 375 px — is checked in the browser, not here.
//
// The board preview that stood in for these pages (SE27.PREVIEW.01–03, ADR-085
// §2 as amended 2026-09-28) was deleted with its tests in this change, as that
// amendment requires.
const MODULE_BLOCK = /\/\* === SPWS-SCORING-MODULE:BEGIN[\s\S]*?\/\* === SPWS-SCORING-MODULE:END === \*\//
const PAGES: [string, string][] = [
  ['calculator', published],
  ['annex', tablePublished],
]

describe('the 2026/2027 engine on the published pages (ADR-103)', () => {
  for (const [name, html] of PAGES) {
    // SE27.PAGE.01 — the formula is the shared module, with EVF classic and the
    // joined engine; the retired field-scaled engine and its base_slope, and the
    // removed place-and-medal engine (ADR-104), are gone everywhere.
    it(`SE27.PAGE.01 ${name}: carries the generated module of both engines, not the retired ones`, () => {
      const block = html.match(MODULE_BLOCK)?.[0] ?? ''
      expect(block.length).toBeGreaterThan(1000)
      expect(html).not.toContain('SPWS_PLACE_MEDAL_V1_2026_2027')
      expect(block).toContain('"SPWS_EVF_JOINED_V1_2026_2027"')
      expect(block).toContain('"EVF_CLASSIC_V1_2025_2026"')
      expect(html).not.toMatch(/FIELD_SCALED|baseSlope|base_slope/)
    })

    // SE27.PAGE.02 — fn_public_scoring_params returns one row per type, ordered
    // by type code, so rows[0] is MEW. A page takes its row by type, never by
    // position, and keeps the #spws-env the release workflow fills in.
    it(`SE27.PAGE.02 ${name}: reads the per-type parameters by type, not by position`, () => {
      expect(html).toContain('id="spws-env"')
      expect(html).toContain('fn_public_scoring_params')
      expect(html).toMatch(/row\.type_code === /)
      expect(html).not.toMatch(/rows\[0\]/)
    })
  }

  // SE27.PAGE.03 (structure) — FR-142's shape for each page.
  // The annex was rewritten for the joined-bracket engine locked on 30 September
  // 2026 (doc/plans/scoring-table-rewrite-plan-2026-09-30.html): the medal
  // table gave way to the premium table and the bracket simulator.
  it('SE27.PAGE.03 annex: 64 x 64, the premium table and the simulator, pinned to 2026/2027', () => {
    expect(tablePublished).toContain('const TABLE_N = 64;')
    expect(tablePublished).toContain("const SEASON_CODE = 'SPWS-2026-2027';")
    expect(tablePublished).toContain('id="coefBody"')
    for (const id of ['premiumTable', 'premiumN', 'simTable', 'ownCat', 'youngCat']) {
      expect(tablePublished).toContain(`id="${id}"`)
    }
    // It computes with the joined-bracket engine and refuses any other.
    expect(tablePublished).toContain('r.engine_code !== SPWSScoring.JOINED_ENGINE')
  })

  it('SE27.PAGE.03 annex: describes no place-and-medal engine outside the shared module', () => {
    const page = tablePublished.replace(MODULE_BLOCK, '')
    expect(page).not.toMatch(/MEDAL_ROWS|PLACE_MEDAL|medalBonus|placeMedalMethod/)
    expect(page).not.toMatch(/∛K|log₂N|3,5 pkt|3\.5 points|13 × ∛/)
  })

  // JB27.PAGE.01 (ADR-104 §8) — the calculator is rebuilt from the annex's
  // tools: the calculator, the premium table and the simulator, with the same
  // texts, following the ACTIVE season and computing only with the joined
  // engine. The SPWS/EVF toggle and the K/m fields are gone, and so is the
  // 64 x 64 table; the rules are a link to the annex, absolute so that the
  // WordPress copy, uploaded alone, still reaches it. The browser half — PL
  // and EN, 375 px, a clean console — is checked in the browser.
  it('JB27.PAGE.01 calculator: the annex tools for the active season, no toggle, the rules linked', () => {
    expect(published).toContain('const MAX_PARTICIPANTS = 300;')
    expect(published).toContain('const SEASON_CODE = null;')
    for (const id of ['participants', 'place', 'joinedToggle', 'ownCat', 'youngCat', 'typeChips',
      'premiumTable', 'premiumN', 'simTable']) {
      expect(published, id).toContain(`id="${id}"`)
    }
    expect(published).toContain('r.engine_code !== SPWSScoring.JOINED_ENGINE')
    for (const id of ['algSpws', 'algEvf', 'fK', 'fC', 'pointsTable', 'coefBody']) {
      expect(published, id).not.toContain(`id="${id}"`)
    }
    expect(published).toContain(
      'href="https://fencer4life.github.io/spws-automated-ranklist/tabela-punktacji.html"',
    )
  })
})

// JB27.CLEAN.06 (ADR-104 §1): the place-and-medal engine and its columns are
// gone from the frontend — the shared module, the row type, the drill-down
// export, the Admin editor, both locales and both published pages.
const RETIRED = /PLACE_MEDAL|placeMedal|medalBonus|int_category_count|int_category_place|int_below_count|num_field_pts|num_below_pts|num_medal_bonus/
describe('JB27.CLEAN.06 — the place-and-medal engine is gone from the frontend', () => {
  const sources: [string, string][] = [
    ['src/lib/scoring.ts', scoringSource],
    ['src/lib/types.ts', typesSource],
    ['src/lib/export.ts', exportSource],
    ['src/components/ScoringConfigEditor.svelte', editorSource],
    ['src/lib/locales/pl.json', plLocale],
    ['src/lib/locales/en.json', enLocale],
    ['public/kalkulator-punktow.html', published],
    ['public/tabela-punktacji.html', tablePublished],
  ]
  for (const [path, text] of sources) {
    it(`${path} names neither the engine nor its columns`, () => {
      expect(text.length).toBeGreaterThan(100)
      expect(text.match(RETIRED)?.[0] ?? null).toBeNull()
    })
  }
})

// WP.DOC.03 (ADR-090 amendment 2026-10-03, FR-150) — the embed/ copies that
// <spws-document> frames on the association's WordPress pages. They are PROD
// copies of the calculator and the annex (release.yml fills them with the PROD
// pair, WP.REL.01) and sit under the SPWS bar, so they carry no banner, no
// language bar and no ribbon of their own; they report their height so the
// frame can grow to it; and their maths is the same generated module as the
// root copies (ADR-102), written by the same generator. Plan:
// doc/plans/wordpress-ranking-points-table-brainstorm-2026-10-02.html §03, §05.
//
// Read through import.meta.glob rather than a static import, so that the
// absence of the copies fails these tests and not the whole file.
const EMBED = import.meta.glob('../public/embed/*.html', {
  query: '?raw', import: 'default', eager: true,
}) as Record<string, string>
const EMBED_PAGES: [string, string, string][] = [
  ['kalkulator-punktow', '../public/embed/kalkulator-punktow.html', published],
  ['tabela-punktacji', '../public/embed/tabela-punktacji.html', tablePublished],
]

describe('WP.DOC.03 — the embed/ copies framed on WordPress', () => {
  for (const [name, path, root] of EMBED_PAGES) {
    it(`${name}: exists, without a banner, a language bar or a ribbon of its own`, () => {
      const html = EMBED[path] ?? ''
      expect(html.length, `${path} is missing`).toBeGreaterThan(1000)
      expect(html).not.toContain('class="document-head"')
      expect(html).not.toContain('class="lang-switch"')
      expect(html).not.toContain('env-ribbon')
      // Still a PROD copy the release fills, and still bilingual through ?lang=.
      expect(html).toContain('id="spws-env"')
      expect(html).toContain('class="copy-pl"')
      expect(html).toContain('class="copy-en"')
    })

    it(`${name}: reports its height to the framing element`, () => {
      const html = EMBED[path] ?? ''
      expect(html).toContain("'spws-doc-height'")
      expect(html).toMatch(/parent\.postMessage\(/)
    })

    it(`${name}: carries the same generated scoring module as the root copy`, () => {
      const html = EMBED[path] ?? ''
      const block = html.match(MODULE_BLOCK)?.[0] ?? ''
      expect(block.length).toBeGreaterThan(1000)
      expect(block).toBe(root.match(MODULE_BLOCK)?.[0])
    })
  }

  it('the generator writes both copies, so --check guards them', () => {
    expect(generatorSource).toContain("'frontend/public/embed/kalkulator-punktow.html'")
    expect(generatorSource).toContain("'frontend/public/embed/tabela-punktacji.html'")
  })
})
