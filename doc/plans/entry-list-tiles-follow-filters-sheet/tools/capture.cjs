// Before/after captures of the entry list (plan §10).
// usage: node capture.cjs <frontend dir (for playwright)> <output dir> <built dist-ce dir>
// The pages and the bundle are answered from a production CE build
// (vite build --config vite.config.ce.ts) at http://site.local, so no server
// runs. Every request for data is answered from fixture.cjs; no database is
// read or written.
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const { TODAY, EVENT_CODE, ROSTER, calendarRow } = require('./fixture.cjs')

const OUT = process.argv[3]
const DIST = process.argv[4]
if (!DIST || !fs.existsSync(path.join(DIST, 'register.html'))) throw new Error('give a built dist-ce dir')
fs.mkdirSync(OUT, { recursive: true })
const BASE = 'http://site.local'
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.json': 'application/json', '.woff2': 'font/woff2' }

async function serveBuild(p) {
  await p.route(`${BASE}/**`, (route) => {
    const file = path.join(DIST, decodeURIComponent(new URL(route.request().url()).pathname))
    if (!file.startsWith(DIST) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      return route.fulfill({ status: 404, body: 'not in build: ' + file })
    }
    return route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || 'application/octet-stream', body: fs.readFileSync(file) })
  })
}

const STATES = {
  '1-unfiltered': {},
  '2-category-v2': { fc: 'V2' },
  '3-search-kow': { q: 'kow' },
  '4-search-and-filters': { q: 'k', fc: 'V2', fg: 'M' },
  '5-weapon-epee': { fw: 'EPEE' },
  '6-no-match': { q: 'qqq' },
}
const WIDTHS = { desktop: 1280, phone: 375 }

function answer(row) {
  return (route) => {
    const req = route.request()
    const url = req.url()
    let body
    if (url.includes('/rest/v1/vw_calendar')) {
      const single = (req.headers()['accept'] || '').includes('vnd.pgrst.object')
      body = single ? row : [row]
    } else if (url.includes('/rest/v1/vw_registration_entry_list')) body = ROSTER
    else if (url.includes('/rpc/')) body = null
    else body = []
    return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
  }
}

async function openStandalone(p) {
  await p.route('http://127.0.0.1:54321/**', answer(calendarRow()))
  await p.goto(`${BASE}/register.html?event=${EVENT_CODE}&view=list`)
}

async function openFromForm(p) {
  // Deadline passed, event not over: the form shows its "closed" step, whose
  // button opens the list with a Back button.
  await p.route('http://127.0.0.1:54321/**', answer(calendarRow({ dt_registration_deadline: '2026-11-10' })))
  await p.goto(`${BASE}/register.html?event=${EVENT_CODE}`)
  await p.locator('spws-registration button.reg-btn').filter({ hasText: /Lista zgłoszonych|Entry list/ }).click()
}

async function openModal(p) {
  await p.route('http://stub.local/**', answer(calendarRow()))
  await p.goto(`${BASE}/index.ce.html`)
  await p.evaluate(() => {
    document.body.replaceChildren()
    const el = document.createElement('spws-calendar')
    for (const [k, v] of Object.entries({ chrome: 'site', 'supabase-prod-url': 'http://stub.local', 'supabase-prod-key': 'stub' })) el.setAttribute(k, v)
    document.body.appendChild(el)
  })
  await p.locator('spws-calendar .entry-list-link').first().click()
}

const SURFACES = {
  standalone: { open: openStandalone, states: Object.keys(STATES) },
  modal: { open: openModal, states: Object.keys(STATES) },
  'form-back': { open: openFromForm, states: ['1-unfiltered', '4-search-and-filters'] },
}

async function setState(p, s) {
  const card = p.locator('.el-card').first()
  await card.locator('input[name="search"]').fill(s.q || '')
  await card.locator('select[name="weaponFilter"]').selectOption(s.fw || '')
  await card.locator('select[name="categoryFilter"]').selectOption(s.fc || '')
  await card.locator('select[name="genderFilter"]').selectOption(s.fg || '')
  await card.locator('.el-title').click()
  await p.mouse.move(0, 0)
  await p.waitForTimeout(350)
}

;(async () => {
  // Software drawing with fixed settings: GPU raster gives run-to-run
  // differences on anti-aliased curves (rounded borders, shadows).
  const b = await chromium.launch({
    args: [
      '--disable-gpu', '--disable-partial-raster', '--disable-skia-runtime-opts',
      '--force-color-profile=srgb', '--disable-lcd-text', '--font-render-hinting=none',
      '--force-device-scale-factor=1',
    ],
  })
  const measures = []
  for (const [surface, def] of Object.entries(SURFACES)) {
    for (const [wName, width] of Object.entries(WIDTHS)) {
      for (const lang of ['pl', 'en']) {
        const p = await b.newPage({ viewport: { width, height: 4200 } })
        const errs = []
        p.on('pageerror', (e) => errs.push(e.message))
        await p.clock.setFixedTime(new Date(TODAY))
        const missing = []
        p.on('response', (r) => { if (r.status() === 404) missing.push(r.url()) })
        await serveBuild(p)
        await def.open(p)
        await p.locator('.el-card td.el-name').first().waitFor({ timeout: 20000 })
        if (lang === 'en') await p.locator('.el-card .lang-btn[aria-label="English"]').click()
        for (const state of def.states) {
          await setState(p, STATES[state])
          const name = `${surface}__${wName}__${lang}__${state}.png`
          await p.evaluate(() => document.fonts.ready)
          // Stable shot: repeat until two consecutive screenshots are equal, so
          // an image still decoding or a transition still running is never
          // what gets compared.
          // Crop on whole pixels, 8px outside the card, so the card's own
          // anti-aliased edge never sits on the crop line.
          const r = await p.locator('.el-card').first().boundingBox()
          const x0 = Math.max(0, Math.floor(r.x) - 8)
          const y0 = Math.max(0, Math.floor(r.y) - 8)
          const clip = {
            x: x0, y: y0,
            width: Math.min(width, Math.ceil(r.x + r.width) + 8) - x0,
            height: Math.min(4200, Math.ceil(r.y + r.height) + 8) - y0,
          }
          const shot = () => p.screenshot({ clip, animations: 'disabled' })
          let prev = await shot()
          for (let k = 0; k < 15; k++) {
            await p.waitForTimeout(150)
            const next = await shot()
            if (next.equals(prev)) break
            prev = next
          }
          fs.writeFileSync(path.join(OUT, name), prev)
          const m = await p.evaluate(() => {
            const pick = (sel) => {
              const all = [document]
              const found = []
              while (all.length) {
                const root = all.pop()
                root.querySelectorAll('*').forEach((el) => {
                  if (el.shadowRoot) all.push(el.shadowRoot)
                  if (el.matches(sel)) found.push(el)
                })
              }
              return found
            }
            const h = (sel) => pick(sel).map((e) => Math.round(e.getBoundingClientRect().height))
            return {
              scrollWidth: document.documentElement.scrollWidth,
              searchClear: h('button.el-search-clear'),
              clearAll: h('button.el-clear-all'),
            }
          })
          measures.push({ name, width, ...m })
        }
        if (errs.length) console.log('page errors', surface, wName, lang, errs)
        if (missing.length) console.log('404s', surface, wName, lang, missing)
        await p.close()
      }
    }
  }
  fs.writeFileSync(path.join(OUT, 'measures.json'), JSON.stringify(measures, null, 1))
  console.log('captured', measures.length, 'images into', OUT)
  const wide = measures.filter((m) => m.scrollWidth > m.width)
  console.log('horizontal scroll in', wide.length, 'states', wide.map((m) => m.name))
  await b.close()
})()
