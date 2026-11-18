// I7 proof on the WordPress page bodies (plan §05). LOCAL only.
// The two bodies in doc/wordpress/ are served as written, except: the bundle comes from a
// local build, the asset base is the local build, and the PROD pair is LOCAL's (127.0.0.1:54321,
// LOCAL's anon key from frontend/index.html). Nothing outside LOCAL and the build is reachable.
//
// usage: node proof.cjs <frontend dir> <repo dir> <dist-ce dir> <out dir> <mode> [reset-dev.sh]
//   mode visitor  — the Ranking and calendar pages as a visitor, page and open drawer,
//                   desktop and phone, PL and EN (for the before/after pixel comparison)
//   mode admin    — signed in on /ranking/?admin=1: drawer, „Znajdź zawody”, the calendar,
//                   an entry list, sign-out; with geometry and „Usuń” counts
//   mode walk     — a visitor registers a throwaway entry on the calendar page; the
//                   administrator removes it from /ranking/ via „Znajdź zawody”
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const [REPO, DIST, OUT, MODE, RESET_PATH] = process.argv.slice(3)
fs.mkdirSync(OUT, { recursive: true })
const BASE = 'http://localhost:5199'
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.json': 'application/json', '.woff2': 'font/woff2', '.webp': 'image/webp' }
const LOCAL_KEY = fs.readFileSync(path.join(REPO, 'frontend/index.html'), 'utf8').match(/supabase-cert-key="([^"]+)"/)[1]
const SURNAME = 'ZZWALKITRZY'
const FIRST = 'Ewa'

function body(name) {
  const src = fs.readFileSync(path.join(REPO, 'doc/wordpress', name), 'utf8')
    .replaceAll('https://fencer4life.github.io/spws-automated-ranklist/assets/main.ce.js', '/assets/main.ce.js')
    .replaceAll('asset-base="https://fencer4life.github.io/spws-automated-ranklist/"', 'asset-base="/"')
    .replaceAll('supabase-prod-url="https://ywgymtgcyturldazcpmw.supabase.co"', 'supabase-prod-url="http://127.0.0.1:54321"')
    .replaceAll('@@SUPABASE_PROD_KEY@@', LOCAL_KEY)
  if (src.includes('supabase.co') || src.includes('@@')) throw new Error(`${name}: a PROD value survived`)
  return `<!doctype html><html lang="pl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0;font-family:sans-serif;background:#fff}</style></head><body>${src}</body></html>`
}
const PAGES = { '/ranking/': body('ranking.html'), '/znajdz-zawody/': body('znajdz-zawody.html') }

async function newPage(b, width, height) {
  const p = await b.newPage({ viewport: { width, height } })
  p.errs = []
  p.on('pageerror', (e) => p.errs.push(e.message))
  await p.route(/^https?:\/\/(?!localhost:5199|127\.0\.0\.1:54321)/, (route) => route.abort())
  await p.route(`${BASE}/**`, (route) => {
    const u = new URL(route.request().url())
    if (PAGES[u.pathname]) return route.fulfill({ status: 200, contentType: 'text/html', body: PAGES[u.pathname] })
    const file = path.join(DIST, decodeURIComponent(u.pathname))
    if (!file.startsWith(DIST) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) return route.fulfill({ status: 404, body: 'not in build' })
    return route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || 'application/octet-stream', body: fs.readFileSync(file) })
  })
  return p
}

// The element's shadow root holds the app; Playwright locators pierce open shadow roots.
async function settled(p, page) {
  if (page === '/znajdz-zawody/') await p.locator('.ln.mid').first().waitFor({ timeout: 30000 })
  else await p.locator('.ranklist-app').first().waitFor({ timeout: 30000 })
  await p.waitForTimeout(1800)
}

async function toLomianki(p) {
  await p.locator('.ln.mid').first().waitFor({ timeout: 30000 })
  for (let i = 0; i < 10 && !(await p.locator('.ln.mid').first().innerText()).includes('Łomianki'); i++) {
    await p.locator('.stp.next').first().click()
    await p.waitForTimeout(600)
  }
  await p.locator('.ln.mid button.p', { hasText: 'Łomianki' }).first().evaluate((el) => el.click())
  await p.waitForTimeout(500)
}

// A visitor registers a throwaway entry through the real form on the calendar page body.
async function register(b, surname, first) {
  const v = await newPage(b, 1280, 1000)
  await v.goto(`${BASE}/znajdz-zawody/`)
  await toLomianki(v)
  await v.locator('.card .registration-link').first().evaluate((el) => el.click())
  const form = v.locator('.reg-card')
  await form.locator('input[name="surname"]').fill(surname)
  await form.locator('input[name="firstName"]').fill(first)
  await form.locator('select[name="gender"]').selectOption('F')
  await form.locator('input[name="birthYear"]').fill('1970')
  await form.locator('input[type="checkbox"][value="EPEE"]').check()
  await form.locator('button.reg-continue').first().click()
  await form.locator('button.reg-id-confirm').click({ timeout: 15000 })
  await form.locator('input.reg-rodo-checkbox').check()
  await form.locator('button.reg-rodo-accept').click()
  await form.locator('.reg-ok').waitFor({ timeout: 15000 })
  const ok = (await form.locator('.reg-ok').innerText()).trim()
  await v.close()
  return ok
}

// Signed in, on the entry list: removes one entry by surname through „Usuń”.
async function removeBySearch(a, needle, surname) {
  await a.locator('input[name="search"]').fill(needle)
  const row = a.locator('tr', { has: a.locator('td.el-name', { hasText: surname }) })
  await row.locator('button.el-remove').click()
  const text = (await a.locator('[role="alertdialog"]').innerText()).replace(/\s+/g, ' ').trim()
  return text
}

async function signIn(p) {
  const reset = fs.readFileSync(RESET_PATH, 'utf8')
  await p.locator('.admin-input').first().fill(reset.match(/^ADMIN_EMAIL="([^"]+)"/m)[1])
  await p.locator('.admin-input').nth(1).fill(reset.match(/^ADMIN_PASSWORD="([^"]+)"/m)[1])
  await p.locator('.admin-submit-btn').click()
  await p.locator('.admin-input').first().waitFor({ state: 'detached', timeout: 15000 })
}

async function geometry(p) {
  return p.evaluate(() => {
    const host = document.querySelector('spws-ranklist, spws-calendar')
    const root = host.shadowRoot
    const app = root.querySelector('.ranklist-app')
    const cal = root.querySelector('.calendar-view')
    return {
      element: host.tagName.toLowerCase(),
      path: location.pathname,
      appClasses: app.className.replace(/svelte-\S+/g, '').trim().split(/\s+/),
      appHeight: Math.round(app.getBoundingClientRect().height),
      calendarHeight: cal ? Math.round(cal.getBoundingClientRect().height) : null,
      viewport: innerHeight,
      sideScroll: document.documentElement.scrollWidth > innerWidth,
    }
  })
}

const SOFT = ['--disable-gpu', '--disable-partial-raster', '--disable-skia-runtime-opts', '--force-color-profile=srgb',
  '--disable-lcd-text', '--font-render-hinting=none', '--force-device-scale-factor=1',
  '--disable-features=LocalNetworkAccessChecks,PrivateNetworkAccessSendPreflights,BlockInsecurePrivateNetworkRequests']
const WIDTHS = { desktop: [1280, 900], phone: [375, 812] }

;(async () => {
  const b = await chromium.launch({ args: SOFT })
  const report = []

  if (MODE === 'visitor') {
    for (const [pg, tag] of [['/ranking/', 'ranking'], ['/znajdz-zawody/', 'calendar']]) {
      for (const [w, [width, height]] of Object.entries(WIDTHS)) {
        for (const lang of ['pl', 'en']) {
          const p = await newPage(b, width, height)
          await p.goto(`${BASE}${pg}`)
          await settled(p, pg)
          if (lang === 'en') { await p.locator('.lang-btn[aria-label="English"]').first().click(); await p.waitForTimeout(900) }
          await p.screenshot({ path: path.join(OUT, `${tag}__${w}__${lang}__page.png`) })
          // The drawer slides in on a `left` transition, and text drawn on that moving layer
          // rasterises differently run to run (seen in two identical runs of the same build).
          // Transitions are switched off inside the element, identically for both builds.
          await p.evaluate(() => {
            const root = document.querySelector('spws-ranklist, spws-calendar').shadowRoot
            const s = document.createElement('style')
            s.textContent = '*,*::before,*::after{transition:none!important;animation:none!important}'
            root.appendChild(s)
          })
          await p.locator('header.site-bar .hamburger-btn').click()
          // Off every element, so no hover state.
          await p.mouse.move(width - 2, height - 2)
          await p.waitForTimeout(1500)
          await p.screenshot({ path: path.join(OUT, `${tag}__${w}__${lang}__drawer.png`) })
          report.push({ tag, w, lang, ...(await geometry(p)), errors: p.errs })
          await p.close()
        }
      }
    }
  }

  if (MODE === 'admin') {
    // One entry on the list to show; the walk-through removes it through „Usuń”.
    if (process.argv[8] !== 'no-register') report.push({ registered: await register(b, 'ZZPOKAZ', 'Anna') })
    for (const [w, [width, height]] of Object.entries(WIDTHS)) {
      const p = await newPage(b, width, height)
      await p.goto(`${BASE}/ranking/?admin=1`)
      await signIn(p)
      await p.waitForTimeout(800)
      await p.locator('header.site-bar .hamburger-btn').click()
      await p.mouse.move(width - 2, height - 2)
      await p.waitForTimeout(900)
      await p.screenshot({ path: path.join(OUT, `admin__${w}__1-drawer.png`) })
      await p.locator('.sidebar .nav-item', { hasText: 'Znajdź zawody' }).click()
      await p.waitForTimeout(600)
      await settled(p, '/znajdz-zawody/')
      const g = await geometry(p)
      g.adminSection = await p.locator('.admin-section').count()
      await p.screenshot({ path: path.join(OUT, `admin__${w}__2-calendar.png`) })
      await toLomianki(p)
      await p.screenshot({ path: path.join(OUT, `admin__${w}__3-card.png`) })
      await p.locator('.card .entry-list-link').first().evaluate((el) => el.click())
      await p.locator('td.el-name').first().waitFor({ timeout: 15000 })
      await p.waitForTimeout(600)
      const rows = await p.locator('tbody tr').count()
      const removes = await p.locator('button.el-remove').count()
      await p.screenshot({ path: path.join(OUT, `admin__${w}__4-entry-list.png`) })
      const entry = { w, calendarInPlace: g, entryRows: rows, removeButtons: removes }
      if (g.path === '/ranking/') {
        // The list closes on its ×; Escape does not close it (I9, recorded in the sheet).
        await p.locator('button.el-close').first().click()
        await p.waitForTimeout(500)
        await p.locator('header.site-bar .hamburger-btn').click()
        await p.waitForTimeout(600)
        await p.locator('.admin-logout-btn').click()
        await p.mouse.move(width - 2, height - 2)
        await p.waitForTimeout(900)
        entry.afterSignOut = await geometry(p)
        entry.afterSignOut.adminSection = await p.locator('.admin-section').count()
        await p.screenshot({ path: path.join(OUT, `admin__${w}__5-signed-out.png`) })
      }
      entry.errors = p.errs
      report.push(entry)
      await p.close()
    }
  }

  if (MODE === 'walk') {
    report.push({ step: '1 visitor registered on the calendar page', ok: await register(b, SURNAME, FIRST) })

    const a = await newPage(b, 1280, 1000)
    await a.goto(`${BASE}/ranking/?admin=1`)
    await signIn(a)
    await a.locator('header.site-bar .hamburger-btn').click()
    await a.waitForTimeout(600)
    await a.locator('.sidebar .nav-item', { hasText: 'Znajdź zawody' }).click()
    await toLomianki(a)
    report.push({ step: '2 signed in on /ranking/, „Znajdź zawody” opened in place', path: new URL(a.url()).pathname })
    await a.locator('.card .entry-list-link').first().evaluate((el) => el.click())
    await a.locator('td.el-name').first().waitFor({ timeout: 15000 })
    report.push({ step: '3 confirmation', text: await removeBySearch(a, 'zzwalkit', SURNAME) })
    await a.screenshot({ path: path.join(OUT, 'walk-1-confirm.png') })
    await a.locator('button.el-remove-confirm').click()
    await a.locator('.el-remove-done').waitFor({ timeout: 15000 })
    report.push({ step: '4 done', text: (await a.locator('.el-remove-done').innerText()).trim(),
      rowsWithName: await a.locator('td.el-name', { hasText: SURNAME }).count() })
    await a.screenshot({ path: path.join(OUT, 'walk-2-done.png') })
    // The entry the captures showed goes the same way.
    await a.locator('input[name="search"]').fill('')
    if (await a.locator('td.el-name', { hasText: 'ZZPOKAZ' }).count()) {
      await removeBySearch(a, 'zzpokaz', 'ZZPOKAZ')
      await a.locator('button.el-remove-confirm').click()
      await a.locator('.el-remove-done').waitFor({ timeout: 15000 })
      report.push({ step: '5 capture entry removed', text: (await a.locator('.el-remove-done').innerText()).trim() })
    }
    report.push({ errors: a.errs })
    await a.close()
  }

  fs.writeFileSync(path.join(OUT, `${MODE}-report.json`), JSON.stringify(report, null, 2))
  console.log(JSON.stringify(report, null, 1).slice(0, 4000))
  await b.close()
})()
