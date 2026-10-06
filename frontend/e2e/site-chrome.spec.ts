// WP.BAR.03, WP.BAR.05, WP.CALC.01 — the SPWS bar on phones, the calendar's
// fitted title, and the calculator's number boxes, measured in a real browser
// against the custom-element build that WordPress loads (assets/main.ce.js).
// ADR-090 amendments 2026-10-03 and 2026-10-06; FR-148, FR-150.
// Plan: doc/plans/wordpress-ranking-points-table-brainstorm-2026-10-02.html §02, §05.
//
// jsdom evaluates no media query and lays nothing out, so the one-row bar, the
// short-title switch at 430 px (WP.BAR.02's width half) and the alignment of the
// digits can only be observed here.

import { test, expect, type Page } from '@playwright/test'

const HREFS: Record<string, string> = {
  'href-home': 'https://weteraniszermierki.pl/',
  'href-ranking': '/ranking/',
  'href-calendar': '/znajdz-zawody/',
  'href-calculator': '/kalkulator-punktow/',
  'href-table': '/tabela-punktacji/',
}

// `short: null` — the calendar's title is fitted by measurement (WP.BAR.05),
// not switched at 430 px.
type SitePage = { name: string; tag: string; attrs: Record<string, string>; short: { pl: string; en: string } | null }

// The four public WordPress pages, each as its body tag (demo data, no database).
const PAGES: SitePage[] = [
  { name: 'ranking', tag: 'spws-ranklist', attrs: { chrome: 'site', view: 'ranklist', demo: '' }, short: { pl: 'Ranking', en: 'Ranklist' } },
  { name: 'calendar', tag: 'spws-calendar', attrs: { chrome: 'site', demo: '' }, short: null },
  { name: 'calculator', tag: 'spws-document', attrs: { doc: 'kalkulator-punktow' }, short: { pl: 'Kalkulator', en: 'Calculator' } },
  { name: 'table', tag: 'spws-document', attrs: { doc: 'tabela-punktacji' }, short: { pl: 'Tabela', en: 'Table' } },
]

/** Replace the harness body with one WordPress page body: a single element.
 *  The page bodies zero the theme's margins (`html, body { margin: 0 }`, ADR-090
 *  §7), so the harness does too; the browser's default 8 px would not be there. */
async function mountPage(page: Page, p: SitePage) {
  await page.goto('/index.ce.html')
  await page.evaluate(({ tag, attrs }) => {
    document.documentElement.style.margin = '0'
    document.body.style.margin = '0'
    document.body.replaceChildren()
    const el = document.createElement(tag)
    for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v)
    document.body.appendChild(el)
  }, { tag: p.tag, attrs: { ...p.attrs, ...HREFS, 'asset-base': `${new URL(page.url()).origin}/` } })
  await expect(page.locator(`${p.tag} header.site-bar`)).toBeVisible()
}

/** The bar's measured shape: one row, nothing wrapped, nothing sticking out. */
async function barShape(page: Page, tag: string) {
  return page.locator(`${tag} header.site-bar`).evaluate((bar) => {
    const kids = Array.from(bar.children).filter((k) => getComputedStyle(k).display !== 'none')
    const mids = kids.map((k) => { const r = k.getBoundingClientRect(); return r.top + r.height / 2 })
    const title = Array.from(bar.querySelectorAll('.site-title-long, .site-title-short, .site-title-fit'))
      .find((t) => getComputedStyle(t).display !== 'none') as HTMLElement | undefined
    const heading = bar.querySelector('.site-title') as HTMLElement | null
    return {
      children: kids.length,
      midSpread: Math.max(...mids) - Math.min(...mids),
      barOverflow: bar.scrollWidth - bar.clientWidth,
      pageOverflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
      titleText: title?.textContent?.trim() ?? null,
      // The title never wraps (nowrap); what can go wrong is an ellipsis.
      titleClipped: heading ? heading.scrollWidth - heading.clientWidth : -1,
    }
  })
}

test.describe('WP.BAR.03 — the bar is one row on phones, on all four pages, in PL and EN', () => {
  for (const width of [320, 360, 390]) {
    for (const p of PAGES) {
      test(`${p.name} at ${width} px`, async ({ page }) => {
        await page.setViewportSize({ width, height: 740 })
        await mountPage(page, p)

        for (const lang of ['pl', 'en'] as const) {
          if (lang === 'en') {
            await page.locator(`${p.tag} header.site-bar .lang-btn[aria-label="English"]`).click()
          }
          const shape = await barShape(page, p.tag)
          expect(shape.children, 'hamburger, logo, title, language').toBeGreaterThanOrEqual(4)
          expect(shape.midSpread, `${lang}: every item on one row`).toBeLessThan(4)
          expect(shape.barOverflow, `${lang}: nothing sticks out of the bar`).toBeLessThanOrEqual(0)
          expect(shape.pageOverflow, `${lang}: no sideways scroll`).toBeLessThanOrEqual(0)
          if (p.short) expect(shape.titleText, `${lang}: the short title`).toBe(p.short[lang])
          else expect(shape.titleText, `${lang}: a fitted title`).toBeTruthy()
          expect(shape.titleClipped, `${lang}: the title is whole, not clipped`).toBe(0)
        }
      })
    }
  }

  test('the long title from 430 px up, the short one below', async ({ page }) => {
    await page.setViewportSize({ width: 429, height: 740 })
    await mountPage(page, PAGES[2])
    expect((await barShape(page, 'spws-document')).titleText).toBe('Kalkulator')
    await page.setViewportSize({ width: 430, height: 740 })
    expect((await barShape(page, 'spws-document')).titleText).toBe('Kalkulator punktów')
  })
})

// WP.BAR.05 — the calendar's title is its menu name wherever it fits (ADR-090
// amendment 2026-10-06). „Znajdź zawody" / "Competition Finder" unfolds
// whenever the room the title has allows it, and squeezes to „Zawody"
// ("Competitions", then "Events") only for lack of room. Measured, not tied to
// a screen width; the font, its size and the bar's single row are unchanged.
// On WordPress the title takes the bar's slack, so its width is the room; the
// github.io header does not stretch its title, so its room is what the header
// leaves with everything on one row.
test.describe('WP.BAR.05 — the calendar title: the full name whenever it fits', () => {
  type Surface = 'WordPress bar' | 'github.io header'
  const SURFACES: { name: Surface; tag: string; attrs: Record<string, string>; ranking: Record<string, string>; zeroMargin: boolean }[] = [
    { name: 'WordPress bar', tag: 'spws-calendar', attrs: { chrome: 'site', demo: '' }, ranking: { chrome: 'site', view: 'ranklist', demo: '' }, zeroMargin: true },
    { name: 'github.io header', tag: 'spws-ranklist', attrs: { chrome: 'full', view: 'calendar', demo: '' }, ranking: { chrome: 'full', view: 'ranklist', demo: '' }, zeroMargin: false },
  ]

  async function mount(page: Page, tag: string, attrs: Record<string, string>, zeroMargin: boolean) {
    await page.goto('/index.ce.html')
    await page.evaluate(({ tag, attrs, zeroMargin }) => {
      if (zeroMargin) {
        document.documentElement.style.margin = '0'
        document.body.style.margin = '0'
      }
      document.body.replaceChildren()
      const el = document.createElement(tag)
      for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v)
      document.body.appendChild(el)
    }, { tag, attrs: { ...attrs, ...HREFS, 'asset-base': `${new URL(page.url()).origin}/` }, zeroMargin })
    await page.waitForTimeout(400) // the logo loads; the title is measured again
  }

  async function titleShape(page: Page, tag: string) {
    return page.locator(tag).evaluate((host) => {
      const root = host.shadowRoot!
      const bar = (root.querySelector('header.site-bar') ?? root.querySelector('header.app-header'))!
      const title = (bar.querySelector('h1.site-title') ?? bar.querySelector('h2.app-title'))!
      const shown = title.querySelector('.site-title-fit, .app-title-fit')
      const copies = [...title.querySelectorAll('.title-measure > span')]
      const w = (el: Element | null) => (el ? el.getBoundingClientRect().width : 0)
      const gap = (el: Element) => parseFloat(getComputedStyle(el).columnGap) || 0
      const room = bar.matches('.site-bar')
        ? w(title)
        : w(bar) - w(bar.querySelector('.hamburger-btn')) - w(bar.querySelector('.header-right')) - 2 * gap(bar) -
          w(title.querySelector('.header-logo')) - gap(title)
      const kids = [...bar.children].filter((k) => getComputedStyle(k).display !== 'none')
      const mids = kids.map((k) => { const r = k.getBoundingClientRect(); return r.top + r.height / 2 })
      return {
        candidates: copies.map((c) => c.textContent ?? ''),
        widths: copies.map(w),
        room,
        shown: shown?.textContent?.trim() ?? null,
        overhang: shown ? shown.getBoundingClientRect().right - title.getBoundingClientRect().right : 0,
        fontSize: getComputedStyle(title).fontSize,
        rowSpread: Math.max(...mids) - Math.min(...mids),
      }
    })
  }

  for (const surface of SURFACES) {
    for (const width of [320, 360, 375, 414, 1280]) {
      test(`${surface.name} at ${width} px, PL and EN`, async ({ page }) => {
        await page.setViewportSize({ width, height: 740 })
        await mount(page, surface.tag, surface.ranking, surface.zeroMargin)
        const rankingFont = (await titleShape(page, surface.tag)).fontSize
        await mount(page, surface.tag, surface.attrs, surface.zeroMargin)
        for (const lang of ['pl', 'en'] as const) {
          if (lang === 'en') {
            await page.locator(`${surface.tag} .lang-btn[aria-label="English"]`).first().click()
            await page.waitForTimeout(200)
          }
          const s = await titleShape(page, surface.tag)
          expect(s.candidates, `${lang}: the candidates`).toEqual(
            lang === 'pl' ? ['Znajdź zawody', 'Zawody'] : ['Competition Finder', 'Competitions', 'Events'],
          )
          const fits = s.widths.findIndex((x) => x <= s.room)
          const expected = s.candidates[fits >= 0 ? fits : s.candidates.length - 1]
          test.info().annotations.push({ type: 'shown', description: `${surface.name} ${width} ${lang}: ${s.shown} (room ${s.room.toFixed(1)}; ${s.candidates.map((c, i) => `${c} ${s.widths[i]!.toFixed(1)}`).join(', ')})` })
          expect(s.shown, `${lang}: the first candidate that fits ${s.room.toFixed(1)} px`).toBe(expected)
          expect(s.overhang, `${lang}: never clipped`).toBeLessThanOrEqual(0.5)
          expect(s.fontSize, `${lang}: the bar's own font size`).toBe(rankingFont)
          if (fits >= 0) expect(s.rowSpread, `${lang}: the bar is one row`).toBeLessThan(4)
        }
      })
    }
  }
})

// WP.ADM.01, the element half: the WordPress page writes `admin-entry` as a bare
// attribute (`<spws-ranklist … admin-entry>`), whose value is "". Only the
// custom-element build shows whether the element reads that as true. The
// credentials point at a closed port: the sign-in modal opens before any request.
test.describe('WP.ADM.01 — admin-entry on the published elements', () => {
  const DEAD_PAIR = { 'supabase-prod-url': 'http://127.0.0.1:9', 'supabase-prod-key': 'e2e-placeholder' }

  async function mountWithAdmin(page: Page, tag: string, attrs: Record<string, string>) {
    await page.goto('/index.ce.html?admin=1')
    await page.evaluate(({ tag, attrs }) => {
      document.body.replaceChildren()
      const el = document.createElement(tag)
      for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v)
      document.body.appendChild(el)
    }, { tag, attrs: { ...attrs, ...DEAD_PAIR, ...HREFS, 'asset-base': `${new URL(page.url()).origin}/` } })
    await expect(page.locator(`${tag} header.site-bar`)).toBeVisible()
  }

  test('/ranking/ with the bare admin-entry attribute opens the sign-in at load', async ({ page }) => {
    await mountWithAdmin(page, 'spws-ranklist', { chrome: 'site', view: 'ranklist', 'admin-entry': '' })
    await expect(page.locator('spws-ranklist .admin-modal-title')).toHaveText('Logowanie administratora')
  })

  test('without admin-entry, ?admin=1 is ignored (ranking and calendar)', async ({ page }) => {
    for (const [tag, attrs] of [
      ['spws-ranklist', { chrome: 'site', view: 'ranklist' }],
      ['spws-calendar', { chrome: 'site' }],
    ] as const) {
      await mountWithAdmin(page, tag, attrs)
      await page.waitForTimeout(300)
      await expect(page.locator(`${tag} .admin-modal`)).toHaveCount(0)
    }
  })
})

// The four copies: the github.io (CERT) root copies and the embed/ (PROD) copies
// that WordPress frames. All come from the same generator.
const DOCUMENTS = [
  '/kalkulator-punktow.html',
  '/tabela-punktacji.html',
  '/embed/kalkulator-punktow.html',
  '/embed/tabela-punktacji.html',
]

test.describe('WP.CALC.01 — the number boxes and the calculator title', () => {
  for (const path of DOCUMENTS) {
    test(`${path}: every number box is right-aligned, vertically centred, with tabular digits`, async ({ page }) => {
      const response = await page.goto(path)
      expect(response?.status(), `${path} is served`).toBe(200)
      const boxes = await page.locator('main input[type="number"], main select').evaluateAll((els) =>
        els
          .filter((el) => (el as HTMLElement).offsetParent !== null)
          .map((el) => {
            const cs = getComputedStyle(el)
            return {
              id: el.id || el.tagName,
              textAlign: cs.textAlign,
              numeric: cs.fontVariantNumeric,
              padTop: cs.paddingTop,
              padBottom: cs.paddingBottom,
            }
          }),
      )
      expect(boxes.length).toBeGreaterThan(0)
      for (const b of boxes) {
        expect(['right', 'end'], `${b.id} text-align`).toContain(b.textAlign)
        expect(b.numeric, `${b.id} tabular digits`).toContain('tabular-nums')
        expect(b.padTop, `${b.id} centred: equal padding above and below`).toBe(b.padBottom)
      }
    })
  }

  test('the calculator is titled „Kalkulator punktów” / "Points calculator"', async ({ page }) => {
    await page.goto('/kalkulator-punktow.html')
    await expect(page.locator('h1 .copy-pl')).toHaveText('Kalkulator punktów')
    await expect(page.locator('h1 .copy-en')).toHaveText('Points calculator')
  })
})

// WP.CALC.02 — the calculator as in the signed-off mock (ADR-090 amendment
// 2026-10-03 §7, doc/adr/assets/adr-090-calculator.png; plan §03 "the rest of
// rev 2's revamp stands"). Markup and CSS only: the maths and its script stay.
// The calculator comes first; the other tools fold below, closed; the rules are
// a pill to the annex; "Stawka" reads as two segments; the result is soft blue.
// The annex keeps its content and order and takes the same controls and colours.
const rgb = (css: string) => (css.match(/\d+(\.\d+)?/g) ?? []).slice(0, 3).map(Number)

test.describe('WP.CALC.02 — the calculator first, the rest folded, the result soft blue', () => {
  for (const path of ['/kalkulator-punktow.html', '/embed/kalkulator-punktow.html']) {
    test(`${path}: the calculator first, the other tools folded and closed, the rules a pill`, async ({ page }) => {
      await page.goto(path)
      const layout = await page.evaluate(() => {
        const at = (id: string) => document.getElementById(id)
        const before = (a: Element | null, b: Element | null) =>
          !!a && !!b && !!(a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING)
        const folded = (id: string) => {
          const d = at(id)?.closest('details')
          return d ? (d.open ? 'open' : 'closed') : 'not folded'
        }
        return {
          calcFirst: ['shortTitle', 'premiumTitle', 'simTitle'].every((id) => before(at('calcTitle'), at(id))),
          shortTitle: folded('shortTitle'),
          premiumTitle: folded('premiumTitle'),
          simTitle: folded('simTitle'),
          calcFolded: folded('calcTitle'),
          lead: document.querySelectorAll('.document-head .lead').length,
          rulesSection: !!at('rulesTitle'),
          pill: document.querySelectorAll('a.rules-pill.annex-link').length,
        }
      })
      expect(layout.calcFirst, 'the calculator comes before every other tool').toBe(true)
      expect(layout.calcFolded).toBe('not folded')
      expect([layout.shortTitle, layout.premiumTitle, layout.simTitle]).toEqual(['closed', 'closed', 'closed'])
      expect(layout.lead, 'no subtitle').toBe(0)
      expect(layout.rulesSection, 'the full rules leave the page').toBe(false)
      expect(layout.pill, 'one pill leads to the annex').toBe(1)
    })
  }

  for (const path of DOCUMENTS) {
    test(`${path}: "Stawka" as two segments, the result soft blue with a blue edge`, async ({ page }) => {
      await page.goto(path)
      const joined = page.locator('#joinedLabel')
      await expect(joined.locator('.seg-single .copy-pl')).toHaveText('Jedna kategoria')
      await expect(joined.locator('.seg-joined .copy-pl')).toHaveText('Łączona')
      const colours = await page.locator('.result').first().evaluate((el) => {
        const cs = getComputedStyle(el)
        return { bg: cs.backgroundColor, edge: cs.borderLeftColor }
      })
      const [br, bgG, bb] = rgb(colours.bg)
      const [er, , eb] = rgb(colours.edge)
      expect(bb, `${path}: a blue background, not pink (${colours.bg})`).toBeGreaterThan(br)
      expect(bb, `${path}: a soft one (${colours.bg})`).toBeGreaterThan(220)
      expect(bgG).toBeGreaterThan(200)
      expect(eb, `${path}: a blue edge, not red (${colours.edge})`).toBeGreaterThan(er)
    })
  }
})
