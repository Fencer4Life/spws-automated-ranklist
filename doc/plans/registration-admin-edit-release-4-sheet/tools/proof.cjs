// FR-170 release 4 proof on the WordPress page bodies (doc/wordpress/). LOCAL only: the bundle
// comes from a local build and the PROD pair is LOCAL's. Nothing outside LOCAL and the build is
// reachable. The administrator signs in with LOCAL's own test account (scripts/reset-dev.sh),
// as the I7 proof did; nothing is printed of it. The caller seeds and removes the entries
// (seed-admin.sql step=admin | step=remove).
//
// The edit dialog is `.ee`: the calendar modal is a role="dialog" too.
// usage: node proof.cjs <frontend dir> <repo dir> <dist-ce dir> <out dir> <mode> <reset-dev.sh>
//   mode visitor — „Lista zgłoszonych” on the calendar page as a visitor, desktop and phone,
//                  PL and EN: must be identical before and after
//   mode admin   — signed in on /ranking/?admin=1 → „Znajdź zawody” → Łomianki → the entry
//                  list, desktop and phone, PL and EN
//   mode dialog  — after build: the edit dialog for a newcomer, for the linked entry (name
//                  locked, roster year ≠) and a refused save (a duplicate), desktop and phone
//   mode walk    — the administrator edits a newcomer and the linked entry and saves
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const [REPO, DIST, OUT, MODE, RESET_PATH] = process.argv.slice(3)
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

async function still(p) {
  await p.evaluate(() => {
    const root = document.querySelector('spws-ranklist, spws-calendar').shadowRoot
    const s = document.createElement('style')
    s.textContent = '*,*::before,*::after{transition:none!important;animation:none!important;caret-color:transparent!important}'
    root.appendChild(s)
  })
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

async function signIn(p) {
  const reset = fs.readFileSync(RESET_PATH, 'utf8')
  await p.locator('.admin-input').first().fill(reset.match(/^ADMIN_EMAIL="([^"]+)"/m)[1])
  await p.locator('.admin-input').nth(1).fill(reset.match(/^ADMIN_PASSWORD="([^"]+)"/m)[1])
  await p.locator('.admin-submit-btn').click()
  await p.locator('.admin-input').first().waitFor({ state: 'detached', timeout: 15000 })
}

async function openList(p) {
  await p.locator('.card .entry-list-link').first().evaluate((el) => el.click())
  await p.locator('td.el-name').first().waitFor({ timeout: 15000 })
  await p.waitForTimeout(900)
}

// A visitor on the calendar page.
async function visitorList(b, width, height, lang) {
  const p = await newPage(b, width, height)
  await p.goto(`${BASE}/znajdz-zawody/`)
  await toLomianki(p)
  await still(p)
  await openList(p)
  if (lang === 'en') { await p.locator('.modal-overlay .lang-btn[aria-label="English"]').first().click(); await p.waitForTimeout(700) }
  return p
}

// Signed in on the Ranking page, „Znajdź zawody”, Łomianki, the list.
async function adminList(b, width, height, lang) {
  const p = await newPage(b, width, height)
  await p.goto(`${BASE}/ranking/?admin=1`)
  await signIn(p)
  await p.waitForTimeout(800)
  await p.locator('header.site-bar .hamburger-btn').click()
  await p.waitForTimeout(600)
  await p.locator('.sidebar .nav-item', { hasText: 'Znajdź zawody' }).click()
  await p.waitForTimeout(600)
  await toLomianki(p)
  await still(p)
  await openList(p)
  if (lang === 'en') { await p.locator('.modal-overlay .lang-btn[aria-label="English"]').first().click(); await p.waitForTimeout(700) }
  return p
}

async function shot(p, name, width, height) {
  await p.mouse.move(width - 2, height - 2)
  await p.waitForTimeout(500)
  await p.screenshot({ path: path.join(OUT, name) })
}

function rowOf(p, surname) {
  return p.locator('tbody tr', { has: p.locator('td.el-name', { hasText: surname }) })
}

async function listFacts(p) {
  return {
    names: await p.locator('td.el-name').allInnerTexts(),
    editButtons: await p.locator('button.el-edit').count(),
    removeButtons: await p.locator('button.el-remove').count(),
    marks: await p.locator('.el-yeardiff').evaluateAll((els) => els.map((e) => e.closest('tr').querySelector('td.el-name').textContent.trim())),
    // I25: per row, is the name cut, would the browser draw „…” there, and do
    // the actions sit on a line below the name.
    rows: await p.locator('tbody tr').evaluateAll((trs) => trs.map((tr) => {
      const n = tr.querySelector('td.el-name')
      const cs = getComputedStyle(n)
      const act = tr.querySelector('td.el-act')
      return {
        name: n.textContent.trim(),
        cut: n.scrollWidth > n.clientWidth,
        ellipsis: cs.display === 'block' && cs.textOverflow === 'ellipsis',
        actionsBelow: act ? act.getBoundingClientRect().top >= n.getBoundingClientRect().bottom - 1 : null,
        chipsOnNameLine: tr.cells[1].getBoundingClientRect().top < n.getBoundingClientRect().bottom,
      }
    })),
    errors: p.errs,
  }
}

const SOFT = ['--disable-gpu', '--disable-partial-raster', '--disable-skia-runtime-opts', '--force-color-profile=srgb',
  '--disable-lcd-text', '--font-render-hinting=none', '--force-device-scale-factor=1',
  '--disable-features=LocalNetworkAccessChecks,PrivateNetworkAccessSendPreflights,BlockInsecurePrivateNetworkRequests']
const WIDTHS = { desktop: [1280, 1000], phone: [375, 812] }

;(async () => {
  const b = await chromium.launch({ args: SOFT })
  const report = []

  if (MODE === 'visitor' || MODE === 'admin') {
    for (const [w, [width, height]] of Object.entries(WIDTHS)) {
      for (const lang of ['pl', 'en']) {
        const p = MODE === 'visitor' ? await visitorList(b, width, height, lang) : await adminList(b, width, height, lang)
        await shot(p, `${MODE}__${w}__${lang}.png`, width, height)
        report.push({ tag: `${MODE}__${w}__${lang}`, ...(await listFacts(p)) })
        await p.close()
      }
    }
  }

  if (MODE === 'dialog') {
    for (const [w, [width, height]] of Object.entries(WIDTHS)) {
      for (const lang of w === 'desktop' ? ['pl', 'en'] : ['pl']) {
        const tag = `dialog__${w}__${lang}`
        const p = await adminList(b, width, height, lang)
        await rowOf(p, 'ZZSMITH').locator('button.el-edit').click()
        await p.locator('.ee').waitFor()
        await shot(p, `${tag}__1-newcomer.png`, width, height)
        const newcomer = {
          surname: await p.locator('.ee input[name="surname"]').inputValue(),
          locked: await p.locator('.ee input[name="surname"]').isDisabled(),
          year: await p.locator('.ee input[name="birthYear"]').inputValue(),
          club: await p.locator('.ee input[name="club"]').inputValue(),
          country: await p.locator('.ee input[name="country"]').inputValue(),
        }
        // A rename into the other newcomer's identity: the database refuses it.
        await p.locator('.ee input[name="surname"]').fill('ZZNOWICKA')
        await p.locator('.ee input[name="firstName"]').fill('Ewa')
        await p.locator('.ee select[name="gender"]').selectOption('F')
        await p.locator('.ee input[name="birthYear"]').fill('1970')
        await p.locator('.ee .ee-title').click()
        await p.locator('.ee button.ee-save').click()
        await p.locator('.ee-error').waitFor({ timeout: 15000 })
        await shot(p, `${tag}__2-refused.png`, width, height)
        const refused = (await p.locator('.ee-error').innerText()).trim()
        await p.locator('.ee button.ee-cancel').click()
        await rowOf(p, 'ZZROSTER').locator('button.el-edit').click()
        await p.locator('.ee').waitFor()
        await shot(p, `${tag}__3-linked.png`, width, height)
        const linked = {
          locked: await p.locator('.ee input[name="surname"]').isDisabled(),
          note: (await p.locator('.ee-locked').innerText()).trim(),
          roster: (await p.locator('.ee-roster-year').innerText()).trim(),
        }
        // 22 Nov addition: a changed year of a linked entry shows what the
        // roster will get (1975 → 1965 moves V2 to V3 in 2026/27). Not saved.
        await p.locator('.ee input[name="birthYear"]').fill('1965')
        await p.locator('.ee .ee-title').click()
        await shot(p, `${tag}__4-roster-change.png`, width, height)
        linked.change = (await p.locator('.ee-roster-year').innerText()).trim()
        linked.category = (await p.locator('.ee-roster-cat').innerText()).trim()
        await p.locator('.ee button.ee-cancel').click()
        report.push({ tag, newcomer, refused, linked, errors: p.errs })
        await p.close()
      }
    }
  }

  if (MODE === 'walk') {
    const p = await adminList(b, 1280, 1000, 'pl')
    report.push({ step: '1 signed in, the list', ...(await listFacts(p)) })
    await rowOf(p, 'ZZSMITH').locator('button.el-edit').click()
    const d = p.locator('.ee')
    await d.locator('input[name="birthYear"]').fill('1988')
    await d.locator('.ee-title').click()
    await d.locator('input[name="club"]').fill('Dublin FC')
    await d.locator('input[name="country"]').fill('irl')
    await d.locator('.cp-opt', { hasText: 'IRL' }).click()
    await p.screenshot({ path: path.join(OUT, 'walk-1-edited.png') })
    await d.locator('button.ee-save').click()
    await p.locator('.el-edit-done').waitFor({ timeout: 15000 })
    report.push({ step: '2 newcomer saved', done: (await p.locator('.el-edit-done').innerText()).trim(),
      flag: await rowOf(p, 'ZZSMITH').locator('.flag').getAttribute('aria-label') })
    await p.screenshot({ path: path.join(OUT, 'walk-2-saved.png') })
    await rowOf(p, 'ZZROSTER').locator('button.el-edit').click()
    // The roster follows (22 Nov addition): declared 1979, roster 1975; the
    // administrator sets 1965 and Ukraine, which the save copies to the roster.
    await d.locator('input[name="birthYear"]').fill('1965')
    await d.locator('.ee-title').click()
    await d.locator('input[name="country"]').fill('ukr')
    await d.locator('.cp-opt', { hasText: 'UKR' }).click()
    report.push({ step: '3 linked: year 1965, country UKR', roster: (await p.locator('.ee-roster-year').innerText()).trim(),
      category: (await p.locator('.ee-roster-cat').innerText()).trim() })
    await p.screenshot({ path: path.join(OUT, 'walk-3a-linked-edited.png') })
    await d.locator('button.ee-save').click()
    await p.locator('.el-edit-done').waitFor({ timeout: 15000 })
    await p.waitForTimeout(500)
    report.push({ step: '4 linked saved', done: (await p.locator('.el-edit-done').innerText()).trim(), ...(await listFacts(p)) })
    await p.screenshot({ path: path.join(OUT, 'walk-3-linked-saved.png') })
    await p.close()
  }

  fs.writeFileSync(path.join(OUT, `${MODE}-report.json`), JSON.stringify(report, null, 2))
  console.log(JSON.stringify(report, null, 1).slice(0, 3500))
  await b.close()
})()
