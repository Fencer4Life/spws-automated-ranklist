// FR-174 picture sheet: the FTL download page, before and after the seed-source line.
// The bundle is a local custom-element build served through Playwright route(); every data
// request is answered here with invented people, and every other host is blocked, so no
// database is read and no real name reaches a capture.
//
// usage: node ftl.cjs <frontend dir (for playwright)> <dist-ce dir> <out dir>
//   states: 1-ours       an event of ours (SPWS ranking): must be identical before and after
//           2-evf-read   an EVF event with the EVF ranking read on 6 Dec 2026: one new line
//           3-evf-none   an EVF event before any read: one new line
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const [DIST, OUT] = process.argv.slice(3)
if (!DIST || !fs.existsSync(path.join(DIST, 'index.ce.html'))) throw new Error('give a built dist-ce dir')
fs.mkdirSync(OUT, { recursive: true })
const BASE = 'http://site.local'
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.json': 'application/json', '.woff2': 'font/woff2', '.webp': 'image/webp' }
const SOFT = ['--disable-gpu', '--disable-partial-raster', '--disable-skia-runtime-opts', '--force-color-profile=srgb',
  '--disable-lcd-text', '--font-render-hinting=none', '--force-device-scale-factor=1']
const WIDTHS = { desktop: 1280, phone: 375 }
const TODAY = '2026-12-07T09:00:00+01:00'

const EVENTS = [
  { id_event: 74, txt_code: 'PPW2-2026-2027', txt_name: 'II Puchar Polski Weteranów', txt_location: 'Opole', dt_start: '2027-01-16', int_registrations: 4 },
  { id_event: 85, txt_code: 'PEW5efs-2026-2027', txt_name: 'EVF Circuit – Łomianki (POL)', txt_location: 'Łomianki', dt_start: '2026-12-12', int_registrations: 5 },
]
const row = (s, f, g, c, w, order, rank, pts, country, ranking, read) => ({
  txt_surname: s, txt_first_name: f, enum_gender: g, enum_age_category: c, enum_weapon: w,
  int_order: order, int_rank: rank, num_rank_points: pts, txt_country: country,
  txt_ranking: ranking, ts_ranking_read: read,
})
const people = (ranking, read) => [
  row('NOWAK', 'Anna', 'F', 'V2', 'EPEE', 1, 3, 100, 'POL', ranking, read),
  row('SVOBODOVÁ', 'Jana', 'F', 'V2', 'EPEE', 2, 17, 40, 'CZE', ranking, read),
  row('BIELSKA', 'Ewa', 'F', 'V2', 'EPEE', 3, null, null, 'POL', ranking, read),
  row('KOWALSKI', 'Jan', 'M', 'V3', 'SABRE', 1, 5, 80, 'POL', ranking, read),
  row('MÜLLER', 'Hans', 'M', 'V3', 'SABRE', 2, null, null, 'GER', ranking, read),
]
const STATES = {
  '1-ours': { event: 'PPW2-2026-2027', rows: people('SPWS', null) },
  '2-evf-read': { event: 'PEW5efs-2026-2027', rows: people('EVF', '2026-12-06T05:42:10Z') },
  '3-evf-none': { event: 'PEW5efs-2026-2027', rows: people('EVF', null) },
}

async function open(b, width, state) {
  const p = await b.newPage({ viewport: { width, height: 4200 } })
  p.errs = []
  p.on('pageerror', (e) => p.errs.push(e.message))
  await p.clock.setFixedTime(new Date(TODAY))
  await p.route(/^https?:\/\/(?!site\.local|stub\.local)/, (route) => route.abort())
  await p.route('http://stub.local/**', (route) => {
    const url = route.request().url()
    let body = []
    if (url.endsWith('/rpc/fn_ftl_export_events')) body = EVENTS
    else if (url.endsWith('/rpc/fn_ftl_export_entries')) body = state.rows
    return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
  })
  await p.route(`${BASE}/**`, (route) => {
    const file = path.join(DIST, decodeURIComponent(new URL(route.request().url()).pathname))
    if (!file.startsWith(DIST) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) return route.fulfill({ status: 404, body: 'not in build' })
    return route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || 'application/octet-stream', body: fs.readFileSync(file) })
  })
  await p.goto(`${BASE}/index.ce.html`)
  await p.evaluate((code) => {
    document.body.replaceChildren()
    const el = document.createElement('spws-ftl-export')
    for (const [k, v] of Object.entries({ 'supabase-prod-url': 'http://stub.local', 'supabase-prod-key': 'stub', token: '00000000-0000-4000-8000-000000000000', event: code })) el.setAttribute(k, v)
    document.body.appendChild(el)
  }, state.event)
  await p.locator('spws-ftl-export [data-field="ftl-download-all"]').waitFor({ timeout: 20000 })
  return p
}

;(async () => {
  const b = await chromium.launch({ args: SOFT })
  let n = 0
  for (const [stateName, state] of Object.entries(STATES)) {
    for (const [wName, width] of Object.entries(WIDTHS)) {
      for (const lang of ['pl', 'en']) {
        const p = await open(b, width, state)
        if (lang === 'en') {
          await p.locator('spws-ftl-export [aria-label="English"]').first().click()
        }
        await p.mouse.move(0, 0)
        await p.evaluate(() => document.fonts.ready)
        const r = await p.locator('spws-ftl-export').boundingBox()
        const clip = { x: Math.floor(r.x), y: Math.floor(r.y), width: Math.min(width, Math.ceil(r.width)), height: Math.min(4200, Math.ceil(r.height)) }
        const shot = () => p.screenshot({ clip, animations: 'disabled' })
        let prev = await shot()
        for (let k = 0; k < 15; k++) {
          await p.waitForTimeout(150)
          const next = await shot()
          if (next.equals(prev)) break
          prev = next
        }
        fs.writeFileSync(path.join(OUT, `${stateName}__${wName}__${lang}.png`), prev)
        const wide = await p.evaluate(() => document.documentElement.scrollWidth)
        if (wide > width) console.log('horizontal scroll', stateName, wName, lang, wide)
        if (p.errs.length) console.log('page errors', stateName, wName, lang, p.errs)
        await p.close()
        n++
      }
    }
  }
  console.log('captured', n, 'images into', OUT)
  await b.close()
})()
