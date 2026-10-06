// §12 captures: node capture.mjs <buildRoot> <outDir> [filter]
//   <buildRoot> holds ce/ (dist-ce) and app/ (dist). Every request is served from
//   disk or stubbed, the date is fixed at 6 Oct 2026, and the same states are
//   driven by dispatching clicks on the same elements in both builds.
import { createRequire } from 'node:module'
import fs from 'node:fs'
import path from 'node:path'
import { EVENTS } from './pool.mjs'

const require = createRequire(new URL('../../../../frontend/package.json', import.meta.url))
const { chromium } = require('@playwright/test')

const [buildRoot, outDir, filter = ''] = process.argv.slice(2)
fs.mkdirSync(outDir, { recursive: true })

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json' }
const HREFS = {
  'href-home': 'https://weteraniszermierki.pl/',
  'href-ranking': '/ranking/',
  'href-calendar': '/znajdz-zawody/',
  'href-calculator': '/kalkulator-punktow/',
  'href-table': '/tabela-punktacji/',
}
const SETTLE = 1000

async function wire(page, dir) {
  await page.clock.setFixedTime(new Date('2026-10-06T10:00:00'))
  await page.addInitScript(DEEP)
  await page.route('http://cap.local/**', async (route) => {
    const p = new URL(route.request().url()).pathname
    const file = path.join(dir, decodeURIComponent(p))
    if (fs.existsSync(file) && fs.statSync(file).isFile()) {
      await route.fulfill({ path: file, contentType: TYPES[path.extname(file)] ?? 'application/octet-stream' })
    } else await route.fulfill({ status: 404, body: '' })
  })
  // The calendar comes from the fixed pool; everything else answers empty.
  const stub = async (route) => {
    const u = route.request().url()
    const json = (body) => route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body), headers: { 'access-control-allow-origin': '*' } })
    if (route.request().method() === 'OPTIONS') return route.fulfill({ status: 204, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' } })
    if (u.includes('/rest/v1/vw_calendar')) return json(EVENTS)
    if (u.includes('/rest/v1/rpc/')) return json(null)
    if (u.includes('/auth/v1/')) return json({})
    return json([])
  }
  await page.route('http://stub.local/**', stub)
  await page.route('http://127.0.0.1:54321/**', stub)
}

// Elements may sit in a shadow root (the custom element) or in light DOM (github.io).
function DEEP() {
  window.__deep = (sel) => {
    const walk = (root) => { const hit = root.querySelector(sel); if (hit) return hit
      for (const el of root.querySelectorAll('*')) if (el.shadowRoot) { const x = walk(el.shadowRoot); if (x) return x }
      return null }
    return walk(document)
  }
}

async function click(page, sel) {
  const ok = await page.evaluate((s) => { const el = window.__deep(s); if (!el) return false; el.click(); return true }, sel)
  if (!ok) throw new Error(`no ${sel}`)
  await page.waitForTimeout(SETTLE)
}

async function rects(page) {
  return page.evaluate(() => {
    const box = (s) => { const el = window.__deep(s); if (!el) return null; const r = el.getBoundingClientRect(); return { x: r.x + scrollX, y: r.y + scrollY, w: r.width, h: r.height } }
    return { vp: box('.vp'), mid: box('.ln.mid'), title: box('h1.site-title') ?? box('h2.app-title'), mid_label: window.__deep('.ln.mid .sm b')?.textContent ?? null }
  })
}

async function shoot(page, name, meta) {
  await page.screenshot({ path: path.join(outDir, `${name}.png`), fullPage: true })
  meta[name] = await rects(page)
}

async function mountCe(page, tag, attrs) {
  await page.goto('http://cap.local/index.ce.html')
  await page.evaluate(({ tag, attrs }) => {
    document.documentElement.style.margin = '0'
    document.body.style.margin = '0'
    document.body.replaceChildren()
    const el = document.createElement(tag)
    for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v)
    document.body.appendChild(el)
  }, { tag, attrs: { ...attrs, ...HREFS, 'asset-base': 'http://cap.local/', 'supabase-prod-url': 'http://stub.local', 'supabase-prod-key': 'stub' } })
  await page.waitForTimeout(1500)
}

async function setLang(page, lang) {
  if (lang === 'en') await click(page, '.lang-btn[aria-label="English"]')
}

async function calendarStates(page, prefix, open, meta) {
  await open()
  await shoot(page, `${prefix}-open`, meta)
  // The drawer is captured at rest: its 0.25 s slide leaves the text
  // rasterised at a run-dependent sub-pixel phase (measured: the same build
  // captured twice differed). The same override goes into both builds.
  await page.evaluate(() => {
    const css = '.sidebar { transition: none !important; }'
    const roots = [document, ...[...document.querySelectorAll('*')].filter((e) => e.shadowRoot).map((e) => e.shadowRoot)]
    for (const r of roots) { const st = document.createElement('style'); st.textContent = css; (r === document ? document.head : r).appendChild(st) }
  })
  await click(page, '.hamburger-btn')
  await shoot(page, `${prefix}-drawer`, meta)
  await page.keyboard.press('Escape')
  await page.waitForTimeout(SETTLE)
  await click(page, '.ln.dn')
  await shoot(page, `${prefix}-later1`, meta)
  await click(page, '.ln.dn')
  await shoot(page, `${prefix}-later2`, meta)
  await open()
  await click(page, '.ln.up')
  await shoot(page, `${prefix}-earlier1`, meta)
  await click(page, '.ln.up')
  await shoot(page, `${prefix}-earlier2`, meta)
}

const browser = await chromium.launch()
const meta = {}
const ce = path.join(buildRoot, 'ce')
const app = path.join(buildRoot, 'app')

for (const width of [320, 375, 1280]) {
  for (const lang of ['pl', 'en']) {
    const ctx = await browser.newContext({ viewport: { width, height: 900 }, deviceScaleFactor: width < 768 ? 2 : 1 })
    const page = await ctx.newPage()
    await wire(page, ce)
    const tagp = `wp-${width}-${lang}`
    if (!filter || tagp.includes(filter)) {
      await calendarStates(page, `${tagp}-calendar`, async () => { await mountCe(page, 'spws-calendar', { chrome: 'site' }); await setLang(page, lang) }, meta)
      // The other three pages' bars.
      for (const [name, tag, attrs] of [['ranking', 'spws-ranklist', { chrome: 'site', view: 'ranklist' }], ['calculator', 'spws-document', { doc: 'kalkulator-punktow' }], ['table', 'spws-document', { doc: 'tabela-punktacji' }]]) {
        await mountCe(page, tag, attrs)
        await setLang(page, lang)
        const bar = page.locator(`${tag} header.site-bar`)
        await bar.screenshot({ path: path.join(outDir, `${tagp}-${name}-bar.png`) })
        meta[`${tagp}-${name}-bar`] = { title: null }
      }
    }
    await ctx.close()
  }
}

for (const width of [320, 360, 375, 414]) {
  for (const lang of ['pl', 'en']) {
    const tagp = `gh-${width}-${lang}`
    if (filter && !tagp.includes(filter)) continue
    const ctx = await browser.newContext({ viewport: { width, height: 900 }, deviceScaleFactor: 2 })
    const page = await ctx.newPage()
    await wire(page, app)
    const open = async () => {
      await page.goto('http://cap.local/index.html')
      await page.waitForTimeout(1500)
      await setLang(page, lang)
      await click(page, '.hamburger-btn')
      await click(page, '.nav-list li:nth-child(2) .nav-item')
      await page.waitForTimeout(800)
    }
    await calendarStates(page, `${tagp}-calendar`, open, meta)
    await ctx.close()
  }
}

await browser.close()
fs.writeFileSync(path.join(outDir, 'meta.json'), JSON.stringify(meta, null, 1))
console.log(`captured ${Object.keys(meta).length} states into ${outDir}`)
