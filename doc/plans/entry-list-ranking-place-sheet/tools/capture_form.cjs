// Before/after captures of the administrator's event form (FR-175, state 7).
// usage: node capture_form.cjs <frontend dir (for playwright)> <output dir> <built harness dir>
// The harness (build_form.sh) mounts EventManager with two invented events;
// requests to stub.local are answered here. Nothing reaches a database.
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))

const OUT = process.argv[3]
const DIST = process.argv[4]
if (!DIST || !fs.existsSync(path.join(DIST, 'index.html'))) throw new Error('give a built harness dir')
fs.mkdirSync(OUT, { recursive: true })
const BASE = 'http://site.local'
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css' }

// event: which card's form opens (0 = registration on, 1 = registration off);
// stored: what the database answers for bool_show_seed.
const STATES = {
  'a-registration-on-box-off': { event: 0, stored: false },
  'b-registration-on-box-on': { event: 0, stored: true },
  'c-registration-off': { event: 1, stored: false },
}
const WIDTHS = { desktop: 1280, phone: 375 }

;(async () => {
  const b = await chromium.launch({
    args: [
      '--disable-gpu', '--disable-partial-raster', '--disable-skia-runtime-opts',
      '--force-color-profile=srgb', '--disable-lcd-text', '--font-render-hinting=none',
      '--force-device-scale-factor=1',
    ],
  })
  const measures = []
  for (const [wName, width] of Object.entries(WIDTHS)) {
    for (const [state, s] of Object.entries(STATES)) {
      const p = await b.newPage({ viewport: { width, height: 3000 } })
      const errs = []
      p.on('pageerror', (e) => errs.push(e.message))
      await p.route(`${BASE}/**`, (route) => {
        const file = path.join(DIST, decodeURIComponent(new URL(route.request().url()).pathname))
        if (!file.startsWith(DIST) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
          return route.fulfill({ status: 404, body: 'not in build' })
        }
        return route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || 'application/octet-stream', body: fs.readFileSync(file) })
      })
      await p.route('http://stub.local/**', (route) => {
        const url = route.request().url()
        const body = url.includes('/rest/v1/tbl_event') ? { bool_show_seed: s.stored } : []
        return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
      })
      await p.goto(`${BASE}/index.html`)
      await p.locator('[data-field="edit-btn"]').nth(s.event).click()
      const form = p.locator('[data-field="event-form"]').first()
      await form.waitFor({ timeout: 20000 })
      await p.mouse.move(0, 0)
      await p.waitForTimeout(400)
      const r = await form.boundingBox()
      const x0 = Math.max(0, Math.floor(r.x) - 8)
      const y0 = Math.max(0, Math.floor(r.y) - 8)
      const clip = { x: x0, y: y0, width: Math.min(width, Math.ceil(r.x + r.width) + 8) - x0, height: Math.ceil(r.y + r.height) + 8 - y0 }
      const shot = () => p.screenshot({ clip, animations: 'disabled' })
      let prev = await shot()
      for (let k = 0; k < 15; k++) {
        await p.waitForTimeout(150)
        const next = await shot()
        if (next.equals(prev)) break
        prev = next
      }
      const name = `form__${wName}__pl__${state}.png`
      fs.writeFileSync(path.join(OUT, name), prev)
      const box = await p.evaluate(() => {
        const el = document.querySelector('[data-field="form-show-seed"]')
        return el ? { checked: el.checked, disabled: el.disabled } : null
      })
      measures.push({ name, width, box, errors: errs })
      if (errs.length) console.log('page errors', name, errs)
      await p.close()
    }
  }
  fs.writeFileSync(path.join(OUT, 'measures.json'), JSON.stringify(measures, null, 1))
  console.log('captured', measures.length, 'images into', OUT)
  for (const m of measures) console.log(m.name, JSON.stringify(m.box))
  await b.close()
})()
