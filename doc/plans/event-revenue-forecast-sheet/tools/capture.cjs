// FR-176 picture sheet captures. Invented data only; no database is read.
// usage: node capture.cjs <frontend dir (for playwright)> <output dir> <mode> <built dir>
//   mode "pages": <built dir> is a production CE build (vite.config.ce.ts).
//     Captures the registration form's first step and the visitor's event card
//     (both must be pixel-identical to main) and, when the build has it, the
//     revenue report page in its states, widths and languages.
//   mode "form": <built dir> is the form harness (build_harness.sh form-harness).
//     Captures the event form in its three states of the revenue link block.
//   mode "card": <built dir> is the card harness. Captures the card as a
//     signed-in administrator and as a visitor sees it.
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const { TODAY, EVENT_CODE, calendarRow } = require('../../entry-list-tiles-follow-filters-sheet/tools/fixture.cjs')

const OUT = process.argv[3]
const MODE = process.argv[4]
const DIST = process.argv[5]
fs.mkdirSync(OUT, { recursive: true })
const BASE = 'http://site.local'
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.json': 'application/json', '.woff2': 'font/woff2' }
const KEY = '11111111-2222-4333-8444-555555555555' // invented
const WIDTHS = { desktop: 1280, phone: 375 }

// --- invented report answers (fn_event_revenue_report's shape) ---------------
const SUR = ['ĆWIK', 'GOŁĄB', 'KOS', 'ŁABĘDŹ', 'NOWAK', 'KOWALSKI', 'WIERZBA', 'ŚWIERK', 'ZAJĄC', 'ŻUREK', 'BARAN', 'DĄB', 'LIS', 'MAZUR']
const GIVEN_F = ['Anna', 'Ewa', 'Maria', 'Zofia']
const GIVEN_M = ['Jan', 'Piotr', 'Tomasz', 'Jerzy', 'Robert']
const SETS = [['EPEE'], ['FOIL'], ['SABRE'], ['EPEE', 'FOIL'], ['EPEE'], ['EPEE', 'SABRE'], ['EPEE', 'FOIL', 'SABRE'], ['SABRE'], ['FOIL', 'SABRE'], ['EPEE'], ['EPEE'], ['FOIL'], ['EPEE', 'FOIL'], ['SABRE']]
function report(fees, n = 14) {
  const entries = Array.from({ length: n }, (_, i) => {
    const g = i % 3 === 0 ? 'F' : 'M'
    const w = SETS[i % SETS.length]
    return {
      id_registration: i + 1, txt_surname: SUR[i % SUR.length], txt_first_name: g === 'F' ? GIVEN_F[i % 4] : GIVEN_M[i % 5],
      enum_gender: g, enum_age_category: ['V0', 'V1', 'V2', 'V3', 'V4'][(i * 3) % 5], arr_weapons: w,
      num_fee: fees[String(w.length)],
    }
  })
  return { ts_generated: '2026-11-22T13:05:00Z', currency: 'PLN', fees, entries }
}
const REPORTS = {
  '1-full': report({ 1: 200, 2: 250, 3: 300, fallback_2: false, fallback_3: false }),
  '2-missing-tier': report({ 1: 200, 2: 400, 3: 300, fallback_2: true, fallback_3: false }),
  '3-no-entries': report({ 1: 200, 2: 250, 3: 300, fallback_2: false, fallback_3: false }, 0),
  '4-not-active': null,
}

function serve(p, dir) {
  return p.route(`${BASE}/**`, (route) => {
    const file = path.join(dir, decodeURIComponent(new URL(route.request().url()).pathname))
    if (!file.startsWith(dir) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      return route.fulfill({ status: 404, body: 'not in build: ' + file })
    }
    return route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || 'application/octet-stream', body: fs.readFileSync(file) })
  })
}

function answer(rep, tokenRow) {
  return (route) => {
    const req = route.request()
    const url = req.url()
    let body
    if (url.includes('/rest/v1/vw_calendar')) {
      const single = (req.headers()['accept'] || '').includes('vnd.pgrst.object')
      body = single ? calendarRow() : [calendarRow()]
    } else if (url.includes('/rpc/fn_event_revenue_report')) body = rep
    else if (url.includes('/rest/v1/tbl_event_report_token')) body = tokenRow
    else if (url.includes('/rest/v1/tbl_event')) body = { bool_show_seed: false }
    else if (url.includes('/rpc/')) body = null
    else body = []
    return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
  }
}

async function settledShot(p, locator, width, height) {
  const r = await locator.boundingBox()
  const x0 = Math.max(0, Math.floor(r.x) - 8)
  const y0 = Math.max(0, Math.floor(r.y) - 8)
  const clip = { x: x0, y: y0, width: Math.min(width, Math.ceil(r.x + r.width) + 8) - x0, height: Math.min(height, Math.ceil(r.y + r.height) + 8) - y0 }
  const shot = () => p.screenshot({ clip, animations: 'disabled' })
  let prev = await shot()
  for (let k = 0; k < 15; k++) {
    await p.waitForTimeout(150)
    const next = await shot()
    if (next.equals(prev)) return prev
    prev = next
  }
  return prev
}

;(async () => {
  const b = await chromium.launch({
    args: ['--disable-gpu', '--disable-partial-raster', '--disable-skia-runtime-opts', '--force-color-profile=srgb',
      '--disable-lcd-text', '--font-render-hinting=none', '--force-device-scale-factor=1'],
  })
  const measures = []
  async function page(width, height) {
    const p = await b.newPage({ viewport: { width, height } })
    const errs = []
    p.on('pageerror', (e) => errs.push(e.message))
    await p.clock.setFixedTime(new Date(TODAY))
    await serve(p, DIST)
    return { p, errs }
  }
  async function keep(p, errs, name, locator, width, height) {
    await p.mouse.move(0, 0)
    await p.evaluate(() => document.fonts.ready)
    const png = await settledShot(p, locator, width, height)
    fs.writeFileSync(path.join(OUT, `${name}.png`), png)
    const m = await p.evaluate(() => ({ scrollWidth: document.documentElement.scrollWidth }))
    measures.push({ name, width, ...m, errors: errs })
    if (errs.length) console.log('page errors', name, errs)
    await p.close()
  }

  if (MODE === 'pages') {
    for (const [wName, width] of Object.entries(WIDTHS)) {
      // The registration form's first step.
      {
        const { p, errs } = await page(width, 3000)
        await p.route('http://127.0.0.1:54321/**', answer(null, null))
        await p.goto(`${BASE}/register.html?event=${EVENT_CODE}`)
        const card = p.locator('.reg-card').first()
        await card.waitFor({ timeout: 20000 })
        await p.waitForTimeout(400)
        await keep(p, errs, `reg__${wName}__pl__step1`, card, width, 3000)
      }
      // The visitor's event card on the public calendar.
      {
        const { p, errs } = await page(width, 3000)
        await p.route('http://stub.local/**', answer(null, null))
        await p.goto(`${BASE}/index.ce.html`)
        await p.evaluate(() => {
          document.body.replaceChildren()
          const el = document.createElement('spws-calendar')
          for (const [k, v] of Object.entries({ chrome: 'site', 'supabase-prod-url': 'http://stub.local', 'supabase-prod-key': 'stub' })) el.setAttribute(k, v)
          document.body.appendChild(el)
        })
        const card = p.locator('spws-calendar .card').first()
        await card.waitFor({ timeout: 20000 })
        await p.waitForTimeout(600)
        await keep(p, errs, `card__${wName}__pl__visitor`, card, width, 3000)
      }
      // The report page, if this build has it.
      const html = fs.readFileSync(path.join(DIST, 'register.html'), 'utf8')
      if (!html.includes('spws-revenue-report')) continue
      for (const lang of ['pl', 'en']) {
        for (const [state, rep] of Object.entries(REPORTS)) {
          const { p, errs } = await page(width, 6000)
          await p.route('http://127.0.0.1:54321/**', answer(rep, null))
          await p.goto(`${BASE}/register.html?event=${EVENT_CODE}&view=revenue&k=${KEY}`)
          const card = p.locator('.rr-card').first()
          await card.waitFor({ timeout: 20000 })
          await p.locator(rep ? '.rr-head, .rr-message' : '.rr-message').first().waitFor({ timeout: 20000 })
          if (rep) await p.locator('.rr-head').waitFor({ timeout: 20000 })
          if (lang === 'en') await p.locator('.lang-btn[aria-label="English"]').click()
          await p.waitForTimeout(300)
          await keep(p, errs, `report__${wName}__${lang}__${state}`, p.locator('.rr-card').first(), width, 6000)
        }
      }
    }
  }

  if (MODE === 'form') {
    const STATES = {
      'a-registration-on-no-key': { event: 0, token: null },
      'b-registration-on-key': { event: 0, token: { uuid_token: KEY } },
      'c-registration-off': { event: 1, token: null },
    }
    for (const [wName, width] of Object.entries(WIDTHS)) {
      for (const [state, s] of Object.entries(STATES)) {
        const { p, errs } = await page(width, 3000)
        await p.route('http://stub.local/**', answer(null, s.token))
        await p.goto(`${BASE}/index.html`)
        await p.locator('[data-field="edit-btn"]').nth(s.event).click()
        const form = p.locator('[data-field="event-form"]').first()
        await form.waitFor({ timeout: 20000 })
        await p.waitForTimeout(500)
        const block = await p.evaluate(() => {
          const el = document.querySelector('[data-field="form-revenue-link"]')
          const url = document.querySelector('[data-field="form-revenue-url"]')
          return el ? { top: Math.round(el.getBoundingClientRect().top), height: Math.round(el.getBoundingClientRect().height), url: url ? url.value : null, create: !!document.querySelector('[data-field="form-revenue-create"]') } : null
        })
        measures.push({ name: `form__${wName}__pl__${state}__block`, block })
        await keep(p, errs, `form__${wName}__pl__${state}`, form, width, 3000)
      }
    }
  }

  if (MODE === 'card') {
    for (const [wName, width] of Object.entries(WIDTHS)) {
      for (const who of ['admin', 'visitor']) {
        const { p, errs } = await page(width, 2000)
        await p.goto(`${BASE}/index.html${who === 'admin' ? '?admin=1' : ''}`)
        const card = p.locator('.card').first()
        await card.waitFor({ timeout: 20000 })
        await p.waitForTimeout(800)
        await keep(p, errs, `cardh__${wName}__pl__${who}`, card, width, 2000)
      }
    }
  }

  fs.writeFileSync(path.join(OUT, 'measures.json'), JSON.stringify(measures, null, 1))
  console.log('captured', measures.filter((m) => !m.block).length, 'images into', OUT)
  const wide = measures.filter((m) => m.scrollWidth > m.width)
  console.log('horizontal scroll in', wide.length, wide.map((m) => m.name))
  for (const m of measures) if (m.block !== undefined) console.log(m.name, JSON.stringify(m.block))
  await b.close()
})()
