// FR-169 release 3 proof on the WordPress calendar page body (doc/wordpress/znajdz-zawody.html).
// LOCAL only: the bundle comes from a local build and the PROD pair is LOCAL's. Nothing outside
// LOCAL and the build is reachable. Form captures stop before „Akceptuję”; mode walk writes one
// entry, which the caller removes (seed-list.sql step=remove).
//
// usage: node proof.cjs <frontend dir> <repo dir> <dist-ce dir> <out dir> <mode> <build>
//   mode form   — the registration form on Łomianki, desktop and phone, PL and EN:
//                 1 empty, 2 typed, 3 a newcomer's name check, 4 the consent screen; on the
//                 after build also 5 the country list after „wiel”, 6 GBR picked
//   mode list   — „Lista zgłoszonych” as a visitor, desktop and phone, PL and EN; the caller
//                 puts the rows on LOCAL first (seed-list.sql step=plain|country)
//   mode filter — after build, rows with countries: „Szpada” and „GER” chosen together
//   mode walk   — a newcomer picks GBR, registers, and finds the flag on the list
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const [REPO, DIST, OUT, MODE, BUILD] = process.argv.slice(3)
fs.mkdirSync(OUT, { recursive: true })
const BASE = 'http://localhost:5199'
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.json': 'application/json', '.woff2': 'font/woff2', '.webp': 'image/webp' }
const LOCAL_KEY = fs.readFileSync(path.join(REPO, 'frontend/index.html'), 'utf8').match(/supabase-cert-key="([^"]+)"/)[1]

function body(name) {
  const src = fs.readFileSync(path.join(REPO, 'doc/wordpress', name), 'utf8')
    .replaceAll('https://fencer4life.github.io/spws-automated-ranklist/assets/main.ce.js', '/assets/main.ce.js')
    .replaceAll('asset-base="https://fencer4life.github.io/spws-automated-ranklist/"', 'asset-base="/"')
    .replaceAll('supabase-prod-url="https://ywgymtgcyturldazcpmw.supabase.co"', 'supabase-prod-url="http://127.0.0.1:54321"')
    .replaceAll('@@SUPABASE_PROD_KEY@@', LOCAL_KEY)
  if (src.includes('supabase.co') || src.includes('@@')) throw new Error(`${name}: a PROD value survived`)
  return `<!doctype html><html lang="pl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0;font-family:sans-serif;background:#fff}</style></head><body>${src}</body></html>`
}
const PAGES = { '/znajdz-zawody/': body('znajdz-zawody.html') }

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

async function toLomianki(p) {
  await p.locator('.ln.mid').first().waitFor({ timeout: 30000 })
  for (let i = 0; i < 10 && !(await p.locator('.ln.mid').first().innerText()).includes('Łomianki'); i++) {
    await p.locator('.stp.next').first().click()
    await p.waitForTimeout(600)
  }
  await p.locator('.ln.mid button.p', { hasText: 'Łomianki' }).first().evaluate((el) => el.click())
  await p.waitForTimeout(500)
}

async function still(p) {
  await p.evaluate(() => {
    const root = document.querySelector('spws-calendar').shadowRoot
    const s = document.createElement('style')
    s.textContent = '*,*::before,*::after{transition:none!important;animation:none!important;caret-color:transparent!important}'
    root.appendChild(s)
  })
}

async function open(b, width, height, lang, what) {
  const p = await newPage(b, width, height)
  await p.goto(`${BASE}/znajdz-zawody/`)
  await toLomianki(p)
  await still(p)
  await p.locator(`.card .${what}`).first().evaluate((el) => el.click())
  await p.waitForTimeout(900)
  if (lang === 'en') { await p.locator('.modal-overlay .lang-btn[aria-label="English"]').first().click(); await p.waitForTimeout(700) }
  return p
}

async function shot(p, name, width, height) {
  await p.mouse.move(width - 2, height - 2)
  await p.waitForTimeout(500)
  await p.screenshot({ path: path.join(OUT, name) })
}

async function identity(form, surname, first, year) {
  await form.locator('input[name="surname"]').fill(surname)
  await form.locator('input[name="firstName"]').fill(first)
  await form.locator('select[name="gender"]').selectOption('F')
  await form.locator('input[name="birthYear"]').fill(year)
  await form.locator('input[type="checkbox"][value="EPEE"]').check()
  await form.locator('button.reg-continue').first().click()
  await form.locator('.reg-idcheck').first().waitFor({ timeout: 15000 })
  await form.page().waitForTimeout(500)
}

const SOFT = ['--disable-gpu', '--disable-partial-raster', '--disable-skia-runtime-opts', '--force-color-profile=srgb',
  '--disable-lcd-text', '--font-render-hinting=none', '--force-device-scale-factor=1',
  '--disable-features=LocalNetworkAccessChecks,PrivateNetworkAccessSendPreflights,BlockInsecurePrivateNetworkRequests']
const WIDTHS = { desktop: [1280, 1000], phone: [375, 812] }

;(async () => {
  const b = await chromium.launch({ args: SOFT })
  const report = []
  if (MODE === 'walk') {
    const p = await open(b, 1280, 1000, 'pl', 'registration-link')
    const form = p.locator('.reg-card')
    await form.locator('input[name="surname"]').fill('zzbrown')
    await form.locator('input[name="firstName"]').fill('Emily')
    await form.locator('select[name="gender"]').selectOption('F')
    await form.locator('input[name="birthYear"]').fill('1975')
    await form.locator('input[name="country"]').fill('wiel')
    await p.screenshot({ path: path.join(OUT, 'walk-1-country-list.png') })
    await form.locator('.cp-opt', { hasText: 'GBR' }).click()
    await form.locator('input[type="checkbox"][value="EPEE"]').check()
    report.push({ step: '1 „wiel” typed, GBR picked', box: await form.locator('input[name="country"]').inputValue(),
      code: (await form.locator('.cp-code').innerText()).trim() })
    await form.locator('button.reg-continue').first().click()
    await form.locator('button.reg-id-confirm').waitFor({ timeout: 15000 })
    await form.locator('button.reg-id-confirm').click()
    await form.locator('input.reg-rodo-checkbox').waitFor({ timeout: 15000 })
    await p.screenshot({ path: path.join(OUT, 'walk-2-consent.png') })
    await form.locator('input.reg-rodo-checkbox').check()
    await form.locator('button.reg-rodo-accept').click()
    await form.locator('.reg-ok').waitFor({ timeout: 15000 })
    report.push({ step: '2 submitted', confirmation: (await form.locator('.reg-ok').innerText()).trim() })
    await p.close()
    const q = await open(b, 1280, 1000, 'pl', 'entry-list-link')
    await q.locator('td.el-name').first().waitFor({ timeout: 15000 })
    await q.waitForTimeout(600)
    const row = q.locator('tbody tr', { hasText: 'ZZBROWN' })
    report.push({ step: '3 on the list', flag: await row.locator('.flag').getAttribute('aria-label'),
      filterChoices: await q.locator('select[name="countryFilter"] option').allInnerTexts() })
    await q.screenshot({ path: path.join(OUT, 'walk-3-list.png') })
    report.push({ errors: p.errs.concat(q.errs) })
    await q.close()
    fs.writeFileSync(path.join(OUT, 'walk-report.json'), JSON.stringify(report, null, 2))
    console.log(JSON.stringify(report, null, 1))
    await b.close()
    return
  }
  for (const [w, [width, height]] of Object.entries(WIDTHS)) {
    for (const lang of ['pl', 'en']) {
      if (MODE === 'form') {
        const tag = `form__${w}__${lang}`
        let p = await open(b, width, height, lang, 'registration-link')
        let form = p.locator('.reg-card')
        await shot(p, `${tag}__1-empty.png`, width, height)
        await form.locator('input[name="surname"]').fill('kowalski')
        await form.locator('input[name="firstName"]').fill('Jan')
        await shot(p, `${tag}__2-typed.png`, width, height)
        await identity(form, 'zznowicjusz', 'Jan', '1970')
        await shot(p, `${tag}__3-name-check.png`, width, height)
        await form.locator('button.reg-id-confirm').click()
        await form.locator('input.reg-rodo-checkbox').waitFor({ timeout: 15000 })
        await p.waitForTimeout(400)
        await shot(p, `${tag}__4-consent.png`, width, height)
        const entry = { tag, consent: (await form.innerText()).includes(lang === 'pl' ? 'Kraj — lista' : 'Country — the entry') }
        let errs = p.errs
        await p.close()
        if (BUILD === 'after') {
          p = await open(b, width, height, lang, 'registration-link')
          form = p.locator('.reg-card')
          entry.default = { box: await form.locator('input[name="country"]').inputValue(), code: (await form.locator('.cp-code').innerText()).trim() }
          await form.locator('input[name="country"]').fill('wiel')
          entry.found = await form.locator('.cp-opt').allInnerTexts()
          await shot(p, `${tag}__5-country-list.png`, width, height)
          await form.locator('.cp-opt', { hasText: 'GBR' }).click()
          entry.picked = { box: await form.locator('input[name="country"]').inputValue(), code: (await form.locator('.cp-code').innerText()).trim() }
          await shot(p, `${tag}__6-country-picked.png`, width, height)
          errs = errs.concat(p.errs)
          await p.close()
        }
        entry.errors = errs
        report.push(entry)
      }
      if (MODE === 'list' || MODE === 'filter') {
        const tag = `${MODE}__${w}__${lang}`
        const p = await open(b, width, height, lang, 'entry-list-link')
        await p.locator('td.el-name').first().waitFor({ timeout: 15000 })
        await p.waitForTimeout(600)
        if (MODE === 'filter') {
          await p.locator('select[name="weaponFilter"]').selectOption('EPEE')
          await p.locator('select[name="countryFilter"]').selectOption('GER')
          await p.waitForTimeout(400)
        }
        report.push({ tag, names: await p.locator('td.el-name').allInnerTexts(),
          flags: await p.locator('td.el-flag .flag').evaluateAll((els) => els.map((e) => e.getAttribute('aria-label'))),
          codes: await p.locator('td.el-flag .el-flagcode').allInnerTexts(),
          filter: await p.locator('select[name="countryFilter"] option').allInnerTexts(),
          errors: p.errs })
        await shot(p, `${tag}.png`, width, height)
        await p.close()
      }
    }
  }
  fs.writeFileSync(path.join(OUT, `${MODE}-report.json`), JSON.stringify(report, null, 2))
  console.log(JSON.stringify(report, null, 1).slice(0, 2500))
  await b.close()
})()
