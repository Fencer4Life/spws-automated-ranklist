// Captures of the administrator's new states on the entry list (FR-166, plan §06 step 2).
// usage: node capture-admin.cjs <frontend dir (absolute, for playwright)> <output dir> <built harness dir>
// The harness mounts the real RegistrationModal in list view with canRemove, inside a custom
// element (as in the live calendar). Every data request is answered from the invented roster in
// ../../entry-list-tiles-follow-filters-sheet/tools/fixture.cjs; a delete is answered by a stub.
// No database is read or written.
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const { TODAY, ROSTER } = require('../../entry-list-tiles-follow-filters-sheet/tools/fixture.cjs')

const OUT = process.argv[3]
const DIST = process.argv[4]
if (!DIST || !fs.existsSync(path.join(DIST, 'index.html'))) throw new Error('give a built harness dir')
fs.mkdirSync(OUT, { recursive: true })
const BASE = 'http://site.local'
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css' }

// A woman and a man from the roster, by their names as listed.
const WOMAN = 'LIS Anna'
const MAN = 'KOWAL Łukasz'

const STATES = {
  '1-list': { query: '', act: async () => {} },
  '2-confirm-woman': { query: '', act: (p) => tapRemove(p, WOMAN) },
  '3-confirm-man': { query: '', act: (p) => tapRemove(p, MAN) },
  '4-confirm-closed': { query: '?open=0', act: (p) => tapRemove(p, WOMAN) },
  '5-done': { query: '', act: async (p) => { await tapRemove(p, WOMAN); await confirm(p, '.el-remove-done') } },
  '6-failed': { query: '', fail: true, act: async (p) => { await tapRemove(p, WOMAN); await confirm(p, '.el-remove-failed') } },
}
const SIZES = { desktop: { width: 1280, height: 900 }, phone: { width: 375, height: 812 } }

async function tapRemove(p, name) {
  const row = p.locator('tr', { has: p.locator('td.el-name', { hasText: name }) }).first()
  await row.locator('button.el-remove').click()
  await p.locator('[role="alertdialog"]').waitFor()
}

async function confirm(p, expect) {
  await p.locator('button.el-remove-confirm').click()
  await p.locator(expect).waitFor()
}

;(async () => {
  const b = await chromium.launch({
    args: [
      '--disable-gpu', '--disable-partial-raster', '--disable-skia-runtime-opts',
      '--force-color-profile=srgb', '--disable-lcd-text', '--font-render-hinting=none',
      '--force-device-scale-factor=1',
    ],
  })
  const report = []
  for (const [wName, size] of Object.entries(SIZES)) {
    for (const lang of ['pl', 'en']) {
      for (const [state, def] of Object.entries(STATES)) {
        const p = await b.newPage({ viewport: size })
        const errs = []
        p.on('pageerror', (e) => errs.push(e.message))
        await p.clock.setFixedTime(new Date(TODAY))
        const deletes = []
        await p.route(`${BASE}/**`, (route) => {
          const file = path.join(DIST, decodeURIComponent(new URL(route.request().url()).pathname))
          if (!file.startsWith(DIST) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
            return route.fulfill({ status: 404, body: 'not in build' })
          }
          return route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || 'application/octet-stream', body: fs.readFileSync(file) })
        })
        await p.route('http://stub.local/**', (route) => {
          const req = route.request()
          const url = req.url()
          let body = []
          if (url.includes('/rest/v1/vw_registration_entry_list')) body = ROSTER
          else if (url.includes('/rest/v1/tbl_registration') && req.method() === 'DELETE') {
            deletes.push(url)
            const id = Number(new URL(url).searchParams.get('id_registration').replace('eq.', ''))
            body = def.fail ? [] : [{ id_registration: id }]
          }
          return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
        })
        await p.goto(`${BASE}/index.html${def.query}`)
        await p.locator('td.el-name').first().waitFor({ timeout: 20000 })
        if (lang === 'en') await p.locator('.lang-btn[aria-label="English"]').click()
        await def.act(p)
        await p.mouse.move(0, 0)
        await p.waitForTimeout(300)
        await p.evaluate(() => document.fonts.ready)
        const shot = () => p.screenshot({ animations: 'disabled' })
        let prev = await shot()
        for (let k = 0; k < 15; k++) {
          await p.waitForTimeout(150)
          const next = await shot()
          if (next.equals(prev)) break
          prev = next
        }
        const name = `admin__${wName}__${lang}__${state}.png`
        fs.writeFileSync(path.join(OUT, name), prev)
        const scrollWidth = await p.evaluate(() => document.documentElement.scrollWidth)
        report.push({ name, width: size.width, scrollWidth, deletes: deletes.length, errors: errs })
        await p.close()
      }
    }
  }
  fs.writeFileSync(path.join(OUT, 'admin-report.json'), JSON.stringify(report, null, 1))
  console.log('captured', report.length, 'images into', OUT)
  console.log('horizontal scroll in', report.filter((r) => r.scrollWidth > r.width).map((r) => r.name))
  console.log('page errors in', report.filter((r) => r.errors.length).map((r) => [r.name, r.errors]))
  console.log('deletes sent per state', Object.fromEntries(report.map((r) => [r.name, r.deletes])))
  await b.close()
})()
