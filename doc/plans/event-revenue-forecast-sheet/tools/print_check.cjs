// FR-176 — prints the report PAGE from Chrome to PDF, for the same invented
// data the .ods samples hold (make_sample.ts → raw.json), so that the page's
// print can be set beside LibreOffice's print of the file (print_check.py).
// usage: node print_check.cjs <frontend dir (for playwright)> <ods out dir> <built dist-ce dir>
// Writes <ods out dir>/chrome/<case>.pdf, and <case>-browser-footer.pdf printed
// with Chrome's own header and footer switched on (as the print dialog's
// „Headers and footers” box does). No database is read.
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const { calendarRow } = require('../../entry-list-tiles-follow-filters-sheet/tools/fixture.cjs')

const OUT = process.argv[3]
const DIST = process.argv[4]
const raws = JSON.parse(fs.readFileSync(path.join(OUT, 'raw.json'), 'utf8'))
fs.mkdirSync(path.join(OUT, 'chrome'), { recursive: true })
const BASE = 'http://site.local'
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png' }
const KEY = '11111111-2222-4333-8444-555555555555' // invented
const ROW = calendarRow({ txt_code: 'PEW5', txt_name: 'PEW5 Łomianki', dt_start: '2026-12-12', dt_end: '2026-12-13', txt_location: 'Łomianki' })

;(async () => {
  const b = await chromium.launch()
  console.log('chromium', b.version())
  for (const name of ['full-pl', 'full-en', 'big-pl', 'big-en', 'empty-pl']) {
    const { raw, lang } = raws[name]
    for (const browserFooter of [false, true]) {
      if (browserFooter && name !== 'full-pl') continue
      const p = await b.newPage({ viewport: { width: 1280, height: 900 } })
      await p.route(`${BASE}/**`, (route) => {
        const file = path.join(DIST, decodeURIComponent(new URL(route.request().url()).pathname))
        if (!file.startsWith(DIST) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) return route.fulfill({ status: 404, body: '' })
        return route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || 'application/octet-stream', body: fs.readFileSync(file) })
      })
      await p.route('http://127.0.0.1:54321/**', (route) => {
        const req = route.request()
        const url = req.url()
        let body = []
        if (url.includes('/rest/v1/vw_calendar')) body = (req.headers()['accept'] || '').includes('vnd.pgrst.object') ? ROW : [ROW]
        else if (url.includes('/rpc/fn_event_revenue_report')) body = raw
        return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
      })
      await p.goto(`${BASE}/register.html?event=PEW5&view=revenue&k=${KEY}`)
      await p.locator('.rr-head').waitFor({ timeout: 20000 })
      if (lang === 'en') await p.locator('.lang-btn[aria-label="English"]').click()
      await p.evaluate(() => document.fonts.ready)
      await p.waitForTimeout(300)
      const file = path.join(OUT, 'chrome', `${name}${browserFooter ? '-browser-footer' : ''}.pdf`)
      await p.pdf({
        path: file, preferCSSPageSize: true, printBackground: true,
        displayHeaderFooter: browserFooter,
        ...(browserFooter ? {} : {}),
      })
      console.log('printed', path.basename(file))
      await p.close()
    }
  }
  await b.close()
})()
