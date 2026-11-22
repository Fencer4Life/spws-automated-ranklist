// Before/after captures of the entry list with the ranking place (FR-175).
// usage: node capture.cjs <frontend dir (for playwright)> <output dir> <built dist-ce dir>
// Pages and bundle are answered from a production CE build at
// http://site.local; every data request is answered from the invented roster
// of the 17 Nov sheet (../../entry-list-tiles-follow-filters-sheet/tools/
// fixture.cjs) and the ranks below. No database is read or written.
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const { TODAY, EVENT_CODE, ROSTER, calendarRow } = require('../../entry-list-tiles-follow-filters-sheet/tools/fixture.cjs')

const OUT = process.argv[3]
const DIST = process.argv[4]
if (!DIST || !fs.existsSync(path.join(DIST, 'register.html'))) throw new Error('give a built dist-ce dir')
fs.mkdirSync(OUT, { recursive: true })
const BASE = 'http://site.local'
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.json': 'application/json', '.woff2': 'font/woff2' }
const READ = '2026-11-23T05:41:00Z'

// Ranks for every épée start: most hold a place, every fourth none, and the
// 2nd and 3rd share 2nd place. Place follows list position, as does the seed
// order. V0 holds none (EVF ranks 40 and over).
function ranks(ranking) {
  const out = []
  const byList = new Map()
  for (const r of ROSTER) {
    if (!r.arr_weapons.includes('EPEE') || r.enum_age_category === 'V0') continue
    const key = `${r.enum_gender}/${r.enum_age_category}`
    const n = (byList.get(key) || 0) + 1
    byList.set(key, n)
    const ranked = n % 4 !== 0
    const place = !ranked ? null : n === 3 ? 2 : n
    out.push({
      id_registration: r.id_registration, enum_weapon: 'EPEE', enum_age_category: r.enum_age_category,
      int_rank: place, int_seed_order: ranked ? n : null, txt_ranking: ranking,
      ts_ranking_read: ranking === 'EVF' ? READ : null,
    })
  }
  return out
}
const EVF = ranks('EVF')
const OURS = ranks('SPWS')

const STATES = {
  '1-no-filter-box-on': { ranks: EVF },
  '2-three-filters-box-off': { ranks: [], fw: 'EPEE', fc: 'V2', fg: 'M' },
  '3-two-filters-box-on': { ranks: EVF, fw: 'EPEE', fc: 'V2' },
  '4-three-filters-evf': { ranks: EVF, fw: 'EPEE', fc: 'V2', fg: 'M' },
  '5-three-filters-ours': { ranks: OURS, fw: 'EPEE', fc: 'V2', fg: 'M' },
  '6-v0-evf-box-on': { ranks: EVF, fw: 'EPEE', fc: 'V0', fg: 'M' },
}
const WIDTHS = { desktop: 1280, phone: 375 }

async function serveBuild(p) {
  await p.route(`${BASE}/**`, (route) => {
    const file = path.join(DIST, decodeURIComponent(new URL(route.request().url()).pathname))
    if (!file.startsWith(DIST) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      return route.fulfill({ status: 404, body: 'not in build: ' + file })
    }
    return route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || 'application/octet-stream', body: fs.readFileSync(file) })
  })
}

function answer(row, rankRows) {
  return (route) => {
    const req = route.request()
    const url = req.url()
    let body
    if (url.includes('/rest/v1/vw_calendar')) {
      const single = (req.headers()['accept'] || '').includes('vnd.pgrst.object')
      body = single ? row : [row]
    } else if (url.includes('/rest/v1/vw_registration_entry_list')) body = ROSTER
    else if (url.includes('/rpc/fn_registration_entry_ranks')) body = rankRows
    else if (url.includes('/rpc/')) body = null
    else body = []
    return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
  }
}

async function openStandalone(p, rankRows) {
  await p.route('http://127.0.0.1:54321/**', answer(calendarRow(), rankRows))
  await p.goto(`${BASE}/register.html?event=${EVENT_CODE}&view=list`)
}

async function openModal(p, rankRows) {
  await p.route('http://stub.local/**', answer(calendarRow(), rankRows))
  await p.goto(`${BASE}/index.ce.html`)
  await p.evaluate(() => {
    document.body.replaceChildren()
    const el = document.createElement('spws-calendar')
    for (const [k, v] of Object.entries({ chrome: 'site', 'supabase-prod-url': 'http://stub.local', 'supabase-prod-key': 'stub' })) el.setAttribute(k, v)
    document.body.appendChild(el)
  })
  await p.locator('spws-calendar .entry-list-link').first().click()
}

const SURFACES = { standalone: openStandalone, modal: openModal }

async function setState(p, s) {
  const card = p.locator('.el-card').first()
  await card.locator('select[name="weaponFilter"]').selectOption(s.fw || '')
  await card.locator('select[name="categoryFilter"]').selectOption(s.fc || '')
  await card.locator('select[name="genderFilter"]').selectOption(s.fg || '')
  await card.locator('.el-title').click()
  await p.mouse.move(0, 0)
  await p.waitForTimeout(350)
}

;(async () => {
  // Software drawing with fixed settings, as in the 17 Nov sheet.
  const b = await chromium.launch({
    args: [
      '--disable-gpu', '--disable-partial-raster', '--disable-skia-runtime-opts',
      '--force-color-profile=srgb', '--disable-lcd-text', '--font-render-hinting=none',
      '--force-device-scale-factor=1',
    ],
  })
  const measures = []
  for (const [surface, open] of Object.entries(SURFACES)) {
    for (const [wName, width] of Object.entries(WIDTHS)) {
      for (const lang of ['pl', 'en']) {
        for (const [state, s] of Object.entries(STATES)) {
          const p = await b.newPage({ viewport: { width, height: 4200 } })
          const errs = []
          p.on('pageerror', (e) => errs.push(e.message))
          await p.clock.setFixedTime(new Date(TODAY))
          await serveBuild(p)
          await open(p, s.ranks)
          await p.locator('.el-card td.el-name').first().waitFor({ timeout: 20000 })
          if (lang === 'en') await p.locator('.el-card .lang-btn[aria-label="English"]').click()
          await setState(p, s)
          await p.evaluate(() => document.fonts.ready)
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
          const name = `${surface}__${wName}__${lang}__${state}.png`
          fs.writeFileSync(path.join(OUT, name), prev)
          const m = await p.evaluate(() => ({ scrollWidth: document.documentElement.scrollWidth }))
          measures.push({ name, width, ...m, errors: errs })
          if (errs.length) console.log('page errors', name, errs)
          await p.close()
        }
      }
    }
  }
  fs.writeFileSync(path.join(OUT, 'measures.json'), JSON.stringify(measures, null, 1))
  console.log('captured', measures.length, 'images into', OUT)
  const wide = measures.filter((m) => m.scrollWidth > m.width)
  console.log('horizontal scroll in', wide.length, 'states', wide.map((m) => m.name))
  await b.close()
})()
